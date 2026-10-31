extends Level
## Город — финал эпизода (первый город, Сан-Франциско, Аляска). В первый раз его нужно
## освободить от банды: зачистить три района (места с волнами), после чего эпизод пройден.
## Потом город становится базой: враги исчезают, открываются входы на уровни эпизода
## (повторные прохождения сложнее и дороже), продаётся недвижимость, летают самолёты.

var hub_mode := false
var _districts_left := 0


func _ready() -> void:
	hub_mode = Game.is_liberated(level_index)
	if hub_mode:
		_enter_hub_mode()
	for entrance in find_children("*", "LevelEntrance"):
		var level_entrance := entrance as LevelEntrance
		level_entrance.active = hub_mode and Game.is_level_unlocked(level_entrance.level_index)
	for point in find_children("*", "TravelPoint"):
		var travel := point as TravelPoint
		travel.active = hub_mode and Game.is_episode_open(travel.episode)
	_districts_left = find_children("*", "WaveZone").size()
	super._ready()
	if hub_mode:
		hud.set_kills_visible(false)
		hud.show_message("Город", _hub_hint())
		Audio.play_music("music_menu")
	else:
		hud.set_objective("Освободите город: осталось районов — %d" % _districts_left)


## Подсказка на базе: если открыт следующий эпизод, а его город ещё не освобождён — лететь туда.
func _hub_hint() -> String:
	for i in Game.EPISODES.size():
		var episode: Dictionary = Game.EPISODES[i]
		if int(episode.city) != level_index and Game.is_episode_open(i + 1) and not Game.is_liberated(int(episode.city)):
			return "%s: летите из аэропорта" % episode.title
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
	title = String(Game.LEVELS[level_index].title)
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
	var home := Game.home_property(level_index)
	if home != "":
		var property := get_node_or_null("Properties/" + home) as Property
		if property and property.get_spawn():
			start = property.get_spawn()
	if start:
		player.global_position = start.global_position
		player.camera_rig.set_yaw(start.global_rotation.y)
		player.reset_physics_interpolation()
		player.camera_rig.snap_to_target()
