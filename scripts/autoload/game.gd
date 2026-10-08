extends Node
## Глобальное состояние игры (автозагрузка Game): список уровней, прогресс,
## рекорды и настройки. Всё сохраняется в user://save.cfg.

signal settings_changed

const SAVE_PATH := "user://save.cfg"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const LEVELS := [
	{"title": "Подземка", "scene": "res://scenes/levels/level_1_underground.tscn"},
	{"title": "Метро", "scene": "res://scenes/levels/level_2_metro.tscn"},
	{"title": "Небоскрёб", "scene": "res://scenes/levels/level_3_skyscraper.tscn"},
]

var settings := {
	"sensitivity": 1.0,
	"volume": 0.8,
	"aim_assist": true,
	"auto_fire": false,
	"shadows": true,
}
var unlocked_levels := 1
## Рекорды: индекс уровня -> {"time": секунды, "kills": убийства, "headshots": хедшоты}.
var records := {}
var current_level := -1
## Тесты выключают запись на диск, чтобы не портить настоящее сохранение.
var save_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()
	apply_settings()


func start_level(index: int) -> void:
	if index < 0 or index >= LEVELS.size():
		go_to_menu()
		return
	current_level = index
	_reset_runtime_state()
	get_tree().change_scene_to_file(LEVELS[index].scene)


func restart_level() -> void:
	if current_level >= 0:
		start_level(current_level)
	else:
		_reset_runtime_state()
		get_tree().reload_current_scene()


func has_next_level(index: int) -> bool:
	return index + 1 < LEVELS.size()


func go_to_menu() -> void:
	_reset_runtime_state()
	get_tree().change_scene_to_file(MENU_SCENE)


func is_level_unlocked(index: int) -> bool:
	return index < unlocked_levels


## Возвращает true, если поставлен новый рекорд времени.
func complete_level(index: int, time: float, kills: int, headshots: int) -> bool:
	unlocked_levels = clampi(maxi(unlocked_levels, index + 2), 1, LEVELS.size())
	var best: Variant = records.get(index)
	var is_record: bool = best == null or time < float(best.time)
	if is_record:
		records[index] = {"time": time, "kills": kills, "headshots": headshots}
	save_data()
	return is_record


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
	for index in records:
		config.set_value("records", str(index), records[index])
	config.save(SAVE_PATH)


func load_data() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for key in settings:
		settings[key] = config.get_value("settings", key, settings[key])
	unlocked_levels = clampi(int(config.get_value("progress", "unlocked_levels", 1)), 1, LEVELS.size())
	for index in LEVELS.size():
		var record: Variant = config.get_value("records", str(index), null)
		if record is Dictionary:
			records[index] = record


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


func _reset_runtime_state() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
