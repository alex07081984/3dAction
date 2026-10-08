class_name Player
extends CharacterBody3D
## Игрок: бег относительно камеры, прыжок, рывок, комбо из трёх ударов, здоровье.
## Все настройки вынесены в @export — их удобно крутить в Инспекторе.

signal health_changed(current: int, maximum: int)
signal died

enum State { MOVE, DASH, ATTACK, DEAD }

## Шаги комбо. windup — замах, active — окно попадания, recovery — восстановление.
## lunge — шаг вперёд при ударе, knockback — насколько отбрасывает врага.
## swing — направление взмаха меча: 1 — справа налево, -1 — слева направо, 0 — сверху вниз.
const COMBO := [
	{"damage": 1, "windup": 0.07, "active": 0.12, "recovery": 0.18, "lunge": 5.0, "knockback": 4.0, "swing": 1},
	{"damage": 1, "windup": 0.07, "active": 0.12, "recovery": 0.18, "lunge": 5.0, "knockback": 4.0, "swing": -1},
	{"damage": 2, "windup": 0.14, "active": 0.16, "recovery": 0.35, "lunge": 8.0, "knockback": 10.0, "swing": 0},
]
const COYOTE_TIME := 0.12  # Можно прыгнуть чуть позже схода с края.
const JUMP_BUFFER := 0.15  # Нажатие прыжка чуть раньше приземления не теряется.
const FALL_LIMIT := -20.0
const SWORD_IDLE := Vector3(-0.9, -0.4, 0.0)

@export_group("Движение")
@export var move_speed := 7.0
@export var acceleration := 45.0
@export var air_acceleration := 15.0
@export var turn_speed := 14.0
@export var jump_velocity := 9.0
@export var gravity := 25.0

@export_group("Рывок")
@export var dash_speed := 20.0
@export var dash_time := 0.18
@export var dash_cooldown := 0.6

@export_group("Бой")
@export var auto_aim_range := 4.5  ## Радиус, в котором удар доворачивает к врагу.
@export var max_health := 10
@export var invincibility_time := 0.8

var health := 0
var state := State.MOVE

var _coyote := 0.0
var _jump_buffer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_left := 0.0
var _dash_dir := Vector3.FORWARD
var _invincible := 0.0
var _blink := 0.0
var _combo_step := 0
var _attack_phase := 0  # 0 — замах, 1 — удар, 2 — восстановление
var _attack_timer := 0.0
var _attack_queued := false
var _hit_bodies: Array[Node] = []
var _spawn_position := Vector3.ZERO
var _sword_tween: Tween

@onready var _pivot: Node3D = $Pivot
@onready var _sword_pivot: Node3D = $Pivot/SwordPivot
@onready var _attack_area: Area3D = $Pivot/AttackArea
@onready var _camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	health = max_health
	_spawn_position = global_position
	_sword_pivot.rotation = SWORD_IDLE
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_apply_friction(acceleration, delta)
		_apply_gravity(delta)
		move_and_slide()
		return

	_tick_timers(delta)
	_read_input()

	match state:
		State.MOVE:
			_move_state(delta)
		State.DASH:
			_dash_state()
		State.ATTACK:
			_attack_state(delta)

	if state != State.DASH:
		_apply_gravity(delta)
	move_and_slide()

	if global_position.y < FALL_LIMIT:
		_fell_out()


func _process(_delta: float) -> void:
	# Мигание после получения урона.
	_pivot.visible = _blink <= 0.0 or int(_blink * 20.0) % 2 == 0


func is_alive() -> bool:
	return state != State.DEAD


func take_damage(amount: int, from_position: Vector3) -> void:
	if state == State.DEAD or _invincible > 0.0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_invincible = invincibility_time
	_blink = invincibility_time
	_camera_rig.shake(0.5)

	var push := global_position - from_position
	push.y = 0.0
	if push.length_squared() > 0.0001:
		push = push.normalized() * 8.0
	velocity = Vector3(push.x, 4.0, push.z)
	_end_attack()
	state = State.MOVE

	if health == 0:
		_die()


func heal(amount: int) -> void:
	if state == State.DEAD:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


# --- Ввод -------------------------------------------------------------------

func _read_input() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= 0.5  # Короткое нажатие — низкий прыжок.
	if Input.is_action_just_pressed("dash"):
		_try_dash()
	if Input.is_action_just_pressed("attack"):
		_try_attack()


## Направление движения в мире с учётом поворота камеры. Длина 0..1.
func _get_move_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return _camera_rig.get_yaw_basis() * Vector3(input.x, 0.0, input.y)


func _get_facing() -> Vector3:
	var forward := -_pivot.global_basis.z
	forward.y = 0.0
	return forward.normalized()


# --- Состояния ----------------------------------------------------------------

func _move_state(delta: float) -> void:
	var direction := _get_move_direction()
	var accel := acceleration if is_on_floor() else air_acceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(direction * move_speed, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if direction.length_squared() > 0.01:
		_face_direction(direction, delta)

	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0


func _try_dash() -> void:
	if _dash_cooldown_left > 0.0 or state == State.DASH:
		return
	var direction := _get_move_direction()
	if direction.length_squared() < 0.01:
		direction = _get_facing()
	_dash_dir = direction.normalized()
	_face_instantly(_dash_dir)
	_end_attack()
	state = State.DASH
	_dash_timer = dash_time
	_dash_cooldown_left = dash_cooldown
	_invincible = maxf(_invincible, dash_time + 0.05)


func _dash_state() -> void:
	velocity = _dash_dir * dash_speed
	if _dash_timer <= 0.0:
		state = State.MOVE
		velocity *= 0.35


func _try_attack() -> void:
	match state:
		State.MOVE:
			_start_attack(0)
		State.DASH:
			state = State.MOVE
			_start_attack(0)
		State.ATTACK:
			if _combo_step < COMBO.size() - 1:
				_attack_queued = true


func _start_attack(step: int) -> void:
	state = State.ATTACK
	_combo_step = step
	_attack_phase = 0
	_attack_queued = false
	_hit_bodies.clear()
	var data: Dictionary = COMBO[step]
	_attack_timer = data.windup

	# Автонаведение: на телефоне сложно точно целиться, поэтому доворачиваем к врагу.
	var target := _find_attack_target()
	if target:
		_face_instantly(target.global_position - global_position)
	else:
		var direction := _get_move_direction()
		if direction.length_squared() > 0.01:
			_face_instantly(direction)

	_animate_swing(data)


func _attack_state(delta: float) -> void:
	_apply_friction(acceleration * 1.5, delta)
	var data: Dictionary = COMBO[_combo_step]

	if _attack_phase == 1:
		_apply_hits(data)

	# Следующий удар комбо можно начать сразу после окна попадания.
	if _attack_phase == 2 and _attack_queued:
		_start_attack(_combo_step + 1)
		return

	if _attack_timer > 0.0:
		return

	match _attack_phase:
		0:
			_attack_phase = 1
			_attack_timer = data.active
			var lunge: Vector3 = _get_facing() * float(data.lunge)
			velocity.x = lunge.x
			velocity.z = lunge.z
			_apply_hits(data)
		1:
			_attack_phase = 2
			_attack_timer = data.recovery
		2:
			_end_attack()
			state = State.MOVE


func _apply_hits(data: Dictionary) -> void:
	var landed := false
	for body in _attack_area.get_overlapping_bodies():
		if body in _hit_bodies or not body.has_method("take_damage"):
			continue
		_hit_bodies.append(body)
		body.take_damage(int(data.damage), global_position, float(data.knockback))
		landed = true
	if landed:
		var heavy := _combo_step == COMBO.size() - 1
		_camera_rig.shake(0.45 if heavy else 0.25)
		_hitstop(0.08 if heavy else 0.04)


func _end_attack() -> void:
	_attack_queued = false
	if _sword_tween:
		_sword_tween.kill()
	_sword_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_sword_tween.tween_property(_sword_pivot, "rotation", SWORD_IDLE, 0.15)


func _find_attack_target() -> Node3D:
	var preferred := _get_move_direction()
	if preferred.length_squared() < 0.01:
		preferred = _get_facing()
	preferred = preferred.normalized()

	var best: Node3D = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if enemy == null:
			continue
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance > auto_aim_range:
			continue
		# Ближние и те, что в направлении стика, — в приоритете.
		var score := distance
		if distance > 0.01:
			score -= to_enemy.normalized().dot(preferred) * 2.0
		if score < best_score:
			best_score = score
			best = enemy
	return best


# --- Вспомогательное ----------------------------------------------------------

func _tick_timers(delta: float) -> void:
	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote -= delta
	_jump_buffer -= delta
	_dash_timer -= delta
	_dash_cooldown_left -= delta
	_invincible -= delta
	_blink -= delta
	_attack_timer -= delta


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _apply_friction(amount: float, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, amount * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_angle := atan2(-direction.x, -direction.z)
	_pivot.rotation.y = lerp_angle(_pivot.rotation.y, target_angle, 1.0 - exp(-turn_speed * delta))


func _face_instantly(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	_pivot.rotation.y = atan2(-direction.x, -direction.z)


## Взмах меча: замах в исходную позу, затем быстрый удар.
func _animate_swing(data: Dictionary) -> void:
	var start: Vector3
	var finish: Vector3
	match int(data.swing):
		1:
			start = Vector3(0.0, -1.9, 0.0)
			finish = Vector3(0.0, 1.6, 0.0)
		-1:
			start = Vector3(0.0, 1.9, 0.0)
			finish = Vector3(0.0, -1.6, 0.0)
		_:
			start = Vector3(1.5, 0.0, 0.0)
			finish = Vector3(-1.3, 0.0, 0.0)
	if _sword_tween:
		_sword_tween.kill()
	_sword_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_sword_tween.tween_property(_sword_pivot, "rotation", start, data.windup)
	_sword_tween.tween_property(_sword_pivot, "rotation", finish, data.active) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Короткая заморозка времени при попадании — удары ощущаются весомее.
func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _die() -> void:
	state = State.DEAD
	_blink = 0.0
	died.emit()
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_pivot, "rotation:x", -PI / 2.0, 0.4).set_trans(Tween.TRANS_BOUNCE)


func _fell_out() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	_camera_rig.snap_to_target()
	_invincible = 0.0
	take_damage(2, global_position)
