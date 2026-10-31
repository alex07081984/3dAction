extends Level
## Город — финал первого эпизода. В первый раз его нужно освободить от банды:
## зачистить три района (места с волнами), после чего эпизод пройден.
## Потом город становится базой: враги исчезают, открываются входы на уровни
## (повторные прохождения сложнее и дороже) и продаётся недвижимость.

var hub_mode := false
var _districts_left := 0


func _ready() -> void:
	hub_mode = Game.town_liberated
	if hub_mode:
		_enter_hub_mode()
	for entrance in find_children("*", "LevelEntrance"):
		var level_entrance := entrance as LevelEntrance
		level_entrance.active = hub_mode and Game.is_level_unlocked(level_entrance.level_index)
	_districts_left = find_children("*", "WaveZone").size()
	super._ready()
	if hub_mode:
		hud.set_kills_visible(false)
		hud.show_message("Город", _hub_hint())
		Audio.play_music("music_menu")
	else:
		hud.set_objective("Освободите город: осталось районов — %d" % _districts_left)


## Подсказка на базе: куда идти дальше по эпизоду 2.
func _hub_hint() -> String:
	var hints := {5: "Эпизод 2: автобус в порт — восточный конец главной улицы",
			6: "Эпизод 2: казино «Фортуна» — западный конец главной улицы",
			7: "Эпизод 2: автобус в тюрьму — северный конец улицы у мэрии"}
	for index in [5, 6, 7]:
		if Game.is_level_unlocked(index) and not Game.records.has(index):
			return hints[index]
	return "Ваша база: задания и недвижимость"


func _on_zone_cleared(_zone: WaveZone) -> void:
	Audio.play_music("music_explore")
	_districts_left -= 1
	if _districts_left > 0:
		hud.show_message("Район освобождён!", "Осталось районов: %d" % _districts_left)
		hud.set_objective("Освободите город: осталось районов — %d" % _districts_left)
	else:
		hud.show_message("Город свободен!", "")
		get_tree().create_timer(2.5, false).timeout.connect(complete)


func _enter_hub_mode() -> void:
	title = "Город"
	objective = "База: задания и жильё"
	for path in ["Enemies", "Pickups"]:
		var node := get_node_or_null(path)
		if node:
			remove_child(node)
			node.queue_free()
	for zone in find_children("*", "WaveZone"):
		zone.get_parent().remove_child(zone)
		zone.queue_free()
	var start := get_node_or_null("HubStart") as Node3D
	var home := Game.home_property()
	if home != "":
		var property := get_node_or_null("Properties/" + home) as Property
		if property and property.get_spawn():
			start = property.get_spawn()
	if start:
		player.global_position = start.global_position
		player.camera_rig.set_yaw(start.global_rotation.y)
		player.reset_physics_interpolation()
		player.camera_rig.snap_to_target()
