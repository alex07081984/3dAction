class_name Enemy
extends CharacterBody3D
## Враг. Три вида: стрелок, псих с битой и громила (настраиваются в своих сценах).
## Стоит на посту, пока не заметит игрока: увидит, услышит выстрел или словит пулю.
## Перед выстрелом целится красным лазером — есть время уйти рывком или за укрытие.
## Дробовик отрывает руки и ноги: без ноги враг прыгает на одной, без руки —
## держится за плечо, а через несколько секунд падает и истекает кровью.

signal died(enemy: Enemy, headshot: bool)

enum Kind { GUNNER, RUSHER, HEAVY }
enum Phase { PAUSE, AIM, FIRE, WINDUP, RECOVER }

const WORLD_MASK := 1
const PLAYER_MASK := 2

@export var kind := Kind.GUNNER
@export var max_health := 70.0
@export var move_speed := 3.0
@export var turn_speed := 7.0
@export var gravity := 22.0
@export var sight_range := 30.0
@export var view_angle_deg := 150.0
@export var alerted := false  ## Сразу знает, где игрок (так появляются враги из волн).
@export var hold_position := true  ## Стрелок стоит на посту, пока видит игрока.
@export var can_be_dismembered := true  ## Можно ли оторвать руку или ногу (боссам нельзя).

@export_group("Стрельба")
@export var damage := 7
@export var aim_time := 0.8  ## Сколько горит лазер перед выстрелом.
@export var burst := 1
@export var burst_interval := 0.14
@export var fire_pause := 1.6
@export_range(0.0, 1.0) var accuracy := 0.65

@export_group("Ближний бой")
@export var melee_damage := 18
@export var melee_range := 1.6
@export var melee_windup := 0.45

@export_group("Добыча")
@export_range(0.0, 1.0) var drop_ammo_chance := 0.25
@export_range(0.0, 1.0) var drop_health_chance := 0.12
@export var health_drop_amount := 20

var health := 0.0

var _awake := false
var _dead := false
var _phase := Phase.PAUSE
var _timer := 0.0
var _shots_left := 0
var _player: Player
var _sees_player := false
var _think := 0.0
var _last_seen := Vector3.ZERO
var _lost_time := 0.0
var _strafe_dir := 0.0
var _strafe_timer := 0.0
var _laser: MeshInstance3D
var _wound_left := 0.0
var _hop_timer := 0.0
var _scream_timer := 0.0
var _wander := Vector3.FORWARD

@onready var model: BlockyCharacter = $Model
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("enemies")
	_apply_difficulty()
	health = max_health
	_think = randf() * 0.2
	_build_laser()
	if alerted:
		_wake.call_deferred(false)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if not is_on_floor():
		velocity.y -= gravity * delta

	_think -= delta
	if _think <= 0.0:
		_think = 0.2
		_sees_player = _can_see_player()
		if _sees_player:
			_last_seen = _player.global_position

	if is_wounded():
		_wounded_logic(delta)
	elif not _awake:
		_slow_down(delta)
		if _sees_player and (_in_view() or _distance_to_player() < 6.0):
			_wake()
	elif not _player_alive():
		_slow_down(delta)
		_show_laser(false)
		model.melee_pose = -1.0
	elif kind == Kind.RUSHER:
		_rusher_logic(delta)
	else:
		_shooter_logic(delta)

	move_and_slide()
	if _dead:
		return
	model.airborne = not is_on_floor()
	var speed_ratio := Vector2(velocity.x, velocity.z).length() / maxf(move_speed, 0.1)
	model.animate(delta, speed_ratio, _awake and kind != Kind.RUSHER and not is_wounded(), _aim_pitch())

	if global_position.y < -25.0:
		_die(BlockyCharacter.Death.FALL, Vector3.DOWN, 0.0)


func is_alive() -> bool:
	return not _dead


## Ранен так, что уже не воюет (оторвана рука или нога) и скоро упадёт.
func is_wounded() -> bool:
	return model.wound != ""


func is_head_hit(point: Vector3) -> bool:
	return point.y - global_position.y >= model.get_neck_height()


## Куда попадает луч: head, torso, arm_l, arm_r, leg_l, leg_r.
func get_hit_part(from: Vector3, direction: Vector3) -> String:
	return model.get_hit_part(from, direction)


## Точка, в которую помощь прицеливания «доводит» выстрел.
func get_aim_point(head: bool) -> Vector3:
	return model.get_head_center() if head else model.get_chest_center()


## Попадание от игрока. parts — урон по частям тела ({"leg_l": 24.0, ...}).
## Возвращает true, если враг убит или смертельно ранен.
func apply_shot(amount: float, headshot: bool, point: Vector3, direction: Vector3, weapon: WeaponData, parts := {}) -> bool:
	if _dead:
		return false
	health -= amount
	_wake()
	model.flinch(0.75 if headshot else 0.45)
	Fx.blood(point, direction, 24 if amount >= 40.0 else 12)
	# Заряд дроби в ногу или руку отрывает её, даже если урона хватило бы на смерть:
	# человечек ещё попрыгает или покорчится, а потом упадёт.
	var limb := "" if is_wounded() else _limb_to_sever(parts, weapon, amount)
	if limb != "":
		_take_wound(limb, direction, weapon.impulse)
		return true
	if health <= 0.0 or is_wounded():
		var mode := BlockyCharacter.Death.FALL
		if amount >= weapon.gib_damage:
			mode = BlockyCharacter.Death.GIB
		elif headshot:
			mode = BlockyCharacter.Death.HEADSHOT
		_die(mode, direction, weapon.impulse)
		return true
	Audio.play_at("hit", point, -3.0)
	# Попадание сбивает прицеливание. Громилу — только хедшот или мощный выстрел.
	if _phase == Phase.AIM or _phase == Phase.WINDUP:
		if kind != Kind.HEAVY or headshot or amount >= 40.0:
			_phase = Phase.PAUSE
			_timer = 0.35
			_show_laser(false)
			model.melee_pose = -1.0
	return false


## Взрыв рядом: урон, отлетевшие руки и ноги, вблизи — на куски.
func apply_blast(amount: float, origin: Vector3, force: float) -> void:
	if _dead:
		return
	var direction := global_position + Vector3.UP - origin
	direction.y = absf(direction.y) + 0.8
	direction = direction.normalized()
	health -= amount
	_wake()
	if health <= 0.0 or is_wounded():
		if amount >= 70.0:
			_die(BlockyCharacter.Death.GIB, direction, force)
			return
		if can_be_dismembered:
			var limbs := BlockyCharacter.LIMBS.duplicate()
			limbs.shuffle()
			for i in randi_range(1, 2):
				model.sever_limb(limbs[i], direction, force)
		_die(BlockyCharacter.Death.FALL, direction, force)
		return
	model.flinch(1.0)
	if can_be_dismembered and amount >= 30.0 and randf() < 0.5:
		_take_wound(BlockyCharacter.LIMBS.pick_random(), direction, force)


## Враг слышит выстрел игрока, если тот достаточно близко.
func hear_noise(position: Vector3, radius: float) -> void:
	if not _awake and not _dead and global_position.distance_to(position) <= radius:
		_wake()


# --- Ранения ----------------------------------------------------------------------

## Какую конечность оторвёт этот выстрел (пусто — никакую). Отрывает, если в неё
## пришлось достаточно урона и заметная доля всего заряда.
func _limb_to_sever(parts: Dictionary, weapon: WeaponData, total: float) -> String:
	if not can_be_dismembered or weapon == null or weapon.sever_damage <= 0.0:
		return ""
	var best := ""
	var best_damage := 0.0
	for part: String in parts:
		if not part in BlockyCharacter.LIMBS or not model.has_limb(part):
			continue
		var need := weapon.sever_damage * (1.3 if part.begins_with("leg") else 1.0) * model.scale.x
		var damage: float = parts[part]
		if damage >= need and damage >= total * 0.3 and damage > best_damage:
			best = part
			best_damage = damage
	return best


func _take_wound(limb: String, direction: Vector3, force: float) -> void:
	if not model.sever_limb(limb, direction, force):
		return
	health = maxf(health, 1.0)
	_wound_left = randf_range(4.5, 6.0)
	_hop_timer = 0.3
	_scream_timer = randf_range(1.2, 1.8)
	_phase = Phase.PAUSE
	_show_laser(false)
	model.melee_pose = -1.0
	_wander = Vector3(direction.x, 0.0, direction.z).normalized()
	if _wander.length_squared() < 0.01:
		_wander = global_basis.z
	Audio.play_at("gib", global_position + Vector3.UP, -6.0, 1.2)
	Audio.play_at("scream", global_position + Vector3.UP * 1.6, 0.0)


## Без ноги — прыгает на одной, без руки — шатается, зажимая рану. Потом падает.
func _wounded_logic(delta: float) -> void:
	_wound_left -= delta
	_scream_timer -= delta
	if _scream_timer <= 0.0:
		_scream_timer = randf_range(1.6, 2.6)
		Audio.play_at("scream", global_position + Vector3.UP * 1.6, -4.0, randf_range(0.9, 1.15))
	if model.wound.begins_with("leg"):
		if is_on_floor():
			_set_horizontal_velocity(Vector3.ZERO, delta * 0.6)
			_hop_timer -= delta
			if _hop_timer <= 0.0:
				_hop_timer = randf_range(0.22, 0.4)
				var direction := _wander.rotated(Vector3.UP, randf_range(-0.7, 0.7))
				if not _ground_ahead(direction):
					_wander = -_wander
					direction = _wander
				velocity = Vector3(direction.x * 1.8, 3.6, direction.z * 1.8)
				Fx.blood(global_position + Vector3.UP * 0.8, Vector3.DOWN, 6)
	else:
		if not _ground_ahead(_wander):
			_wander = _wander.rotated(Vector3.UP, PI * randf_range(0.6, 1.4))
		_set_horizontal_velocity(_wander * 0.9, delta)
		_face(-_wander, delta * 0.4)
	if _wound_left <= 0.0:
		_die(BlockyCharacter.Death.FALL, -global_basis.z, 1.5)


# --- Стрелок и громила --------------------------------------------------------

func _shooter_logic(delta: float) -> void:
	_face(_flat_to(_player.global_position), delta)
	if not _sees_player:
		_show_laser(false)
		if _phase != Phase.PAUSE:
			_phase = Phase.PAUSE
			_timer = 0.4
		_lost_time += delta
		if not hold_position or _lost_time > 2.0:
			_move_to(_last_seen, delta)
		else:
			_slow_down(delta)
		return

	_lost_time = 0.0
	_timer -= delta
	match _phase:
		Phase.PAUSE:
			_strafe(delta)
			if _timer <= 0.0:
				_phase = Phase.AIM
				_timer = aim_time
		Phase.AIM:
			_slow_down(delta)
			_show_laser(true)
			if _timer <= 0.0:
				_phase = Phase.FIRE
				_shots_left = burst
				_timer = 0.0
		Phase.FIRE:
			_slow_down(delta)
			if _timer <= 0.0:
				_fire()
				_shots_left -= 1
				_timer = burst_interval
				if _shots_left <= 0:
					_phase = Phase.PAUSE
					_timer = fire_pause * randf_range(0.8, 1.25)
					_show_laser(false)
		_:
			_phase = Phase.PAUSE


func _fire() -> void:
	var muzzle := model.get_muzzle_position()
	var target := _player.global_position + Vector3.UP * 1.2
	var distance := muzzle.distance_to(target)
	var chance := accuracy * clampf(1.2 - distance / 35.0, 0.35, 1.0)
	if Vector2(_player.velocity.x, _player.velocity.z).length() > 3.0:
		chance *= 0.75
	if _player.is_dodging():
		chance = 0.0
	var will_hit := randf() < chance
	var aim := target
	if not will_hit:
		var side := (target - muzzle).cross(Vector3.UP).normalized()
		aim += side * randf_range(0.7, 1.3) * (1.0 if randf() < 0.5 else -1.0) + Vector3.UP * randf_range(-0.3, 0.6)
	var direction := (aim - muzzle).normalized()
	var end := muzzle + direction * 80.0
	var query := PhysicsRayQueryParameters3D.create(muzzle, end, WORLD_MASK | PLAYER_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		end = hit.position
		if hit.collider is Player:
			if will_hit:
				(hit.collider as Player).take_damage(damage, global_position)
		else:
			Fx.sparks(end, hit.normal)
			if hit.collider.has_method("take_hit"):
				hit.collider.take_hit(float(damage), end, direction)
	Fx.tracer(muzzle, end, Color(1.0, 0.45, 0.25))
	Fx.muzzle_flash(muzzle, direction)
	Audio.play_at("enemy_shot", muzzle, -2.0)
	model.recoil(0.2)


func _strafe(delta: float) -> void:
	if hold_position:
		_slow_down(delta)
		return
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(1.0, 2.5)
		_strafe_dir = [-1.0, 0.0, 1.0].pick_random()
	var side := global_basis.x * _strafe_dir
	if _strafe_dir != 0.0 and _ground_ahead(side):
		_set_horizontal_velocity(side * move_speed * 0.6, delta)
	else:
		_slow_down(delta)


# --- Псих с битой --------------------------------------------------------------

func _rusher_logic(delta: float) -> void:
	var to_player := _flat_to(_player.global_position)
	var distance := to_player.length()
	match _phase:
		Phase.WINDUP:
			_slow_down(delta)
			_face(to_player, delta)
			_timer -= delta
			model.melee_pose = 1.0 - clampf(_timer / melee_windup, 0.0, 1.0)
			if _timer <= 0.0:
				_strike(distance, to_player)
		Phase.RECOVER:
			_slow_down(delta)
			_timer -= delta
			if _timer < 0.3:
				model.melee_pose = -1.0
			if _timer <= 0.0:
				_phase = Phase.PAUSE
		_:
			model.melee_pose = -1.0
			if distance <= melee_range:
				_phase = Phase.WINDUP
				_timer = melee_windup
				return
			var direction := (to_player / maxf(distance, 0.01) + _separation()).normalized()
			if _ground_ahead(direction):
				_set_horizontal_velocity(direction * move_speed, delta)
			else:
				_slow_down(delta)
			_face(direction, delta)


func _strike(distance: float, to_player: Vector3) -> void:
	model.melee_pose = 0.0
	_phase = Phase.RECOVER
	_timer = 0.6
	Audio.play_at("swing", global_position)
	var forward := -global_basis.z
	if distance <= melee_range + 0.6 and forward.dot(to_player.normalized()) > 0.3:
		_player.take_damage(melee_damage, global_position)
		Audio.play_at("melee_hit", _player.global_position)


# --- Общее ----------------------------------------------------------------------

func _wake(alert_neighbors := true) -> void:
	if _awake or _dead:
		return
	_awake = true
	_phase = Phase.PAUSE
	_timer = randf_range(0.3, 0.9)
	if is_instance_valid(_player):
		_last_seen = _player.global_position
	if alert_neighbors:
		# Будим соседей, но без цепной реакции на весь уровень.
		for node in get_tree().get_nodes_in_group("enemies"):
			var other := node as Enemy
			if other and other != self and other.global_position.distance_to(global_position) < 10.0:
				other._wake(false)


func _die(mode: BlockyCharacter.Death, direction: Vector3, force: float) -> void:
	_dead = true
	remove_from_group("enemies")
	_show_laser(false)
	_collision.set_deferred("disabled", true)
	model.break_apart(mode, direction, force)
	match mode:
		BlockyCharacter.Death.GIB:
			Audio.play_at("gib", global_position + Vector3.UP)
		BlockyCharacter.Death.HEADSHOT:
			Audio.play_at("headshot", global_position + Vector3.UP * 1.7)
		_:
			Audio.play_at("death", global_position + Vector3.UP)
	_drop_loot()
	var headshot := mode == BlockyCharacter.Death.HEADSHOT
	died.emit(self, headshot)
	get_tree().call_group("level", "register_kill", headshot)
	queue_free()


func _drop_loot() -> void:
	var roll := randf()
	var pickup: Pickup = null
	if roll < drop_health_chance:
		pickup = Pickup.new()
		pickup.kind = Pickup.Kind.HEALTH
		pickup.heal_amount = health_drop_amount
	elif roll < drop_health_chance + drop_ammo_chance:
		pickup = Pickup.new()
		pickup.kind = Pickup.Kind.AMMO
	if pickup and get_tree().current_scene:
		get_tree().current_scene.add_child(pickup)
		pickup.global_position = global_position + Vector3.UP * 0.1


func _can_see_player() -> bool:
	if not _player_alive():
		return false
	var eye := global_position + Vector3.UP * 1.6 * model.scale.y
	var target := _player.global_position + Vector3.UP * 1.3
	if eye.distance_to(target) > sight_range:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, WORLD_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _in_view() -> bool:
	var to_player := _flat_to(_player.global_position)
	if to_player.length_squared() < 0.01:
		return true
	return rad_to_deg((-global_basis.z).angle_to(to_player)) <= view_angle_deg * 0.5


func _player_alive() -> bool:
	return is_instance_valid(_player) and _player.is_alive()


func _distance_to_player() -> float:
	return _flat_to(_player.global_position).length() if is_instance_valid(_player) else INF


func _flat_to(point: Vector3) -> Vector3:
	var offset := point - global_position
	offset.y = 0.0
	return offset


func _aim_pitch() -> float:
	if not _awake or not _player_alive():
		return 0.0
	var offset := _player.global_position + Vector3.UP * 1.2 - (global_position + Vector3.UP * 1.4 * model.scale.y)
	return clampf(atan2(offset.y, Vector2(offset.x, offset.z).length()), -0.9, 0.9)


func _move_to(point: Vector3, delta: float) -> void:
	var offset := _flat_to(point)
	if offset.length() < 1.5:
		_slow_down(delta)
		return
	var direction := (offset.normalized() + _separation()).normalized()
	if _ground_ahead(direction):
		_set_horizontal_velocity(direction * move_speed, delta)
	else:
		_slow_down(delta)


## Есть ли пол впереди — чтобы враги не прыгали с платформ и крыш.
func _ground_ahead(direction: Vector3) -> bool:
	var from := global_position + direction.normalized() * 0.8 + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.6, WORLD_MASK)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Node3D
		if other == null or other == self:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance > 0.001 and distance < 1.4:
			push += away / distance * (1.4 - distance)
	return push


func _face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-turn_speed * delta))


func _set_horizontal_velocity(target: Vector3, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, 25.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _slow_down(delta: float) -> void:
	_set_horizontal_velocity(Vector3.ZERO, delta)


## На повторных прохождениях враги крепче, больнее бьют, метче и быстрее целятся.
func _apply_difficulty() -> void:
	var tier: int = Game.current_tier
	if tier <= 0:
		return
	max_health *= Game.enemy_health_multiplier()
	damage = roundi(damage * Game.enemy_damage_multiplier())
	melee_damage = roundi(melee_damage * Game.enemy_damage_multiplier())
	accuracy = minf(accuracy + 0.04 * tier, 0.95)
	aim_time *= maxf(0.6, 1.0 - 0.06 * tier)
	move_speed *= 1.0 + 0.03 * tier


func _build_laser() -> void:
	_laser = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018, 0.018, 1.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.1, 0.1, 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	_laser.mesh = mesh
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser.top_level = true
	_laser.visible = false
	add_child(_laser)


## Красный лазер от ствола к игроку — предупреждение о выстреле.
func _show_laser(on: bool) -> void:
	if _laser == null:
		return
	_laser.visible = on and _player_alive()
	if not _laser.visible:
		return
	var from := model.get_muzzle_position()
	var to := _player.global_position + Vector3.UP * 1.2
	var length := from.distance_to(to)
	if length < 0.1:
		return
	_laser.global_transform = Transform3D(Basis.looking_at(to - from), (from + to) * 0.5)
	_laser.scale = Vector3(1.0, 1.0, length)
	# В последние мгновения лазер мигает — сейчас выстрелит.
	if _phase == Phase.AIM and _timer < 0.25:
		_laser.visible = int(_timer * 30.0) % 2 == 0
