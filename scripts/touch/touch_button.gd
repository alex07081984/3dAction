class_name TouchActionButton
extends Control
## Круглая сенсорная кнопка, которая нажимает действие из Input Map.
## Поддерживает мультитач: можно держать джойстик и одновременно бить и прыгать.

@export var action := &"attack"
@export var text := "A"
@export var font_size := 26
@export var color := Color(1, 1, 1, 0.22)
@export var pressed_color := Color(1, 1, 1, 0.5)
@export var ring_color := Color(1, 1, 1, 0.55)
@export var touch_margin := 1.25  ## Зона касания больше нарисованного круга — легче попасть.

var _finger := -1


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _finger == -1 and _hit(touch.position):
				_finger = touch.index
				Input.action_press(action)
				queue_redraw()
				get_viewport().set_input_as_handled()
		elif touch.index == _finger:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		# Палец на кнопке не должен заодно крутить камеру.
		if (event as InputEventScreenDrag).index == _finger:
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED \
			or what == NOTIFICATION_EXIT_TREE:
		if _finger != -1:
			_release()


func _draw() -> void:
	var center := size * 0.5
	var radius := _radius()
	draw_circle(center, radius, pressed_color if _finger != -1 else color)
	draw_arc(center, radius, 0.0, TAU, 48, ring_color, 3.0, true)
	var font := get_theme_default_font()
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(center.x - text_width * 0.5, baseline), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)


func _hit(screen_position: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * screen_position
	return local.distance_to(size * 0.5) <= _radius() * touch_margin


func _radius() -> float:
	return minf(size.x, size.y) * 0.5


func _release() -> void:
	_finger = -1
	Input.action_release(action)
	queue_redraw()
