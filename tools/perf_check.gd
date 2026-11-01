extends SceneTree
## Замер нагрузки по уровням (на ПК, с окном — без --headless):
##   godot --path . -s res://tools/perf_check.gd -- 1
## Последний аргумент — графика: 0 низкая, 1 средняя, 2 высокая (по умолчанию 2).
## Печатает для каждого уровня вызовы отрисовки, объекты в кадре и кадры в секунду.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var game := root.get_node("/root/Game")
	game.save_enabled = false
	var args := OS.get_cmdline_user_args()
	var quality := int(args[0]) if args.size() > 0 else 2
	game.set_graphics(quality)
	print("Графика: %s" % ["низкая", "средняя", "высокая"][quality])
	var scenes: Array = []
	for level in game.LEVELS:
		scenes.append(level.scene)
	scenes.append(game.TRAIN_SCENE)
	scenes.append(game.CHASE_SCENE)
	for path in scenes:
		var level: Node = (load(path) as PackedScene).instantiate()
		root.add_child(level)
		current_scene = level
		for i in 40:
			await process_frame
		var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var objects := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		print("%-34s отрисовок %4d  объектов %4d  FPS %d" % [String(path).get_file(), draws, objects,
				Engine.get_frames_per_second()])
		level.queue_free()
		await process_frame
	quit()
