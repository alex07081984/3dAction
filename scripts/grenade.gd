class_name Grenade
extends RigidBody3D
## Граната: летит по дуге, отскакивает от стен, мигает и пищит всё чаще,
## а потом взрывается (как бочка: ранит всех вокруг и подрывает соседние бочки).
## Бросают её игрок и Начальник тюрьмы.

@export var fuse := 2.2
@export var blast_radius := 5.5
@export var blast_damage := 170.0
@export var player_damage := 35

var _left := 0.0
var _beep := 0.0
var _light: OmniLight3D
var _exploded := false


## Бросок по дуге так, чтобы граната упала в точке target (не дальше max_range).
static func throw_at(parent: Node, from: Vector3, target: Vector3, max_range := 24.0, fuse_time := 2.2,
		damage_to_player := 35) -> Grenade:
	var offset := target - from
	var flat := Vector3(offset.x, 0.0, offset.z)
	if flat.length() > max_range:
		flat = flat.normalized() * max_range
	var distance := flat.length()
	var flight := clampf(distance / 12.0, 0.45, 1.3)
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var velocity := flat / flight
	velocity.y = (offset.y + 0.5 * gravity * flight * flight) / flight
	var grenade := Grenade.new()
	grenade.fuse = fuse_time
	grenade.player_damage = damage_to_player
	parent.add_child(grenade)
	grenade.global_position = from
	grenade.linear_velocity = velocity
	grenade.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	grenade.reset_physics_interpolation()
	Audio.play_at("swing", from, -4.0, 1.3)
	return grenade


func _ready() -> void:
	add_to_group("grenades")
	collision_layer = 8
	collision_mask = 1 | 8
	mass = 0.4
	continuous_cd = true
	var material := PhysicsMaterial.new()
	material.bounce = 0.35
	material.friction = 0.8
	physics_material_override = material
	# После первого касания граната быстро гасит скорость и не укатывается от цели.
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered, CONNECT_ONE_SHOT)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.09
	shape.shape = sphere
	add_child(shape)
	var model := Node3D.new()
	BlockyCharacter.add_part_mesh(model, [[Vector3(0.13, 0.17, 0.13), Vector3.ZERO, Color(0.22, 0.26, 0.16), 0.04],
			[Vector3(0.05, 0.05, 0.05), Vector3(0, 0.1, 0), Color(0.5, 0.5, 0.48)],
			[Vector3(0.02, 0.1, 0.06), Vector3(0.05, 0.06, 0), Color(0.5, 0.5, 0.48)]])
	add_child(model)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.15, 0.1)
	_light.light_energy = 1.5
	_light.omni_range = 2.5
	_light.position.y = 0.12
	add_child(_light)
	_left = fuse


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_left -= delta
	_beep -= delta
	if _beep <= 0.0:
		# Чем ближе взрыв, тем чаще писк и мигание.
		_beep = clampf(_left * 0.22, 0.07, 0.45)
		_light.visible = not _light.visible
		if _light.visible:
			Audio.play_at("beep", global_position, -4.0, 1.0, 0.02)
	if _left <= 0.0:
		explode()


func _on_body_entered(_body: Node) -> void:
	linear_damp = 5.0
	angular_damp = 3.0


func explode() -> void:
	if _exploded or not is_inside_tree():
		return
	_exploded = true
	Explosive.blast(self, global_position + Vector3.UP * 0.25, blast_radius, blast_damage, player_damage)
	queue_free()
