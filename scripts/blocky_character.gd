class_name BlockyCharacter
extends Node3D
## Человечек из скошенных блоков: таз, торс, голова с лицом, руки и ноги
## с локтями и коленями, одежда, причёски, шапки и оружие в руке.
## Модель строится кодом, поэтому внешность меняется прямо в Инспекторе.
## Всё тело — один меш на скелете (один вызов отрисовки на человечка); отдельные
## меши частей тела появляются, только когда их отрывает или тело разваливается.
## Умеет ходить, целиться двумя руками, замахиваться битой и разваливаться:
## падать целиком, терять голову (хедшот), руку или ногу (дробовик)
## и разлетаться на куски (дробовик в упор, взрыв).

enum Death { FALL, HEADSHOT, GIB }

const LIMBS := ["arm_l", "arm_r", "leg_l", "leg_r"]
const DEBRIS_LAYER := 8  # слой 4 «debris»
const DEBRIS_MASK := 1 | 8  # мир и другие обломки
const DEBRIS_LIFETIME := 9.0
const MAX_DEBRIS := 40
## Пропорции телосложений: ширина, толщина корпуса, толщина рук и ног, длина ног.
const BUILDS := {
	"normal": [1.0, 1.0, 1.0, 1.0],
	"fat": [1.42, 1.65, 1.32, 0.93],
	"thin": [0.8, 0.8, 0.76, 1.07],
	"bulky": [1.2, 1.14, 1.25, 1.0],
}
const SKIN_TONES := [Color(0.93, 0.76, 0.62), Color(0.86, 0.66, 0.52), Color(0.74, 0.54, 0.4),
		Color(0.56, 0.39, 0.28), Color(0.4, 0.27, 0.19)]
const HAIR_COLORS := [Color(0.07, 0.05, 0.04), Color(0.2, 0.13, 0.08), Color(0.42, 0.28, 0.15),
		Color(0.62, 0.5, 0.3), Color(0.38, 0.37, 0.36)]

static var _debris: Array = []
static var _material_cache := {}
static var _mesh_cache := {}
static var _vertex_material: StandardMaterial3D

@export_enum("normal", "fat", "thin", "bulky") var build := "normal"
@export_range(0.7, 1.2, 0.01) var leg_length := 1.0  ## Длина ног (1 — обычная).
@export_range(0.7, 1.2, 0.01) var torso_length := 1.0  ## Высота туловища (1 — обычная).
@export_enum("tshirt", "tank", "shirt", "hoodie", "jacket", "suit", "coat") var outfit := "tshirt"
@export_enum("short", "buzz", "long", "slick", "mohawk", "bald") var hair_style := "short"
@export_enum("none", "cap", "beanie", "fedora", "helmet", "bandana") var hat := "none"
@export_enum("none", "stubble", "mustache", "beard") var beard := "none"
@export_enum("none", "glasses", "shades") var eyewear := "none"
@export var cigar := false
@export var skin_color := Color(0.92, 0.74, 0.6)
@export var shirt_color := Color(0.25, 0.45, 0.85)
@export var jacket_color := Color(0.12, 0.12, 0.13)  ## Куртка, пиджак или плащ.
@export var tie_color := Color(0.5, 0.06, 0.06)
@export var pants_color := Color(0.16, 0.17, 0.22)
@export var hair_color := Color(0.18, 0.12, 0.08)
@export var hat_color := Color(0.1, 0.1, 0.11)
@export var shoe_color := Color(0.1, 0.1, 0.1)
@export var glove_color := Color(0, 0, 0, 0)  ## Перчатки. Прозрачный цвет — без перчаток.
@export var vest_color := Color(0, 0, 0, 0)  ## Бронежилет. Прозрачный цвет — без жилета.
@export var mask_color := Color(0, 0, 0, 0)  ## Балаклава. Прозрачный цвет — без маски.
@export var weapon := "pistol"  ## pistol, deagle, shotgun, rifle, bat или пусто.
## Случайные лицо, причёска, шапка и оттенки одежды — чтобы враги не были близнецами.
@export var random_look := false

## Поза удара битой: -1 — нет, 0..1 — от «опущена» до «занесена над головой».
var melee_pose := -1.0
var muzzle: Node3D
## Рана, после которой человечек уже не воюет: "leg_l" — прыгает на одной ноге,
## "arm_r" — держится за плечо и т. п. Пусто — цел.
var wound := ""
## В воздухе ли сейчас (для прыжков на одной ноге).
var airborne := false

var _hips: Node3D
var _chest: Node3D
var _torso: Node3D
var _neck: Node3D
var _hand: Node3D
var _gun: Node3D
var _limbs := {}  # "arm_l" -> [плечо, локоть], "leg_l" -> [бедро, колено]
var _parts: Array[Node3D] = []  # опоры частей тела в порядке построения (кость скелета = индекс)
var _part_boxes := {}  # опора -> коробки её меша
var _part_shadow := {}  # опора -> отбрасывает ли тень, когда станет отдельным мешем
var _detached := {}  # опоры, у которых уже свой меш (оторваны или тело развалилось)
var _skeleton: Skeleton3D
var _stumps := {}
var _phase := 0.0
var _time := 0.0
var _recoil := 0.0
var _flinch := 0.0
var _broken := false

# Размеры, зависят от телосложения.
var _w := 1.0
var _d := 1.0
var _l := 1.0
var _thigh := 0.43
var _shin := 0.38
var _hip_y := 0.895
var _hip_x := 0.105
var _waist := 0.08
var _neck_y := 0.54
var _shoulder_x := 0.285
var _shoulder_y := 0.47
var _upper := 0.29
var _fore := 0.25


func _ready() -> void:
	if random_look:
		_randomize_look()
	_build()


## Обновить позу. speed — скорость ходьбы 0..1, aim_pitch — наклон прицела (вверх > 0).
func animate(delta: float, speed: float, aiming: bool, aim_pitch := 0.0) -> void:
	if _broken or _hips == null:
		return
	_pose(delta, speed, aiming, aim_pitch)
	_sync_skeleton()


func _pose(delta: float, speed: float, aiming: bool, aim_pitch: float) -> void:
	_time += delta
	speed = clampf(speed, 0.0, 1.2)
	_phase += delta * (4.0 + 7.0 * speed)
	_recoil = move_toward(_recoil, 0.0, delta * 4.0)
	_flinch = move_toward(_flinch, 0.0, delta * 3.0)
	var walk := minf(speed, 1.0)
	var swing := sin(_phase) * 0.75 * walk
	var breathe := sin(_time * 2.2) * 0.015

	_hips.rotation = Vector3.ZERO
	if wound.begins_with("leg"):
		_pose_hopping()
	else:
		_hips.position.y = _hip_y + absf(sin(_phase)) * 0.05 * walk - 0.03 * walk
		_set_limb("leg_l", Vector3(swing + 0.03, 0, 0), Vector3(-maxf(0.0, cos(_phase)) * 1.1 * walk - 0.06, 0, 0))
		_set_limb("leg_r", Vector3(-swing + 0.03, 0, 0), Vector3(-maxf(0.0, -cos(_phase)) * 1.1 * walk - 0.06, 0, 0))

	_chest.rotation = Vector3(-_flinch * 0.45 + _recoil * 0.3 - 0.1 * walk + breathe, 0, 0)
	_neck.rotation = Vector3.ZERO

	if wound.begins_with("arm"):
		_pose_clutching()
		return
	if wound.begins_with("leg"):
		# Машет руками, чтобы удержать равновесие.
		_set_limb("arm_l", Vector3(0.3, 0, -1.0 - 0.45 * sin(_time * 9.0)), Vector3(0.5, 0, 0))
		_set_limb("arm_r", Vector3(0.3, 0, 1.0 + 0.45 * sin(_time * 9.0 + 1.3)), Vector3(0.5, 0, 0))
		_neck.rotation.x = 0.25
		return

	if melee_pose >= 0.0:
		_set_limb("arm_r", Vector3(lerpf(0.4, PI * 1.05, melee_pose), 0, 0), Vector3(lerpf(0.2, 0.6, melee_pose), 0, 0))
		_set_limb("arm_l", Vector3(swing * 0.5, 0, -0.1), Vector3(0.3, 0, 0))
	elif aiming and _limbs.has("arm_r"):
		var pitch := PI / 2.0 + aim_pitch + _recoil
		_set_limb("arm_r", Vector3(pitch, 0.15, 0), Vector3.ZERO)
		_neck.rotation.x = aim_pitch * 0.5
		_support_weapon()
	else:
		_set_limb("arm_r", Vector3(-swing * 0.8, 0, 0.07), Vector3(0.2 + 0.3 * walk, 0, 0))
		_set_limb("arm_l", Vector3(swing * 0.8, 0, -0.07), Vector3(0.2 + 0.3 * walk, 0, 0))


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
	_no_shadow(_gun)
	_hand.add_child(_gun)
	muzzle = _gun.get_node("Muzzle")


## Точка выстрела: дуло, а если оружия нет — уровень груди.
func get_muzzle_position() -> Vector3:
	if is_instance_valid(muzzle):
		return muzzle.global_position
	return global_position + Vector3.UP * 1.3 * global_basis.get_scale().y


## Центр головы — сюда «доводит» выстрел помощь в прицеливании.
func get_head_center() -> Vector3:
	if _neck == null:
		return global_position + Vector3.UP * 1.72 * global_basis.get_scale().y
	return _neck.global_transform * Vector3(0, 0.22, -0.01)


func get_chest_center() -> Vector3:
	if _chest == null:
		return global_position + Vector3.UP * 1.15 * global_basis.get_scale().y
	return _chest.global_transform * Vector3(0, 0.3, 0)


## Высота шеи над землёй (с учётом масштаба): всё, что выше, — голова.
func get_neck_height() -> float:
	return (_hip_y + _waist + _neck_y) * global_basis.get_scale().y


func has_limb(limb: String) -> bool:
	return _limbs.has(limb)


## В какую часть тела попадает луч: head, torso, arm_l, arm_r, leg_l, leg_r.
## Считается по настоящей позе: поднятые руки, шаг, наклон.
func get_hit_part(from: Vector3, direction: Vector3) -> String:
	if _hips == null or _broken:
		return "torso"
	direction = direction.normalized()
	var s := global_basis.get_scale().x
	var parts := [["torso", _hips.global_position, _neck.global_position, 0.2 * _w * s]]
	parts.append(["head", _neck.global_transform * Vector3(0, 0.08, 0), _neck.global_transform * Vector3(0, 0.36, 0), 0.165 * s])
	for limb: String in _limbs:
		var root: Node3D = _limbs[limb][0]
		var joint: Node3D = _limbs[limb][1]
		var is_arm := limb.begins_with("arm")
		var tip := joint.global_transform * Vector3(0, -(_fore + 0.1 if is_arm else _shin + 0.06), 0)
		var radius := (0.085 if is_arm else 0.11) * _l * s
		parts.append([limb, root.global_position, joint.global_position, radius])
		parts.append([limb, joint.global_position, tip, radius])
	var best := "torso"
	var best_score := INF
	var first_t := INF
	var first := ""
	for part: Array in parts:
		var result := _ray_to_segment(from, direction, part[1], part[2])
		var score: float = result.x / float(part[3])
		if score <= 1.0 and result.y < first_t:
			first_t = result.y
			first = part[0]
		if score < best_score:
			best_score = score
			best = part[0]
	return first if first != "" else best


## Отрывает руку или ногу. Возвращает false, если её уже нет.
func sever_limb(limb: String, direction: Vector3, force: float) -> bool:
	if _broken or _hips == null or not _limbs.has(limb):
		return false
	var root: Node3D = _limbs[limb][0]
	var joint: Node3D = _limbs[limb][1]
	var is_arm := limb.begins_with("arm")
	var parent := root.get_parent() as Node3D
	var socket := root.position
	_limbs.erase(limb)
	if wound == "":
		wound = limb
	if limb == "arm_r":
		_hand = null
		_gun = null
		muzzle = null
		melee_pose = -1.0
	elif limb == "arm_l":
		# Уцелевшая рука зажимает рану — оружие падает.
		drop_weapon()
	joint.basis = Basis()
	_detach_part(root)
	_detach_part(joint)
	var length := (_upper + _fore + 0.1) if is_arm else (_thigh + _shin + 0.08)
	var size := Vector3(0.14, length, 0.15) * _l if is_arm else Vector3(0.2 * _l, length, 0.24 * _l)
	direction.y = maxf(direction.y, 0.0)
	direction = direction.normalized() if direction.length_squared() > 0.001 else -global_basis.z
	var body := _make_body(root, size, Vector3(0, -length * 0.5, 0), _debris_container())
	body.linear_velocity = direction * force * randf_range(0.5, 0.9) \
			+ Vector3(randf_range(-1.5, 1.5), randf_range(2.5, 4.5), randf_range(-1.5, 1.5))
	body.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	Fx.blood_fountain(body, Vector3(0, length * 0.5, 0), 0.7)
	# Культя: кровавый срез и струя крови, которая двигается вместе с телом.
	var stump := _pivot(parent, "Stump_" + limb, socket)
	var flesh := Color(0.45, 0.03, 0.03)
	add_part_mesh(stump, [[Vector3(0.13, 0.07, 0.14) * _l, Vector3(0, -0.02, 0), flesh, 0.02],
			[Vector3(0.04, 0.05, 0.04), Vector3(0, -0.06, 0), Color(0.9, 0.86, 0.78)]])
	_no_shadow(stump)
	_stumps[limb] = stump
	var spray := Vector3(0, -0.05, 0)
	Fx.blood_fountain(stump, spray, 6.0)
	Fx.blood(stump.global_position, direction, 30)
	return true


## Бросает оружие на пол (например, когда оторвало руку, а держать нечем).
func drop_weapon() -> void:
	if _gun == null:
		return
	var gun := _gun
	_gun = null
	muzzle = null
	var body := RigidBody3D.new()
	body.collision_layer = DEBRIS_LAYER
	body.collision_mask = DEBRIS_MASK
	body.mass = 1.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.08, 0.14, 0.5)
	shape.shape = box
	body.add_child(shape)
	_debris_container().add_child(body)
	body.global_transform = Transform3D(gun.global_basis.orthonormalized(), gun.global_position)
	gun.reparent(body, true)
	body.linear_velocity = Vector3(randf_range(-1, 1), 1.5, randf_range(-1, 1))
	body.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	body.reset_physics_interpolation()
	_register_debris(body)


## Разваливает модель на физические обломки. Сам узел после этого пустой.
func break_apart(mode: Death, direction: Vector3, force: float) -> void:
	if _broken or _hips == null:
		return
	_broken = true
	# Дальше части тела летят отдельно: у каждой свой меш, скелет больше не нужен.
	for part in _parts:
		_detach_part(part)
	_skeleton.visible = false
	_skeleton.queue_free()
	direction.y = maxf(direction.y, 0.0)
	direction = direction.normalized() if direction.length_squared() > 0.001 else -global_basis.z
	var container := _debris_container()
	var neck_position := _neck.global_transform * Vector3(0, 0.05, 0)
	var head_size := Vector3(0.31, 0.36, 0.33)
	var head_center := Vector3(0, 0.21, 0)
	var top := _waist + _neck_y

	match mode:
		Death.GIB:
			var center := _chest.global_position
			var parts := [[_neck, head_size, head_center]]
			for limb: String in _limbs:
				var root: Node3D = _limbs[limb][0]
				(_limbs[limb][1] as Node3D).basis = Basis()
				var is_arm := limb.begins_with("arm")
				var length := (_upper + _fore + 0.1) if is_arm else (_thigh + _shin + 0.08)
				var size := Vector3(0.14, length, 0.15) * _l if is_arm else Vector3(0.2 * _l, length, 0.24 * _l)
				parts.append([root, size, Vector3(0, -length * 0.5, 0)])
			parts.append([_torso, Vector3(0.44 * _w, 0.54, 0.26 * _d), Vector3.ZERO])
			parts.append([_hips, Vector3(0.36 * _w, 0.2, 0.23 * _d), Vector3.ZERO])
			_limbs.clear()
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
			var head := _make_body(_neck, head_size, head_center, container)
			head.linear_velocity = direction * force * 0.8 + Vector3(randf_range(-1, 1), randf_range(4, 6), randf_range(-1, 1))
			head.angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
			Fx.blood_fountain(head, Vector3.ZERO, 0.6)
			Fx.blood(neck_position, direction, 30)
			var torso := _make_body(_hips, Vector3(0.5 * _w, top + _hip_y, 0.32 * _d), Vector3(0, (top - _hip_y) * 0.5, 0), container)
			_topple(torso, direction, force * 0.3)
			# Фонтан крови из шеи, который падает вместе с телом.
			Fx.blood_fountain(torso, torso.to_local(neck_position), 2.2)
			Fx.blood_pool(neck_position, 1.3)

		_:
			top += 0.37
			var whole := _make_body(_hips, Vector3(0.5 * _w, top + _hip_y, 0.34 * _d), Vector3(0, (top - _hip_y) * 0.5, 0), container)
			_topple(whole, direction, force * 0.4)
			Fx.blood_pool(global_position + Vector3.UP * 0.5, 1.0)


## Строит модельку оружия. Ствол смотрит в -Z, рукоять вниз.
## Точки: «Muzzle» — дуло, «Support» — куда кладётся вторая рука.
static func build_weapon_model(kind: String) -> Node3D:
	var gun := Node3D.new()
	gun.name = "Gun"
	var dark := Color(0.13, 0.13, 0.15)
	var black := Color(0.06, 0.06, 0.07)
	var wood := Color(0.42, 0.25, 0.12)
	var muzzle_at := Vector3(0, 0.075, -0.19)
	var support_at := Vector3(-0.035, -0.02, 0.03)
	var boxes := []
	match kind:
		"pistol":
			boxes = [[Vector3(0.05, 0.05, 0.22), Vector3(0, 0.075, -0.07), dark, 0.008],
					[Vector3(0.044, 0.035, 0.17), Vector3(0, 0.04, -0.06), black],
					[Vector3(0.042, 0.13, 0.06), Vector3(0, -0.01, 0.02), black, 0.008],
					[Vector3(0.012, 0.035, 0.05), Vector3(0, 0.005, -0.04), black]]
		"deagle":
			var steel := Color(0.7, 0.71, 0.75)
			boxes = [[Vector3(0.065, 0.07, 0.3), Vector3(0, 0.085, -0.1), steel, 0.01],
					[Vector3(0.03, 0.014, 0.28), Vector3(0, 0.126, -0.1), steel.darkened(0.25)],
					[Vector3(0.055, 0.04, 0.2), Vector3(0, 0.035, -0.06), steel.darkened(0.35)],
					[Vector3(0.052, 0.14, 0.07), Vector3(0, -0.02, 0.03), black, 0.01],
					[Vector3(0.014, 0.04, 0.06), Vector3(0, 0.0, -0.05), black]]
			muzzle_at = Vector3(0, 0.085, -0.26)
		"shotgun":
			boxes = [[Vector3(0.06, 0.1, 0.26), Vector3(0, 0.06, -0.04), dark, 0.01],
					[Vector3(0.04, 0.04, 0.6), Vector3(0, 0.095, -0.46), dark],
					[Vector3(0.035, 0.035, 0.5), Vector3(0, 0.05, -0.41), dark.lightened(0.08)],
					[Vector3(0.068, 0.065, 0.2), Vector3(0, 0.05, -0.38), wood, 0.012],
					[Vector3(0.05, 0.11, 0.3), Vector3(0, 0.015, 0.22), wood, 0.015],
					[Vector3(0.045, 0.1, 0.07), Vector3(0, -0.02, 0.05), wood]]
			muzzle_at = Vector3(0, 0.095, -0.77)
			support_at = Vector3(0, -0.005, -0.38)
		"rifle":
			var olive := Color(0.2, 0.22, 0.17)
			boxes = [[Vector3(0.06, 0.1, 0.34), Vector3(0, 0.06, -0.1), olive, 0.01],
					[Vector3(0.062, 0.075, 0.22), Vector3(0, 0.06, -0.38), wood, 0.012],
					[Vector3(0.03, 0.03, 0.26), Vector3(0, 0.08, -0.6), dark],
					[Vector3(0.045, 0.17, 0.07), Vector3(0, -0.07, -0.17), black, 0.01],
					[Vector3(0.045, 0.1, 0.05), Vector3(0, -0.02, 0.03), black],
					[Vector3(0.05, 0.1, 0.26), Vector3(0, 0.04, 0.22), wood, 0.015]]
			muzzle_at = Vector3(0, 0.08, -0.74)
			support_at = Vector3(0, 0.0, -0.38)
		"bat":
			boxes = [[Vector3(0.05, 0.05, 0.42), Vector3(0, 0.0, -0.17), wood, 0.01],
					[Vector3(0.085, 0.085, 0.42), Vector3(0, 0.0, -0.58), wood.lightened(0.15), 0.02],
					[Vector3(0.065, 0.065, 0.03), Vector3(0, 0.0, 0.05), wood.darkened(0.2)]]
			muzzle_at = Vector3(0, 0, -0.8)
	if not boxes.is_empty():
		add_part_mesh(gun, boxes)
	for marker_name in ["Muzzle", "Support"]:
		var marker := Marker3D.new()
		marker.name = marker_name
		marker.position = muzzle_at if marker_name == "Muzzle" else support_at
		gun.add_child(marker)
	return gun


# --- Позы ----------------------------------------------------------------------

func _set_limb(limb: String, upper: Vector3, lower: Vector3) -> void:
	if not _limbs.has(limb):
		return
	(_limbs[limb][0] as Node3D).rotation = upper
	(_limbs[limb][1] as Node3D).rotation = lower


## Вторая рука держит оружие за цевьё или обхватывает рукоять пистолета.
func _support_weapon() -> void:
	if not _limbs.has("arm_l"):
		return
	var support := _gun.get_node_or_null("Support") as Node3D if _gun else null
	if support == null or weapon == "bat":
		_set_limb("arm_l", Vector3(0.2, 0, -0.1), Vector3(0.3, 0, 0))
		return
	_reach("arm_l", _chest.to_local(support.global_position), Vector3(-1.0, -1.0, 0.4))


## Прыжки на одной ноге: корпус наклонён к здоровой ноге, она пружинит.
func _pose_hopping() -> void:
	var lost_left := wound == "leg_l"
	var side := -1.0 if lost_left else 1.0
	var bend := 0.15 if airborne else 0.55 + 0.1 * sin(_time * 20.0)
	_hips.position.y = _hip_y - (0.02 if airborne else 0.11)
	_hips.rotation = Vector3(0, 0, side * 0.16)
	_set_limb("leg_r" if lost_left else "leg_l", Vector3(0.25 + bend * 0.5, 0, side * 0.14), Vector3(-bend, 0, 0))


## Целая рука зажимает культю, человечек согнулся от боли.
func _pose_clutching() -> void:
	var lost_right := wound == "arm_r"
	var good := "arm_l" if lost_right else "arm_r"
	_chest.rotation = Vector3(-0.35 + 0.06 * sin(_time * 3.0), 0, (0.12 if lost_right else -0.12))
	_neck.rotation = Vector3(-0.25, 0, 0)
	var stump_side := 1.0 if lost_right else -1.0
	var target := Vector3(stump_side * (_shoulder_x - 0.05), _shoulder_y - 0.02, -0.13 * _d)
	_reach(good, target, Vector3(-stump_side, -1.0, 0.6))


## Простая двухзвенная инверсная кинематика: кисть тянется к точке (в осях груди).
func _reach(limb: String, target: Vector3, pole: Vector3) -> void:
	if not _limbs.has(limb):
		return
	var root: Node3D = _limbs[limb][0]
	var joint: Node3D = _limbs[limb][1]
	var a := _upper
	var b := _fore + 0.06
	var start := root.position
	var offset := target - start
	var dist := clampf(offset.length(), absf(a - b) + 0.02, a + b - 0.002)
	var dir := offset.normalized() if offset.length_squared() > 0.0001 else Vector3.DOWN
	var along := (a * a - b * b + dist * dist) / (2.0 * dist)
	var height := sqrt(maxf(a * a - along * along, 0.0))
	var bend := pole - dir * pole.dot(dir)
	bend = bend.normalized() if bend.length_squared() > 0.0001 else Vector3.BACK
	var elbow := start + dir * along + bend * height
	root.basis = _bone_basis(elbow - start)
	joint.basis = _bone_basis(root.basis.inverse() * (start + dir * dist - elbow))


## Поворот кости так, чтобы её ось -Y смотрела вдоль direction.
static func _bone_basis(direction: Vector3) -> Basis:
	var y := -direction.normalized()
	var x := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.95 else Vector3.BACK
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	return Basis(x, y, z)


## Расстояние от луча до отрезка (x) и где вдоль луча ближайшая точка (y).
static func _ray_to_segment(origin: Vector3, direction: Vector3, a: Vector3, b: Vector3) -> Vector2:
	var u := b - a
	var w := origin - a
	var uu := u.dot(u)
	var ud := u.dot(direction)
	var uw := u.dot(w)
	var dw := direction.dot(w)
	var s := 0.0
	var denominator := uu - ud * ud
	if denominator > 0.000001:
		s = clampf((uw - ud * dw) / denominator, 0.0, 1.0)
	var t := maxf(s * ud - dw, 0.0)
	if uu > 0.000001:
		s = clampf((uw + t * ud) / uu, 0.0, 1.0)
	return Vector2((w + direction * t - u * s).length(), t)


# --- Построение модели -------------------------------------------------------
# Каждая часть тела — один меш с цветами в вершинах: так персонаж рисуется
# за дюжину вызовов, а одинаковые враги делят одни и те же меши.

func _build() -> void:
	var proportions: Array = BUILDS.get(build, BUILDS["normal"])
	_w = proportions[0]
	_d = proportions[1]
	_l = proportions[2]
	_thigh = 0.43 * proportions[3] * leg_length
	_shin = 0.38 * proportions[3] * leg_length
	_hip_y = _thigh + _shin + 0.085
	_waist = 0.08 * torso_length
	_neck_y = 0.54 * torso_length
	_shoulder_y = 0.47 * torso_length
	# Руки растут вместе с телом, чтобы кисти не висели у колен.
	var arm := (leg_length + torso_length) * 0.5
	_upper = 0.29 * arm
	_fore = 0.25 * arm
	_hip_x = 0.09 * _w + 0.015
	_shoulder_x = 0.21 * _w + 0.075 * _l

	_hips = _pivot(self, "Hips", Vector3(0, _hip_y, 0))
	_add_part(_hips, _pelvis_boxes())
	for side in [-1.0, 1.0]:
		var hip := _pivot(_hips, "HipL" if side < 0.0 else "HipR", Vector3(side * _hip_x, 0, 0))
		_add_part(hip, _thigh_boxes())
		var knee := _pivot(hip, "Knee", Vector3(0, -_thigh, 0))
		_add_part(knee, _shin_boxes())
		_limbs["leg_l" if side < 0.0 else "leg_r"] = [hip, knee]

	_chest = _pivot(_hips, "Chest", Vector3(0, _waist, 0))
	_torso = _pivot(_chest, "Torso", Vector3(0, 0.28 * torso_length, 0))
	_add_part(_torso, _stretch_y(_torso_boxes(), torso_length))
	_neck = _pivot(_chest, "Neck", Vector3(0, _neck_y, 0))
	_add_part(_neck, _head_boxes(), false)

	for side in [-1.0, 1.0]:
		var shoulder := _pivot(_chest, "ShoulderL" if side < 0.0 else "ShoulderR", Vector3(side * _shoulder_x, _shoulder_y, 0))
		_add_part(shoulder, _upper_arm_boxes(), false)
		var elbow := _pivot(shoulder, "Elbow", Vector3(0, -_upper, 0))
		_add_part(elbow, _forearm_boxes(side), false)
		_limbs["arm_l" if side < 0.0 else "arm_r"] = [shoulder, elbow]
		if side > 0.0:
			# Кисть правой руки повёрнута так, чтобы ствол смотрел вдоль руки.
			_hand = _pivot(elbow, "Grip", Vector3(0, -_fore - 0.06, 0))
			_hand.rotation.x = -PI / 2.0
	set_weapon(weapon)
	_build_skin()
	animate(0.0, 0.0, false)


func _add_part(pivot: Node3D, boxes: Array, shadow := true) -> void:
	_parts.append(pivot)
	_part_boxes[pivot] = boxes
	_part_shadow[pivot] = shadow


## Всё тело одним мешем: каждая часть привязана к своей кости, кости повторяют опоры.
func _build_skin() -> void:
	_skeleton = Skeleton3D.new()
	_skeleton.name = "Skeleton"
	add_child(_skeleton)
	var skin := Skin.new()
	var all_boxes := []
	for i in _parts.size():
		_skeleton.add_bone("%s%d" % [_parts[i].name, i])
		skin.add_bind(i, Transform3D.IDENTITY)
		all_boxes.append(_part_boxes[_parts[i]])
	var key := "skinned" + str(all_boxes)
	if not _mesh_cache.has(key):
		var tool := SurfaceTool.new()
		tool.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in all_boxes.size():
			for box: Array in all_boxes[i]:
				_add_shape(tool, box[0], box[1], box[2], box[3] if box.size() > 3 else 0.0,
						box[4] if box.size() > 4 else Vector2.ONE, i)
		tool.index()
		tool.set_material(_vertex_color_material())
		_mesh_cache[key] = tool.commit()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _mesh_cache[key]
	body.skin = skin
	# Вершины лежат в осях своих костей, поэтому границы задаём сами.
	body.custom_aabb = AABB(Vector3(-1.0, -0.2, -1.0), Vector3(2.0, 2.6, 2.0))
	_skeleton.add_child(body)


## Кости скелета повторяют опоры (Node3D), которые двигает анимация.
func _sync_skeleton() -> void:
	if _skeleton == null or _broken:
		return
	for i in _parts.size():
		var part := _parts[i]
		if _detached.has(part):
			_skeleton.set_bone_pose_scale(i, Vector3.ONE * 0.0001)
			continue
		var pose := part.transform
		var node := part.get_parent() as Node3D
		while node != self:
			pose = node.transform * pose
			node = node.get_parent() as Node3D
		_skeleton.set_bone_pose_position(i, pose.origin)
		_skeleton.set_bone_pose_rotation(i, pose.basis.get_rotation_quaternion())
		_skeleton.set_bone_pose_scale(i, pose.basis.get_scale())


## Часть тела получает собственный меш, а на общем скелете её больше не видно.
func _detach_part(part: Node3D) -> void:
	if _detached.has(part) or not is_instance_valid(part):
		return
	_detached[part] = true
	var mesh := add_part_mesh(part, _part_boxes[part])
	if not _part_shadow[part]:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sync_skeleton()


func _randomize_look() -> void:
	skin_color = SKIN_TONES.pick_random()
	hair_color = HAIR_COLORS.pick_random()
	if mask_color.a > 0.0 and randf() < 0.5:
		mask_color = Color(0, 0, 0, 0)
	if mask_color.a <= 0.0:
		hair_style = ["short", "short", "buzz", "slick", "long", "bald", "mohawk"].pick_random()
		beard = ["none", "none", "stubble", "stubble", "mustache", "beard"].pick_random()
		if hat == "none":
			hat = ["none", "none", "none", "cap", "beanie", "fedora"].pick_random()
		if eyewear == "none" and randf() < 0.18:
			eyewear = "shades"
	hat_color = [Color(0.1, 0.1, 0.11), Color(0.2, 0.16, 0.12), Color(0.18, 0.2, 0.24), Color(0.3, 0.07, 0.07)].pick_random()
	var shade := randf_range(-0.12, 0.12)
	shirt_color = shirt_color.lightened(shade) if shade > 0.0 else shirt_color.darkened(-shade)
	jacket_color = jacket_color.lightened(randf_range(0.0, 0.12))
	pants_color = pants_color.lightened(randf_range(0.0, 0.1))


func _sleeve_color() -> Color:
	match outfit:
		"jacket", "suit", "coat":
			return jacket_color
		"tank":
			return skin_color
	return shirt_color


func _body_color() -> Color:
	return jacket_color if outfit in ["jacket", "suit", "coat"] else shirt_color


func _hand_color() -> Color:
	return glove_color if glove_color.a > 0.0 else skin_color


func _pelvis_boxes() -> Array:
	var boxes := [[Vector3(0.36 * _w, 0.2, 0.23 * _d), Vector3(0, 0.01, 0), pants_color, 0.03],
			[Vector3(0.37 * _w, 0.05, 0.24 * _d), Vector3(0, 0.09, 0), Color(0.09, 0.07, 0.05), 0.015],
			[Vector3(0.06, 0.04, 0.02), Vector3(0, 0.09, -0.12 * _d - 0.004), Color(0.62, 0.56, 0.38)]]
	if outfit == "coat":
		# Полы плаща: спереди разрез, чтобы ноги свободно шагали.
		var coat := jacket_color
		var length := 0.46 * leg_length
		var center := 0.08 - length * 0.5
		boxes.append([Vector3(0.4 * _w, length, 0.05), Vector3(0, center, 0.115 * _d), coat, 0.015])
		for side in [-1.0, 1.0]:
			boxes.append([Vector3(0.05, length, 0.25 * _d), Vector3(side * 0.19 * _w, center, 0.0), coat, 0.015])
			boxes.append([Vector3(0.12 * _w, length, 0.04), Vector3(side * 0.14 * _w, center, -0.12 * _d), coat, 0.015])
	return boxes


## Растягивает или сплющивает набор коробок по высоте.
static func _stretch_y(boxes: Array, factor: float) -> Array:
	if is_equal_approx(factor, 1.0):
		return boxes
	var result := []
	for box: Array in boxes:
		var copy := box.duplicate()
		copy[0] = Vector3(box[0].x, box[0].y * factor, box[0].z)
		copy[1] = Vector3(box[1].x, box[1].y * factor, box[1].z)
		result.append(copy)
	return result


func _thigh_boxes() -> Array:
	return [[Vector3(0.19 * _l, _thigh + 0.06, 0.21 * _l), Vector3(0, -_thigh * 0.5 + 0.02, 0), pants_color, 0.035, Vector2(0.86, 1.1)]]


func _shin_boxes() -> Array:
	var sole := Color(0.04, 0.04, 0.04)
	return [[Vector3(0.16 * _l, _shin, 0.18 * _l), Vector3(0, -_shin * 0.5, 0), pants_color, 0.03, Vector2(0.86, 1.04)],
			[Vector3(0.168 * _l, 0.15, 0.188 * _l), Vector3(0, -_shin + 0.05, 0), shoe_color, 0.02],
			[Vector3(0.16 * _l, 0.08, 0.28), Vector3(0, -_shin - 0.035, -0.06), shoe_color, 0.03],
			[Vector3(0.17 * _l, 0.025, 0.29), Vector3(0, -_shin - 0.0725, -0.06), sole]]


func _torso_boxes() -> Array:
	var body := _body_color()
	var front := -0.13 * _d
	var fat := build == "fat"
	var boxes := [[Vector3(0.34 * _w, 0.26, 0.21 * _d), Vector3(0, -0.15, 0), body, 0.06 if fat else 0.04, Vector2(1.12, 1.02) if fat else Vector2(1.0, 1.08)],
			[Vector3(0.42 * _w, 0.3, 0.25 * _d), Vector3(0, 0.09, 0), body, 0.07 if fat else 0.05, Vector2(1.0, 0.9) if fat else Vector2(0.92, 1.06)],
			[Vector3(0.5 * _w, 0.09, 0.2 * _d), Vector3(0, 0.21, 0.01), skin_color if outfit == "tank" else body, 0.04]]
	if fat:
		# Пивное пузо нависает над ремнём.
		boxes.append([Vector3(0.36 * _w, 0.34, 0.12 * _d), Vector3(0, -0.14, -0.08 * _d), body, 0.08])
		front -= 0.06 * _d
	match outfit:
		"tank":
			for side in [-1.0, 1.0]:
				boxes.append([Vector3(0.07, 0.1, 0.21 * _d), Vector3(side * 0.11 * _w, 0.21, 0.01), shirt_color])
			boxes.append([Vector3(0.16 * _w, 0.08, 0.02), Vector3(0, 0.2, -0.13 * _d), skin_color])
		"tshirt":
			boxes.append([Vector3(0.12, 0.05, 0.02), Vector3(0, 0.22, -0.12 * _d), skin_color])
		"shirt":
			boxes.append([Vector3(0.2, 0.05, 0.17), Vector3(0, 0.255, -0.01), shirt_color.lightened(0.12), 0.01])
			boxes.append([Vector3(0.035, 0.46, 0.02), Vector3(0, -0.03, front), shirt_color.darkened(0.15)])
		"hoodie":
			var dark := shirt_color.darkened(0.2)
			boxes.append([Vector3(0.3, 0.13, 0.14), Vector3(0, 0.25, 0.1 * _d), dark, 0.04])
			boxes.append([Vector3(0.24 * _w, 0.11, 0.025), Vector3(0, -0.17, front + 0.01), dark])
			for side in [-1.0, 1.0]:
				boxes.append([Vector3(0.015, 0.13, 0.015), Vector3(side * 0.045, 0.12, front - 0.01), Color(0.85, 0.85, 0.82)])
		"jacket", "suit", "coat":
			# Расстёгнутый пиджак: видна рубашка, лацканы, у костюма — галстук.
			boxes.append([Vector3(0.11 * _w, 0.44, 0.03), Vector3(0, 0.0, front - 0.002), shirt_color])
			for side in [-1.0, 1.0]:
				boxes.append([Vector3(0.05, 0.26, 0.03), Vector3(side * 0.075 * _w, 0.08, front - 0.008), jacket_color.darkened(0.25)])
			if outfit == "suit":
				boxes.append([Vector3(0.045, 0.34, 0.02), Vector3(0, -0.02, front - 0.02), tie_color])
				boxes.append([Vector3(0.06, 0.05, 0.025), Vector3(0, 0.17, front - 0.02), tie_color.darkened(0.2)])
			if outfit == "coat":
				boxes.append([Vector3(0.3 * _w + 0.04, 0.12, 0.2 * _d + 0.04), Vector3(0, 0.27, 0.03), jacket_color, 0.03])
				boxes.append([Vector3(0.355 * _w, 0.05, 0.225 * _d), Vector3(0, -0.2, 0), jacket_color.darkened(0.3), 0.02])
	if vest_color.a > 0.0:
		boxes.append([Vector3(0.46 * _w, 0.42, 0.29 * _d), Vector3(0, 0.0, 0), vest_color, 0.04])
		for x in [-0.12, 0.0, 0.12]:
			boxes.append([Vector3(0.08, 0.09, 0.05), Vector3(x * _w, -0.12, -0.155 * _d), vest_color.lightened(0.08), 0.01])
	return boxes


func _head_boxes() -> Array:
	var masked := mask_color.a > 0.0
	var face := mask_color if masked else skin_color
	var jaw := 1.15 if build == "fat" else (0.92 if build == "thin" else 1.0)
	var boxes := [[Vector3(0.12, 0.12, 0.12), Vector3(0, 0.03, 0), face],
			[Vector3(0.25 * jaw, 0.13, 0.26), Vector3(0, 0.13, -0.005), face, 0.035],
			[Vector3(0.29, 0.22, 0.31), Vector3(0, 0.26, 0.01), face, 0.05]]
	if build == "fat":
		boxes.append([Vector3(0.22, 0.06, 0.18), Vector3(0, 0.075, -0.06), face, 0.02])
	for side in [-1.0, 1.0]:
		boxes.append([Vector3(0.035, 0.08, 0.06), Vector3(side * 0.152, 0.22, 0.02), face.darkened(0.06)])
	if masked:
		boxes.append([Vector3(0.2, 0.065, 0.012), Vector3(0, 0.232, -0.148), skin_color])
		boxes.append([Vector3(0.07, 0.03, 0.012), Vector3(0, 0.125, -0.136), Color(0.05, 0.03, 0.03)])
	else:
		boxes.append([Vector3(0.045, 0.075, 0.05), Vector3(0, 0.19, -0.155), skin_color.darkened(0.08), 0.012])
		boxes.append([Vector3(0.09, 0.022, 0.015), Vector3(0, 0.125, -0.137), skin_color.lerp(Color(0.5, 0.15, 0.13), 0.55)])
	var brow := hair_color.darkened(0.2)
	for side in [-1.0, 1.0]:
		boxes.append([Vector3(0.065, 0.035, 0.012), Vector3(side * 0.065, 0.232, -0.15), Color(0.9, 0.88, 0.84)])
		boxes.append([Vector3(0.03, 0.035, 0.012), Vector3(side * 0.062, 0.232, -0.155), Color(0.07, 0.05, 0.04)])
		if not masked:
			boxes.append([Vector3(0.08, 0.022, 0.025), Vector3(side * 0.065, 0.268, -0.152), brow])
	if not masked:
		boxes.append_array(_beard_boxes(jaw))
		boxes.append_array(_hair_boxes())
	boxes.append_array(_hat_boxes())
	match eyewear:
		"glasses":
			for side in [-1.0, 1.0]:
				boxes.append([Vector3(0.085, 0.055, 0.008), Vector3(side * 0.065, 0.233, -0.16), Color(0.12, 0.12, 0.13)])
				boxes.append([Vector3(0.012, 0.015, 0.15), Vector3(side * 0.148, 0.245, -0.085), Color(0.12, 0.12, 0.13)])
		"shades":
			boxes.append([Vector3(0.25, 0.055, 0.016), Vector3(0, 0.234, -0.161), Color(0.02, 0.02, 0.025)])
			for side in [-1.0, 1.0]:
				boxes.append([Vector3(0.012, 0.015, 0.15), Vector3(side * 0.148, 0.245, -0.085), Color(0.02, 0.02, 0.025)])
	if cigar:
		boxes.append([Vector3(0.024, 0.024, 0.11), Vector3(0.045, 0.13, -0.19), Color(0.33, 0.2, 0.1)])
		boxes.append([Vector3(0.026, 0.026, 0.015), Vector3(0.045, 0.13, -0.25), Color(1.0, 0.42, 0.12)])
	return boxes


func _beard_boxes(jaw: float) -> Array:
	var stubble := skin_color.lerp(hair_color, 0.4)
	match beard:
		"stubble":
			return [[Vector3(0.255 * jaw, 0.09, 0.265), Vector3(0, 0.11, -0.006), stubble, 0.035]]
		"mustache":
			return [[Vector3(0.1, 0.025, 0.02), Vector3(0, 0.15, -0.145), hair_color]]
		"beard":
			return [[Vector3(0.26 * jaw, 0.14, 0.14), Vector3(0, 0.1, -0.07), hair_color, 0.04],
					[Vector3(0.1, 0.025, 0.02), Vector3(0, 0.15, -0.145), hair_color]]
	return []


func _hair_boxes() -> Array:
	var covered := hat in ["cap", "beanie", "fedora", "helmet"]
	var boxes := []
	match hair_style:
		"short", "long":
			if not covered:
				boxes.append([Vector3(0.305, 0.06, 0.325), Vector3(0, 0.375, 0.012), hair_color, 0.03])
			boxes.append([Vector3(0.3, 0.17, 0.05), Vector3(0, 0.29, 0.155), hair_color, 0.02])
			for side in [-1.0, 1.0]:
				boxes.append([Vector3(0.025, 0.1, 0.2), Vector3(side * 0.146, 0.31, 0.04), hair_color])
			if hair_style == "long":
				boxes.append([Vector3(0.3, 0.32, 0.06), Vector3(0, 0.22, 0.16), hair_color, 0.02])
				for side in [-1.0, 1.0]:
					boxes.append([Vector3(0.03, 0.22, 0.18), Vector3(side * 0.149, 0.25, 0.07), hair_color])
		"buzz":
			if not covered:
				boxes.append([Vector3(0.298, 0.025, 0.318), Vector3(0, 0.37, 0.012), hair_color])
			boxes.append([Vector3(0.296, 0.12, 0.02), Vector3(0, 0.31, 0.163), hair_color])
		"slick":
			if not covered:
				boxes.append([Vector3(0.3, 0.075, 0.33), Vector3(0, 0.38, 0.02), hair_color, 0.035])
			boxes.append([Vector3(0.3, 0.15, 0.04), Vector3(0, 0.3, 0.158), hair_color, 0.015])
			for side in [-1.0, 1.0]:
				boxes.append([Vector3(0.02, 0.08, 0.05), Vector3(side * 0.146, 0.2, 0.0), hair_color])
		"mohawk":
			if not covered:
				boxes.append([Vector3(0.06, 0.11, 0.3), Vector3(0, 0.41, 0.02), hair_color, 0.02])
	return boxes


func _hat_boxes() -> Array:
	var band := Color(0.06, 0.05, 0.04)
	match hat:
		"cap":
			return [[Vector3(0.315, 0.09, 0.335), Vector3(0, 0.38, 0.012), hat_color, 0.04],
					[Vector3(0.24, 0.02, 0.13), Vector3(0, 0.345, -0.2), hat_color.darkened(0.15)]]
		"beanie":
			return [[Vector3(0.315, 0.14, 0.335), Vector3(0, 0.375, 0.012), hat_color, 0.05],
					[Vector3(0.325, 0.05, 0.345), Vector3(0, 0.325, 0.012), hat_color.darkened(0.12), 0.02]]
		"fedora":
			return [[Vector3(0.46, 0.02, 0.46), Vector3(0, 0.355, 0.012), hat_color, 0.01],
					[Vector3(0.3, 0.13, 0.31), Vector3(0, 0.43, 0.012), hat_color, 0.03, Vector2(1.0, 0.85)],
					[Vector3(0.305, 0.035, 0.315), Vector3(0, 0.385, 0.012), band]]
		"helmet":
			return [[Vector3(0.35, 0.16, 0.37), Vector3(0, 0.37, 0.012), hat_color, 0.06],
					[Vector3(0.37, 0.03, 0.39), Vector3(0, 0.3, 0.012), hat_color.darkened(0.1), 0.01]]
		"bandana":
			return [[Vector3(0.305, 0.07, 0.325), Vector3(0, 0.35, 0.012), hat_color, 0.02],
					[Vector3(0.06, 0.06, 0.04), Vector3(0, 0.33, 0.18), hat_color]]
	return []


func _upper_arm_boxes() -> Array:
	var sleeve := _sleeve_color()
	var boxes := [[Vector3(0.15, 0.12, 0.16) * _l, Vector3(0, -0.03, 0), sleeve, 0.045]]
	if outfit == "tshirt":
		boxes.append([Vector3(0.145 * _l, _upper * 0.5, 0.155 * _l), Vector3(0, -_upper * 0.25, 0), shirt_color, 0.03])
		boxes.append([Vector3(0.13 * _l, _upper, 0.14 * _l), Vector3(0, -_upper * 0.5, 0), skin_color, 0.035, Vector2(0.88, 1.05)])
	else:
		boxes.append([Vector3(0.13 * _l, _upper, 0.14 * _l), Vector3(0, -_upper * 0.5, 0), sleeve, 0.035, Vector2(0.88, 1.05)])
	return boxes


func _forearm_boxes(side: float) -> Array:
	var long_sleeves := outfit not in ["tshirt", "tank"]
	var hand := _hand_color()
	var boxes := [[Vector3(0.115 * _l, _fore, 0.125 * _l), Vector3(0, -_fore * 0.5, 0),
			_sleeve_color() if long_sleeves else skin_color, 0.03, Vector2(0.85, 1.05)]]
	if outfit in ["jacket", "suit", "coat", "shirt"]:
		boxes.append([Vector3(0.12 * _l, 0.04, 0.13 * _l), Vector3(0, -_fore + 0.02, 0), shirt_color.lightened(0.1)])
	boxes.append([Vector3(0.075, 0.11, 0.1), Vector3(0, -_fore - 0.055, -0.005), hand, 0.025])
	boxes.append([Vector3(0.03, 0.06, 0.035), Vector3(-side * 0.045, -_fore - 0.04, -0.035), hand])
	return boxes


## Добавляет к узлу один меш из нескольких цветных коробок:
## [[размер, смещение, цвет, скос рёбер, сужение (низ, верх)], ...] — два последних необязательны.
static func add_part_mesh(parent: Node3D, boxes: Array) -> MeshInstance3D:
	var key := str(boxes)
	if not _mesh_cache.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for box: Array in boxes:
			var bevel: float = box[3] if box.size() > 3 else 0.0
			var taper: Vector2 = box[4] if box.size() > 4 else Vector2.ONE
			_add_shape(tool, box[0], box[1], box[2], bevel, taper)
		tool.set_material(_vertex_color_material())
		_mesh_cache[key] = tool.commit()
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = _mesh_cache[key]
	parent.add_child(instance)
	return instance


## Мелочь (оружие, культи, оторванные руки и голова) теней не отбрасывает — экономия на телефоне.
static func _no_shadow(part: Node3D) -> void:
	for child in part.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Коробка со скошенными рёбрами (bevel) и сужением книзу/кверху (taper: множители низа и верха).
static func _add_shape(tool: SurfaceTool, size: Vector3, offset: Vector3, color: Color, bevel: float, taper: Vector2, bone := -1) -> void:
	var h := size * 0.5
	var c := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.8)
	var i := h - Vector3.ONE * c
	var polygons := []
	# Грани.
	for axis in 3:
		for sign_value in [-1.0, 1.0]:
			var a := (axis + 1) % 3
			var b := (axis + 2) % 3
			var polygon := []
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var p := Vector3.ZERO
				p[axis] = sign_value * h[axis]
				p[a] = corner.x * i[a]
				p[b] = corner.y * i[b]
				polygon.append(p)
			polygons.append(polygon)
	if c > 0.0001:
		# Скосы рёбер.
		for axis in 3:
			var a := (axis + 1) % 3
			var b := (axis + 2) % 3
			for sa in [-1.0, 1.0]:
				for sb in [-1.0, 1.0]:
					var polygon := []
					for along in [-1.0, 1.0]:
						var p := Vector3.ZERO
						p[axis] = along * i[axis]
						p[a] = sa * h[a]
						p[b] = sb * i[b]
						polygon.append(p)
					for along in [1.0, -1.0]:
						var p := Vector3.ZERO
						p[axis] = along * i[axis]
						p[a] = sa * i[a]
						p[b] = sb * h[b]
						polygon.append(p)
					polygons.append(polygon)
		# Уголки.
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					polygons.append([Vector3(sx * h.x, sy * i.y, sz * i.z), Vector3(sx * i.x, sy * h.y, sz * i.z),
							Vector3(sx * i.x, sy * i.y, sz * h.z)])
	for polygon: Array in polygons:
		var points := []
		var center := Vector3.ZERO
		for p: Vector3 in polygon:
			var k := (p.y + h.y) / size.y if size.y > 0.0 else 0.5
			var s := lerpf(taper.x, taper.y, k)
			var q := Vector3(p.x * s, p.y, p.z * s)
			points.append(q)
			center += q
		center /= points.size()
		var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
		if normal.dot(center) < 0.0:
			points.reverse()
			normal = -normal
		normal = normal.normalized()
		# В Godot лицевая сторона треугольника — по часовой стрелке.
		for t in range(1, points.size() - 1):
			for index in [0, t + 1, t]:
				tool.set_normal(normal)
				tool.set_color(color)
				if bone >= 0:
					tool.set_bones(PackedInt32Array([bone, 0, 0, 0]))
					tool.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
				tool.add_vertex(points[index] + offset)


static func _vertex_color_material() -> StandardMaterial3D:
	if _vertex_material == null:
		_vertex_material = StandardMaterial3D.new()
		_vertex_material.vertex_color_use_as_albedo = true
		_vertex_material.vertex_color_is_srgb = true
		_vertex_material.roughness = 0.75
	return _vertex_material


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


## Обломки, которые сейчас лежат на уровне (их расталкивают взрывы).
static func get_debris() -> Array:
	return _debris.filter(func(item: Variant) -> bool: return is_instance_valid(item))


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
