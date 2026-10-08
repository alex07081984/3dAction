class_name CameraRig
extends Node3D
## Камера от третьего лица.
## Плавно следует за целью, вращается свайпом по экрану, правым стиком
## геймпада или мышью с зажатой правой кнопкой (для теста на ПК).
## SpringArm3D не даёт камере проходить сквозь стены.

@export var target: Node3D  ## Если не задано — берётся родитель.
@export var height := 1.4  ## Высота точки, вокруг которой вращается камера.
@export var follow_speed := 12.0
@export var distance := 5.5

@export_group("Чувствительность")
@export var touch_sensitivity := 0.006
@export var mouse_sensitivity := 0.005
@export var stick_speed := 3.0
@export var invert_y := false

@export_group("Наклон")
@export var initial_pitch_deg := -20.0
@export var min_pitch_deg := -65.0
@export var max_pitch_deg := 20.0

var _shake := 0.0

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	# Камера не должна поворачиваться вместе с игроком.
	top_level = true
	if target == null:
		target = get_parent() as Node3D
	if target is CollisionObject3D:
		_arm.add_excluded_object((target as CollisionObject3D).get_rid())
	_arm.spring_length = distance
	_arm.rotation.x = deg_to_rad(initial_pitch_deg)
	if target:
		global_position = target.global_position + Vector3.UP * height
		rotation.y = target.global_rotation.y
	reset_physics_interpolation()


func _unhandled_input(event: InputEvent) -> void:
	# Сюда доходят только касания, которые не забрали джойстик и кнопки.
	if event is InputEventScreenDrag:
		_rotate_by((event as InputEventScreenDrag).relative * touch_sensitivity)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_rotate_by(motion.relative * mouse_sensitivity)


func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		var goal := target.global_position + Vector3.UP * height
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))

	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		_rotate_by(look * stick_speed * delta)

	# Тряска камеры затухает со временем.
	_shake = move_toward(_shake, 0.0, delta * 1.5)
	_camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.4
	_camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.4


## Поворот камеры только по горизонтали — по нему считается направление движения.
func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, rotation.y)


func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.0)


func snap_to_target() -> void:
	if is_instance_valid(target):
		global_position = target.global_position + Vector3.UP * height
		reset_physics_interpolation()


func _rotate_by(amount: Vector2) -> void:
	rotation.y -= amount.x
	var pitch_delta := amount.y if invert_y else -amount.y
	_arm.rotation.x = clampf(_arm.rotation.x + pitch_delta,
			deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
