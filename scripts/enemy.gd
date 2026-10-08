class_name Enemy
extends CharacterBody3D
## Простой враг ближнего боя.
## Идёт к игроку, перед ударом заметно замахивается (светится и откидывается назад),
## чтобы игрок успел отпрыгнуть или сделать рывок. Получив удар, теряет замах.

signal died(enemy: Enemy)

enum State { IDLE, CHASE, WINDUP, RECOVER, HURT, DEAD }

@export var max_health := 4
@export var move_speed := 3.8
@export var acceleration := 20.0
@export var turn_speed := 8.0
@export var detect_radius := 40.0
@export var attack_range := 1.7
@export var attack_damage := 1
@export var windup_time := 0.6
@export var recover_time := 0.8
@export var hurt_time := 0.35
@export var gravity := 25.0
@export var body_color := Color(0.85, 0.22, 0.2)
@export var telegraph_color := Color(1.0, 0.85, 0.3)

var state := State.IDLE
var health := 0

var _timer := 0.0
var _player: Node3D
var _material: StandardMaterial3D
var _flash_tween: Tween

@onready var _pivot: Node3D = $Pivot
@onready var _body: MeshInstance3D = $Pivot/Body
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	# Свой материал у каждого врага, чтобы вспышки не красили всех сразу.
	_material = StandardMaterial3D.new()
	_material.albedo_color = body_color
	_body.material_override = _material


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D

	_timer -= delta
	if not is_on_floor():
		velocity.y -= gravity * delta

	match state:
		State.IDLE:
			_idle_state(delta)
		State.CHASE:
			_chase_state(delta)
		State.WINDUP:
			_windup_state(delta)
		State.RECOVER, State.HURT:
			_slow_down(delta)
			if _timer <= 0.0:
				state = State.CHASE

	move_and_slide()

	if global_position.y < -20.0:
		_die()


func is_alive() -> bool:
	return state != State.DEAD


func take_damage(amount: int, from_position: Vector3, knockback := 5.0) -> void:
	if state == State.DEAD:
		return
	health -= amount
	var push := global_position - from_position
	push.y = 0.0
	if push.length_squared() > 0.0001:
		push = push.normalized()
	velocity = push * knockback + Vector3.UP * 2.0
	_reset_telegraph()
	_flash()
	if health <= 0:
		_die()
		return
	state = State.HURT
	_timer = hurt_time


# --- Состояния ----------------------------------------------------------------

func _idle_state(delta: float) -> void:
	_slow_down(delta)
	if _player_is_valid() and _distance_to_player() <= detect_radius:
		state = State.CHASE


func _chase_state(delta: float) -> void:
	if not _player_is_valid():
		state = State.IDLE
		return
	var to_player := _flat_to_player()
	var distance := to_player.length()
	if distance <= attack_range:
		_start_windup()
		return
	var direction := (to_player / maxf(distance, 0.001) + _separation()).normalized()
	_set_horizontal_velocity(direction * move_speed, delta)
	_turn_towards(direction, turn_speed, delta)


func _start_windup() -> void:
	state = State.WINDUP
	_timer = windup_time


func _windup_state(delta: float) -> void:
	_slow_down(delta)
	# Во время замаха враг медленно доворачивается — от удара можно уйти вбок.
	if _player_is_valid():
		_turn_towards(_flat_to_player(), turn_speed * 0.3, delta)
	var progress := 1.0 - clampf(_timer / windup_time, 0.0, 1.0)
	_material.albedo_color = body_color.lerp(telegraph_color, progress)
	_pivot.rotation.x = 0.35 * progress
	if _timer <= 0.0:
		_strike()


func _strike() -> void:
	_reset_telegraph()
	var forward := -_pivot.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	velocity += forward * 6.0
	if _player_is_valid():
		var to_player := _flat_to_player()
		var in_range := to_player.length() <= attack_range + 0.6
		var in_front := forward.dot(to_player.normalized()) > 0.4
		if in_range and in_front and _player.has_method("take_damage"):
			_player.take_damage(attack_damage, global_position)
	state = State.RECOVER
	_timer = recover_time


func _die() -> void:
	state = State.DEAD
	remove_from_group("enemies")
	_collision.set_deferred("disabled", true)
	died.emit(self)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_parallel(true)
	tween.tween_property(_pivot, "scale", Vector3(1.4, 0.05, 1.4), 0.25)
	tween.tween_property(_pivot, "position:y", -0.4, 0.25)
	tween.chain().tween_callback(queue_free)


# --- Вспомогательное ----------------------------------------------------------

func _player_is_valid() -> bool:
	if not is_instance_valid(_player):
		return false
	return not _player.has_method("is_alive") or _player.is_alive()


func _flat_to_player() -> Vector3:
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	return to_player


func _distance_to_player() -> float:
	return _flat_to_player().length()


## Враги слегка расталкивают друг друга, чтобы не слипаться в одну кучу.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Node3D
		if other == self or other == null:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance > 0.001 and distance < 1.5:
			push += away / distance * (1.5 - distance)
	return push


func _set_horizontal_velocity(target: Vector3, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _slow_down(delta: float) -> void:
	_set_horizontal_velocity(Vector3.ZERO, delta)


func _turn_towards(direction: Vector3, speed: float, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	var target_angle := atan2(-direction.x, -direction.z)
	_pivot.rotation.y = lerp_angle(_pivot.rotation.y, target_angle, 1.0 - exp(-speed * delta))


func _reset_telegraph() -> void:
	_material.albedo_color = body_color
	_pivot.rotation.x = 0.0


func _flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_material.albedo_color = Color.WHITE
	_flash_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_flash_tween.tween_property(_material, "albedo_color", body_color, 0.2)
