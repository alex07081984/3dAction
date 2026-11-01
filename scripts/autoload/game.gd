extends Node
## Глобальное состояние игры (автозагрузка Game): уровни, прогресс, рекорды, деньги,
## сложность повторных прохождений, недвижимость с улучшениями и настройки.
## Всё сохраняется в user://save.cfg.

signal settings_changed
signal economy_changed

const SAVE_PATH := "user://save.cfg"
## Версия сохранения. 2 — в эпизод 2 добавлен уровень на вертолёте (номер 9),
## номера уровней после него сдвинулись на один.
const SAVE_VERSION := 2
const MENU_SCENE := "res://scenes/main_menu.tscn"
const TOWN_INDEX := 4
const MAX_TIER := 10
const LEVELS := [
	{"title": "Подземка", "scene": "res://scenes/levels/level_1_underground.tscn", "reward": 150},
	{"title": "Метро", "scene": "res://scenes/levels/level_2_metro.tscn", "reward": 200},
	{"title": "Небоскрёб", "scene": "res://scenes/levels/level_3_skyscraper.tscn", "reward": 250},
	{"title": "Особняк", "scene": "res://scenes/levels/level_4_mansion.tscn", "reward": 300},
	{"title": "Город", "scene": "res://scenes/levels/level_5_town.tscn", "reward": 500},
	# Эпизод 2: открывается после освобождения города, входы — на окраинах города.
	{"title": "Порт", "scene": "res://scenes/levels/level_6_port.tscn", "reward": 400},
	{"title": "Казино", "scene": "res://scenes/levels/level_7_casino.tscn", "reward": 450},
	{"title": "Алькатрас", "scene": "res://scenes/levels/level_8_prison.tscn", "reward": 600},
	{"title": "Мост Золотые Ворота", "scene": "res://scenes/levels/level_9_bridge.tscn", "reward": 700},
	{"title": "Вертолёт над заливом", "scene": "res://scenes/levels/level_heli_bay.tscn", "reward": 800},
	{"title": "Сан-Франциско", "scene": "res://scenes/levels/level_10_san_francisco.tscn", "reward": 900},
	# Эпизод 3: Аляска.
	{"title": "Золотой прииск", "scene": "res://scenes/levels/level_11_gold_mine.tscn", "reward": 800},
	{"title": "Заброшенный городок", "scene": "res://scenes/levels/level_12_ghost_town.tscn", "reward": 1000},
	{"title": "Аляска", "scene": "res://scenes/levels/level_13_alaska.tscn", "reward": 1200},
]
## Эпизоды: уровни идут по порядку с first до city, а город в конце нужно освободить —
## после этого он становится базой с входами на уровни эпизода. Между базами летают самолёты.
const EPISODES := [
	{"title": "Эпизод 1", "first": 0, "city": 4},
	{"title": "Эпизод 2 · Сан-Франциско", "first": 5, "city": 10},
	{"title": "Эпизод 3 · Аляска", "first": 11, "city": 13},
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
	{"id": "flat", "city": 10, "title": "Квартира в викторианском доме", "price": 8000, "upgrades": [
		{"id": "espresso", "title": "Кофемашина", "price": 2000, "perk": "money", "value": 0.1,
				"text": "+10% денег за задания"},
		{"id": "magnum_safe", "title": "Сейф с патронами .44", "price": 2500, "perk": "ammo", "value": 0.25,
				"text": "+25% патронов в запасе"},
		{"id": "punching_bag", "title": "Боксёрская груша", "price": 3000, "perk": "max_health", "value": 15.0,
				"text": "+15 к здоровью"},
	]},
	{"id": "cabin", "city": 13, "title": "Бревенчатый дом у озера", "price": 12000, "upgrades": [
		{"id": "stove", "title": "Печь и медвежья шкура", "price": 3000, "perk": "max_health", "value": 15.0,
				"text": "+15 к здоровью"},
		{"id": "workbench", "title": "Верстак оружейника", "price": 4500, "perk": "damage", "value": 0.1,
				"text": "+10% урона"},
		{"id": "gold_pan", "title": "Лоток старателя", "price": 3500, "perk": "money", "value": 0.1,
				"text": "+10% денег за задания"},
	]},
]

var settings := {
	"sensitivity": 1.0,
	"volume": 0.8,
	"aim_assist": true,
	"auto_fire": false,
	"shadows": true,
	"noir": true,
	"music": true,
	"blood": true,
}
var unlocked_levels := 1
## Рекорды: индекс уровня -> {"time": секунды, "kills": убийства, "headshots": хедшоты}.
var records := {}
## Лучшие звёзды за уровень (1–3): индекс уровня -> число.
var stars := {}
## Замедление времени после эффектных убийств (тесты его выключают).
var slowmo_enabled := true
## Режим ярости: всё вокруг замедляется.
var bullet_time := false
var money := 0
## Сколько раз пройден каждый уровень. Каждое прохождение повышает сложность и награду.
var completions := {}
## Город освобождён — эпизод пройден, город стал базой.
var town_liberated := false
## Освобождённые города следующих эпизодов (номера уровней-городов).
var liberated_cities: Array = []
var owned_properties: Array = []
var owned_upgrades: Array = []  # строки вида "shack/bed"
var current_level := -1
## Сложность текущего захода на уровень (0 — первое прохождение).
var current_tier := 0
## Тесты выключают запись на диск, чтобы не портить настоящее сохранение.
var save_enabled := true

var _slowmo_left := 0.0
var _slowmo_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()
	apply_settings()


func _process(delta: float) -> void:
	# Время замедления считаем по настоящим часам, а не по игровым.
	var real := delta / maxf(Engine.time_scale, 0.01)
	if _slowmo_left > 0.0 and not get_tree().paused:
		_slowmo_left -= real
	var target := 1.0
	if bullet_time:
		target = 0.45
	if _slowmo_left > 0.0:
		target = minf(target, _slowmo_scale)
	if not is_equal_approx(Engine.time_scale, target):
		Engine.time_scale = target
		AudioServer.playback_speed_scale = lerpf(1.0, target, 0.6)


## Кинематографичное замедление на долю секунды (последний враг волны, босс повержен).
func slow_motion(seconds := 0.9, scale := 0.25) -> void:
	if not slowmo_enabled:
		return
	_slowmo_left = maxf(_slowmo_left, seconds)
	_slowmo_scale = scale


## Много крови: куски тел, оторванные руки, пятна на стенах (выключается в настройках).
func gore() -> bool:
	return bool(settings.get("blood", true))


func stars_of(index: int) -> int:
	return int(stars.get(index, 0))


# --- Уровни ---------------------------------------------------------------------

func start_level(index: int) -> void:
	if index < 0 or index >= LEVELS.size():
		go_to_menu()
		return
	current_level = index
	current_tier = 0 if is_city(index) else tier_of(index)
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


## В город-базу: в указанный, иначе в город текущего эпизода, иначе в последний освобождённый.
func go_to_town(city := -1) -> void:
	save_data()
	if city < 0 or not is_liberated(city):
		city = city_of(current_level) if current_level >= 0 and is_liberated(city_of(current_level)) else latest_city()
	start_level(maxi(city, TOWN_INDEX))


## Номер эпизода (с 1).
func episode_of(index: int) -> int:
	for i in EPISODES.size():
		if index <= int(EPISODES[i].city):
			return i + 1
	return EPISODES.size()


func city_of(index: int) -> int:
	return int(EPISODES[episode_of(index) - 1].city)


func is_city(index: int) -> bool:
	for episode in EPISODES:
		if int(episode.city) == index:
			return true
	return false


func is_liberated(city: int) -> bool:
	return town_liberated if city == TOWN_INDEX else city in liberated_cities


## Последний освобождённый город (-1 — ещё ни одного).
func latest_city() -> int:
	var best := -1
	for episode in EPISODES:
		if is_liberated(int(episode.city)):
			best = int(episode.city)
	return best


## Финал эпизода — освобождение города: после него «Эпизод пройден!».
func is_episode_finale(index: int) -> bool:
	return is_city(index)


## Куда ведёт перелёт в эпизод: в освобождённый город или на первый непройденный уровень.
func travel_target(episode: int) -> int:
	var data: Dictionary = EPISODES[episode - 1]
	if is_liberated(int(data.city)):
		return int(data.city)
	return clampi(unlocked_levels - 1, int(data.first), int(data.city))


func is_episode_open(episode: int) -> bool:
	return episode >= 1 and episode <= EPISODES.size() and is_level_unlocked(int(EPISODES[episode - 1].first))


func travel(episode: int) -> void:
	var target := travel_target(episode)
	if is_city(target) and is_liberated(target):
		go_to_town(target)
	else:
		save_data()
		start_level(target)


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


## Награда за убийство (combo — множитель серии убийств). Возвращает, сколько денег начислено.
func reward_kill(headshot: bool, combo := 1) -> int:
	var amount := roundi((10 + (5 if headshot else 0)) * reward_multiplier() * maxi(combo, 1))
	add_money(amount)
	return amount


## Итог уровня: {"record": новый рекорд времени, "reward": деньги за прохождение}.
func complete_level(index: int, time: float, kills: int, headshots: int, earned_stars := 1) -> Dictionary:
	var reward := roundi(LEVELS[index].reward * reward_multiplier())
	add_money(reward)
	completions[index] = int(completions.get(index, 0)) + 1
	if index == TOWN_INDEX:
		town_liberated = true
	elif is_city(index) and not index in liberated_cities:
		liberated_cities.append(index)
	unlocked_levels = clampi(maxi(unlocked_levels, index + 2), 1, LEVELS.size())
	stars[index] = maxi(stars_of(index), clampi(earned_stars, 0, 3))
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


## В первом городе жильё покупается по порядку: хибара, квартира, особняк.
## В других городах — как только город освобождён.
func is_property_available(id: String) -> bool:
	for i in PROPERTIES.size():
		if PROPERTIES[i].id != id:
			continue
		var city := property_city(id)
		if city != TOWN_INDEX:
			return is_liberated(city)
		return i == 0 or owns_property(PROPERTIES[i - 1].id)
	return false


func property_city(id: String) -> int:
	return int(property(id).get("city", TOWN_INDEX))


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


## Самое дорогое жильё игрока в этом городе — там он появляется.
func home_property(city := TOWN_INDEX) -> String:
	var home := ""
	for item in PROPERTIES:
		if owns_property(item.id) and int(item.get("city", TOWN_INDEX)) == city:
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
	config.set_value("progress", "save_version", SAVE_VERSION)
	config.set_value("progress", "unlocked_levels", unlocked_levels)
	config.set_value("progress", "liberated_cities", liberated_cities)
	config.set_value("progress", "money", money)
	config.set_value("progress", "town_liberated", town_liberated)
	config.set_value("progress", "properties", owned_properties)
	config.set_value("progress", "upgrades", owned_upgrades)
	for index in records:
		config.set_value("records", str(index), records[index])
	for index in completions:
		config.set_value("completions", str(index), completions[index])
	for index in stars:
		config.set_value("stars", str(index), stars[index])
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
	liberated_cities = Array(config.get_value("progress", "liberated_cities", []))
	owned_properties = Array(config.get_value("progress", "properties", []))
	owned_upgrades = Array(config.get_value("progress", "upgrades", []))
	for index in LEVELS.size():
		var record: Variant = config.get_value("records", str(index), null)
		if record is Dictionary:
			records[index] = record
		completions[index] = int(config.get_value("completions", str(index), 0))
		if config.has_section_key("stars", str(index)):
			stars[index] = int(config.get_value("stars", str(index), 0))
	var version := int(config.get_value("progress", "save_version", 1))
	if version < 2:
		_insert_level(9)


## Старое сохранение: перед уровнем at вставлен новый — сдвигаем номера уровней.
func _insert_level(at: int) -> void:
	var shift := func(index: int) -> int: return index + 1 if index >= at else index
	for table in [records, completions, stars]:
		var moved := {}
		for index in table:
			moved[shift.call(int(index))] = table[index]
		table.clear()
		table.merge(moved)
	liberated_cities = liberated_cities.map(func(city: Variant) -> int: return shift.call(int(city)))
	if unlocked_levels > at:
		unlocked_levels = mini(unlocked_levels + 1, LEVELS.size())


## Сброс прогресса (для тестов).
func reset_progress() -> void:
	unlocked_levels = 1
	records = {}
	stars = {}
	money = 0
	completions = {}
	town_liberated = false
	liberated_cities = []
	owned_properties = []
	owned_upgrades = []
	economy_changed.emit()


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


func _reset_runtime_state() -> void:
	get_tree().paused = false
	bullet_time = false
	_slowmo_left = 0.0
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
