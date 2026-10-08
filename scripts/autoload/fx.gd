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


## Взрыв: вспышка света, огненный шар, дым, искры и копоть на полу.
func explosion(position: Vector3, radius := 5.0) -> void:
	var root := _root()
	if root == null:
		return
	var holder := Node3D.new()
	holder.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.add_child(holder)
	holder.global_position = position
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 7.0
	light.omni_range = radius * 2.6
	holder.add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.6).set_ease(Tween.EASE_IN)
	var fireball := _flame_particles(Color(1.0, 0.85, 0.4), 0.9, 28)
	fireball.one_shot = true
	fireball.explosiveness = 1.0
	fireball.lifetime = 0.7
	fireball.spread = 180.0
	fireball.initial_velocity_min = radius * 0.6
	fireball.initial_velocity_max = radius * 1.4
	fireball.damping_min = radius * 1.5
	fireball.damping_max = radius * 2.0
	fireball.gravity = Vector3(0, 3.0, 0)
	holder.add_child(fireball)
	fireball.emitting = true
	var smoke := _smoke_particles(1.4, 18)
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.lifetime = 2.6
	smoke.spread = 180.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = radius * 0.7
	smoke.damping_min = 2.0
	smoke.damping_max = 3.0
	smoke.gravity = Vector3(0, 1.6, 0)
	holder.add_child(smoke)
	smoke.emitting = true
	_burst(position, Vector3.UP, Color(1.0, 0.7, 0.3), 30, 16.0, 0.05, 0.9, 12.0, 90.0)
	_burst(position, Vector3.UP, Color(0.15, 0.13, 0.12), 14, 9.0, 0.12, 1.4, 16.0, 70.0)
	var hit := _raycast(position + Vector3.UP * 0.3, position + Vector3.DOWN * 3.0)
	if not hit.is_empty():
		_decal(hit.position, hit.normal, Color(0.03, 0.03, 0.03, 0.9), radius * 0.55)
	_free_after(holder, 3.0)


## Огонь, привязанный к узлу (горящая бочка, сопло улетающего баллона).
func fire(parent: Node3D, local_position: Vector3, size := 1.0, light := true) -> Node3D:
	var flames := _flame_particles(Color(1.0, 0.6, 0.2), 0.32 * size, 26)
	flames.lifetime = 0.55
	flames.direction = Vector3.UP
	flames.spread = 14.0
	flames.initial_velocity_min = 1.0 * size
	flames.initial_velocity_max = 2.4 * size
	flames.gravity = Vector3(0, 2.0, 0)
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.18 * size
	parent.add_child(flames)
	flames.position = local_position
	flames.emitting = true
	var smoke := _smoke_particles(0.5 * size, 10)
	smoke.lifetime = 1.6
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 2.0
	smoke.gravity = Vector3(0, 0.8, 0)
	flames.add_child(smoke)
	smoke.position = Vector3(0, 0.4 * size, 0)
	smoke.emitting = true
	if light:
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.55, 0.2)
		glow.light_energy = 2.2
		glow.omni_range = 5.0
		flames.add_child(glow)
		glow.position = Vector3(0, 0.3, 0)
		var flicker := glow.create_tween().set_loops()
		flicker.tween_property(glow, "light_energy", 1.4, 0.08)
		flicker.tween_property(glow, "light_energy", 2.4, 0.11)
	return flames


## Облако дыма (дымовая шашка Худого).
func smoke_cloud(position: Vector3) -> void:
	var root := _root()
	if root == null:
		return
	var smoke := _smoke_particles(1.6, 24)
	smoke.one_shot = true
	smoke.explosiveness = 0.9
	smoke.lifetime = 2.4
	smoke.spread = 180.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 3.0
	smoke.damping_min = 1.5
	smoke.damping_max = 2.5
	smoke.gravity = Vector3(0, 0.5, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.6, 0.6, 0.62, 0.9))
	ramp.set_color(1, Color(0.4, 0.4, 0.42, 0.0))
	smoke.color_ramp = ramp
	root.add_child(smoke)
	smoke.global_position = position
	smoke.emitting = true
	_free_after(smoke, 3.0)


## Струя газа из пробитого баллона.
func gas_jet(parent: Node3D, local_position: Vector3, direction: Vector3) -> Node3D:
	var jet := _smoke_particles(0.18, 30)
	jet.material_override = _particle_material("gas")
	jet.lifetime = 0.45
	jet.local_coords = false
	jet.direction = direction
	jet.spread = 10.0
	jet.initial_velocity_min = 6.0
	jet.initial_velocity_max = 9.0
	jet.gravity = Vector3.ZERO
	jet.damping_min = 8.0
	jet.damping_max = 10.0
	parent.add_child(jet)
	jet.position = local_position
	jet.emitting = true
	return jet


func _flame_particles(color: Color, size: float, amount: int) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size * 0.5
	mesh.height = size
	mesh.radial_segments = 6
	mesh.rings = 3
	particles.mesh = mesh
	particles.material_override = _particle_material("fire")
	particles.amount = amount
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.2
	particles.scale_amount_curve = _grow_shrink_curve()
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(0.5, 0.05, 0.0, 0.0))
	ramp.add_point(0.45, Color(1.0, 0.35, 0.05, 0.85))
	particles.color_ramp = ramp
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return particles


func _smoke_particles(size: float, amount: int) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size * 0.5
	mesh.height = size
	mesh.radial_segments = 6
	mesh.rings = 3
	particles.mesh = mesh
	particles.material_override = _particle_material("smoke")
	particles.amount = amount
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	particles.scale_amount_curve = _grow_curve()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.22, 0.21, 0.2, 0.7))
	ramp.set_color(1, Color(0.1, 0.1, 0.1, 0.0))
	particles.color_ramp = ramp
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return particles


func _particle_material(kind: String) -> StandardMaterial3D:
	var key := "particles_" + kind
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if kind == "fire":
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		if kind == "gas":
			material.albedo_color = Color(0.9, 0.92, 0.95, 0.35)
		_materials[key] = material
	return _materials[key]


func _grow_shrink_curve() -> Curve:
	if not _materials.has("curve_grow_shrink"):
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.4))
		curve.add_point(Vector2(0.3, 1.0))
		curve.add_point(Vector2(1.0, 0.2))
		_materials["curve_grow_shrink"] = curve
	return _materials["curve_grow_shrink"]


func _grow_curve() -> Curve:
	if not _materials.has("curve_grow"):
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.3))
		curve.add_point(Vector2(1.0, 1.0))
		_materials["curve_grow"] = curve
	return _materials["curve_grow"]


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
