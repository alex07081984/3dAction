class_name CableCar
extends AnimatableBody3D
## Канатный трамвай: ездит по рельсам вверх по холму и обратно, звенит на остановках.
## Путь — дочерние Marker3D по порядку. На него можно запрыгнуть и прокатиться.

@export var speed := 4.0
@export var stop_time := 3.0
@export var body_color := Color(0.55, 0.08, 0.06)

var _points: Array[Vector3] = []
var _lengths: Array[float] = []
var _total := 0.0
var _s := 0.0
var _direction := 1.0
var _wait := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	for child in get_children():
		if child is Marker3D:
			_points.append((child as Marker3D).global_position)
	for child in get_children():
		if child is Marker3D:
			remove_child(child)
			child.queue_free()
	for i in range(1, _points.size()):
		_lengths.append(_points[i - 1].distance_to(_points[i]))
		_total += _lengths[-1]
	_build()
	_place()


func _physics_process(delta: float) -> void:
	if _total <= 0.0:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	_s += speed * delta * _direction
	if _s >= _total or _s <= 0.0:
		_s = clampf(_s, 0.0, _total)
		_direction = -_direction
		_wait = stop_time
		Audio.play_at("beep", global_position + Vector3.UP * 3.0, 2.0, 0.55)
	_place()


func _place() -> void:
	var here := _point(_s)
	var ahead := _point(_s + 2.0) - _point(_s - 2.0)
	ahead.y = 0.0
	if ahead.length_squared() < 0.001:
		return
	global_transform = Transform3D(Basis.looking_at(ahead.normalized()), here)


func _point(s: float) -> Vector3:
	s = clampf(s, 0.0, _total)
	for i in _lengths.size():
		if s <= _lengths[i]:
			return _points[i].lerp(_points[i + 1], s / maxf(_lengths[i], 0.001))
		s -= _lengths[i]
	return _points[-1]


func _build() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 0.4, 7.0)
	shape.shape = box
	shape.position.y = 0.6
	add_child(shape)
	var wood := Color(0.4, 0.26, 0.14)
	var cream := Color(0.85, 0.8, 0.65)
	var boxes := [[Vector3(2.4, 0.4, 7.0), Vector3(0, 0.6, 0), wood, 0.05],
			[Vector3(2.3, 1.0, 4.4), Vector3(0, 1.3, 0), body_color, 0.05],
			[Vector3(2.32, 0.6, 4.2), Vector3(0, 2.1, 0), Color(0.12, 0.13, 0.15)],
			[Vector3(2.5, 0.25, 7.2), Vector3(0, 2.6, 0), cream, 0.08],
			[Vector3(1.6, 0.4, 0.6), Vector3(0, 2.85, 0), cream]]
	for z in [-3.2, 3.2]:
		for x in [-1.0, 1.0]:
			boxes.append([Vector3(0.08, 2.0, 0.08), Vector3(x, 1.6, z), wood])
	for z in [-2.6, 2.6]:
		for x in [-0.9, 0.9]:
			boxes.append([Vector3(0.2, 0.5, 0.5), Vector3(x, 0.25, z), Color(0.05, 0.05, 0.05)])
	BlockyCharacter.add_part_mesh(self, boxes)
