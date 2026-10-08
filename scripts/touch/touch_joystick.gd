class_name TouchJoystick
extends Control
## Плавающий виртуальный джойстик.
## Появляется там, где палец коснулся экрана внутри этого Control,
## и нажимает действия движения из Input Map с силой от 0 до 1.
## Поэтому игрок одинаково управляется джойстиком, клавиатурой и геймпадом.

@export var action_left := &"move_left"
@export var action_right := &"move_right"
@export var action_up := &"move_forward"
@export var action_down := &"move_back"
@export var radius := 110.0
@export var knob_radius := 48.0
@export_range(0.0, 0.5) var dead_zone := 0.1
@export var base_color := Color(1, 1, 1, 0.16)
@export var ring_color := Color(1, 1, 1, 0.4)
@export var knob_color := Color(1, 1, 1, 0.5)

var _finger := -1  # Индекс пальца, который держит джойстик (-1 — никто).
var _center := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	_on_resized()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _finger == -1 and get_global_rect().has_point(touch.position):
				_finger = touch.index
				_center = _to_local(touch.position)
				_update_knob(touch.position)
				get_viewport().set_input_as_handled()
		elif touch.index == _finger:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _finger:
			_update_knob(drag.position)
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Отпускаем стик при паузе и скрытии, иначе персонаж продолжит бежать сам.
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED \
			or what == NOTIFICATION_EXIT_TREE:
		if _finger != -1 or _knob != Vector2.ZERO:
			_release()


func _draw() -> void:
	var active := _finger != -1
	draw_circle(_center, radius, base_color if active else base_color * Color(1, 1, 1, 0.6))
	draw_arc(_center, radius, 0.0, TAU, 64, ring_color, 3.0, true)
	draw_circle(_center + _knob, knob_radius, knob_color)


func _update_knob(screen_position: Vector2) -> void:
	_knob = (_to_local(screen_position) - _center).limit_length(radius)
	var value := _knob / radius
	if value.length() < dead_zone:
		value = Vector2.ZERO
	_apply_axis(action_left, action_right, value.x)
	_apply_axis(action_up, action_down, value.y)
	queue_redraw()


func _release() -> void:
	_finger = -1
	_knob = Vector2.ZERO
	_center = _rest_position()
	for action in [action_left, action_right, action_up, action_down]:
		Input.action_release(action)
	queue_redraw()


func _apply_axis(negative: StringName, positive: StringName, value: float) -> void:
	if value < 0.0:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	elif value > 0.0:
		Input.action_press(positive, value)
		Input.action_release(negative)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


## Где джойстик рисуется, когда его никто не трогает.
func _rest_position() -> Vector2:
	var margin := radius + 50.0
	return Vector2(minf(margin, size.x * 0.5), maxf(size.y - margin, size.y * 0.5))


func _to_local(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position


func _on_resized() -> void:
	if _finger == -1:
		_center = _rest_position()
		queue_redraw()
