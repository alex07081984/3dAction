extends Node3D
## Главная сцена: запускает волны врагов, связывает игрока с HUD, перезапускает уровень.

@export var enemy_scene: PackedScene
@export var first_wave_size := 3
@export var enemies_per_wave := 2  ## На сколько врагов больше в каждой следующей волне.
@export var heal_per_wave := 3
@export var time_between_waves := 2.5
@export var speed_bonus_per_wave := 0.15

var _wave := 0
var _alive := 0

@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD
@onready var _spawn_points: Node3D = $SpawnPoints
@onready var _enemies: Node3D = $Enemies


func _ready() -> void:
	Engine.time_scale = 1.0
	_player.health_changed.connect(_hud.set_health)
	_player.died.connect(_on_player_died)
	_hud.set_health(_player.health, _player.max_health)
	_hud.restart_requested.connect(_restart)
	_hud.set_wave(0)
	_hud.set_enemies_left(0)
	_after(1.0, _start_next_wave)


func _start_next_wave() -> void:
	if not _player.is_alive():
		return
	_wave += 1
	if _wave > 1:
		_player.heal(heal_per_wave)
	_hud.set_wave(_wave)
	_hud.show_message("Волна %d" % _wave)

	var count := first_wave_size + (_wave - 1) * enemies_per_wave
	_alive = count
	_hud.set_enemies_left(_alive)
	var points := _spawn_points.get_children()
	for i in count:
		var point := points[i % points.size()] as Node3D
		# Враги появляются по очереди, а не все в один кадр.
		_after(0.3 * i, _spawn_enemy.bind(point.global_position))


func _spawn_enemy(at: Vector3) -> void:
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.position = at + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
	enemy.move_speed += speed_bonus_per_wave * (_wave - 1)
	enemy.died.connect(_on_enemy_died)
	_enemies.add_child(enemy)


func _on_enemy_died(_enemy: Enemy) -> void:
	_alive = maxi(_alive - 1, 0)
	_hud.set_enemies_left(_alive)
	if _alive == 0 and _player.is_alive():
		_hud.show_message("Волна пройдена!")
		_after(time_between_waves, _start_next_wave)


func _on_player_died() -> void:
	_after(1.2, _hud.show_game_over.bind(_wave))


func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


## Вызывает функцию через delay секунд. Таймер стоит на паузе вместе с игрой,
## а если сцена перезапустится раньше — вызов просто отменится.
func _after(delay: float, callback: Callable) -> void:
	get_tree().create_timer(delay, false).timeout.connect(callback)
