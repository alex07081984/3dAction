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
		(entrance as LevelEntrance).active = hub_mode
	_districts_left = find_children("*", "WaveZone").size()
	super._ready()
	if hub_mode:
		hud.set_kills_visible(false)
		hud.show_message("Город", "Ваша база: задания и недвижимость")
	else:
		hud.set_objective("Освободите город: осталось районов — %d" % _districts_left)


func _on_zone_cleared(_zone: WaveZone) -> void:
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
