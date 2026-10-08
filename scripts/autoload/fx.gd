extends Node
## Визуальные эффекты (автозагрузка Fx): вспышки выстрелов, трассеры, кровь, искры,
## следы от пуль и лужи крови. Всё создаётся кодом и само исчезает.
## Эффекты кладутся в текущую сцену, поэтому пропадают при рестарте уровня.

const MAX_DECALS := 40
const WORLD_MASK := 1

var _materials := {}
var _decals: Array = []


func muzzle_flash(position: Vector3, direction: Vector3) -> void:
	var root := _root()
	if root == null:
		return
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _material(Color(1.0, 0.85, 0.4), true)
	flash.mesh = mesh
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.add_child(flash)
	flash.global_position = position + direction * 0.1
	_look(flash, direction)
	flash.scale = Vector3(1.0, 1.0, 2.2)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 2.5
	light.omni_range = 5.0
	flash.add_child(light)
	_free_after(flash, 0.05)


func tracer(from: Vector3, to: Vector3, color := Color(1.0, 0.9, 0.55)) -> void:
	var root := _root()
	var length := from.distance_to(to)
	if root == null or length < 0.3:
		return
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, length)
	mesh.material = _material(color, true)
	line.mesh = mesh
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.add_child(line)
	line.global_position = (from + to) * 0.5
	_look(line, to - from)
	var tween := line.create_tween()
	tween.tween_property(line, "scale", Vector3(0.1, 0.1, 1.0), 0.07)
	tween.tween_callback(line.queue_free)


func blood(position: Vector3, direction: Vector3, amount := 16) -> void:
	_burst(position, direction, Color(0.55, 0.02, 0.02), amount, 4.5, 0.07, 0.7, 14.0, 40.0)


func sparks(position: Vector3, normal: Vector3) -> void:
	_burst(position, normal, Color(1.0, 0.85, 0.45), 8, 6.0, 0.035, 0.25, 9.0, 55.0)
	_burst(position, normal, Color(0.5, 0.48, 0.45), 5, 1.5, 0.08, 0.5, 1.0, 40.0)


## Струя крови, которая бьёт из точки, привязанной к движущейся части тела.
func blood_fountain(parent: Node3D, local_position: Vector3, duration := 1.2) -> void:
	var particles := _make_particles(Color(0.6, 0.0, 0.0), 0.06)
	particles.one_shot = false
	particles.amount = 48
	particles.lifetime = 0.7
	particles.direction = Vector3.UP
	particles.spread = 25.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3(0, -14.0, 0)
	parent.add_child(particles)
	particles.position = local_position
	particles.emitting = true
	# Твин живёт вместе с частицами: если кусок тела удалят раньше, ничего не сломается.
	var tween := particles.create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(particles.set.bind("emitting", false))
	tween.tween_interval(particles.lifetime + 0.2)
	tween.tween_callback(particles.queue_free)


## Лужа крови на полу под точкой.
func blood_pool(position: Vector3, size := 1.0) -> void:
	var hit := _raycast(position + Vector3.UP * 0.5, position + Vector3.DOWN * 3.0)
	if hit.is_empty():
		return
	var pool := _decal(hit.position, hit.normal, Color(0.32, 0.0, 0.0, 0.92), size * randf_range(0.8, 1.3))
	if pool:
		var final_scale := pool.scale
		pool.scale = final_scale * 0.2
		pool.create_tween().tween_property(pool, "scale", final_scale, 1.5)


## След от пули на стене.
func bullet_hole(position: Vector3, normal: Vector3) -> void:
	_decal(position, normal, Color(0.05, 0.05, 0.05, 0.9), 0.12)


func _decal(position: Vector3, normal: Vector3, color: Color, size: float) -> Node3D:
	var root := _root()
	if root == null:
		return null
	var decal := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE
	mesh.material = _material(color, false)
	decal.mesh = mesh
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decal.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.add_child(decal)
	# Плоскость PlaneMesh смотрит вверх (+Y) — поворачиваем её вдоль нормали поверхности.
	var up := normal.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var forward := side.cross(up)
	decal.global_transform = Transform3D(Basis(side, up, forward), position + up * 0.012)
	decal.rotate_object_local(Vector3.UP, randf() * TAU)
	decal.scale = Vector3(size, 1.0, size)
	_decals = _decals.filter(func(item: Variant) -> bool: return is_instance_valid(item))
	_decals.append(decal)
	while _decals.size() > MAX_DECALS:
		var old: Variant = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	return decal


func _burst(position: Vector3, direction: Vector3, color: Color, amount: int, speed: float,
		size: float, lifetime: float, gravity: float, spread: float) -> void:
	var root := _root()
	if root == null:
		return
	var particles := _make_particles(color, size)
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.UP
	particles.spread = spread
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -gravity, 0)
	root.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	_free_after(particles, lifetime + 0.3)


func _make_particles(color: Color, size: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	mesh.material = _material(color, true)
	particles.mesh = mesh
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.3
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


func _material(color: Color, unshaded: bool) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), unshaded]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		if unshaded:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if color.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = material
	return _materials[key]


func _look(node: Node3D, direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	var up := Vector3.UP if absf(direction.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	node.look_at(node.global_position + direction, up)


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var root := _root() as Node3D
	if root == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	return root.get_world_3d().direct_space_state.intersect_ray(query)


func _free_after(node: Node, seconds: float) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(node.queue_free)


func _root() -> Node:
	return get_tree().current_scene
