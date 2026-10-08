class_name CameraRig
extends Node3D
## Камера из-за плеча для шутера от третьего лица.
## Вращается свайпом по экрану, правым стиком, стрелками или мышью с зажатой
## правой кнопкой. Две «пружины» (SpringArm3D) не дают камере залезть в стену:
## одна сдвигает её к плечу, вторая отводит назад.

@export var target: Node3D  ## Если не задано — берётся родитель.
@export var height := 1.55
@export var follow_speed := 18.0
@export var distance := 3.0
@export var shoulder_offset := 0.6

@export_group("Чувствительность")
@export var touch_sensitivity := 0.005
@export var mouse_sensitivity := 0.004
@export var stick_speed := 2.6
@export var invert_y := false

@export_group("Наклон")
@export var initial_pitch_deg := -8.0
@export var min_pitch_deg := -70.0
@export var max_pitch_deg := 60.0

var camera: Camera3D

var _shake := 0.0
var _kick := 0.0

@onready var _shoulder: SpringArm3D = $ShoulderArm
@onready var _arm: SpringArm3D = $ShoulderArm/Shoulder/SpringArm3D


func _ready() -> void:
	top_level = true
	camera = $ShoulderArm/Shoulder/SpringArm3D/Camera3D
	if target == null:
		target = get_parent() as Node3D
	if target is CollisionObject3D:
		var rid := (target as CollisionObject3D).get_rid()
		_shoulder.add_excluded_object(rid)
		_arm.add_excluded_object(rid)
	_shoulder.spring_length = shoulder_offset
	_arm.spring_length = distance
	_arm.rotation.x = deg_to_rad(initial_pitch_deg)
	if target:
		global_position = target.global_position + Vector3.UP * height
	reset_physics_interpolation()


func _unhandled_input(event: InputEvent) -> void:
	# Сюда доходят касания, которые не забрал джойстик, а также свайпы с кнопки огня.
	if event is InputEventScreenDrag:
		_rotate_by((event as InputEventScreenDrag).relative * touch_sensitivity * _sensitivity())
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_rotate_by(motion.relative * mouse_sensitivity * _sensitivity())


func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		var goal := target.global_position + Vector3.UP * height
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))

	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		_rotate_by(look * stick_speed * delta * _sensitivity())

	# Отдача подбрасывает камеру и плавно возвращается.
	_kick = move_toward(_kick, 0.0, delta * 0.35)
	camera.rotation.x = _kick
	_shake = move_toward(_shake, 0.0, delta * 1.8)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.15
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.15


func get_yaw() -> float:
	return rotation.y


func set_yaw(value: float) -> void:
	rotation.y = value


## Наклон прицела: больше нуля — смотрим вверх.
func get_pitch() -> float:
	return _arm.rotation.x + _kick


func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, rotation.y)


## Луч из центра экрана (там, где прицел): [начало, направление].
func get_aim_ray() -> Array:
	var center := get_viewport().get_visible_rect().size * 0.5
	return [camera.project_ray_origin(center), camera.project_ray_normal(center)]


func add_recoil(degrees: float) -> void:
	_kick = minf(_kick + deg_to_rad(degrees), deg_to_rad(12.0))


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


func _sensitivity() -> float:
	return float(Game.settings.get("sensitivity", 1.0))
