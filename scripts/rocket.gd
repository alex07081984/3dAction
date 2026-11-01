class_name Rocket
extends Node3D
## Ракета (РПГ игрока, позже — ракеты вертолёта и снаряды танка): летит по прямой,
## оставляет дымный след и взрывается при попадании во что угодно.

const WORLD_MASK := 1
const PLAYER_MASK := 2
const ENEMY_MASK := 4
const LIFETIME := 4.0

var velocity := Vector3.ZERO
var radius := 5.5
var damage := 200.0
var player_damage := 40
var mask := WORLD_MASK | ENEMY_MASK
var exclude: Array[RID] = []

var _life := LIFETIME
var _done := false
var _trail: CPUParticles3D


## Выпустить ракету. hits_player — ракета врага: попадает в игрока, а не во врагов.
static func launch(parent: Node, from: Vector3, direction: Vector3, speed: float, blast_radius: float,
		blast_damage: float, damage_to_player: int, shooter: CollisionObject3D = null, hits_player := false) -> Rocket:
	var rocket := Rocket.new()
	rocket.name = "Rocket"
	rocket.velocity = direction.normalized() * speed
	rocket.radius = blast_radius
	rocket.damage = blast_damage
	rocket.player_damage = damage_to_player
	rocket.mask = WORLD_MASK | (PLAYER_MASK if hits_player else ENEMY_MASK)
	if shooter:
		rocket.exclude.append(shooter.get_rid())
	parent.add_child(rocket)
	rocket.global_position = from
	var up := Vector3.UP if absf(direction.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	rocket.look_at(from + direction, up)
	rocket.reset_physics_interpolation()
	return rocket


func is_exploded() -> bool:
	return _done


func _ready() -> void:
	add_to_group("rockets")
	_build()


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life -= delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		_explode(hit.position - velocity.normalized() * 0.25)
		return
	global_position = to
	if _life <= 0.0:
		_explode(global_position)


func _explode(at: Vector3) -> void:
	_done = true
	global_position = at
	Explosive.blast(self, at, radius, damage, player_damage)
	# Дымный след ещё повисит в воздухе.
	if is_instance_valid(_trail) and get_parent():
		_trail.reparent(get_parent())
		_trail.emitting = false
		get_tree().create_timer(_trail.lifetime + 0.2, false).timeout.connect(_trail.queue_free)
	queue_free()


func _build() -> void:
	var olive := Color(0.3, 0.33, 0.22)
	var body := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.05
	tube.bottom_radius = 0.05
	tube.height = 0.55
	tube.radial_segments = 8
	tube.material = _mat(olive)
	body.mesh = tube
	body.rotation.x = PI / 2
	add_child(body)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.09
	cone.height = 0.28
	cone.radial_segments = 8
	cone.material = _mat(olive.darkened(0.3))
	head.mesh = cone
	head.rotation.x = -PI / 2
	head.position = Vector3(0, 0, -0.4)
	add_child(head)
	# Огонь из сопла, свет и дымный след.
	var flame := MeshInstance3D.new()
	var glow := SphereMesh.new()
	glow.radius = 0.09
	glow.height = 0.3
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.7, 0.3)
	glow.material = hot
	flame.mesh = glow
	flame.position = Vector3(0, 0, 0.35)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 2.0
	light.omni_range = 4.0
	light.position = Vector3(0, 0, 0.5)
	add_child(light)
	_trail = CPUParticles3D.new()
	var puff := SphereMesh.new()
	puff.radius = 0.12
	puff.height = 0.24
	puff.radial_segments = 6
	puff.rings = 3
	var smoke := StandardMaterial3D.new()
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.vertex_color_use_as_albedo = true
	puff.material = smoke
	_trail.mesh = puff
	_trail.amount = 40
	_trail.lifetime = 1.0
	_trail.local_coords = false
	_trail.direction = Vector3(0, 0, 1)
	_trail.spread = 8.0
	_trail.initial_velocity_min = 0.5
	_trail.initial_velocity_max = 1.2
	_trail.gravity = Vector3(0, 0.6, 0)
	_trail.scale_amount_min = 0.8
	_trail.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.82, 0.78, 0.7))
	ramp.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	_trail.color_ramp = ramp
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_trail.position = Vector3(0, 0, 0.4)
	add_child(_trail)
	_trail.emitting = true


static func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return material
