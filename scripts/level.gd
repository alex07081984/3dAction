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
	hud.next_requested.connect(func() -> void: Game.start_level(level_index + 1))
	player.died.connect(_on_player_died)

	for zone in find_children("*", "WaveZone"):
		zone.started.connect(_on_zone_started)
		zone.wave_started.connect(_on_wave_started)
		zone.cleared.connect(_on_zone_cleared)

	var shadows: bool = Game.settings.get("shadows", true)
	for light in find_children("*", "DirectionalLight3D"):
		(light as DirectionalLight3D).shadow_enabled = shadows

	hud.show_message(title, objective)


func _process(delta: float) -> void:
	if not _finished and player.is_alive():
		time += delta


func register_kill(headshot: bool) -> void:
	kills += 1
	if headshot:
		headshots += 1
	hud.set_kills(kills)


func complete() -> void:
	if _finished or not player.is_alive():
		return
	_finished = true
	var record := Game.complete_level(level_index, time, kills, headshots)
	Audio.play("level_complete")
	hud.show_level_complete(title, time, kills, headshots, record, Game.has_next_level(level_index))


func _on_player_died() -> void:
	get_tree().create_timer(1.5, false).timeout.connect(hud.show_game_over)


func _on_zone_started(zone: WaveZone) -> void:
	hud.show_message(zone.title, "Продержитесь!")


func _on_wave_started(_zone: WaveZone, wave: int, total: int) -> void:
	hud.set_objective("Волна %d из %d" % [wave, total])


func _on_zone_cleared(_zone: WaveZone) -> void:
	hud.show_message("Чисто!", "Проход открыт")
	hud.set_objective(objective)
