class_name Level
extends Node3D
## Корень уровня: связывает игрока, HUD и места с волнами, считает время,
## убийства и хедшоты, показывает итог и открывает следующий уровень.

@export var level_index := 0
@export var title := "Подземка"
@export var objective := "Найдите выход"
@export var start_weapons: Array[WeaponData] = []

var kills := 0
var headshots := 0
var time := 0.0

var _finished := false

@onready var player: Player = $Player
@onready var hud: Hud = $HUD


func _ready() -> void:
	add_to_group("level")
	Game.current_level = level_index
	Engine.time_scale = 1.0
	for weapon in start_weapons:
		player.give_weapon(weapon, false)
	if not player.weapons.is_empty():
		player.switch_weapon_to(player.weapons[0])
	hud.bind_player(player)
	hud.restart_requested.connect(Game.restart_level)
	hud.menu_requested.connect(Game.go_to_menu)
	hud.town_requested.connect(Game.go_to_town)
	hud.next_requested.connect(_on_next_requested)
	hud.set_town_available(Game.latest_city() >= 0 and not Game.is_city(level_index))
	player.died.connect(_on_player_died)

	for zone in find_children("*", "WaveZone"):
		zone.started.connect(_on_zone_started)
		zone.wave_started.connect(_on_wave_started)
		zone.cleared.connect(_on_zone_cleared)

	var shadows: bool = Game.settings.get("shadows", true)
	for light in find_children("*", "DirectionalLight3D"):
		(light as DirectionalLight3D).shadow_enabled = shadows

	Audio.play_music("music_explore")
	var tier: int = Game.current_tier
	hud.show_message(title, objective if tier == 0 else "Сложность %d · награда ×%.1f" % [tier + 1, Game.reward_multiplier()])
	hud.set_objective(objective)


func _process(delta: float) -> void:
	if not _finished and player.is_alive():
		time += delta


func register_kill(headshot: bool) -> void:
	kills += 1
	if headshot:
		headshots += 1
	hud.set_kills(kills)
	hud.show_money_popup(Game.reward_kill(headshot))


func complete() -> void:
	if _finished or not player.is_alive():
		return
	_finished = true
	var result := Game.complete_level(level_index, time, kills, headshots)
	Audio.stop_music()
	Audio.play("level_complete")
	var next_text := ""
	if _continues_episode():
		next_text = "Следующий уровень"
	elif Game.latest_city() >= 0:
		next_text = "В город"
	var heading := "%s пройден!" % title
	if Game.is_episode_finale(level_index):
		heading = "Эпизод %d пройден!" % Game.episode_of(level_index)
	hud.show_level_complete(heading, time, kills, headshots, result.reward, result.record, next_text)


func _on_next_requested() -> void:
	if _continues_episode():
		Game.start_level(level_index + 1)
	else:
		Game.go_to_town(Game.city_of(level_index))


## Уровень ведёт к следующему уровню того же эпизода (а не обратно в город).
func _continues_episode() -> bool:
	if Game.is_episode_finale(level_index) or not Game.has_next_level(level_index):
		return false
	return not Game.is_liberated(Game.city_of(level_index))


func _on_player_died() -> void:
	Audio.stop_music()
	Game.save_data()
	get_tree().create_timer(1.5, false).timeout.connect(hud.show_game_over)


## Босс побеждён: либо уровень пройден сразу, либо открывается выход.
## Босс заметил игрока — играет музыка боя.
func on_boss_fight(_boss: Boss) -> void:
	Audio.play_music("music_combat")


func on_boss_defeated(boss: Boss) -> void:
	Audio.play_music("music_explore")
	if boss.completes_level:
		get_tree().create_timer(3.0, false).timeout.connect(complete)
	else:
		hud.set_objective(objective)


func _on_zone_started(zone: WaveZone) -> void:
	Audio.play_music("music_combat")
	hud.show_message(zone.title, "Продержитесь!")


func _on_wave_started(_zone: WaveZone, wave: int, total: int) -> void:
	hud.set_objective("Волна %d из %d" % [wave, total])


func _on_zone_cleared(_zone: WaveZone) -> void:
	Audio.play_music("music_explore")
	hud.show_message("Чисто!", "Проход открыт")
	hud.set_objective(objective)
