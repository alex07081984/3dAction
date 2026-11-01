class_name ChaseCar
extends CharacterBody3D
## Машина на шоссе. Попутные (traffic, бензовоз) едут медленнее и остаются позади;
## бензовоз от выстрелов взрывается так, что сносит всех рядом.
## Машины и мотоциклы банды догоняют сзади, держатся рядом, стрелок высовывается
## и стреляет (перед выстрелом — красный лазер), машины иногда идут на таран.
## Можно взорвать машину или застрелить стрелка — тогда она теряет управление и разбивается.

enum Kind { TRAFFIC, TANKER, CAR, BIKE }

const WORLD_MASK := 1
const PLAYER_MASK := 2
const PAINT := [Color(0.5, 0.06, 0.05), Color(0.75, 0.73, 0.68), Color(0.12, 0.2, 0.35), Color(0.3, 0.26, 0.2),
		Color(0.2, 0.32, 0.2)]

var kind := Kind.TRAFFIC
var hostile := false
var health := 100.0
var wrecked := false
## Скорость попутной машины по дороге (она медленнее героя и отстаёт).
var cruise := 18.0

var _level: Node
var _player: Player
var _rider: BlockyCharacter
var _rider_health := 0.0
var _rider_height := 1.2
var _offset := Vector3.ZERO  ## Где держаться относительно героя.
var _offset_timer := 0.0
var _aim_left := 0.0
var _fire_timer := 2.0
var _ram_left := 0.0
var _ram_timer := 7.0
var _out_of_control := 0.0
var _wreck_time := 0.0
var _spin := Vector3.ZERO
var _laser: MeshInstance3D
var _body_mesh: MeshInstance3D
var _sideways := 1.0


static func create(car_kind: Kind, level: Node) -> ChaseCar:
	var car := ChaseCar.new()
	car.kind = car_kind
	car._level = level
	car.hostile = car_kind == Kind.CAR or car_kind == Kind.BIKE
	return car


func _ready() -> void:
	add_to_group("chase_cars")
	if hostile:
		add_to_group("vehicles")
	collision_layer = 4 if hostile else 1
	collision_mask = 0
	_player = get_tree().get_first_node_in_group("player") as Player
	match kind:
		Kind.TRAFFIC:
			health = 110.0
			_build_car(PAINT.pick_random(), false)
		Kind.TANKER:
			health = 70.0
			_build_tanker()
		Kind.CAR:
			health = 160.0 * Game.enemy_health_multiplier()
			_build_car(Color(0.08, 0.08, 0.09), true)
		Kind.BIKE:
			health = 70.0 * Game.enemy_health_multiplier()
			_build_bike()
	if hostile:
		_rider_health = 45.0 * Game.enemy_health_multiplier()
		_pick_offset()
		_build_laser()
	_fire_timer = randf_range(1.5, 3.0)


func is_rider_alive() -> bool:
	return _rider != null and _rider_health > 0.0


## Попадание пули: выше кузова — в стрелка (в голову втрое больнее), ниже — в машину.
func take_hit(damage: float, point: Vector3, direction: Vector3) -> void:
	if wrecked:
		return
	Fx.sparks(point, -direction)
	if hostile and is_rider_alive() and point.y > global_position.y + _rider_height - 0.1:
		var headshot := point.y > global_position.y + _rider_height + 1.25
		_rider_health -= damage * (3.0 if headshot else 1.0)
		Fx.blood(point, direction, 14)
		if _rider_health <= 0.0:
			_kill_rider(headshot, direction)
		return
	health -= damage
	if health <= 0.0:
		explode()


## Машина взрывается и кувыркается назад.
func explode() -> void:
	if wrecked:
		return
	var radius := 7.0
	var damage := 220.0
	var to_player := 35
	if kind == Kind.TANKER:
		radius = 12.0
		damage = 320.0
		to_player = 50
	elif kind == Kind.BIKE:
		radius = 4.0
		damage = 120.0
		to_player = 18
	if is_rider_alive():
		_rider_health = 0.0
		_rider.break_apart(BlockyCharacter.Death.GIB, Vector3.UP + Vector3.BACK, 9.0)
		_count_kill(false)
	_wreck()
	Explosive.blast(self, global_position + Vector3.UP, radius, damage, to_player)


## Столкновение с машиной героя: отлетает и разбивается.
func crash(push: float) -> void:
	if wrecked:
		return
	position.x += push
	if kind == Kind.TANKER:
		explode()
		return
	if is_rider_alive():
		_kill_rider(false, Vector3(push, 1, 0))
	_wreck()


func _physics_process(delta: float) -> void:
	var speed: float = _level.speed if _level else 30.0
	if wrecked:
		_wreck_time += delta
		position.z += speed * 0.9 * delta
		position.y = maxf(position.y + (4.0 - 12.0 * _wreck_time) * delta, 0.0)
		rotation += _spin * delta * maxf(1.0 - _wreck_time * 0.4, 0.0)
		if position.z > 160.0:
			queue_free()
		return
	if not hostile:
		position.z += (speed - cruise) * delta
		if position.z > 160.0:
			queue_free()
		return
	if _out_of_control > 0.0:
		# Стрелок убит: машину ведёт в кювет, потом она разбивается.
		_out_of_control -= delta
		position.x += _sideways * 6.0 * delta
		position.z += 6.0 * delta
		rotation.y += _sideways * 1.5 * delta
		if _out_of_control <= 0.0:
			explode()
		return
	_chase(delta)
	if is_rider_alive():
		_rider.animate(delta, 0.0, true, 0.0)
		_shoot(delta)
		_rider.rotation.y = lerp_angle(_rider.rotation.y, _yaw_to_player() - rotation.y, 1.0 - exp(-8.0 * delta))


# --- Погоня ---------------------------------------------------------------------------

func _chase(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_offset_timer -= delta
	if _offset_timer <= 0.0:
		_pick_offset()
	var goal := _player.global_position + _offset
	var road: float = _level.road_half - 1.3 if _level else 7.7
	goal.x = clampf(goal.x, -road, road)
	if kind == Kind.CAR:
		_ram_timer -= delta
		if _ram_timer <= 0.0 and absf(_offset.z) < 6.0:
			_ram_timer = randf_range(6.0, 10.0)
			_ram_left = 1.2
	if _ram_left > 0.0:
		_ram_left -= delta
		goal.x = _player.global_position.x
	var lateral := (8.0 if kind == Kind.BIKE else 6.0) * (2.0 if _ram_left > 0.0 else 1.0)
	position.x = move_toward(position.x, goal.x, lateral * delta)
	position.z = move_toward(position.z, goal.z, 14.0 * delta)
	rotation.y = lerp_angle(rotation.y, clampf((goal.x - position.x) * -0.08, -0.3, 0.3), 1.0 - exp(-4.0 * delta))
	if kind == Kind.BIKE:
		rotation.z = clampf((goal.x - position.x) * -0.1, -0.35, 0.35)


func _pick_offset() -> void:
	_offset_timer = randf_range(3.0, 6.0)
	var side := -1.0 if randf() < 0.5 else 1.0
	match kind:
		Kind.BIKE:
			_offset = Vector3(side * randf_range(2.5, 5.0), 0, randf_range(-4.0, 12.0))
		_:
			_offset = Vector3(side * randf_range(3.6, 5.0), 0, randf_range(-3.0, 10.0))


func _shoot(delta: float) -> void:
	if not is_instance_valid(_player) or not _player.is_alive() or global_position.z - _player.global_position.z > 45.0:
		_show_laser(false)
		return
	if _aim_left > 0.0:
		_aim_left -= delta
		_show_laser(true)
		if _aim_left <= 0.0:
			_fire()
		return
	_show_laser(false)
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = randf_range(1.6, 2.8)
		_aim_left = 0.8


func _fire() -> void:
	var muzzle := _rider.get_muzzle_position()
	var target := _player.global_position + Vector3.UP * 1.2
	var distance := muzzle.distance_to(target)
	var will_hit := randf() < 0.55 * clampf(1.2 - distance / 40.0, 0.35, 1.0)
	var aim := target
	if not will_hit:
		aim += Vector3(randf_range(-1.5, 1.5), randf_range(-0.3, 1.0), randf_range(-1.5, 1.5))
	var direction := (aim - muzzle).normalized()
	var end := muzzle + direction * 80.0
	var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(muzzle, end, WORLD_MASK | PLAYER_MASK, [get_rid()]))
	if hit:
		end = hit.position
		if hit.collider is Player and will_hit:
			(hit.collider as Player).take_damage(roundi((5 if kind == Kind.BIKE else 7) * Game.enemy_damage_multiplier()),
					global_position)
	Fx.tracer(muzzle, end, Color(1.0, 0.45, 0.25))
	Fx.muzzle_flash(muzzle, direction)
	Audio.play_at("enemy_shot", muzzle, 0.0)
	_rider.recoil(0.25)


func _kill_rider(headshot: bool, direction: Vector3) -> void:
	_rider_health = 0.0
	_show_laser(false)
	_rider.break_apart(BlockyCharacter.Death.HEADSHOT if headshot else BlockyCharacter.Death.FALL, direction, 6.0)
	Audio.play_at("headshot" if headshot else "death", global_position + Vector3.UP * 2.0)
	_count_kill(headshot)
	_sideways = 1.0 if position.x > 0.0 else -1.0
	_out_of_control = 1.4


func _count_kill(headshot: bool) -> void:
	if hostile:
		get_tree().call_group("level", "register_kill", headshot)


func _wreck() -> void:
	wrecked = true
	_show_laser(false)
	remove_from_group("vehicles")
	var burnt := StandardMaterial3D.new()
	burnt.albedo_color = Color(0.07, 0.065, 0.06)
	for child in find_children("*", "MeshInstance3D", true, false):
		if child != _laser:
			(child as MeshInstance3D).material_override = burnt
	Fx.fire(self, Vector3(0, 1.0, -1.0), 1.4)
	_spin = Vector3(randf_range(-3, 3), randf_range(-2, 2), randf_range(-4, 4))
	collision_layer = 0


func _yaw_to_player() -> float:
	var to := _player.global_position - global_position
	return atan2(-to.x, -to.z)


# --- Модели ------------------------------------------------------------------------------

func _build_car(paint: Color, gang: bool) -> void:
	_add_box(Vector3(2.0, 1.55, 4.4), Vector3(0, 0.85, 0), null)
	_body_mesh = _mesh(Vector3(2.0, 0.8, 4.4), Vector3(0, 0.75, 0), paint)
	_mesh(Vector3(1.8, 0.65, 2.2), Vector3(0, 1.47, 0.25), Color(0.05, 0.06, 0.08))
	_mesh(Vector3(2.05, 0.75, 0.75), Vector3(0, 0.38, -1.4), Color(0.05, 0.05, 0.05))
	_mesh(Vector3(2.05, 0.75, 0.75), Vector3(0, 0.38, 1.4), Color(0.05, 0.05, 0.05))
	if gang:
		# Стрелок высовывается из люка на крыше.
		_add_rider(Vector3(0, 1.2, 0.4), "rifle", 1.2)


func _build_tanker() -> void:
	_add_box(Vector3(2.4, 3.2, 9.0), Vector3(0, 1.6, 0.5), null)
	_body_mesh = _mesh(Vector3(2.3, 2.2, 2.4), Vector3(0, 1.4, -3.0), Color(0.55, 0.08, 0.06))
	var tank := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.2
	cylinder.bottom_radius = 1.2
	cylinder.height = 6.4
	cylinder.radial_segments = 14
	cylinder.material = _material(Color(0.82, 0.82, 0.8))
	tank.mesh = cylinder
	tank.rotation.x = PI / 2
	tank.position = Vector3(0, 1.9, 1.6)
	add_child(tank)
	_mesh(Vector3(2.45, 0.35, 6.4), Vector3(0, 1.9, 1.6), Color(0.8, 0.1, 0.05))
	_mesh(Vector3(2.4, 0.8, 0.8), Vector3(0, 0.4, -3.0), Color(0.05, 0.05, 0.05))
	_mesh(Vector3(2.4, 0.8, 0.8), Vector3(0, 0.4, 2.8), Color(0.05, 0.05, 0.05))
	var label := Label3D.new()
	label.text = "ОГНЕОПАСНО"
	label.pixel_size = 0.008
	label.font_size = 56
	label.modulate = Color(0.85, 0.1, 0.05)
	label.position = Vector3(1.23, 1.9, 1.6)
	label.rotation.y = PI / 2
	add_child(label)
	cruise = 16.0


func _build_bike() -> void:
	_add_box(Vector3(0.8, 1.1, 2.1), Vector3(0, 0.55, 0), null)
	_body_mesh = _mesh(Vector3(0.45, 0.5, 1.6), Vector3(0, 0.7, 0), Color(0.1, 0.1, 0.1))
	_mesh(Vector3(0.18, 0.7, 0.7), Vector3(0, 0.35, -0.85), Color(0.05, 0.05, 0.05))
	_mesh(Vector3(0.18, 0.7, 0.7), Vector3(0, 0.35, 0.85), Color(0.05, 0.05, 0.05))
	_mesh(Vector3(0.7, 0.08, 0.08), Vector3(0, 1.15, -0.6), Color(0.6, 0.6, 0.6))
	_add_rider(Vector3(0, 0.55, 0.15), "pistol", 0.55)


func _add_rider(at: Vector3, weapon: String, threshold: float) -> void:
	_rider = BlockyCharacter.new()
	_rider.random_look = true
	_rider.outfit = "jacket"
	_rider.weapon = weapon
	_rider.position = at
	add_child(_rider)
	_rider_height = threshold
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.9
	shape.shape = capsule
	shape.position = at + Vector3.UP * 0.95
	add_child(shape)


func _add_box(size: Vector3, center: Vector3, _unused: Variant) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	add_child(shape)


func _mesh(size: Vector3, center: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _material(color)
	mesh.mesh = box
	mesh.position = center
	add_child(mesh)
	return mesh


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.4
	material.metallic = 0.3
	return material


func _build_laser() -> void:
	_laser = MeshInstance3D.new()
	var beam := BoxMesh.new()
	beam.size = Vector3(0.025, 0.025, 1.0)
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1.0, 0.1, 0.1, 0.75)
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material = red
	_laser.mesh = beam
	_laser.top_level = true
	_laser.visible = false
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_laser)


func _show_laser(on: bool) -> void:
	if _laser == null:
		return
	_laser.visible = on and is_rider_alive() and is_instance_valid(_player)
	if not _laser.visible:
		return
	var from := _rider.get_muzzle_position()
	var to := _player.global_position + Vector3.UP * 1.2
	_laser.global_transform = Transform3D(Basis.looking_at(to - from), (from + to) * 0.5)
	_laser.scale = Vector3(1.0, 1.0, from.distance_to(to))
	if _aim_left < 0.25:
		_laser.visible = int(_aim_left * 30.0) % 2 == 0
