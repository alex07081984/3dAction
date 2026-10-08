extends Control
## Панель настроек. Используется и в главном меню, и в паузе.
## Значения сразу применяются и сохраняются через Game.set_setting().

signal closed

@onready var _sensitivity: HSlider = %Sensitivity
@onready var _sensitivity_value: Label = %SensitivityValue
@onready var _volume: HSlider = %Volume
@onready var _volume_value: Label = %VolumeValue
@onready var _aim_assist: CheckButton = %AimAssist
@onready var _auto_fire: CheckButton = %AutoFire
@onready var _shadows: CheckButton = %Shadows


func _ready() -> void:
	_sync()
	_sensitivity.value_changed.connect(_on_sensitivity)
	_volume.value_changed.connect(_on_volume)
	_aim_assist.toggled.connect(func(on: bool) -> void: Game.set_setting("aim_assist", on))
	_auto_fire.toggled.connect(func(on: bool) -> void: Game.set_setting("auto_fire", on))
	_shadows.toggled.connect(_on_shadows)
	%DoneButton.pressed.connect(_on_done)
	visibility_changed.connect(_sync)


func _on_done() -> void:
	Audio.play("ui_click")
	closed.emit()


func _sync() -> void:
	_sensitivity.set_value_no_signal(float(Game.settings.sensitivity))
	_volume.set_value_no_signal(float(Game.settings.volume))
	_aim_assist.set_pressed_no_signal(bool(Game.settings.aim_assist))
	_auto_fire.set_pressed_no_signal(bool(Game.settings.auto_fire))
	_shadows.set_pressed_no_signal(bool(Game.settings.shadows))
	_update_labels()


func _on_sensitivity(value: float) -> void:
	Game.set_setting("sensitivity", value)
	_update_labels()


func _on_volume(value: float) -> void:
	Game.set_setting("volume", value)
	_update_labels()
	Audio.play("ui_click")


func _on_shadows(on: bool) -> void:
	Game.set_setting("shadows", on)
	# Тени переключаются сразу, если мы на уровне.
	for light in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		(light as DirectionalLight3D).shadow_enabled = on


func _update_labels() -> void:
	_sensitivity_value.text = "%.1f" % _sensitivity.value
	_volume_value.text = "%d%%" % roundi(_volume.value * 100.0)
