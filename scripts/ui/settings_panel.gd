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
@onready var _noir: CheckButton = %Noir
@onready var _music: CheckButton = %Music
@onready var _blood: CheckButton = %Blood
@onready var _show_fps: CheckButton = %ShowFps
@onready var _graphics: Button = %GraphicsButton
@onready var _language: Button = %LanguageButton

const GRAPHICS_NAMES := ["Низкая (быстрее)", "Средняя", "Высокая"]


func _ready() -> void:
	_sync()
	_sensitivity.value_changed.connect(_on_sensitivity)
	_volume.value_changed.connect(_on_volume)
	_aim_assist.toggled.connect(func(on: bool) -> void: Game.set_setting("aim_assist", on))
	_auto_fire.toggled.connect(func(on: bool) -> void: Game.set_setting("auto_fire", on))
	_shadows.toggled.connect(_on_shadows)
	_noir.toggled.connect(func(on: bool) -> void: Game.set_setting("noir", on))
	_music.toggled.connect(func(on: bool) -> void: Audio.set_music_enabled(on))
	_blood.toggled.connect(func(on: bool) -> void: Game.set_setting("blood", on))
	_show_fps.toggled.connect(func(on: bool) -> void: Game.set_setting("show_fps", on))
	_graphics.pressed.connect(_on_graphics)
	_language.pressed.connect(_on_language)
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
	_noir.set_pressed_no_signal(bool(Game.settings.get("noir", true)))
	_music.set_pressed_no_signal(bool(Game.settings.get("music", true)))
	_blood.set_pressed_no_signal(bool(Game.settings.get("blood", true)))
	_show_fps.set_pressed_no_signal(bool(Game.settings.get("show_fps", false)))
	_shadows.set_pressed_no_signal(bool(Game.settings.shadows))
	_graphics.text = tr(GRAPHICS_NAMES[Game.graphics_quality()])
	# Название языка пишется на нём самом и не переводится.
	_language.text = Game.language_name(Game.language())
	_update_labels()


## Язык по кругу: English → Deutsch → Français → Русский. Подписи в сценах переводятся сразу,
## собранные кодом — при следующем обновлении (меню пересобирает их по сигналу settings_changed).
func _on_language() -> void:
	Audio.play("ui_click")
	Game.set_setting("language", Game.next_language())
	_sync()


## Графика по кругу: низкая → средняя → высокая. Тени включаются по пресету.
func _on_graphics() -> void:
	Audio.play("ui_click")
	Game.set_graphics((Game.graphics_quality() + 1) % 3)
	_sync()


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
