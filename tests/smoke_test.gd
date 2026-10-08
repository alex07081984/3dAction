extends SceneTree
## Автопроверка без окна. Запуск с ПК:
##   godot --headless --path . -s res://tests/smoke_test.gd
## Сами проверки лежат в smoke_runner.gd: он загружается, когда автозагрузки
## (Game, Audio, Fx) уже на месте, иначе скрипты игры не скомпилируются.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/smoke_runner.gd").new()
	runner.name = "SmokeRunner"
	root.add_child(runner)
