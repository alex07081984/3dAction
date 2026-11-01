class_name Player
extends CharacterBody3D
## Игрок-стрелок: бег относительно камеры, прыжок, рывок с неуязвимостью,
## три вида оружия, перезарядка, помощь в прицеливании и хедшоты.
## Персонаж всегда смотрит туда же, куда камера (как в мобильных шутерах).

signal health_changed(current: int, maximum: int)
signal ammo_changed(weapon: WeaponData, magazine: int, reserve: int)
signal weapon_changed(weapon: WeaponData)
signal reload_started(duration: float)
signal shot_fired(weapon: WeaponData)
signal hit_confirmed(headshot: bool, killed: bool)
signal picked_up(text: String)
signal grenades_changed(count: int)
signal scope_changed(on: bool)
signal rage_changed(value: float, active: bool)
signal died

const WORLD_MASK := 1
const ENEMY_MASK := 4
const FALL_LIMIT := -25.0
const RAGE_TIME := 6.0  ## Сколько секунд (настоящих) длится ярость.

@export_group("Движение")
@export var move_speed := 6.0
@export var acceleration := 45.0
@export var air_acceleration := 14.0
@export var jump_velocity := 8.0
@export var gravity := 22.0
@export var turn_speed := 20.0

@export_group("Рывок")
@export var dodge_speed := 15.0
@export var dodge_time := 0.25
@export var dodge_cooldown := 0.7

@export_group("Бой")
@export var max_health := 100
@export var start_weapons: Array[WeaponData] = []
@export var aim_assist_deg := 4.0  ## Насколько далеко от прицела помощь «доводит» выстрел.
@export var hurt_invincibility := 0.25
@export var max_grenades := 5
@export var start_grenades := 2

var health := 0
var weapons: Array[WeaponData] = []
var current_weapon: WeaponData
## Враг под прицелом (с учётом помощи в прицеливании) — для красного прицела и автоогня.
var aim_target: Node3D
var aim_is_head := false
## Зона действия, в которой стоит игрок (вход на уровень, дверь дома и т. п.).
var interactable: Interactable

var _ammo := {}  # id оружия -> {"mag": int, "reserve": int}
var _fire_cooldown := 0.0
var _reload_left := 0.0
var _dodge_left := 0.0
var _dodge_cooldown_left := 0.0
var _dodge_dir := Vector3.ZERO
var _invincible := 0.0
var _dead := false
var _spawn_position := Vector3.ZERO
var _damage_bonus := 1.0
var _aim_start := Vector3.ZERO
var _aim_point := Vector3.ZERO
var grenades := 0
var _grenade_cooldown := 0.0
## Смотрим в оптический прицел снайперской винтовки.
var scoped := false
## Ярость копится за убийства (0–100). Полная — можно включить: всё вокруг замедляется,
## а герой двигается и стреляет в обычном темпе, без перезарядки и с бонусом к урону.
var rage := 0.0
var _rage_left := 0.0

@onready var model: BlockyCharacter = $Model
@onready var camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	add_to_group("player")
	# Бонусы от улучшений недвижимости.
	max_health += roundi(Game.perk("max_health"))
	_damage_bonus = 1.0 + Game.perk("damage")
	health = max_health
	_spawn_position = global_position
	# Поворот, заданный на уровне, отдаём камере, а само тело не вращаем.
	camera_rig.set_yaw(rotation.y)
	rotation = Vector3.ZERO
	model.rotation.y = camera_rig.get_yaw()
	for weapon in start_weapons:
		give_weapon(weapon, false)
	grenades = start_grenades


func _physics_process(delta: float) -> void:
	if _dead:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		_apply_gravity(delta)
		move_and_slide()
		return

	_tick_timers(delta)

	if Input.is_action_just_pressed("dodge"):
		_try_dodge()
	if Input.is_action_just_pressed("reload"):
		start_reload()
	if Input.is_action_just_pressed("switch_weapon"):
		switch_weapon()
	if Input.is_action_just_pressed("grenade"):
		throw_grenade()
	if Input.is_action_just_pressed("aim_scope"):
		toggle_scope()
	if Input.is_action_just_pressed("rage"):
		activate_rage()
	if Input.is_action_just_pressed("interact") and is_instance_valid(interactable) and interactable.active:
		interactable.interact(self)

	var direction := _get_move_direction()
	# В ярости мир замедлен, а герой — нет: скорость пересчитываем на настоящие секунды.
	var haste := 1.0 / maxf(Engine.time_scale, 0.05) if is_raging() else 1.0
	if _dodge_left > 0.0:
		velocity.x = _dodge_dir.x * dodge_speed * haste
		velocity.z = _dodge_dir.z * dodge_speed * haste
	else:
		var accel := (acceleration if is_on_floor() else air_acceleration) * haste * haste
		var speed := move_speed * (0.45 if scoped else 1.0) * haste
		var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * speed, accel * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity
	_apply_gravity(delta)
	move_and_slide()

	# Персонаж разворачивается туда, куда смотрит камера.
	model.rotation.y = lerp_angle(model.rotation.y, camera_rig.get_yaw(), 1.0 - exp(-turn_speed * delta))
	var speed_ratio := Vector2(velocity.x, velocity.z).length() / (move_speed * haste)
	model.animate(delta, speed_ratio, true, camera_rig.get_pitch())
	model.scale.y = 0.75 if _dodge_left > 0.0 else 1.0
	# Если камеру прижало стеной к спине (или смотрим в оптику), прячем персонажа, чтобы он не закрывал обзор.
	model.visible = not scoped and camera_rig.camera.global_position.distance_to(global_position + Vector3.UP * 1.4) > 0.9

	_update_aim()
	var wants_fire := Input.is_action_pressed("fire")
	if not wants_fire and Game.settings.get("auto_fire", false) and aim_target != null:
		wants_fire = true
	if wants_fire:
		_try_fire()

	if global_position.y < FALL_LIMIT:
		take_damage(max_health, global_position)


func is_alive() -> bool:
	return not _dead


func set_interactable(zone: Interactable) -> void:
	interactable = zone


func clear_interactable(zone: Interactable) -> void:
	if interactable == zone:
		interactable = null


func is_dodging() -> bool:
	return _dodge_left > 0.0


func is_reloading() -> bool:
	return _reload_left > 0.0


func is_raging() -> bool:
	return _rage_left > 0.0


func add_rage(amount: float) -> void:
	if _dead or is_raging() or amount <= 0.0:
		return
	var was_full := rage >= 100.0
	rage = minf(rage + amount, 100.0)
	rage_changed.emit(rage, false)
	if rage >= 100.0 and not was_full:
		picked_up.emit("Ярость готова!")


## Включить ярость, если шкала полная.
func activate_rage() -> bool:
	if _dead or is_raging() or rage < 100.0:
		return false
	_rage_left = RAGE_TIME
	Game.bullet_time = true
	camera_rig.shake(0.4)
	Audio.play("rage", 2.0)
	rage_changed.emit(rage, true)
	return true


func end_rage() -> void:
	if is_raging():
		_stop_rage()


func _stop_rage() -> void:
	_rage_left = 0.0
	rage = 0.0
	Game.bullet_time = false
	rage_changed.emit(0.0, false)


## Толчок взрывной волной.
func knockback(impulse: Vector3) -> void:
	if _dead:
		return
	velocity += impulse


func has_scope() -> bool:
	return current_weapon != null and current_weapon.scope_fov > 0.0


## Оптика снайперской винтовки: вкл/выкл. Без винтовки ничего не делает.
func toggle_scope() -> void:
	set_scoped(not scoped)


func set_scoped(on: bool) -> void:
	on = on and has_scope() and not _dead and _reload_left <= 0.0
	if on == scoped:
		return
	scoped = on
	camera_rig.set_scope(current_weapon.scope_fov if on else 0.0)
	Audio.play("switch", -8.0, 1.5 if on else 1.2)
	scope_changed.emit(on)


func get_ammo(weapon: WeaponData) -> Dictionary:
	return _ammo.get(weapon.id, {"mag": 0, "reserve": 0})


func take_damage(amount: int, from_position: Vector3) -> void:
	if _dead or _invincible > 0.0:
		return
	amount = maxi(roundi(amount * (1.0 - Game.perk("armor"))), 1)
	health = maxi(health - amount, 0)
	_invincible = hurt_invincibility
	health_changed.emit(health, max_health)
	camera_rig.shake(0.35)
	model.flinch(0.5)
	Audio.play("hurt", -2.0)
	if health == 0:
		_die(from_position)


## Бросить гранату туда, куда смотрит прицел (дальше 24 м не долетит).
func throw_grenade() -> bool:
	if _dead or grenades <= 0 or _grenade_cooldown > 0.0:
		return false
	grenades -= 1
	_grenade_cooldown = 0.8
	var from := global_position + Vector3.UP * 1.6 + camera_rig.get_yaw_basis() * Vector3(0.3, 0.0, -0.6)
	var container := get_tree().current_scene if get_tree().current_scene else get_parent()
	Grenade.throw_at(container, from, _aim_point, 24.0)
	model.recoil(0.4)
	grenades_changed.emit(grenades)
	return true


func add_grenades(amount: int) -> bool:
	if grenades >= max_grenades:
		return false
	grenades = mini(grenades + amount, max_grenades)
	grenades_changed.emit(grenades)
	picked_up.emit("Гранаты: %d" % grenades)
	return true


func heal(amount: int) -> bool:
	if _dead or health >= max_health:
		return false
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)
	picked_up.emit("+%d здоровья" % amount)
	return true


## Выдаёт оружие. Если оно уже есть — добавляет к нему патроны.
func give_weapon(weapon: WeaponData, announce := true) -> bool:
	if weapon == null:
		return false
	if _ammo.has(weapon.id):
		var added := _add_reserve(weapon, weapon.ammo_per_pickup * 2)
		if added and announce:
			picked_up.emit("Патроны: %s" % weapon.display_name)
		return added
	weapons.append(weapon)
	var reserve := roundi(weapon.start_reserve * (1.0 + Game.perk("ammo")))
	_ammo[weapon.id] = {"mag": weapon.magazine, "reserve": mini(reserve, weapon.max_reserve)}
	_select(weapon)
	if announce:
		picked_up.emit("Новое оружие: %s!" % weapon.display_name)
	return true


## Коробка патронов: пополняет всё оружие с ограниченным боезапасом.
func add_ammo() -> bool:
	var added := false
	for weapon in weapons:
		if _add_reserve(weapon, weapon.ammo_per_pickup):
			added = true
	if added:
		picked_up.emit("Патроны")
	return added


func switch_weapon() -> void:
	if weapons.size() < 2 or _dead:
		return
	var index := (weapons.find(current_weapon) + 1) % weapons.size()
	_select(weapons[index])
	Audio.play("switch", -4.0)


func switch_weapon_to(weapon: WeaponData) -> void:
	if weapon in weapons and weapon != current_weapon:
		_select(weapon)


func start_reload() -> void:
	if current_weapon == null or _reload_left > 0.0 or _dead:
		return
	var state: Dictionary = _ammo[current_weapon.id]
	if state.mag >= current_weapon.magazine:
		return
	if not current_weapon.infinite_ammo and state.reserve <= 0:
		return
	set_scoped(false)
	_reload_left = current_weapon.reload_time
	reload_started.emit(current_weapon.reload_time)
	Audio.play("reload", -3.0)


# --- Стрельба -----------------------------------------------------------------

func _try_fire() -> void:
	if current_weapon == null or _fire_cooldown > 0.0 or _reload_left > 0.0:
		return
	var state: Dictionary = _ammo[current_weapon.id]
	var raging := is_raging()
	if state.mag <= 0 and not raging:
		_fire_cooldown = 0.3
		if current_weapon.infinite_ammo or state.reserve > 0:
			start_reload()
		else:
			Audio.play("dry_fire")
		return
	# В ярости патроны не тратятся.
	if not raging:
		state.mag -= 1
	_fire_cooldown = current_weapon.fire_interval
	_shoot(current_weapon)
	_emit_ammo()
	if state.mag == 0 and not raging:
		start_reload()


func _shoot(weapon: WeaponData) -> void:
	var space := get_world_3d().direct_space_state
	var base_dir := (_aim_point - _aim_start).normalized()
	var muzzle := model.get_muzzle_position()
	var bonus := _damage_bonus * (1.5 if is_raging() else 1.0)
	if weapon.projectile != "":
		_launch_rocket(weapon, muzzle, bonus)
		return
	var results := {}  # враг -> {"damage", "head", "point", "dir", "parts"}
	var impact_shown := false

	# Снайперская винтовка без оптики стреляет с большим разбросом.
	var spread := weapon.spread_deg
	if weapon.scope_fov > 0.0 and not scoped:
		spread = maxf(spread, weapon.hip_spread_deg)
	for i in weapon.pellets:
		var dir := _spread(base_dir, spread)
		var end := _aim_start + dir * weapon.max_range
		var query := PhysicsRayQueryParameters3D.create(_aim_start, end, WORLD_MASK | ENEMY_MASK, [get_rid()])
		var hit := space.intersect_ray(query)
		if hit:
			end = hit.position
			var enemy := hit.collider as Enemy
			if enemy and enemy.is_alive():
				# Часть тела считаем по настоящей позе модели: так дробь отрывает руки и ноги.
				var part := enemy.get_hit_part(_aim_start, dir)
				var head := part == "head"
				var damage := weapon.damage * (weapon.headshot_multiplier if head else 1.0) * bonus
				if not results.has(enemy):
					results[enemy] = {"damage": 0.0, "head": false, "point": end, "dir": dir, "parts": {}}
				results[enemy].damage += damage
				results[enemy].head = results[enemy].head or head
				results[enemy].parts[part] = results[enemy].parts.get(part, 0.0) + damage
				if head:
					results[enemy].point = end
			elif hit.collider.has_method("take_hit"):
				# Бочки и баллоны.
				hit.collider.take_hit(weapon.damage * bonus, end, dir)
				Fx.sparks(end, hit.normal)
			elif not impact_shown or i % 3 == 0:
				Fx.sparks(end, hit.normal)
				Fx.bullet_hole(end, hit.normal)
				if not impact_shown:
					Audio.play_at("impact", end, -6.0)
				impact_shown = true
		Fx.tracer(muzzle, end)

	for enemy in results:
		var info: Dictionary = results[enemy]
		var killed: bool = enemy.apply_shot(info.damage, info.head, info.point, info.dir, weapon, info.parts)
		hit_confirmed.emit(info.head, killed)

	Fx.muzzle_flash(muzzle, base_dir)
	Audio.play(weapon.sound, -2.0)
	camera_rig.add_recoil(weapon.recoil_deg)
	camera_rig.shake(weapon.shake)
	model.recoil(0.12 + weapon.recoil_deg * 0.04)
	shot_fired.emit(weapon)
	# Выстрел слышат враги поблизости.
	get_tree().call_group("enemies", "hear_noise", global_position, 22.0)
	get_tree().call_group("civilians", "panic", global_position, 30.0)


## РПГ: ракета летит из ствола туда, куда смотрит прицел.
func _launch_rocket(weapon: WeaponData, muzzle: Vector3, bonus: float) -> void:
	var direction := _spread((_aim_point - muzzle).normalized(), weapon.spread_deg)
	var container := get_tree().current_scene if get_tree().current_scene else get_parent()
	Rocket.launch(container, muzzle, direction, weapon.projectile_speed, weapon.blast_radius,
			weapon.damage * bonus, weapon.player_blast_damage, self)
	Fx.muzzle_flash(muzzle, direction)
	Audio.play(weapon.sound, 0.0)
	camera_rig.add_recoil(weapon.recoil_deg)
	camera_rig.shake(weapon.shake)
	model.recoil(0.5)
	shot_fired.emit(weapon)
	get_tree().call_group("enemies", "hear_noise", global_position, 30.0)
	get_tree().call_group("civilians", "panic", global_position, 35.0)


## Где прицел: обычный луч из центра экрана, а если он мимо — помощь
## в прицеливании ищет голову или грудь врага рядом с прицелом.
func _update_aim() -> void:
	var ray := camera_rig.get_aim_ray()
	var origin: Vector3 = ray[0]
	var forward: Vector3 = ray[1]
	var weapon_range := current_weapon.max_range if current_weapon else 60.0
	# Луч начинаем на уровне игрока, чтобы не цеплять то, что между камерой и героем.
	var skip := maxf((global_position + Vector3.UP * 1.3 - origin).dot(forward), 0.0)
	_aim_start = origin + forward * skip
	var end := origin + forward * (skip + weapon_range)
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(_aim_start, end, WORLD_MASK | ENEMY_MASK, [get_rid()]))
	_aim_point = hit.position if hit else end
	aim_target = null
	aim_is_head = false
	var direct: Enemy = null
	if hit:
		direct = hit.collider as Enemy
	if direct and direct.is_alive():
		aim_target = direct
		aim_is_head = direct.get_hit_part(_aim_start, forward) == "head"
		return
	if not Game.settings.get("aim_assist", true):
		return

	# В оптике помощь в прицеливании сужается вместе с обзором.
	var best_angle := deg_to_rad(aim_assist_deg) * camera_rig.zoom_ratio()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		for is_head in [true, false]:
			var point := enemy.get_aim_point(is_head)
			var to_point := point - origin
			var along := to_point.dot(forward)
			if along < skip or along > skip + weapon_range:
				continue
			var angle := forward.angle_to(to_point)
			if angle >= best_angle:
				continue
			var blocked := space.intersect_ray(PhysicsRayQueryParameters3D.create(_aim_start, point, WORLD_MASK, [get_rid()]))
			if blocked:
				continue
			best_angle = angle
			aim_target = enemy
			aim_is_head = is_head
			_aim_point = point


func _spread(direction: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return direction
	var angle := deg_to_rad(degrees) * sqrt(randf())
	var around := randf() * TAU
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	var basis := Basis.looking_at(direction, up)
	return (basis * Vector3(sin(angle) * cos(around), sin(angle) * sin(around), -cos(angle))).normalized()


# --- Вспомогательное ----------------------------------------------------------

func _select(weapon: WeaponData) -> void:
	set_scoped(false)
	current_weapon = weapon
	_reload_left = 0.0
	_fire_cooldown = 0.25
	model.set_weapon(weapon.model)
	weapon_changed.emit(weapon)
	_emit_ammo()


func _add_reserve(weapon: WeaponData, amount: int) -> bool:
	if weapon.infinite_ammo or amount <= 0:
		return false
	var state: Dictionary = _ammo[weapon.id]
	if state.reserve >= weapon.max_reserve:
		return false
	state.reserve = mini(state.reserve + amount, weapon.max_reserve)
	if weapon == current_weapon:
		_emit_ammo()
	return true


func _emit_ammo() -> void:
	if current_weapon == null:
		return
	var state: Dictionary = _ammo[current_weapon.id]
	var reserve: int = -1 if current_weapon.infinite_ammo else state.reserve
	ammo_changed.emit(current_weapon, state.mag, reserve)


func _finish_reload() -> void:
	var state: Dictionary = _ammo[current_weapon.id]
	var need: int = current_weapon.magazine - state.mag
	var take: int = need if current_weapon.infinite_ammo else mini(need, state.reserve)
	state.mag += take
	if not current_weapon.infinite_ammo:
		state.reserve -= take
	_emit_ammo()


func _tick_timers(delta: float) -> void:
	# В ярости герой живёт по настоящим часам, а мир вокруг — замедленно.
	if is_raging():
		delta /= maxf(Engine.time_scale, 0.05)
		_rage_left -= delta
		rage = 100.0 * maxf(_rage_left, 0.0) / RAGE_TIME
		rage_changed.emit(rage, true)
		if _rage_left <= 0.0:
			_stop_rage()
	_fire_cooldown -= delta
	_grenade_cooldown -= delta
	_dodge_left -= delta
	_dodge_cooldown_left -= delta
	_invincible -= delta
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()


func _get_move_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return camera_rig.get_yaw_basis() * Vector3(input.x, 0.0, input.y)


func _try_dodge() -> void:
	if _dodge_cooldown_left > 0.0 or not is_on_floor():
		return
	var direction := _get_move_direction()
	if direction.length_squared() < 0.01:
		direction = camera_rig.get_yaw_basis() * Vector3.BACK
	set_scoped(false)
	_dodge_dir = direction.normalized()
	_dodge_left = dodge_time
	_dodge_cooldown_left = dodge_cooldown
	_invincible = maxf(_invincible, dodge_time + 0.05)
	Audio.play("swing", -6.0, 0.8)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _die(from_position: Vector3) -> void:
	set_scoped(false)
	end_rage()
	_dead = true
	aim_target = null
	var direction := global_position - from_position
	model.break_apart(BlockyCharacter.Death.FALL, direction, 3.0)
	Audio.play("death")
	died.emit()
