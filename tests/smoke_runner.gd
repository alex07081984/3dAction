extends Node
## Автопроверка игры. Запускается через tests/smoke_test.gd (см. там).
## Проверяет меню, все уровни (в том числе что маршрут проходим), стрельбу, хедшоты,
## разрыв тела дробовиком, отрыв рук и ног, модели с суставами, бочки и баллоны,
## боссов (фазы, подмога, прятки), врагов, подбор предметов, сенсорное управление,
## места с волнами, выход с уровня, паузу и смерть, а также экономику:
## деньги, сложность повторов, освобождение города, базу, входы на уровни,
## покупку жилья, улучшения и их бонусы.

var _failed := 0
var _passed := 0
var _game: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _run() -> void:
	await get_tree().process_frame
	_game = get_node("/root/Game")
	_game.save_enabled = false
	_game.reset_progress()
	_game.settings.aim_assist = true
	_game.settings.auto_fire = false

	await _test_menu()
	for index in _game.LEVELS.size():
		await _test_level_structure(index)
	await _test_combat()
	await _test_models()
	await _test_dismemberment()
	await _test_explosives()
	await _test_enemies_fight_back()
	await _test_touch()
	await _test_wave_zone_and_exit()
	await _test_fat_boss()
	await _test_thin_boss()
	await _test_pause_and_death()
	await _test_difficulty_and_money()
	await _test_town_liberation()
	await _test_hub_and_entrances()
	await _test_property_and_perks()

	print("\n=== Пройдено: %d, провалено: %d ===" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Меню и уровни ------------------------------------------------------------

func _test_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(6)
	_check(get_tree().current_scene != null and get_tree().current_scene.name == "MainMenu", "главное меню загружается")
	var list := get_tree().current_scene.get_node("%LevelList")
	_check(list.get_child_count() == 5, "в меню 5 уровней")
	_check(not (list.get_child(0) as Button).disabled and (list.get_child(1) as Button).disabled,
			"открыт только первый уровень")


func _test_level_structure(index: int) -> void:
	_game.start_level(index)
	await _frames(8)
	var level := get_tree().current_scene as Level
	var title: String = _game.LEVELS[index].title
	_check(level != null and level.level_index == index, "%s: уровень загружается" % title)
	if level == null:
		return
	var enemies := get_tree().get_nodes_in_group("enemies").size()
	_check(enemies >= 8, "%s: врагов на постах %d" % [title, enemies])
	var zones := level.find_children("*", "WaveZone")
	_check(zones.size() >= 2 and zones.size() <= 3, "%s: мест с волнами %d" % [title, zones.size()])
	if index == 3:
		_check(level.get_node_or_null("Enemies/ThinBoss") is Boss, "%s: хозяин особняка — Худой" % title)
	elif index != _game.TOWN_INDEX:
		_check(level.has_node("Exit"), "%s: есть выход" % title)
	if index == 2:
		_check(level.get_node_or_null("Enemies/FatBoss") is Boss, "%s: на крыше ждёт Толстяк" % title)
	var explosives := level.get_node_or_null("Explosives")
	_check(explosives != null and explosives.get_child_count() >= 8,
			"%s: бочки и баллоны (%d)" % [title, explosives.get_child_count() if explosives else 0])
	var expected_weapons: int = [1, 2, 3, 3, 3][index]
	_check(level.player.weapons.size() == expected_weapons, "%s: стартовое оружие (%d)" % [title, level.player.weapons.size()])
	var problems := _route_problems(level)
	_check(problems.is_empty(), "%s: маршрут от старта до выхода проходим %s" % [title, problems])


## Проверяет маршрут из узлов Route: между точками нет стен, под ногами есть пол.
func _route_problems(level: Node3D) -> Array:
	var problems := []
	var points := level.get_node("Route").get_children()
	var space := level.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.0
	for i in points.size() - 1:
		var a: Vector3 = points[i].global_position
		var b: Vector3 = points[i + 1].global_position
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = capsule
		params.collision_mask = 1
		params.transform = Transform3D(Basis(), a + Vector3.UP * 1.1)
		params.motion = b - a
		var motion := space.cast_motion(params)
		if motion[0] < 1.0:
			problems.append("стена %d→%d" % [i, i + 1])
		var steps := maxi(int(a.distance_to(b) / 0.5), 1)
		for s in steps + 1:
			var p := a.lerp(b, float(s) / steps)
			var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.6, p + Vector3.DOWN * 2.0, 1)
			if space.intersect_ray(ray).is_empty():
				problems.append("нет пола у %s" % p.snapped(Vector3.ONE * 0.1))
				break
	return problems


# --- Стрельба -----------------------------------------------------------------

func _test_combat() -> void:
	var level := await _fresh_level(0)
	var player := level.player
	var hud := level.hud
	_check(hud.get_node("%AmmoLabel").text.begins_with("12 /"), "HUD показывает патроны пистолета")

	# Пистолет: попадание в корпус.
	var enemy := _spawn_enemy(level, "gunner", player.global_position + Vector3(0, 0, -7))
	await _frames(3)
	await _aim_at(player, enemy.get_aim_point(false))
	await _fire(player)
	_check(enemy.health < enemy.max_health, "пистолет ранит врага (%d/%d)" % [enemy.health, enemy.max_health])
	var state := player.get_ammo(player.current_weapon)
	_check(state.mag < 12, "патроны тратятся (%d)" % state.mag)

	# Хедшот отрывает голову.
	var victim := _spawn_enemy(level, "gunner", player.global_position + Vector3(1.5, 0, -7))
	await _frames(3)
	for i in 4:
		if not is_instance_valid(victim):
			break
		await _aim_at(player, victim.get_aim_point(true))
		_check_silent(player.aim_is_head)
		await _fire(player)
		await _frames(10)
	_check(not is_instance_valid(victim), "хедшот из пистолета убивает")
	_check(_debris_with_node(level, "Neck") > 0, "при хедшоте голова отлетает отдельно")

	# Перезарядка.
	var pistol := player.current_weapon
	for i in 20:
		if player.is_reloading():
			break
		await _fire(player)
	_check(player.is_reloading(), "пустой магазин запускает перезарядку")
	await _seconds(pistol.reload_time + 0.2)
	_check(player.get_ammo(pistol).mag == pistol.magazine, "после перезарядки магазин полный")

	# Подбор дробовика и смена оружия.
	var shotgun_pickup := Pickup.new()
	shotgun_pickup.kind = Pickup.Kind.WEAPON
	shotgun_pickup.weapon = load("res://weapons/shotgun.tres")
	level.add_child(shotgun_pickup)
	shotgun_pickup.global_position = player.global_position
	await _frames(10)
	_check(player.current_weapon.id == "shotgun", "подобранный дробовик сразу в руках")
	_check(hud.get_node("%SwitchButton").text == "Дробь", "кнопка смены оружия показывает дробовик")
	player.switch_weapon()
	await _frames(2)
	_check(player.current_weapon.id == "pistol", "смена оружия работает")
	player.switch_weapon()
	await _seconds(0.4)

	# Дробовик в упор разрывает тело на куски.
	var before := _debris_count(level)
	var target := _spawn_enemy(level, "gunner", player.global_position + Vector3(0, 0, -2.6))
	await _frames(3)
	await _aim_at(player, target.get_aim_point(false))
	await _fire(player)
	await _frames(3)
	_check(not is_instance_valid(target), "дробовик в упор убивает")
	_check(_debris_count(level) - before >= 10, "тело разлетается на куски (%d обломков)" % (_debris_count(level) - before))

	# Аптечка.
	player.take_damage(40, player.global_position + Vector3.FORWARD)
	await _seconds(0.3)
	var hurt := player.health
	var medkit := Pickup.new()
	medkit.kind = Pickup.Kind.HEALTH
	level.add_child(medkit)
	medkit.global_position = player.global_position
	await _frames(10)
	_check(player.health > hurt, "аптечка лечит (%d → %d)" % [hurt, player.health])


func _test_enemies_fight_back() -> void:
	var level := await _fresh_level(0)
	var player := level.player
	var gunner := _spawn_enemy(level, "gunner", player.global_position + Vector3(0, 0, -6))
	gunner.accuracy = 1.0
	gunner.alerted = true
	var start := player.health
	await _seconds(3.0)
	_check(player.health < start, "стрелок попадает в игрока (%d → %d)" % [start, player.health])
	gunner.apply_shot(1000.0, false, gunner.global_position, Vector3.FORWARD, load("res://weapons/pistol.tres"))
	await _seconds(0.6)

	var rusher := _spawn_enemy(level, "rusher", player.global_position + Vector3(0, 0, -5))
	rusher.alerted = true
	start = player.health
	await _seconds(2.5)
	_check(player.health < start, "псих с битой добегает и бьёт (%d → %d)" % [start, player.health])


# --- Сенсорное управление -----------------------------------------------------

func _test_touch() -> void:
	var level := await _fresh_level(0)
	var player := level.player
	var hud := level.hud
	var joystick := hud.get_node("TouchControls/Joystick") as Control
	var at := joystick.get_global_rect().get_center()
	var start := player.global_position
	_touch(0, at, true)
	_drag(0, at + Vector2(0, -100), Vector2(0, -100))
	await _frames(30)
	_touch(0, at + Vector2(0, -100), false)
	_check(start.distance_to(player.global_position) > 1.5, "джойстик двигает игрока")

	var fire := hud.get_node("TouchControls/FireButton") as Control
	var center := fire.get_global_rect().get_center()
	var mag: int = player.get_ammo(player.current_weapon).mag
	var yaw := player.camera_rig.get_yaw()
	_touch(1, center, true)
	await _frames(3)
	_drag(1, center + Vector2(80, 0), Vector2(80, 0))
	await _frames(3)
	_touch(1, center + Vector2(80, 0), false)
	_check(player.get_ammo(player.current_weapon).mag < mag, "кнопка огня стреляет")
	_check(not is_equal_approx(yaw, player.camera_rig.get_yaw()), "свайп с кнопки огня ведёт прицел")

	var free_yaw := player.camera_rig.get_yaw()
	_touch(2, Vector2(800, 150), true)
	_drag(2, Vector2(900, 150), Vector2(100, 0))
	_touch(2, Vector2(900, 150), false)
	await _frames(2)
	_check(not is_equal_approx(free_yaw, player.camera_rig.get_yaw()), "свайп по экрану крутит камеру")


# --- Волны и выход -------------------------------------------------------------

func _test_wave_zone_and_exit() -> void:
	var level := await _fresh_level(0, false)
	var player := level.player
	var zone := level.get_node("ZoneSettler") as WaveZone
	var barrier := zone.get_node("Barriers").get_child(0) as CSGShape3D
	_check(not barrier.visible and not barrier.use_collision, "проходы открыты до начала волн")
	_teleport(player, zone.global_position)
	await _frames(5)
	_check(zone.active and barrier.visible and barrier.use_collision, "вход в зону закрывает проходы")
	var killed := await _clear_zone(zone)
	_check(zone.done and not barrier.visible, "после всех волн проходы открываются (убито %d)" % killed)
	_check(level.kills >= killed, "уровень считает убийства (%d)" % level.kills)

	_teleport(player, level.get_node("Exit").global_position)
	await _frames(5)
	_check(level.hud.get_node("%LevelComplete").visible, "выход завершает уровень")
	_check(_game.unlocked_levels >= 2, "открывается следующий уровень")
	_check(_game.records.has(0), "рекорд уровня сохранён")
	_check(_game.money >= 150, "за прохождение начислены деньги ($%d)" % _game.money)
	_check(_game.tier_of(0) == 1, "следующий заход на уровень сложнее")


# --- Модели, раны, взрывы ---------------------------------------------------------

func _test_models() -> void:
	var level := await _fresh_level(0)
	var player := level.player
	var gunner := _spawn_enemy(level, "gunner", player.global_position + Vector3(0, 0, -6))
	gunner.sight_range = 0.5  # пусть стоит спокойно, руки вниз
	await _frames(3)
	var model := gunner.model
	_check(model.has_limb("arm_l") and model.has_limb("leg_r") and model.find_child("Knee", true, false) != null
			and model.find_child("Elbow", true, false) != null, "у человечков руки и ноги с локтями и коленями")
	var eye := player.global_position + Vector3.UP * 1.6
	_check(model.get_hit_part(eye, model.get_head_center() - eye) == "head", "луч в лицо попадает в голову")
	_check(model.get_hit_part(eye, model.get_chest_center() - eye) == "torso", "луч в грудь попадает в корпус")
	var knee := (model.find_child("HipL", true, false) as Node3D).get_node("Knee") as Node3D
	_check(model.get_hit_part(eye, knee.global_position - eye) == "leg_l", "луч в колено попадает в ногу")
	var fat := (load("res://scenes/enemies/fat_boss.tscn") as PackedScene).instantiate() as Boss
	var thin := (load("res://scenes/enemies/thin_boss.tscn") as PackedScene).instantiate() as Boss
	level.add_child(fat)
	level.add_child(thin)
	fat.global_position = player.global_position + Vector3(-30, 0, 0)
	thin.global_position = player.global_position + Vector3(-34, 0, 0)
	await _frames(2)
	var fat_torso := fat.model.find_child("Torso", true, false).get_child(0) as MeshInstance3D
	var thin_torso := thin.model.find_child("Torso", true, false).get_child(0) as MeshInstance3D
	_check(fat_torso.get_aabb().size.x > thin_torso.get_aabb().size.x * 1.5, "Толстяк толстый, Худой худой")
	fat.queue_free()
	thin.queue_free()


func _test_dismemberment() -> void:
	var level := await _fresh_level(0)
	var player := level.player
	player.max_health = 100000
	player.health = 100000
	player.give_weapon(load("res://weapons/shotgun.tres"), false)
	await _seconds(0.4)
	var kills := level.kills

	# Заряд дроби в ногу: нога отлетает, враг прыгает на одной, потом падает.
	var hopper: Enemy = null
	var attempts := 0
	for attempt in 8:
		attempts += 1
		var enemy := _spawn_enemy(level, "gunner", player.global_position + Vector3(0.3, 0, -4.5))
		await _frames(3)
		var knee := (enemy.model.find_child("HipL", true, false) as Node3D).get_node("Knee") as Node3D
		await _aim_at(player, knee.global_position)
		await _fire(player)
		if is_instance_valid(enemy) and enemy.is_wounded():
			hopper = enemy
			break
		if is_instance_valid(enemy):
			enemy.queue_free()
		await _frames(2)
	_check(hopper != null and hopper.model.wound.begins_with("leg"), "дробь в ногу отрывает ногу (выстрелов: %d)" % attempts)
	if hopper:
		_check(_debris_with_node(level, "HipL") + _debris_with_node(level, "HipR") > 0, "оторванная нога лежит отдельно")
		var ground := hopper.global_position.y
		var highest := ground
		for i in 90:
			await get_tree().physics_frame
			if is_instance_valid(hopper):
				highest = maxf(highest, hopper.global_position.y)
		_check(highest > ground + 0.2, "без ноги враг прыгает на одной (%.2f м)" % (highest - ground))
		await _seconds(6.5)
		_check(not is_instance_valid(hopper), "раненый истекает кровью и падает")
		_check(level.kills > kills, "смерть от раны засчитана")

	# Дробь в руку (урон по частям тела как от выстрела сбоку): рука с пистолетом отлетает.
	var shotgun: WeaponData = load("res://weapons/shotgun.tres")
	var clutcher := _spawn_enemy(level, "gunner", player.global_position + Vector3(0, 0, -6.5))
	clutcher.sight_range = 0.5
	await _frames(3)
	var arm_hit := clutcher.global_position + Vector3.UP * 1.2
	clutcher.apply_shot(36.0, false, arm_hit, Vector3.FORWARD, shotgun, {"arm_r": 24.0, "torso": 12.0})
	if not clutcher.model.wound.begins_with("arm"):
		clutcher = null
	_check(clutcher != null, "дробь в руку отрывает руку")
	if clutcher:
		_check(not clutcher.model.has_limb(clutcher.model.wound), "руки на месте нет")
		if clutcher.model.wound == "arm_r":
			_check(clutcher.model.muzzle == null, "оружие улетело вместе с рукой")
		await _seconds(1.0)
		_check(is_instance_valid(clutcher) and clutcher.is_alive(), "без руки враг ещё жив и держится за плечо")
		await _aim_at(player, clutcher.get_aim_point(false))
		await _fire(player)
		await _frames(3)
		_check(not is_instance_valid(clutcher), "раненого можно добить")


func _spawn_prop(level: Node, scene_name: String, at: Vector3) -> Explosive:
	var prop := (load("res://scenes/props/%s.tscn" % scene_name) as PackedScene).instantiate() as Explosive
	level.add_child(prop)
	prop.global_position = at
	return prop


func _test_explosives() -> void:
	var level := await _fresh_level(0)
	for node in get_tree().get_nodes_in_group("explosives"):
		node.queue_free()
	var player := level.player
	player.max_health = 1000
	player.health = 1000
	_teleport(player, Vector3(-1, 0, -31))
	var barrel := _spawn_prop(level, "explosive_barrel", Vector3(-0.5, 0, -36))
	var neighbour := _spawn_prop(level, "explosive_barrel", Vector3(1.5, 0, -37))
	var victims := []
	for at in [Vector3(-1.5, 0, -37.2), Vector3(0.8, 0, -35.2)]:
		var enemy := _spawn_enemy(level, "gunner", at)
		enemy.sight_range = 0.5
		victims.append(enemy)
	await _frames(5)
	var kills := level.kills
	await _aim_at(player, barrel.global_position + Vector3.UP * 0.5)
	await _fire(player)
	_check(is_instance_valid(barrel) and barrel.get("_burning"), "от пули бочка загорается")
	await _seconds(2.6)
	_check(not is_instance_valid(barrel), "горящая бочка взрывается")
	_check(victims.all(func(e: Variant) -> bool: return not is_instance_valid(e)), "взрыв убивает врагов рядом")
	_check(level.kills >= kills + 2, "убийства взрывом засчитаны")
	_check(not is_instance_valid(neighbour), "соседняя бочка взрывается следом")
	_check(player.health < 1000, "взрыв ранит и игрока (%d)" % player.health)

	var cylinder := _spawn_prop(level, "gas_cylinder", Vector3(-3, 0, -36))
	await _frames(5)
	await _aim_at(player, cylinder.global_position + Vector3.UP * 0.6)
	await _fire(player)
	_check(is_instance_valid(cylinder) and cylinder.get("_leaking"), "пробитый баллон шипит")
	var start := cylinder.global_position
	await _seconds(0.75)
	_check(is_instance_valid(cylinder) and not cylinder.freeze and cylinder.global_position.distance_to(start) > 0.3,
			"баллон срывается с места и летит")
	await _seconds(2.5)
	_check(not is_instance_valid(cylinder), "улетевший баллон взрывается")


# --- Боссы ---------------------------------------------------------------------

func _boss_henchmen() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(
			func(e: Node) -> bool: return not e is Boss and e.health_drop_amount == 25)


func _test_fat_boss() -> void:
	var level := await _fresh_level(2, false)
	var player := level.player
	player.max_health = 100000
	player.health = 100000
	var hud := level.hud
	var exit := level.get_node("Exit")
	_teleport(player, exit.global_position)
	await _frames(5)
	_check(not hud.get_node("%LevelComplete").visible, "эвакуация закрыта, пока жив Толстяк")
	var boss := level.get_node("Enemies/FatBoss") as Boss
	_teleport(player, Vector3(-10, 25, -214))
	await _seconds(1.0)
	_check(hud.get_node("%BossBar").visible, "полоса здоровья босса на экране")
	var deagle: WeaponData = load("res://weapons/deagle.tres")
	boss.apply_shot(boss.health + 1.0, false, boss.global_position + Vector3.UP, Vector3.FORWARD, deagle)
	_check(boss.is_alive() and boss.phase == 2, "Толстяк не умирает, а переходит во 2-ю фазу")
	await _seconds(3.5)
	var henchmen := _boss_henchmen()
	_check(henchmen.size() >= 4, "на новой фазе приходит подмога (%d)" % henchmen.size())
	_check(henchmen.all(func(e: Variant) -> bool: return e.drop_health_chance >= 0.5), "с прислужников босса чаще падают аптечки")
	boss.apply_shot(boss.health + 1.0, false, boss.global_position + Vector3.UP, Vector3.FORWARD, deagle)
	_check(boss.phase == 3 and boss.model.weapon == "shotgun", "в 3-й фазе Толстяк берёт дробовик")
	await _seconds(2.0)
	var money: int = _game.money
	boss.apply_shot(100000.0, false, boss.global_position + Vector3.UP, Vector3.FORWARD, deagle)
	await _frames(3)
	_check(not is_instance_valid(boss), "Толстяк побеждён")
	_check(_game.money > money, "за босса платят премию ($%d)" % (_game.money - money))
	_check(not hud.get_node("%BossBar").visible, "полоса босса скрыта")
	_teleport(player, exit.global_position)
	await _frames(5)
	_check(hud.get_node("%LevelComplete").visible, "после Толстяка вертолёт забирает игрока")


## Подходим к спрятавшемуся боссу так, чтобы он был на виду.
func _approach(player: Player, boss: Boss) -> void:
	var space := boss.get_world_3d().direct_space_state
	for distance in [3.0, 2.0, 4.5]:
		for i in 12:
			var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 12.0)
			var spot: Vector3 = boss.global_position + direction * distance
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP, spot + Vector3.DOWN, 1))
			if floor_hit.is_empty() or absf(floor_hit.position.y - boss.global_position.y) > 0.2:
				continue
			var head := boss.global_position + Vector3.UP * 1.6
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(head, spot + Vector3.UP * 1.3, 1)).is_empty():
				continue
			var shape := PhysicsShapeQueryParameters3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.4
			capsule.height = 1.8
			shape.shape = capsule
			shape.transform = Transform3D(Basis(), spot + Vector3.UP * 1.0)
			shape.collision_mask = 1
			if not space.intersect_shape(shape, 1).is_empty():
				continue
			_teleport(player, spot)
			return


func _test_thin_boss() -> void:
	var level := await _fresh_level(3, false)
	var player := level.player
	player.max_health = 100000
	player.health = 100000
	var hud := level.hud
	var boss := level.get_node("Enemies/ThinBoss") as Boss
	var study := boss.global_position
	_teleport(player, Vector3(0, 5, -253))
	await _seconds(1.0)
	_check(hud.get_node("%BossBar").visible, "Худой замечает игрока в кабинете")
	var deagle: WeaponData = load("res://weapons/deagle.tres")
	boss.apply_shot(boss.health + 1.0, false, boss.global_position + Vector3.UP, Vector3.FORWARD, deagle)
	await _frames(3)
	_check(boss.hidden and boss.global_position.distance_to(study) > 8.0, "после фазы Худой прячется в другой комнате")
	_check(hud.get_node("%ObjectiveLabel").text.contains("Найдите"), "задание: найти Худого")
	await _seconds(3.0)
	_check(_boss_henchmen().size() >= 4, "по особняку снова ходят прислужники")
	await _approach(player, boss)
	await _seconds(0.8)
	_check(not boss.hidden, "найденный Худой выходит на бой")
	boss.apply_shot(boss.health + 1.0, false, boss.global_position + Vector3.UP, Vector3.FORWARD, deagle)
	await _frames(3)
	_check(boss.hidden and boss.phase == 3, "после 2-й фазы Худой снова прячется")
	_check(boss.model.weapon == "deagle", "в 3-й фазе у Худого Desert Eagle")
	await _approach(player, boss)
	await _seconds(0.8)
	boss.apply_shot(100000.0, true, boss.global_position + Vector3.UP * 2.0, Vector3.FORWARD, deagle)
	await _seconds(3.5)
	_check(not is_instance_valid(boss), "Худой побеждён")
	_check(hud.get_node("%LevelComplete").visible, "победа над Худым завершает особняк")


func _test_pause_and_death() -> void:
	var level := await _fresh_level(0)
	var hud := level.hud
	hud.toggle_pause()
	_check(get_tree().paused and hud.get_node("%PauseMenu").visible, "пауза включается")
	hud.get_node("%SettingsButton").pressed.emit()
	_check(hud.get_node("%SettingsPanel").visible, "настройки открываются из паузы")
	_game.set_setting("sensitivity", 1.5)
	hud.toggle_pause()
	_check(not hud.get_node("%SettingsPanel").visible and hud.get_node("%PauseMenu").visible, "назад из настроек в паузу")
	hud.toggle_pause()
	_check(not get_tree().paused, "пауза выключается")
	_game.set_setting("sensitivity", 1.0)

	level.player.take_damage(999, level.player.global_position)
	_check(not level.player.is_alive(), "игрок умирает")
	await _seconds(2.0)
	_check(hud.get_node("%GameOver").visible and get_tree().paused, "экран поражения")
	_game.restart_level()
	await _frames(5)
	_check(not get_tree().paused and get_tree().current_scene != level, "рестарт перезагружает уровень")


# --- Экономика, город и база ---------------------------------------------------------

func _test_difficulty_and_money() -> void:
	_game.reset_progress()
	_game.completions[0] = 2
	_game.start_level(0)
	await _frames(8)
	_check(_game.current_tier == 2, "повторный заход идёт на сложности 3")
	var gunner: Enemy = null
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.kind == Enemy.Kind.GUNNER:
			gunner = node
			break
	_check(gunner != null and is_equal_approx(gunner.max_health, 70.0 * 1.6), "враги крепче на повторе (%s)" % (gunner.max_health if gunner else 0.0))
	var before: int = _game.money
	gunner.apply_shot(1000.0, false, gunner.global_position, Vector3.FORWARD, load("res://weapons/pistol.tres"))
	await _frames(2)
	_check(_game.money - before == 20, "за убийство на повторе платят больше ($%d)" % (_game.money - before))


func _test_town_liberation() -> void:
	_game.reset_progress()
	_game.unlocked_levels = 5
	var level := await _fresh_level(_game.TOWN_INDEX, false)
	_check(not level.get("hub_mode"), "в первый раз город захвачен бандой")
	var zones := level.find_children("*", "WaveZone")
	_check(zones.size() == 3, "в городе три района с волнами")
	for zone in zones:
		_teleport(level.player, zone.global_position)
		await _frames(5)
		await _clear_zone(zone)
	await _seconds(3.5)
	_check(level.hud.get_node("%LevelComplete").visible, "после трёх районов город освобождён")
	_check(_game.town_liberated, "город стал базой")
	_check(level.hud.get_node("%NextButton").text == "В город", "кнопка «В город» после эпизода")


func _test_hub_and_entrances() -> void:
	_game.town_liberated = true
	_game.completions[1] = 1
	var level := await _fresh_level(_game.TOWN_INDEX, false)
	_check(level.get("hub_mode"), "город открывается как база")
	_check(get_tree().get_nodes_in_group("enemies").is_empty(), "на базе нет врагов")
	var entrances := level.find_children("*", "LevelEntrance")
	_check(entrances.size() == 4, "в городе 4 входа на уровни")
	var metro: LevelEntrance = null
	for entrance in entrances:
		if entrance.level_index == 1:
			metro = entrance
	_teleport(level.player, metro.global_position)
	await _frames(5)
	_check(level.player.interactable == metro, "у входа в метро появляется кнопка действия")
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)
	_check(level.hud.get_node("%EntrancePanel").visible, "открывается окно задания")
	level.hud.get_node("%EntranceStartButton").pressed.emit()
	await _frames(8)
	var metro_level := get_tree().current_scene as Level
	_check(metro_level != null and metro_level.level_index == 1 and _game.current_tier == 1,
			"из города запускается метро на сложности 2")


func _test_property_and_perks() -> void:
	_game.town_liberated = true
	_game.money = 30000
	var level := await _fresh_level(_game.TOWN_INDEX, false)
	var shack := level.get_node("Properties/shack") as Property
	var door := shack.get_node("Door") as CSGShape3D
	_check(door.visible and door.use_collision, "дверь хибары закрыта, пока не куплена")
	_teleport(level.player, level.get_node("Entrances/ShackDoor").global_position)
	await _frames(5)
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)
	_check(level.hud.get_node("%PropertyPanel").visible, "открывается окно покупки")
	level.hud.get_node("%PropertyBuyButton").pressed.emit()
	await _frames(3)
	_check(_game.owns_property("shack") and _game.money == 29000, "хибара куплена за $1000")
	_check(not door.visible and not door.use_collision, "дверь купленной хибары открыта")
	var rows := level.hud.get_node("%UpgradeList").get_children()
	_check(rows.size() == 3, "в окне три улучшения")
	(rows[0].get_child(1) as Button).pressed.emit()
	await _frames(3)
	_check(_game.has_upgrade("shack", "bed"), "улучшение «кровать» куплено")
	_check(shack.get_node("Furniture/bed").visible, "кровать появилась в хибаре")
	_check(not shack.get_node("Furniture/stash").visible, "некупленного улучшения нет")
	_check(not _game.buy_property("mansion"), "особняк нельзя купить раньше квартиры")
	level.hud._close_panels()

	var town := await _fresh_level(_game.TOWN_INDEX, false)
	var spawn := (town.get_node("Properties/shack") as Property).get_spawn()
	_check(town.player.global_position.distance_to(spawn.global_position) < 1.0, "на базе игрок появляется дома")
	var mission := await _fresh_level(0)
	_check(mission.player.max_health == 110, "кровать даёт +10 к здоровью на заданиях")


# --- Помощники -------------------------------------------------------------------

func _fresh_level(index: int, clear_enemies := true) -> Level:
	_game.start_level(index)
	await _frames(8)
	var level := get_tree().current_scene as Level
	if clear_enemies:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			enemy.queue_free()
		await _frames(2)
	return level


func _spawn_enemy(level: Node, kind: String, at: Vector3) -> Enemy:
	var enemy := (load("res://scenes/enemies/%s.tscn" % kind) as PackedScene).instantiate() as Enemy
	enemy.drop_ammo_chance = 0.0
	enemy.drop_health_chance = 0.0
	level.add_child(enemy)
	enemy.global_position = at
	enemy.rotation.y = PI
	return enemy


func _clear_zone(zone: WaveZone) -> int:
	var pistol: WeaponData = load("res://weapons/pistol.tres")
	var killed := 0
	for i in 900:
		if zone.done:
			break
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.is_alive() and enemy.global_position.distance_to(zone.global_position) < 40.0:
				enemy.apply_shot(1000.0, false, enemy.global_position + Vector3.UP, Vector3.FORWARD, pistol)
				killed += 1
		await get_tree().physics_frame
	return killed


func _aim_at(player: Player, point: Vector3) -> void:
	var rig := player.camera_rig
	var arm := rig.get_node("ShoulderArm/Shoulder/SpringArm3D") as Node3D
	for i in 4:
		var direction := (point - rig.camera.global_position).normalized()
		rig.set_yaw(atan2(-direction.x, -direction.z))
		arm.rotation.x = asin(direction.y)
		await _frames(2)


func _fire(player: Player) -> void:
	await _seconds(player.current_weapon.fire_interval + 0.05)
	Input.action_press("fire")
	await _frames(2)
	Input.action_release("fire")
	await _frames(2)


func _teleport(player: Player, at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	player.camera_rig.snap_to_target()


func _debris_count(level: Node) -> int:
	var debris := level.get_node_or_null("Debris")
	return 0 if debris == null else debris.get_child_count()


func _debris_with_node(level: Node, node_name: String) -> int:
	var debris := level.get_node_or_null("Debris")
	var count := 0
	if debris:
		for body in debris.get_children():
			if body.has_node(node_name):
				count += 1
	return count


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Ждём игровое время в физических кадрах (60 в секунду).
func _seconds(time: float) -> void:
	await _frames(ceili(time * Engine.physics_ticks_per_second))


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  OK   ", label)
	else:
		_failed += 1
		printerr("  FAIL ", label)


func _check_silent(_condition: bool) -> void:
	pass


# Координаты касаний — в пикселях интерфейса (1280x720), переводим в пиксели окна.
func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = get_tree().root.get_final_transform() * position
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = get_tree().root.get_final_transform() * position
	event.relative = get_tree().root.get_final_transform().basis_xform(relative)
	Input.parse_input_event(event)
