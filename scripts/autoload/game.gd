extends Node
## Глобальное состояние игры (автозагрузка Game): уровни, прогресс, рекорды, деньги,
## сложность повторных прохождений, недвижимость с улучшениями и настройки.
## Всё сохраняется в user://save.cfg.

signal settings_changed
signal economy_changed

const SAVE_PATH := "user://save.cfg"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const TOWN_INDEX := 4
const MAX_TIER := 10
const LEVELS := [
	{"title": "Подземка", "scene": "res://scenes/levels/level_1_underground.tscn", "reward": 150},
	{"title": "Метро", "scene": "res://scenes/levels/level_2_metro.tscn", "reward": 200},
	{"title": "Небоскрёб", "scene": "res://scenes/levels/level_3_skyscraper.tscn", "reward": 250},
	{"title": "Особняк", "scene": "res://scenes/levels/level_4_mansion.tscn", "reward": 300},
	{"title": "Город", "scene": "res://scenes/levels/level_5_town.tscn", "reward": 500},
]
## Недвижимость покупается по порядку: хибара → квартира → особняк.
## Улучшения видны внутри как мебель и дают бонусы (perk) во всех уровнях.
const PROPERTIES := [
	{"id": "shack", "title": "Хибара", "price": 1000, "upgrades": [
		{"id": "bed", "title": "Нормальная кровать", "price": 300, "perk": "max_health", "value": 10.0,
				"text": "+10 к здоровью"},
		{"id": "stash", "title": "Тайник с патронами", "price": 500, "perk": "ammo", "value": 0.25,
				"text": "+25% патронов в запасе"},
		{"id": "lamp", "title": "Генератор и лампа", "price": 400, "perk": "money", "value": 0.05,
				"text": "+5% денег за задания"},
	]},
	{"id": "apartment", "title": "Квартира", "price": 5000, "upgrades": [
		{"id": "gym", "title": "Тренажёр", "price": 1200, "perk": "max_health", "value": 15.0,
				"text": "+15 к здоровью"},
		{"id": "gun_cabinet", "title": "Оружейный шкаф", "price": 1500, "perk": "damage", "value": 0.1,
				"text": "+10% урона"},
		{"id": "tv", "title": "Телевизор и диван", "price": 1000, "perk": "money", "value": 0.1,
				"text": "+10% денег за задания"},
	]},
	{"id": "mansion", "title": "Особняк", "price": 15000, "upgrades": [
		{"id": "range", "title": "Тир в подвале", "price": 4000, "perk": "damage", "value": 0.1,
				"text": "+10% урона"},
		{"id": "armory", "title": "Гардероб с бронежилетами", "price": 5000, "perk": "armor", "value": 0.2,
				"text": "−20% получаемого урона"},
		{"id": "pool", "title": "Бассейн", "price": 6000, "perk": "max_health", "value": 20.0,
				"text": "+20 к здоровью"},
	]},
]

var settings := {
	"sensitivity": 1.0,
	"volume": 0.8,
	"aim_assist": true,
	"auto_fire": false,
	"shadows": true,
	"noir": true,
}
var unlocked_levels := 1
## Рекорды: индекс уровня -> {"time": секунды, "kills": убийства, "headshots": хедшоты}.
var records := {}
var money := 0
## Сколько раз пройден каждый уровень. Каждое прохождение повышает сложность и награду.
var completions := {}
## Город освобождён — эпизод пройден, город стал базой.
var town_liberated := false
var owned_properties: Array = []
var owned_upgrades: Array = []  # строки вида "shack/bed"
var current_level := -1
## Сложность текущего захода на уровень (0 — первое прохождение).
var current_tier := 0
## Тесты выключают запись на диск, чтобы не портить настоящее сохранение.
var save_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()
	apply_settings()


# --- Уровни ---------------------------------------------------------------------

func start_level(index: int) -> void:
	if index < 0 or index >= LEVELS.size():
		go_to_menu()
		return
	current_level = index
	current_tier = 0 if index == TOWN_INDEX else tier_of(index)
	_reset_runtime_state()
	get_tree().change_scene_to_file(LEVELS[index].scene)


func restart_level() -> void:
	if current_level >= 0:
		start_level(current_level)
	else:
		_reset_runtime_state()
		get_tree().reload_current_scene()


func go_to_menu() -> void:
	save_data()
	_reset_runtime_state()
	get_tree().change_scene_to_file(MENU_SCENE)


func go_to_town() -> void:
	save_data()
	start_level(TOWN_INDEX)


func has_next_level(index: int) -> bool:
	return index + 1 < LEVELS.size()


func is_level_unlocked(index: int) -> bool:
	return index < unlocked_levels


## Сложность уровня: сколько раз он уже пройден (не больше MAX_TIER).
func tier_of(index: int) -> int:
	return mini(int(completions.get(index, 0)), MAX_TIER)


func reward_multiplier(tier := -1) -> float:
	if tier < 0:
		tier = current_tier
	return (1.0 + 0.5 * tier) * (1.0 + perk("money"))


func level_reward(index: int, tier := -1) -> int:
	if tier < 0:
		tier = tier_of(index)
	return roundi(LEVELS[index].reward * reward_multiplier(tier))


## Множители для врагов на текущей сложности.
func enemy_health_multiplier() -> float:
	return 1.0 + 0.3 * current_tier


func enemy_damage_multiplier() -> float:
	return 1.0 + 0.2 * current_tier


## Награда за убийство. Возвращает, сколько денег начислено.
func reward_kill(headshot: bool) -> int:
	var amount := roundi((10 + (5 if headshot else 0)) * reward_multiplier())
	add_money(amount)
	return amount


## Итог уровня: {"record": новый рекорд времени, "reward": деньги за прохождение}.
func complete_level(index: int, time: float, kills: int, headshots: int) -> Dictionary:
	var reward := roundi(LEVELS[index].reward * reward_multiplier())
	add_money(reward)
	completions[index] = int(completions.get(index, 0)) + 1
	if index == TOWN_INDEX:
		town_liberated = true
	unlocked_levels = clampi(maxi(unlocked_levels, index + 2), 1, LEVELS.size())
	var best: Variant = records.get(index)
	var is_record: bool = best == null or time < float(best.time)
	if is_record:
		records[index] = {"time": time, "kills": kills, "headshots": headshots}
	save_data()
	return {"record": is_record, "reward": reward}


# --- Деньги и недвижимость ------------------------------------------------------

func add_money(amount: int) -> void:
	money = maxi(money + amount, 0)
	economy_changed.emit()


func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	economy_changed.emit()
	save_data()
	return true


func property(id: String) -> Dictionary:
	for item in PROPERTIES:
		if item.id == id:
			return item
	return {}


func owns_property(id: String) -> bool:
	return id in owned_properties


## Купить можно только по порядку: сначала хибару, потом квартиру, потом особняк.
func is_property_available(id: String) -> bool:
	for i in PROPERTIES.size():
		if PROPERTIES[i].id == id:
			return i == 0 or owns_property(PROPERTIES[i - 1].id)
	return false


func buy_property(id: String) -> bool:
	var item := property(id)
	if item.is_empty() or owns_property(id) or not is_property_available(id):
		return false
	if not spend(int(item.price)):
		return false
	owned_properties.append(id)
	save_data()
	economy_changed.emit()
	return true


func has_upgrade(property_id: String, upgrade_id: String) -> bool:
	return "%s/%s" % [property_id, upgrade_id] in owned_upgrades


func buy_upgrade(property_id: String, upgrade_id: String) -> bool:
	if not owns_property(property_id) or has_upgrade(property_id, upgrade_id):
		return false
	for upgrade in property(property_id).get("upgrades", []):
		if upgrade.id == upgrade_id:
			if not spend(int(upgrade.price)):
				return false
			owned_upgrades.append("%s/%s" % [property_id, upgrade_id])
			save_data()
			economy_changed.emit()
			return true
	return false


## Сумма бонусов купленных улучшений: max_health, damage, armor, ammo, money.
func perk(name: String) -> float:
	var total := 0.0
	for item in PROPERTIES:
		for upgrade in item.upgrades:
			if upgrade.perk == name and has_upgrade(item.id, upgrade.id):
				total += float(upgrade.value)
	return total


## Самое дорогое жильё игрока — там он появляется в городе.
func home_property() -> String:
	var home := ""
	for item in PROPERTIES:
		if owns_property(item.id):
			home = item.id
	return home


# --- Настройки и сохранение ---------------------------------------------------------

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save_data()
	settings_changed.emit()


func apply_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	var volume := float(settings.volume)
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))


func save_data() -> void:
	if not save_enabled:
		return
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("settings", key, settings[key])
	config.set_value("progress", "unlocked_levels", unlocked_levels)
	config.set_value("progress", "money", money)
	config.set_value("progress", "town_liberated", town_liberated)
	config.set_value("progress", "properties", owned_properties)
	config.set_value("progress", "upgrades", owned_upgrades)
	for index in records:
		config.set_value("records", str(index), records[index])
	for index in completions:
		config.set_value("completions", str(index), completions[index])
	config.save(SAVE_PATH)


func load_data() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for key in settings:
		settings[key] = config.get_value("settings", key, settings[key])
	unlocked_levels = clampi(int(config.get_value("progress", "unlocked_levels", 1)), 1, LEVELS.size())
	money = int(config.get_value("progress", "money", 0))
	town_liberated = bool(config.get_value("progress", "town_liberated", false))
	owned_properties = Array(config.get_value("progress", "properties", []))
	owned_upgrades = Array(config.get_value("progress", "upgrades", []))
	for index in LEVELS.size():
		var record: Variant = config.get_value("records", str(index), null)
		if record is Dictionary:
			records[index] = record
		completions[index] = int(config.get_value("completions", str(index), 0))


## Сброс прогресса (для тестов).
func reset_progress() -> void:
	unlocked_levels = 1
	records = {}
	money = 0
	completions = {}
	town_liberated = false
	owned_properties = []
	owned_upgrades = []
	economy_changed.emit()


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


func _reset_runtime_state() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
