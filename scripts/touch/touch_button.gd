class_name TouchActionButton
extends Control
## Круглая сенсорная кнопка, которая нажимает действие из Input Map.
## Поддерживает мультитач: можно бежать джойстиком и одновременно стрелять.
## С pass_drag палец на кнопке ещё и крутит камеру — удобно для кнопки огня:
## нажал и ведёшь прицел, не отпуская.

@export var action := &"fire"
@export var text := "A":
	set(value):
		text = value
		queue_redraw()
@export var font_size := 26
@export var color := Color(1, 1, 1, 0.22)
@export var pressed_color := Color(1, 1, 1, 0.5)
@export var ring_color := Color(1, 1, 1, 0.55)
@export var touch_margin := 1.2  ## Зона касания больше нарисованного круга — легче попасть.
@export var pass_drag := false  ## Свайп с этой кнопки поворачивает камеру.

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
		# Палец на обычной кнопке не должен крутить камеру.
		if (event as InputEventScreenDrag).index == _finger and not pass_drag:
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
	var lines := text.split("\n")
	var line_height := font.get_height(font_size)
	var top := center.y - line_height * lines.size() * 0.5 + font.get_ascent(font_size)
	for i in lines.size():
		var width := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(center.x - width * 0.5, top + i * line_height), lines[i],
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
