class_name BlockyCharacter
extends Node3D
## Персонаж из блоков: голова, торс, руки, ноги и оружие в руке.
## Модель строится кодом, поэтому цвета меняются прямо в Инспекторе.
## Умеет ходить, целиться, замахиваться битой и разваливаться:
## падать целиком, терять голову (хедшот) или разлетаться на куски (дробовик в упор).

enum Death { FALL, HEADSHOT, GIB }

const NECK_Y := 1.52  ## Высота шеи: всё, что выше, — попадание в голову.
const DEBRIS_LAYER := 8  # слой 4 «debris»
const DEBRIS_MASK := 1 | 8  # мир и другие обломки
const DEBRIS_LIFETIME := 9.0
const MAX_DEBRIS := 36

static var _debris: Array = []
static var _material_cache := {}

@export var skin_color := Color(0.92, 0.74, 0.6)
@export var shirt_color := Color(0.25, 0.45, 0.85)
@export var pants_color := Color(0.16, 0.17, 0.22)
@export var hair_color := Color(0.18, 0.12, 0.08)
@export var shoe_color := Color(0.1, 0.1, 0.1)
@export var vest_color := Color(0, 0, 0, 0)  ## Бронежилет. Прозрачный цвет — без жилета.
@export var mask_color := Color(0, 0, 0, 0)  ## Балаклава. Прозрачный цвет — без маски.
@export var weapon := "pistol"  ## pistol, deagle, shotgun, rifle, bat или пусто.

## Поза удара битой: -1 — нет, 0..1 — от «опущена» до «занесена над головой».
var melee_pose := -1.0
var muzzle: Node3D

var _hips: Node3D
var _chest: Node3D
var _torso: MeshInstance3D
var _neck: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _hand: Node3D
var _gun: Node3D
var _phase := 0.0
var _recoil := 0.0
var _flinch := 0.0
var _broken := false


func _ready() -> void:
	_build()


## Обновить позу. speed — скорость ходьбы 0..1, aim_pitch — наклон прицела (вверх > 0).
func animate(delta: float, speed: float, aiming: bool, aim_pitch := 0.0) -> void:
	if _broken or _hips == null:
		return
	speed = clampf(speed, 0.0, 1.2)
	_phase += delta * (4.0 + 7.0 * speed)
	var swing := sin(_phase) * 0.8 * minf(speed, 1.0)
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_hips.position.y = 0.9 + absf(sin(_phase)) * 0.05 * minf(speed, 1.0)

	_recoil = move_toward(_recoil, 0.0, delta * 4.0)
	_flinch = move_toward(_flinch, 0.0, delta * 3.0)
	_chest.rotation.x = -_flinch * 0.45 + _recoil * 0.3

	if melee_pose >= 0.0:
		_arm_r.rotation = Vector3(lerpf(0.4, PI * 1.05, melee_pose), 0.0, 0.0)
		_arm_l.rotation = Vector3(swing * 0.5, 0.0, -0.1)
		_neck.rotation.x = 0.0
	elif aiming:
		var pitch := PI / 2.0 + aim_pitch + _recoil
		_arm_r.rotation = Vector3(pitch, 0.15, 0.0)
		_arm_l.rotation = Vector3(pitch - 0.1, -0.7, 0.0)
		_neck.rotation.x = aim_pitch * 0.5
	else:
		_arm_r.rotation = Vector3(-swing * 0.8, 0.0, 0.06)
		_arm_l.rotation = Vector3(swing * 0.8, 0.0, -0.06)
		_neck.rotation.x = 0.0


func recoil(amount := 0.25) -> void:
	_recoil = maxf(_recoil, amount)


func flinch(amount := 0.6) -> void:
	_flinch = maxf(_flinch, amount)


func set_weapon(kind: String) -> void:
	weapon = kind
	if _gun:
		_gun.queue_free()
		_gun = null
	muzzle = null
	if kind.is_empty() or _hand == null:
		return
	_gun = build_weapon_model(kind)
	_hand.add_child(_gun)
	muzzle = _gun.get_node("Muzzle")


## Точка выстрела: дуло, а если оружия нет — уровень груди.
func get_muzzle_position() -> Vector3:
	if is_instance_valid(muzzle):
		return muzzle.global_position
	return global_position + Vector3.UP * 1.3 * global_basis.get_scale().y


## Разваливает модель на физические обломки. Сам узел после этого пустой.
func break_apart(mode: Death, direction: Vector3, force: float) -> void:
	if _broken or _hips == null:
		return
	_broken = true
	direction.y = maxf(direction.y, 0.0)
	direction = direction.normalized() if direction.length_squared() > 0.001 else -global_basis.z
	var container := _debris_container()
	var neck_position := _neck.global_transform * Vector3(0, 0.05, 0)

	match mode:
		Death.GIB:
			var center := _chest.global_position
			var parts := [
				[_neck, Vector3(0.38, 0.38, 0.38), Vector3(0, 0.21, 0)],
				[_arm_l, Vector3(0.17, 0.7, 0.19), Vector3(0, -0.33, 0)],
				[_arm_r, Vector3(0.17, 0.7, 0.19), Vector3(0, -0.33, 0)],
				[_leg_l, Vector3(0.23, 0.9, 0.26), Vector3(0, -0.43, 0)],
				[_leg_r, Vector3(0.23, 0.9, 0.26), Vector3(0, -0.43, 0)],
				[_torso, Vector3(0.56, 0.62, 0.3), Vector3.ZERO],
			]
			for part in parts:
				var body := _make_body(part[0], part[1], part[2], container)
				var spread := Vector3(randf_range(-3, 3), randf_range(2.5, 6.0), randf_range(-3, 3))
				body.linear_velocity = direction * force * randf_range(0.6, 1.3) + spread
				body.angular_velocity = Vector3(randf_range(-14, 14), randf_range(-14, 14), randf_range(-14, 14))
				Fx.blood_fountain(body, Vector3.ZERO, 0.45)
			for i in 6:
				_spawn_chunk(container, center, direction, force)
			Fx.blood(center, direction, 40)
			Fx.blood(center, Vector3.UP, 25)
			Fx.blood_pool(center, 1.8)

		Death.HEADSHOT:
			var head := _make_body(_neck, Vector3(0.38, 0.38, 0.38), Vector3(0, 0.21, 0), container)
			head.linear_velocity = direction * force * 0.8 + Vector3(randf_range(-1, 1), randf_range(4, 6), randf_range(-1, 1))
			head.angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
			Fx.blood_fountain(head, Vector3.ZERO, 0.6)
			Fx.blood(neck_position, direction, 30)
			var torso := _make_body(_hips, Vector3(0.6, 1.52, 0.35), Vector3(0, -0.14, 0), container)
			_topple(torso, direction, force * 0.3)
			# Фонтан крови из шеи, который падает вместе с телом.
			Fx.blood_fountain(torso, torso.to_local(neck_position), 2.2)
			Fx.blood_pool(neck_position, 1.3)

		_:
			var whole := _make_body(_hips, Vector3(0.6, 1.92, 0.4), Vector3(0, 0.06, 0), container)
			_topple(whole, direction, force * 0.4)
			Fx.blood_pool(global_position + Vector3.UP * 0.5, 1.0)


## Строит модельку оружия. Ствол смотрит в -Z, рукоять вниз. Есть точка «Muzzle».
static func build_weapon_model(kind: String) -> Node3D:
	var gun := Node3D.new()
	gun.name = "Gun"
	var dark := Color(0.13, 0.13, 0.15)
	var wood := Color(0.45, 0.28, 0.14)
	var muzzle_at := Vector3(0, 0.07, -0.22)
	match kind:
		"pistol":
			add_box(gun, Vector3(0.06, 0.09, 0.24), Vector3(0, 0.07, -0.08), dark)
			add_box(gun, Vector3(0.05, 0.14, 0.07), Vector3(0, 0.0, 0.02), Color(0.08, 0.08, 0.08))
		"deagle":
			var steel := Color(0.72, 0.73, 0.77)
			add_box(gun, Vector3(0.075, 0.11, 0.33), Vector3(0, 0.08, -0.11), steel)
			add_box(gun, Vector3(0.06, 0.15, 0.08), Vector3(0, -0.01, 0.03), Color(0.08, 0.08, 0.08))
			add_box(gun, Vector3(0.05, 0.04, 0.05), Vector3(0, 0.15, 0.0), steel)
			muzzle_at = Vector3(0, 0.08, -0.29)
		"shotgun":
			add_box(gun, Vector3(0.07, 0.11, 0.3), Vector3(0, 0.06, -0.05), dark)
			add_box(gun, Vector3(0.05, 0.05, 0.62), Vector3(0, 0.09, -0.5), dark)
			add_box(gun, Vector3(0.08, 0.07, 0.22), Vector3(0, 0.03, -0.38), wood)
			add_box(gun, Vector3(0.06, 0.12, 0.32), Vector3(0, 0.03, 0.22), wood)
			muzzle_at = Vector3(0, 0.09, -0.82)
		"rifle":
			var olive := Color(0.2, 0.22, 0.17)
			add_box(gun, Vector3(0.07, 0.13, 0.6), Vector3(0, 0.07, -0.2), olive)
			add_box(gun, Vector3(0.04, 0.04, 0.3), Vector3(0, 0.09, -0.62), dark)
			add_box(gun, Vector3(0.05, 0.16, 0.08), Vector3(0, -0.06, -0.12), dark)
			add_box(gun, Vector3(0.06, 0.11, 0.25), Vector3(0, 0.04, 0.2), olive)
			muzzle_at = Vector3(0, 0.09, -0.78)
		"bat":
			add_box(gun, Vector3(0.06, 0.06, 0.5), Vector3(0, 0.0, -0.2), wood)
			add_box(gun, Vector3(0.1, 0.1, 0.42), Vector3(0, 0.0, -0.62), wood.lightened(0.15))
			muzzle_at = Vector3(0, 0, -0.8)
	var marker := Marker3D.new()
	marker.name = "Muzzle"
	marker.position = muzzle_at
	gun.add_child(marker)
	return gun


# --- Построение модели -------------------------------------------------------

func _build() -> void:
	_hips = _pivot(self, "Hips", Vector3(0, 0.9, 0))
	_leg_l = _pivot(_hips, "HipL", Vector3(-0.14, 0, 0))
	_leg_r = _pivot(_hips, "HipR", Vector3(0.14, 0, 0))
	for leg in [_leg_l, _leg_r]:
		add_box(leg, Vector3(0.22, 0.78, 0.24), Vector3(0, -0.39, 0), pants_color)
		add_box(leg, Vector3(0.23, 0.12, 0.3), Vector3(0, -0.84, -0.03), shoe_color)

	_chest = _pivot(_hips, "Chest", Vector3.ZERO)
	_torso = add_box(_chest, Vector3(0.56, 0.62, 0.3), Vector3(0, 0.31, 0), shirt_color)
	add_box(_torso, Vector3(0.58, 0.08, 0.32), Vector3(0, -0.27, 0), Color(0.12, 0.1, 0.08))
	if vest_color.a > 0.0:
		add_box(_torso, Vector3(0.6, 0.44, 0.36), Vector3(0, 0.05, 0), vest_color)

	_neck = _pivot(_chest, "Neck", Vector3(0, 0.62, 0))
	var masked := mask_color.a > 0.0
	var head := add_box(_neck, Vector3(0.38, 0.38, 0.38), Vector3(0, 0.21, 0), mask_color if masked else skin_color)
	if masked:
		add_box(head, Vector3(0.3, 0.09, 0.02), Vector3(0, 0.03, -0.19), skin_color)
	else:
		add_box(head, Vector3(0.4, 0.12, 0.4), Vector3(0, 0.17, 0.01), hair_color)
	for x in [-0.08, 0.08]:
		add_box(head, Vector3(0.06, 0.05, 0.02), Vector3(x, 0.03, -0.2), Color(0.05, 0.05, 0.05))

	_arm_l = _pivot(_chest, "ShoulderL", Vector3(-0.37, 0.56, 0))
	_arm_r = _pivot(_chest, "ShoulderR", Vector3(0.37, 0.56, 0))
	for arm in [_arm_l, _arm_r]:
		add_box(arm, Vector3(0.17, 0.56, 0.19), Vector3(0, -0.26, 0), shirt_color)
		add_box(arm, Vector3(0.15, 0.13, 0.17), Vector3(0, -0.6, 0), skin_color)
	# Кисть правой руки повёрнута так, чтобы ствол смотрел вдоль руки.
	_hand = _pivot(_arm_r, "Grip", Vector3(0, -0.62, 0))
	_hand.rotation.x = -PI / 2.0
	set_weapon(weapon)


func _pivot(parent: Node3D, node_name: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = at
	parent.add_child(node)
	return node


static func add_box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	parent.add_child(mesh_instance)
	return mesh_instance


static func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _material_cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.8
		_material_cache[key] = material
	return _material_cache[key]


# --- Обломки -------------------------------------------------------------------

## Превращает часть модели в физическое тело, не сдвигая её на экране.
func _make_body(part: Node3D, size: Vector3, center: Vector3, container: Node) -> RigidBody3D:
	var scale_factor := part.global_basis.get_scale().x
	var body := RigidBody3D.new()
	body.collision_layer = DEBRIS_LAYER
	body.collision_mask = DEBRIS_MASK
	body.mass = maxf(size.x * size.y * size.z * 60.0, 0.5)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size * scale_factor
	shape.shape = box
	body.add_child(shape)
	container.add_child(body)
	body.global_transform = Transform3D(part.global_basis.orthonormalized(), part.global_transform * center)
	part.reparent(body, true)
	body.reset_physics_interpolation()
	_register_debris(body)
	return body


func _topple(body: RigidBody3D, direction: Vector3, push: float) -> void:
	body.linear_velocity = direction * push + Vector3.UP * 1.5
	body.angular_velocity = Vector3.UP.cross(direction) * randf_range(2.0, 3.5) \
			+ Vector3(0, randf_range(-1.5, 1.5), 0)


## Кусочки «мяса» для взрыва тела.
func _spawn_chunk(container: Node, at: Vector3, direction: Vector3, force: float) -> void:
	var body := RigidBody3D.new()
	body.collision_layer = DEBRIS_LAYER
	body.collision_mask = DEBRIS_MASK
	var size := Vector3.ONE * randf_range(0.1, 0.18)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_box(body, size, Vector3.ZERO, Color(0.5, 0.03, 0.03))
	container.add_child(body)
	body.global_position = at + Vector3(randf_range(-0.2, 0.2), randf_range(-0.3, 0.3), randf_range(-0.2, 0.2))
	body.linear_velocity = direction * force * randf_range(0.5, 1.4) \
			+ Vector3(randf_range(-4, 4), randf_range(2, 7), randf_range(-4, 4))
	body.angular_velocity = Vector3(randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15))
	body.reset_physics_interpolation()
	_register_debris(body)


func _register_debris(body: RigidBody3D) -> void:
	# Обломки прошлых уровней уже удалены вместе со сценой — выкидываем их из списка.
	_debris = _debris.filter(func(item: Variant) -> bool: return is_instance_valid(item))
	_debris.append(body)
	while _debris.size() > MAX_DEBRIS:
		var old: Variant = _debris.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	# Через несколько секунд обломок замирает и уходит под пол.
	# Все вызовы привязаны к самому обломку: персонажа к этому моменту уже нет.
	var tween := body.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(DEBRIS_LIFETIME)
	tween.tween_callback(body.set.bind("freeze", true))
	tween.tween_callback(body.set.bind("collision_layer", 0))
	tween.tween_callback(body.set.bind("collision_mask", 0))
	tween.tween_property(body, "position:y", -0.8, 1.2).as_relative()
	tween.tween_callback(body.queue_free)


func _debris_container() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return get_parent()
	var container := scene.get_node_or_null("Debris")
	if container == null:
		container = Node3D.new()
		container.name = "Debris"
		scene.add_child(container)
	return container
