class_name StreetLamps
extends Node3D
## Уличные фонари ночного города. Каждый дочерний Marker3D — фонарь (кронштейн смотрит по -Z).
## Столбы, плафоны, круги света на асфальте и световые конусы в тумане рисуются
## через MultiMesh — все фонари вместе стоят всего несколько вызовов отрисовки.
## Настоящий свет (OmniLight3D) горит только у части фонарей: на телефоне это главная экономия.

@export var real_light_every := 2  ## Настоящий свет у каждого N-го фонаря (0 — ни у одного).
@export var light_color := Color(1.0, 0.8, 0.52)
@export var light_energy := 1.5
@export var light_range := 11.0
@export var height := 4.6  ## Высота плафона.
@export var arm_length := 1.3  ## Вынос кронштейна над дорогой.
@export var pool_radius := 4.2  ## Радиус светлого круга на земле.

const POST_COLOR := Color(0.08, 0.08, 0.09)


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
	if real_light_every > 0:
		for i in range(0, transforms.size(), real_light_every):
			var light := OmniLight3D.new()
			light.name = "Light%d" % i
			light.light_color = light_color
			light.light_energy = light_energy
			light.omni_range = light_range
			light.omni_attenuation = 2.0
			light.shadow_enabled = false
			light.distance_fade_enabled = true
			light.distance_fade_begin = 45.0
			light.distance_fade_length = 10.0
			light.transform = transforms[i] * Transform3D(Basis(), Vector3(0, height - 0.5, -arm_length))
			add_child(light)


func get_lamp_count() -> int:
	var count := 0
	for child in get_children():
		if child is Marker3D:
			count += 1
	return count


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], offset: Transform3D, shadow: bool) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i] * offset)
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
	gradient.set_color(0, Color(light_color, 0.4))
	gradient.set_color(1, Color(light_color, 0.0))
	gradient.add_point(0.45, Color(light_color, 0.16))
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
