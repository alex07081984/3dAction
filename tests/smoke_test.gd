extends SceneTree
## Быстрая автопроверка без окна. Запуск с ПК:
##   godot --headless --path . -s res://tests/smoke_test.gd
## Загружает главную сцену, имитирует касания и нажатия и проверяет,
## что персонаж двигается, камера крутится, удары наносят урон и т. д.

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(10)

	var player := main.get_node("Player") as Player
	var hud := main.get_node("HUD") as Hud
	var rig := player.get_node("CameraRig") as CameraRig
	_check(player != null and hud != null and rig != null, "главная сцена собрана")
	_check(hud.get_node("%HealthLabel").text == "10 / 10", "HUD показывает здоровье")

	# Движение с клавиатуры/геймпада: вперёд — это от камеры, то есть к -Z.
	var start := player.global_position
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	_check(start.z - player.global_position.z > 1.5, "игрок бежит вперёд (%.2f м)" % (start.z - player.global_position.z))

	# Сенсорный джойстик: касание в его зоне и свайп вверх.
	var joystick := hud.get_node("TouchControls/Joystick") as TouchJoystick
	var touch_at := joystick.get_global_rect().get_center()
	_touch(0, touch_at, true)
	_drag(0, touch_at + Vector2(0, -100), Vector2(0, -100))
	await _frames(2)
	_check(Input.get_action_strength("move_forward") > 0.8, "джойстик нажимает move_forward")
	start = player.global_position
	await _frames(20)
	_check(start.z - player.global_position.z > 1.0, "игрок бежит от джойстика")
	_touch(0, touch_at + Vector2(0, -100), false)
	await _frames(2)
	_check(not Input.is_action_pressed("move_forward"), "отпущенный джойстик отпускает движение")

	# Свайп по свободной части экрана крутит камеру.
	var yaw := rig.rotation.y
	_touch(1, Vector2(800, 200), true)
	_drag(1, Vector2(900, 200), Vector2(100, 0))
	_touch(1, Vector2(900, 200), false)
	await _frames(2)
	_check(not is_equal_approx(yaw, rig.rotation.y), "свайп поворачивает камеру")

	# Свайп, начатый на джойстике, камеру не крутит.
	yaw = rig.rotation.y
	_touch(2, touch_at, true)
	_drag(2, touch_at + Vector2(120, 0), Vector2(120, 0))
	_touch(2, touch_at + Vector2(120, 0), false)
	await _frames(2)
	_check(is_equal_approx(yaw, rig.rotation.y), "палец на джойстике не крутит камеру")

	# Удар сенсорной кнопкой по врагу перед игроком.
	await _frames(20)
	var enemy := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	main.get_node("Enemies").add_child(enemy)
	enemy.global_position = player.global_position + Vector3(0.5, 0.0, -1.6)
	await _frames(3)
	var attack_button := hud.get_node("TouchControls/AttackButton") as Control
	var button_at := attack_button.get_global_rect().get_center()
	_touch(3, button_at, true)
	await _frames(3)
	_touch(3, button_at, false)
	await _frames(25)
	_check(enemy.health < enemy.max_health, "удар кнопкой наносит урон (%d/%d)" % [enemy.health, enemy.max_health])

	# Комбо добивает врага.
	for i in 6:
		enemy.global_position = player.global_position + Vector3(0.0, 0.0, -1.5)
		Input.action_press("attack")
		await _frames(3)
		Input.action_release("attack")
		await _frames(12)
		if not is_instance_valid(enemy) or not enemy.is_alive():
			break
	_check(not is_instance_valid(enemy) or not enemy.is_alive(), "комбо убивает врага")

	# Урон игроку обновляет HUD.
	await _frames(60)
	var before := player.health
	player.take_damage(3, player.global_position + Vector3.FORWARD)
	_check(player.health == before - 3, "игрок получает урон")
	_check(hud.get_node("%HealthLabel").text == "%d / 10" % player.health, "HUD обновил здоровье")

	# Пауза.
	hud.toggle_pause()
	_check(paused and hud.get_node("%PauseMenu").visible, "пауза включается")
	hud.toggle_pause()
	_check(not paused and not hud.get_node("%PauseMenu").visible, "пауза выключается")

	# Волна врагов появляется сама.
	await _frames(120)
	_check(get_nodes_in_group("enemies").size() >= 3, "волна 1 заспавнилась (%d)" % get_nodes_in_group("enemies").size())
	_check(hud.get_node("%WaveLabel").text == "Волна 1", "HUD показывает номер волны")

	# Смерть и рестарт.
	player.take_damage(999, player.global_position)
	_check(not player.is_alive(), "игрок умирает")
	await _frames(100)
	_check(hud.get_node("%GameOver").visible and paused, "экран поражения")
	hud.restart_requested.emit()
	await _frames(5)
	_check(not paused and current_scene != main and current_scene.has_node("Player"), "рестарт перезагружает сцену")

	print("\n=== Пройдено: %d, провалено: %d ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  OK   ", label)
	else:
		_failed += 1
		printerr("  FAIL ", label)


# Координаты в тестах — в пикселях интерфейса (1280x720). Настоящие касания приходят
# в пикселях окна, поэтому переводим их так же, как это делает экран телефона.
func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * position
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = root.get_final_transform() * position
	event.relative = root.get_final_transform().basis_xform(relative)
	Input.parse_input_event(event)
