class_name ChaseLevel
extends TravelLevel
## Погоня по шоссе между городами. Герой стоит в кабриолете (за рулём — напарник),
## джойстиком рулит влево-вправо (относительно того, куда смотрит камера) и газует или тормозит,
## а стреляет в любую сторону. Сзади догоняют мотоциклы и машины банды (три волны),
## навстречу по полосам — попутные машины и бензовозы (врезаться больно, бензовоз взрывается).
## На дороге лежат ящики с аптечками и патронами — подберите, проехав по ним.
## В конце прилетает вертолёт банды, а после него — город назначения.

const WAVES := [[["bike", 3]], [["car", 2], ["bike", 2]], [["car", 3], ["bike", 2]]]
const MIN_SPEED := 22.0
const MAX_SPEED := 38.0

var wave := 0

var _car: Node3D
var _cruise := 30.0
var _steer := 0.0
var _wave_timer := 4.0
var _wave_active := false
var _traffic_timer := 2.0
var _pickup_timer := 8.0
var _boss: AttackHelicopter
var _boss_started := false
var _arriving := false
var _crash_cooldown := 0.0
var _driver: BlockyCharacter


func _ready() -> void:
	speed = 30.0
	road_half = 9.0
	side_offset = 8.0
	track_texture = "res://textures/asphalt.png"
	track_tint = Color(0.55, 0.55, 0.58)
	sound_name = "engine"
	front_z = -3.0
	tunnel_warning = ["ТОННЕЛЬ!", "Держитесь своей полосы"]
	title_prefix = "Шоссе"
	objective = "Оторвитесь от погони банды"
	super._ready()
	_car = $PlayerCar
	_driver = get_node_or_null("PlayerCar/Driver") as BlockyCharacter
	_boss = get_node_or_null("ChaseHeli") as AttackHelicopter
	player.mount_to($PlayerCar/Seat, 4.2, 1.9, -0.2)
	hud.set_mounted(true, true)


## Разметка полос едет вместе с пейзажем.
func _spawn_row(z: float) -> void:
	super._spawn_row(z)
	for x in [-4.5, 0.0, 4.5]:
		_props.append({"type": "dash", "pos": Vector3(x, 0, z), "yaw": 0.0, "scale": 1.0})


## Сколько машин банды сейчас на дороге.
func get_pursuer_count() -> int:
	return get_tree().get_nodes_in_group("chase_cars").filter(
			func(car: Variant) -> bool: return car.hostile and not car.wrecked).size()


## Машина героя: где по ширине дороги.
func get_car_x() -> float:
	return _car.position.x


## Выпустить волну погони (тесты могут вызвать сразу).
func spawn_wave(index: int) -> void:
	wave = index + 1
	_wave_active = true
	var count := 0
	for group in WAVES[mini(index, WAVES.size() - 1)]:
		for i in int(group[1]) + (Game.current_tier if group[0] == "bike" else 0):
			var kind := ChaseCar.Kind.CAR if group[0] == "car" else ChaseCar.Kind.BIKE
			var car := ChaseCar.create(kind, self)
			add_child(car)
			var lane := randf_range(-road_half + 2.0, road_half - 2.0)
			car.position = Vector3(lane, 0, 70.0 + count * 12.0)
			count += 1
	hud.show_message("Погоня! Волна %d из %d" % [wave, WAVES.size()], "Мотоциклы и машины банды сзади")
	hud.set_objective("Погоня: волна %d из %d" % [wave, WAVES.size()])
	Audio.play_music("music_combat")


## Попутная машина или бензовоз впереди на полосе.
func spawn_traffic(kind := ChaseCar.Kind.TRAFFIC, x := INF, z := -260.0) -> ChaseCar:
	var car := ChaseCar.create(kind, self)
	add_child(car)
	if x == INF:
		x = [-6.75, -2.25, 2.25, 6.75].pick_random()
	car.position = Vector3(x, 0, z)
	return car


func start_boss() -> void:
	if _boss_started or not is_instance_valid(_boss):
		return
	_boss_started = true
	_boss.global_position = player.global_position + Vector3(20, 25, 60)
	_boss.activate()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_drive(delta)
	_scroll_loose_things(delta)
	_spawn_logic(delta)
	_crash_logic(delta)


func _drive(delta: float) -> void:
	if not player.is_alive():
		_cruise = move_toward(_cruise, 0.0, 10.0 * delta)
		speed = _cruise
		return
	# Джойстик относительно камеры: «влево на экране» — всегда влево на экране.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := player.camera_rig.get_yaw_basis() * Vector3(input.x, 0, input.y)
	_steer = move_toward(_steer, clampf(wish.x, -1.0, 1.0), 4.0 * delta)
	var limit := road_half - 1.2
	_car.position.x = clampf(_car.position.x + _steer * 9.0 * delta, -limit, limit)
	_cruise = clampf(_cruise - wish.z * 10.0 * delta, MIN_SPEED, MAX_SPEED)
	if absf(wish.z) < 0.1:
		_cruise = move_toward(_cruise, 30.0, 3.0 * delta)
	speed = _cruise
	_car.rotation.y = lerp_angle(_car.rotation.y, -_steer * 0.12, 1.0 - exp(-6.0 * delta))
	_car.rotation.z = lerp_angle(_car.rotation.z, _steer * 0.04, 1.0 - exp(-6.0 * delta))
	if _crash_cooldown > 0.0:
		_crash_cooldown -= delta
	if _driver:
		_driver.animate(delta, 0.0, false, 0.0)


## Обломки тел, гранаты и ящики на дороге уезжают назад вместе с асфальтом.
func _scroll_loose_things(delta: float) -> void:
	var step := Vector3(0, 0, speed * delta)
	for body in BlockyCharacter.get_debris():
		var piece := body as Node3D
		if piece and piece.global_position.y < 3.0:
			piece.global_position += step
	for node in get_tree().get_nodes_in_group("grenades"):
		(node as Node3D).global_position += step
	for node in get_tree().get_nodes_in_group("road_items"):
		var item := node as Node3D
		item.global_position += step
		if item.global_position.z > 60.0:
			item.queue_free()


func _spawn_logic(delta: float) -> void:
	_traffic_timer -= delta
	if _traffic_timer <= 0.0:
		_traffic_timer = randf_range(2.2, 4.0)
		spawn_traffic(ChaseCar.Kind.TANKER if randf() < 0.18 else ChaseCar.Kind.TRAFFIC)
	_pickup_timer -= delta
	if _pickup_timer <= 0.0:
		_pickup_timer = randf_range(9.0, 14.0)
		_spawn_pickup()
	if _arriving:
		return
	if _wave_active:
		if get_pursuer_count() == 0:
			_wave_active = false
			_wave_timer = 4.0
			Game.slow_motion(0.8, 0.3)
			hud.show_message("Оторвались!", "Но это ещё не всё…" if wave < WAVES.size() else "Сверху вертолёт!")
			Audio.play_music("music_explore")
		return
	if _boss_started:
		return
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		if wave < WAVES.size():
			spawn_wave(wave)
		else:
			start_boss()


func _spawn_pickup() -> void:
	var box := Pickup.new()
	var roll := randf()
	box.kind = Pickup.Kind.HEALTH if roll < 0.45 else (Pickup.Kind.AMMO if roll < 0.8 else Pickup.Kind.GRENADE)
	box.add_to_group("road_items")
	add_child(box)
	box.global_position = Vector3([-6.75, -2.25, 2.25, 6.75].pick_random(), 0.2, -220.0)


## Машина героя врезается в попутную: больно, а попутную отбрасывает.
func _crash_logic(_delta: float) -> void:
	if _crash_cooldown > 0.0 or not player.is_alive():
		return
	for node in get_tree().get_nodes_in_group("chase_cars"):
		var car := node as ChaseCar
		if car == null or car.wrecked or car.hostile:
			continue
		var gap := car.global_position - _car.global_position
		if absf(gap.x) < 2.1 and absf(gap.z) < 4.6:
			_crash_cooldown = 1.0
			player.take_damage(18, car.global_position)
			player.camera_rig.shake(0.8)
			Audio.play_at("explosion", car.global_position, 0.0, 1.6)
			Fx.sparks(car.global_position + Vector3.UP, Vector3.UP)
			car.crash(signf(gap.x) * 2.0 if absf(gap.x) > 0.05 else 2.0)
			hud.show_toast("Авария! Смотрите на дорогу")
			return


## Вертолёт банды сбит — впереди город.
func on_vehicle_destroyed(_vehicle: Node) -> void:
	_arriving = true
	Audio.play_music("music_explore")
	hud.show_message("Город на горизонте!", Game.city_name(Game.travel_to))
	get_tree().create_timer(3.0, false).timeout.connect(complete)
