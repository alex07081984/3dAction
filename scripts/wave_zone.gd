class_name WaveZone
extends Area3D
## Место с волнами врагов. Когда игрок заходит в зону, проходы закрываются
## (узлы в «Barriers» становятся видимыми и твёрдыми), и из точек в «Spawns»
## идут волны. После последней волны проходы открываются.

signal started(zone: WaveZone)
signal wave_started(zone: WaveZone, wave: int, total: int)
signal cleared(zone: WaveZone)

@export var title := "Засада!"
@export var waves := 2
@export var enemies_in_first_wave := 4
@export var extra_per_wave := 2
@export_range(0.0, 1.0) var rusher_share := 0.3
@export var heavy_in_last_wave := 0  ## Сколько громил в последней волне.
@export var gunner_scene: PackedScene
@export var rusher_scene: PackedScene
@export var heavy_scene: PackedScene
@export var spawn_interval := 0.45
@export var pause_between_waves := 1.8

var active := false
var done := false
var wave := 0

var _alive := 0

@onready var _spawns: Node = $Spawns
@onready var _barriers: Node = $Barriers


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	_set_barriers(false)


func start() -> void:
	if active or done:
		return
	active = true
	_set_barriers(true)
	Audio.play("alarm", -4.0)
	started.emit(self)
	_next_wave()


func _on_body_entered(body: Node) -> void:
	if body is Player and (body as Player).is_alive():
		start()


func _next_wave() -> void:
	if not is_inside_tree():
		return
	wave += 1
	# На повторных прохождениях в каждой волне больше врагов.
	var count := enemies_in_first_wave + (wave - 1) * extra_per_wave + Game.current_tier
	_alive = count
	wave_started.emit(self, wave, waves)
	var points := _spawns.get_children()
	for i in count:
		var scene := gunner_scene
		if wave == waves and i < heavy_in_last_wave + int(Game.current_tier / 3.0) and heavy_scene:
			scene = heavy_scene
		elif randf() < rusher_share and rusher_scene:
			scene = rusher_scene
		var point := points[i % points.size()] as Node3D
		get_tree().create_timer(spawn_interval * i, false).timeout.connect(_spawn.bind(scene, point))


func _spawn(scene: PackedScene, point: Node3D) -> void:
	var enemy := scene.instantiate() as Enemy
	enemy.alerted = true
	enemy.hold_position = false
	enemy.drop_ammo_chance = 0.35
	enemy.died.connect(_on_enemy_died)
	var container := get_tree().current_scene.get_node_or_null("Enemies")
	if container == null:
		container = get_tree().current_scene
	container.add_child(enemy)
	var jitter := Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8))
	enemy.global_position = point.global_position + jitter
	enemy.rotation.y = point.global_rotation.y
	enemy.reset_physics_interpolation()


func _on_enemy_died(_enemy: Enemy, _headshot: bool) -> void:
	_alive -= 1
	if _alive > 0 or not active:
		return
	if wave < waves:
		get_tree().create_timer(pause_between_waves, false).timeout.connect(_next_wave)
	else:
		active = false
		done = true
		_set_barriers(false)
		Audio.play("door", -2.0)
		cleared.emit(self)


func _set_barriers(closed: bool) -> void:
	for barrier in _barriers.get_children():
		if barrier is Node3D:
			barrier.visible = closed
		if barrier is CSGShape3D:
			barrier.use_collision = closed
		elif barrier is CollisionObject3D:
			barrier.collision_layer = 1 if closed else 0
