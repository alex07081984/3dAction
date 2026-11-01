class_name Traffic
extends Node3D
## Машины в освобождённом городе: ездят по кольцу улиц по правой полосе,
## тормозят перед игроком и перед машиной впереди, сигналят.

@export var count := 5
@export var corners: Array[Vector3] = [Vector3(-36, 0, -36), Vector3(36, 0, -36), Vector3(36, 0, 36), Vector3(-36, 0, 36)]
@export var lane_offset := 1.1
@export var speed := 7.0

const COLORS := [Color(0.5, 0.06, 0.05), Color(0.08, 0.08, 0.09), Color(0.75, 0.73, 0.68), Color(0.12, 0.2, 0.35), Color(0.3, 0.26, 0.2)]

var _cars := []  # {"body", "s", "speed", "honk"}
var _length := 0.0
var _player: Node3D
static var _light_materials := {}


func _ready() -> void:
	count = maxi(roundi(count * [0.6, 0.8, 1.0][Game.graphics_quality()]), 2)
	if not Game.is_liberated(Game.current_level):
		return
	for i in corners.size():
		_length += corners[i].distance_to(corners[(i + 1) % corners.size()])
	for i in count:
		var body := _build_car(COLORS[i % COLORS.size()])
		add_child(body)
		_cars.append({"body": body, "s": _length * i / count, "speed": speed, "honk": 0.0})
		_place(_cars[-1])


func get_car_count() -> int:
	return _cars.size()


func get_car(index: int) -> Node3D:
	return _cars[index].body


func _physics_process(delta: float) -> void:
	if _cars.is_empty():
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	for i in _cars.size():
		var car: Dictionary = _cars[i]
		var body: Node3D = car.body
		var target := speed
		# Машина впереди слишком близко.
		var ahead: Dictionary = _cars[(i + 1) % _cars.size()]
		if _cars.size() > 1 and fposmod(ahead.s - car.s, _length) < 9.0:
			target = 0.0
		# Игрок на дороге перед машиной.
		car.honk -= delta
		if _player:
			var local := body.global_basis.inverse() * (_player.global_position - body.global_position)
			if local.z < -1.5 and local.z > -9.0 and absf(local.x) < 1.9:
				target = 0.0
				if car.honk <= 0.0:
					car.honk = 3.0
					Audio.play_at("horn", body.global_position, -2.0)
		car.speed = move_toward(car.speed, target, 14.0 * delta)
		car.s = fposmod(car.s + car.speed * delta, _length)
		_place(car)


func _place(car: Dictionary) -> void:
	var here := _point(car.s)
	var direction := _point(car.s + 3.0) - _point(car.s - 3.0)
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	direction = direction.normalized()
	var right := direction.cross(Vector3.UP)
	var body: Node3D = car.body
	body.global_transform = Transform3D(Basis.looking_at(direction), here + right * lane_offset)


func _point(s: float) -> Vector3:
	s = fposmod(s, _length)
	for i in corners.size():
		var a := corners[i]
		var b := corners[(i + 1) % corners.size()]
		var length := a.distance_to(b)
		if s <= length:
			return a.lerp(b, s / length)
		s -= length
	return corners[0]


func _build_car(color: Color) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.4, 4.3)
	shape.shape = box
	shape.position.y = 0.8
	body.add_child(shape)
	var dark := Color(0.04, 0.04, 0.05)
	var boxes := [[Vector3(1.9, 0.7, 4.3), Vector3(0, 0.6, 0), color, 0.08],
			[Vector3(1.7, 0.6, 2.2), Vector3(0, 1.2, 0.3), color.darkened(0.1), 0.1],
			[Vector3(1.72, 0.42, 2.02), Vector3(0, 1.22, 0.3), Color(0.08, 0.1, 0.13)]]
	for x in [-0.88, 0.88]:
		for z in [-1.35, 1.35]:
			boxes.append([Vector3(0.28, 0.62, 0.62), Vector3(x, 0.31, z), dark, 0.05])
	BlockyCharacter.add_part_mesh(body, boxes)
	for spec in [[Vector3(1.5, 0.14, 0.05), Vector3(0, 0.68, -2.16), Color(1.0, 0.95, 0.8)],
			[Vector3(1.6, 0.12, 0.05), Vector3(0, 0.72, 2.16), Color(0.9, 0.08, 0.05)]]:
		var light := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = spec[0]
		mesh.material = _light_material(spec[2])
		light.mesh = mesh
		light.position = spec[1]
		light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(light)
	return body


static func _light_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _light_materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		_light_materials[key] = material
	return _light_materials[key]
