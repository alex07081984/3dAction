class_name StreetLamps
extends Node3D
## Уличные фонари ночного города. Каждый дочерний Marker3D — фонарь (кронштейн смотрит по -Z).
## Столбы, плафоны, круги света на асфальте и световые конусы в тумане рисуются
## через MultiMesh — все фонари вместе стоят всего несколько вызовов отрисовки.
## Настоящий свет (OmniLight3D) горит только у части фонарей: на телефоне это главная экономия.
## Между фонарями по разные стороны улицы натянуты гирлянды тёплых лампочек — тоже MultiMesh.

@export var real_light_every := 2  ## Настоящий свет у каждого N-го фонаря (0 — ни у одного).
@export var real_light_every_high := 1  ## То же на высокой графике.
@export var light_color := Color(1.0, 0.8, 0.52)
@export var light_energy := 2.1
@export var light_range := 15.0
@export var height := 4.6  ## Высота плафона.
@export var arm_length := 1.3  ## Вынос кронштейна над дорогой.
@export var pool_radius := 5.0  ## Радиус светлого круга на земле.
@export var garlands := true  ## Гирлянды над улицей между фонарями напротив друг друга.
@export var garland_max_span := 20.0

const POST_COLOR := Color(0.08, 0.08, 0.09)
const BULB_STEP := 0.65  ## Шаг лампочек в гирлянде, м.
const BULB_WARM := Color(1.0, 0.82, 0.5)
const BULB_RED := Color(1.0, 0.18, 0.1)
const HALO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = COLOR.rgb * pow(facing, 4.0) * 0.55;
}
"""


func _ready() -> void:
	var transforms: Array[Transform3D] = []
	for child in get_children():
		if child is Marker3D:
			transforms.append((child as Marker3D).transform)
	if transforms.is_empty():
		return
	_add_multimesh("Posts", _post_mesh(), transforms, Transform3D.IDENTITY, true)
	var head_offset := Transform3D(Basis(), Vector3(0, height - 0.12, -arm_length))
	_add_multimesh("Heads", _head_mesh(), transforms, head_offset, false)
	var pool_offset := Transform3D(Basis(), Vector3(0, 0.04, -arm_length))
	_add_multimesh("Pools", _pool_mesh(), transforms, pool_offset, false)
	var cone_offset := Transform3D(Basis(), Vector3(0, (height - 0.2) * 0.5, -arm_length))
	_add_multimesh("Cones", _cone_mesh(), transforms, cone_offset, false)
	_add_colliders(transforms)
	if garlands:
		_add_garlands(transforms)
	var every := real_light_every_high if Game.graphics_quality() >= 2 else real_light_every
	if every > 0:
		for i in range(0, transforms.size(), every):
			var light := OmniLight3D.new()
			light.name = "Light%d" % i
			light.light_color = light_color
			light.light_energy = light_energy
			light.omni_range = light_range
			light.omni_attenuation = 1.2
			# Без блика: на мокром асфальте он вспыхивает у ног героя ярким овалом.
			light.light_specular = 0.0
			light.shadow_enabled = false
			light.distance_fade_enabled = true
			light.distance_fade_begin = 45.0
			light.distance_fade_length = 10.0
			light.transform = transforms[i] * Transform3D(Basis(), Vector3(0, height - 0.5, -arm_length))
			add_child(light)


## Пары фонарей для гирлянд: стоят по разные стороны одной улицы (кронштейны смотрят
## навстречу друг другу) не дальше garland_max_span. У каждого фонаря — до двух гирлянд,
## поэтому над улицей получается «зигзаг».
func get_garland_pairs(transforms: Array[Transform3D]) -> Array[Vector2i]:
	var pairs: Array[Vector2i] = []
	for i in transforms.size():
		var from := transforms[i].origin
		var facing := _arm_direction(transforms[i])
		var candidates: Array = []
		for j in transforms.size():
			if j == i:
				continue
			var to := transforms[j].origin - from
			to.y = 0.0
			var span := to.length()
			if span < 6.0 or span > garland_max_span:
				continue
			var other := _arm_direction(transforms[j])
			if facing.dot(other) > -0.7 or facing.dot(to) < 0.3 * span or other.dot(-to) < 0.3 * span:
				continue
			candidates.append([span, j])
		candidates.sort()
		for k in mini(2, candidates.size()):
			var j: int = candidates[k][1]
			var pair := Vector2i(mini(i, j), maxi(i, j))
			if not pairs.has(pair):
				pairs.append(pair)
	return pairs


func _arm_direction(t: Transform3D) -> Vector3:
	var direction := -t.basis.z
	direction.y = 0.0
	return direction.normalized()


## Гирлянды: провод провисает дугой, на нём лампочки (тёплые и каждая пятая — красная)
## с мягким ореолом. Всё — три MultiMesh на весь город.
func _add_garlands(transforms: Array[Transform3D]) -> void:
	var bulbs: Array[Transform3D] = []
	var colors: Array[Color] = []
	var wires: Array[Transform3D] = []
	var attach := Vector3(0, height + 0.1, -arm_length)
	for pair in get_garland_pairs(transforms):
		var a := transforms[pair.x] * attach
		var b := transforms[pair.y] * attach
		var span := a.distance_to(b)
		var steps := maxi(int(span / BULB_STEP), 2)
		var sag := span * 0.06
		var previous := a
		for k in range(1, steps + 1):
			var t := float(k) / steps
			var point := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
			var segment := point - previous
			if segment.length() > 0.01:
				# Провод вытянут по оси Z на длину отрезка (scaled_local нет в Godot 4.4).
				var basis := Basis.looking_at(segment.normalized(), Vector3.UP) * Basis.from_scale(Vector3(1, 1, segment.length()))
				wires.append(Transform3D(basis, (point + previous) * 0.5))
			if k < steps:
				bulbs.append(Transform3D(Basis(), point + Vector3.DOWN * 0.07))
				colors.append(BULB_RED if (k + pair.x) % 5 == 0 else BULB_WARM)
			previous = point
	if bulbs.is_empty():
		return
	var wire_mesh := BoxMesh.new()
	wire_mesh.size = Vector3(0.025, 0.025, 1.0)
	var wire_material := StandardMaterial3D.new()
	wire_material.albedo_color = POST_COLOR
	wire_mesh.material = wire_material
	_add_multimesh("GarlandWires", wire_mesh, wires, Transform3D.IDENTITY, false)
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.07
	bulb_mesh.height = 0.14
	bulb_mesh.radial_segments = 6
	bulb_mesh.rings = 3
	var bulb_material := StandardMaterial3D.new()
	bulb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_material.vertex_color_use_as_albedo = true
	bulb_mesh.material = bulb_material
	_add_multimesh("GarlandBulbs", bulb_mesh, bulbs, Transform3D.IDENTITY, false, colors)
	# Ореол — полупрозрачный шар, ярче в середине (без billboard: он ломается в MultiMesh).
	var halo := SphereMesh.new()
	halo.radius = 0.24
	halo.height = 0.48
	halo.radial_segments = 8
	halo.rings = 4
	var halo_material := ShaderMaterial.new()
	halo_material.shader = Shader.new()
	halo_material.shader.code = HALO_SHADER
	halo.material = halo_material
	_add_multimesh("GarlandHalos", halo, bulbs, Transform3D.IDENTITY, false, colors)


func get_lamp_count() -> int:
	var count := 0
	for child in get_children():
		if child is Marker3D:
			count += 1
	return count


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], offset: Transform3D, shadow: bool,
		colors: Array[Color] = []) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i] * offset)
		if multimesh.use_colors:
			multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	if not shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## Столб с кронштейном (один меш с цветами в вершинах).
func _post_mesh() -> Mesh:
	var holder := Node3D.new()
	var mesh := BlockyCharacter.add_part_mesh(holder, [
			[Vector3(0.28, 0.3, 0.28), Vector3(0, 0.15, 0), POST_COLOR, 0.04],
			[Vector3(0.14, height, 0.14), Vector3(0, height * 0.5, 0), POST_COLOR, 0.03, Vector2(1.2, 0.8)],
			[Vector3(0.08, 0.08, arm_length + 0.1), Vector3(0, height, -arm_length * 0.5), POST_COLOR],
			[Vector3(0.36, 0.12, 0.3), Vector3(0, height + 0.02, -arm_length), POST_COLOR, 0.03]]).mesh
	holder.free()
	return mesh


func _head_mesh() -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.06, 0.24)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.93, 0.75)
	box.material = material
	return box


## Светлый круг на асфальте: плоскость с радиальным градиентом, складывается со светом.
func _pool_mesh() -> Mesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * pool_radius * 2.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(light_color, 0.5))
	gradient.set_color(1, Color(light_color, 0.0))
	gradient.add_point(0.45, Color(light_color, 0.22))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	plane.material = _glow_material(texture, Color(1, 1, 1, 0.55))
	return plane


## Световой конус в тумане под плафоном.
func _cone_mesh() -> Mesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.18
	cone.bottom_radius = pool_radius * 0.75
	cone.height = height - 0.2
	cone.radial_segments = 12
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var gradient := Gradient.new()
	# У CylinderMesh низ развёртки — v = 1: конус ярче у плафона и тает к земле.
	gradient.set_color(0, Color(light_color, 0.0))
	gradient.set_color(1, Color(light_color, 0.07))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 4
	texture.height = 32
	cone.material = _glow_material(texture, Color.WHITE)
	return cone


func _glow_material(texture: Texture2D, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = texture
	material.albedo_color = color
	material.disable_fog = true
	return material


func _add_colliders(transforms: Array[Transform3D]) -> void:
	var body := StaticBody3D.new()
	body.name = "Colliders"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = 0.12
	shape.height = height
	for t in transforms:
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.transform = t * Transform3D(Basis(), Vector3(0, height * 0.5, 0))
		body.add_child(collider)
	add_child(body)
