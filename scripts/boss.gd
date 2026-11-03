class_name Boss
extends Enemy
## Босс уровня: три фазы, полоса здоровья вверху экрана, на каждой новой фазе
## приходят новые прислужники, а с них чаще падают аптечки.
## Толстяк (крыша небоскрёба) с каждой фазой злее, а в последней берёт дробовик и прёт напролом.
## Худой (особняк) после каждой фазы бросает дымовую шашку и прячется в другой комнате:
## ищите его по смеху. В последней фазе стреляет из Desert Eagle.
## Снайпер (заброшенный городок) сидит на вышках и после каждой фазы перебегает
## на другую позицию: ищите блик оптики и красный лазер.

signal cleared(boss: Boss)  ## Босс побеждён (на это смотрит выход с уровня).

@export var boss_name := "Толстяк"
@export var phases := 3
@export var phase_health := 450.0  ## Здоровье на одну фазу (на повторах растёт со сложностью).
@export var final_weapon := "shotgun"  ## Оружие последней фазы: shotgun или deagle.
@export var final_damage := 40  ## Урон в последней фазе (у дробовика — весь заряд в упор).
@export var hides := false  ## Прятаться после каждой фазы (Худой).
## Снайпер: после каждой фазы (и если долго не видит игрока) перебегает на другую позицию из hide_points.
@export var relocates := false
@export var hide_points: NodePath  ## Узел с Marker3D, где можно спрятаться. Имя маркера — подсказка игроку.
@export var henchman_points: NodePath  ## Узел с Marker3D, откуда приходят прислужники.
@export var henchmen_per_phase := 4
@export var completes_level := false  ## Уровень пройден сразу после победы над боссом.
@export var final_burst := 0  ## Длина очереди в последней фазе (0 — одиночные выстрелы).
@export var blackout := false  ## При смене фазы гаснет свет (Крупье).
@export var grenade_interval := 0.0  ## Бросает гранату раз в столько секунд (0 — не бросает).
@export var reward := 400  ## Премия за босса (умножается на сложность).
@export var gunner_scene: PackedScene
@export var rusher_scene: PackedScene
@export var heavy_scene: PackedScene

var phase := 1
var defeated := false
var hidden := false

var _phase_max := 0.0
var _transition := 0.0
var _announced := false
var _laugh_timer := 0.0
var _hint_timer := 0.0
var _hidden_time := 0.0
var _hide_name := ""
var _charging := false
var _grenade_timer := 3.0
var _nest: Node3D


func _ready() -> void:
	can_be_dismembered = false
	max_health = phase_health
	super._ready()
	_phase_max = max_health
	add_to_group("bosses")


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _transition > 0.0:
		_transition -= delta
	if hidden:
		_hide_logic(delta)
	elif grenade_interval > 0.0 and _awake and _transition <= 0.0:
		_grenade_logic(delta)
	if relocates and _awake and _transition <= 0.0 and _lost_time > 7.0 and _player_alive():
		# Потерял игрока из виду — ищет новую позицию.
		_lost_time = 0.0
		_relocate(false)
	super._physics_process(delta)


## Попадание от игрока. Между фазами босс неуязвим, а последний удар фазы его не убивает.
func apply_shot(amount: float, headshot: bool, point: Vector3, direction: Vector3, weapon: WeaponData, parts := {}) -> bool:
	if _dead:
		return false
	if hidden:
		_wake()
	if _transition > 0.0:
		Fx.sparks(point, -direction)
		return false
	if phase < phases and health - amount <= 0.0:
		Fx.blood(point, direction, 24)
		model.flinch(1.0)
		_next_phase()
		return false
	var killed := super.apply_shot(amount, headshot, point, direction, weapon, parts)
	_update_bar()
	return killed


func apply_blast(amount: float, origin: Vector3, force: float) -> void:
	if _dead or _transition > 0.0:
		return
	if hidden:
		_wake()
	if phase < phases and health - amount <= 0.0:
		model.flinch(1.0)
		_next_phase()
		return
	super.apply_blast(amount, origin, force)
	_update_bar()


## Спрятавшийся босс не выдаёт себя на звук выстрелов.
func hear_noise(position: Vector3, radius: float) -> void:
	if not hidden:
		super.hear_noise(position, radius)


func get_phase_fraction() -> float:
	return clampf(health / maxf(_phase_max, 1.0), 0.0, 1.0)


func _wake(alert_neighbors := true) -> void:
	if _dead:
		return
	if hidden:
		hidden = false
		_hud("show_message", "Попался!", tr("%s найден") % tr(boss_name))
		_hud("set_objective", tr("Убейте: %s") % tr(boss_name))
		Audio.play_at("laugh", _head(), 4.0)
	if not _announced:
		_announced = true
		_hud("show_message", boss_name, tr("Босс! Фаза 1 из %d") % phases)
		Audio.play_at("laugh" if hides else "roar", _head(), 4.0)
		get_tree().call_group("level", "on_boss_fight", self)
	super._wake(alert_neighbors)
	_update_bar()


# --- Фазы ------------------------------------------------------------------------

func _next_phase() -> void:
	phase += 1
	health = _phase_max
	_transition = 1.6
	_phase = Phase.PAUSE
	_timer = 1.0
	_show_laser(false)
	model.flinch(1.0)
	if phase >= phases:
		_enter_final_phase()
	else:
		# С каждой фазой злее: длиннее очереди, меньше пауз, меньше стоит на месте.
		# Снайпер вместо очередей целится быстрее.
		if relocates:
			aim_time *= 0.85
		else:
			burst += 2
			hold_position = false
		fire_pause *= 0.8
		accuracy = minf(accuracy + 0.05, 0.9)
	_spawn_henchmen()
	if blackout:
		_blackout()
	if hides:
		_vanish()
	elif relocates:
		_relocate(true)
	else:
		Audio.play_at("roar", _head(), 6.0)
		_hud("show_message", tr("%s в ярости!") % tr(boss_name), tr("Фаза %d из %d · подмога!") % [phase, phases])
	_update_bar()


func _enter_final_phase() -> void:
	model.set_weapon(final_weapon)
	damage = roundi(final_damage * Game.enemy_damage_multiplier())
	burst = maxi(final_burst, 1)
	hold_position = relocates
	if final_weapon == "sniper":
		shot_sound = "sniper"
		aim_time = maxf(aim_time * 0.8, 0.7)
		fire_pause = 1.2
		accuracy = minf(accuracy + 0.08, 0.9)
	elif final_weapon == "shotgun":
		_charging = true
		shot_sound = "shotgun"
		move_speed *= 1.7
		aim_time = 0.5
		fire_pause = 1.1
		sight_range = 45.0
	elif final_weapon in ["knife", "bat"]:
		# Последняя фаза — рукопашная: бежит прямо на игрока с ножом.
		kind = Kind.RUSHER
		melee_damage = roundi(final_damage * Game.enemy_damage_multiplier())
		melee_windup = 0.35
		move_speed *= 1.9
		_show_laser(false)
	elif final_weapon == "rifle":
		shot_sound = "rifle"
		burst_interval = 0.09
		aim_time = 0.65
		fire_pause = 1.3
		move_speed *= 1.2
	else:
		shot_sound = "deagle"
		aim_time = 0.6
		fire_pause = 1.0
		accuracy = minf(accuracy + 0.15, 0.9)
		move_speed *= 1.3


func _die(mode: BlockyCharacter.Death, direction: Vector3, force: float) -> void:
	if _dead:
		return
	defeated = true
	hidden = false
	var bonus := roundi(reward * Game.reward_multiplier())
	super._die(mode, direction, force)
	Game.add_money(bonus)
	_hud("hide_boss")
	_hud("show_message", tr("%s повержен!") % tr(boss_name), tr("Премия: $%d") % bonus)
	cleared.emit(self)
	get_tree().call_group("level", "on_boss_defeated", self)


# --- Гранаты (Начальник тюрьмы) и затемнение (Крупье) ----------------------------

func _grenade_logic(delta: float) -> void:
	_grenade_timer -= delta
	if _grenade_timer > 0.0 or not _sees_player or not _player_alive():
		return
	var distance := _distance_to_player()
	if distance < 5.0 or distance > 24.0:
		return
	_grenade_timer = grenade_interval * randf_range(0.8, 1.2)
	var from := global_position + Vector3.UP * 2.2 * model.scale.y
	var target := _player.global_position + _player.velocity * 0.6
	Grenade.throw_at(get_parent(), from, target, 24.0, 2.4, 30)
	model.recoil(0.6)


## Свет на уровне гаснет на пару секунд — в темноте приходит подмога.
func _blackout() -> void:
	var lights := get_tree().current_scene.find_children("*", "OmniLight3D", true, false)
	for light in lights:
		light.visible = false
	Audio.play_at("door", _head(), 2.0, 0.6)
	get_tree().create_timer(2.6, false).timeout.connect(func() -> void:
		for light in lights:
			if is_instance_valid(light):
				light.visible = true)


# --- Позиции Снайпера --------------------------------------------------------------

## Дымовая шашка — и снайпер уже на другой вышке. Сразу снова целится.
func _relocate(new_phase: bool) -> void:
	var point := _pick_nest()
	if point == null:
		if new_phase:
			_hud("show_message", tr("%s в ярости!") % tr(boss_name), tr("Фаза %d из %d") % [phase, phases])
		return
	Fx.smoke_cloud(global_position + Vector3.UP)
	Audio.play_at("smoke", global_position + Vector3.UP)
	global_position = point.global_position
	rotation.y = point.global_rotation.y
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	_nest = point
	_phase = Phase.PAUSE
	_timer = 1.2
	_show_laser(false)
	var where := tr(String(point.name))
	if new_phase:
		_hud("show_message", tr("%s сменил позицию!") % tr(boss_name), tr("Фаза %d из %d · он теперь: %s") % [phase, phases, where])
	else:
		_hud("show_message", tr("%s перебежал") % tr(boss_name), tr("Ищите блик прицела: %s") % where)
	_hud("set_objective", tr("Убейте: %s (%s)") % [tr(boss_name), where])


## Другая позиция, подальше от игрока (но не дальше, чем он видит).
func _pick_nest() -> Node3D:
	var holder := get_node_or_null(hide_points)
	if holder == null:
		return null
	var options: Array[Node3D] = []
	for child in holder.get_children():
		var point := child as Node3D
		if point == null or point == _nest or point.global_position.distance_to(global_position) < 6.0:
			continue
		if _player_alive():
			var distance := point.global_position.distance_to(_player.global_position)
			if distance < 14.0 or distance > sight_range - 5.0:
				continue
		options.append(point)
	return options.pick_random() if not options.is_empty() else null


# --- Прятки (Худой) -------------------------------------------------------------

func _vanish() -> void:
	var point := _pick_hide_point()
	Fx.smoke_cloud(global_position + Vector3.UP)
	Audio.play_at("smoke", global_position + Vector3.UP)
	Audio.play_at("laugh", _head(), 6.0)
	if point == null:
		_hud("show_message", tr("%s звереет!") % tr(boss_name), tr("Фаза %d из %d") % [phase, phases])
		return
	_hud("show_message", tr("%s сбежал!") % tr(boss_name), tr("Ищите его по смеху — фаза %d из %d") % [phase, phases])
	_hud("set_objective", tr("Найдите: %s") % tr(boss_name))
	global_position = point.global_position
	rotation.y = point.global_rotation.y
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	_hide_name = String(point.name)
	hidden = true
	_awake = false
	_sees_player = false
	_transition = 0.0
	_laugh_timer = 3.0
	_hint_timer = 14.0
	_hidden_time = 0.0


func _hide_logic(delta: float) -> void:
	_laugh_timer -= delta
	_hint_timer -= delta
	_hidden_time += delta
	if _laugh_timer <= 0.0:
		_laugh_timer = randf_range(6.0, 8.0)
		Audio.play_at("laugh", _head(), 8.0)
		if _hint_timer <= 0.0:
			_hud("set_objective", tr("Смех доносится: %s") % tr(_hide_name))
	if _sees_player and _distance_to_player() < 16.0:
		_wake()
	elif _hidden_time > 50.0:
		# Надоело ждать — выходит на охоту сам.
		_wake()


## Укрытие подальше от игрока и вне его поля зрения.
func _pick_hide_point() -> Node3D:
	var holder := get_node_or_null(hide_points)
	if holder == null:
		return null
	var good: Array[Node3D] = []
	var fallback: Node3D = null
	var fallback_distance := -1.0
	for child in holder.get_children():
		var point := child as Node3D
		if point == null or point.global_position.distance_to(global_position) < 8.0:
			continue
		var distance := point.global_position.distance_to(_player.global_position) if _player_alive() else 100.0
		if distance > fallback_distance:
			fallback = point
			fallback_distance = distance
		if distance > 15.0 and not _visible_from_player(point.global_position):
			good.append(point)
	return good.pick_random() if not good.is_empty() else fallback


func _visible_from_player(point: Vector3) -> bool:
	if not _player_alive():
		return false
	var query := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 1.5, point + Vector3.UP * 1.5, WORLD_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# --- Прислужники ----------------------------------------------------------------

func _spawn_henchmen() -> void:
	var holder := get_node_or_null(henchman_points)
	if holder == null or not _player_alive():
		return
	# Приходят из ближайших к игроку точек, но не прямо у него под носом.
	var points: Array[Node3D] = []
	for child in holder.get_children():
		if child is Node3D and (child as Node3D).global_position.distance_to(_player.global_position) > 9.0:
			points.append(child)
	if points.is_empty():
		return
	points.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(_player.global_position) < b.global_position.distance_squared_to(_player.global_position))
	var count := henchmen_per_phase + (phase - 2) * 2 + Game.current_tier
	for i in count:
		var scene := gunner_scene
		if phase >= phases and i == 0 and heavy_scene:
			scene = heavy_scene
		elif i % 3 == 2 and rusher_scene:
			scene = rusher_scene
		if scene == null:
			continue
		var point := points[i % mini(points.size(), 4)]
		get_tree().create_timer(0.4 + 0.45 * i, false).timeout.connect(_spawn_henchman.bind(scene, point))


func _spawn_henchman(scene: PackedScene, point: Node3D) -> void:
	if not is_inside_tree() or not is_instance_valid(point):
		return
	var henchman := scene.instantiate() as Enemy
	henchman.alerted = true
	henchman.hold_position = false
	# С прислужников босса аптечки падают чаще.
	henchman.drop_health_chance = 0.5
	henchman.health_drop_amount = 25
	henchman.drop_ammo_chance = 0.4
	get_parent().add_child(henchman)
	var jitter := Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8))
	henchman.global_position = point.global_position + jitter
	henchman.rotation.y = point.global_rotation.y
	henchman.reset_physics_interpolation()


# --- Бой ------------------------------------------------------------------------

## В последней фазе Толстяк идёт прямо на игрока.
func _strafe(delta: float) -> void:
	if _charging and _player_alive():
		var to_player := _flat_to(_player.global_position)
		if to_player.length() > 3.5:
			var direction := (to_player.normalized() + _separation()).normalized()
			if _ground_ahead(direction):
				_set_horizontal_velocity(direction * move_speed, delta)
				return
		_slow_down(delta)
		return
	super._strafe(delta)


## Дробовик: заряд дроби — в упор очень больно, издалека почти безопасно.
func _fire() -> void:
	if not _charging:
		super._fire()
		return
	var muzzle := model.get_muzzle_position()
	var target := _player.global_position + Vector3.UP * 1.2
	var distance := muzzle.distance_to(target)
	var space := get_world_3d().direct_space_state
	var hits := 0
	for i in 8:
		var direction := (target - muzzle).normalized().rotated(Vector3.UP, randf_range(-0.1, 0.1))
		direction = (direction + Vector3.UP * randf_range(-0.06, 0.06)).normalized()
		var end := muzzle + direction * minf(distance + 3.0, 40.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, end, WORLD_MASK, [get_rid()]))
		if hit:
			end = hit.position
			if hit.collider.has_method("take_hit"):
				hit.collider.take_hit(float(damage) / 8.0, end, direction)
		elif not _player.is_dodging() and randf() < accuracy * clampf(1.3 - distance / 12.0, 0.08, 1.0):
			hits += 1
		Fx.tracer(muzzle, end, Color(1.0, 0.6, 0.3))
	if hits > 0:
		_player.take_damage(maxi(roundi(damage * hits / 8.0), 1), global_position)
	Fx.muzzle_flash(muzzle, (target - muzzle).normalized())
	Audio.play_at(shot_sound, muzzle, 0.0)
	model.recoil(0.5)


func _update_bar() -> void:
	if _announced and not _dead:
		_hud("update_boss", boss_name, get_phase_fraction(), phase, phases, "прячется" if hidden else "")


func _head() -> Vector3:
	return global_position + Vector3.UP * 1.8 * model.scale.y


func _hud(method: String, a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null, e: Variant = null) -> void:
	var args := [a, b, c, d, e].filter(func(value: Variant) -> bool: return value != null)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method(method):
		hud.callv(method, args)
