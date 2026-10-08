class_name Hud
extends CanvasLayer
## Интерфейс шутера: здоровье, патроны, прицел, сообщения, пауза с настройками,
## экраны поражения и прохождения уровня, сенсорное управление.
## Работает и на паузе (process_mode = Always), а сенсорные кнопки на паузе отключаются.

signal restart_requested
signal menu_requested
signal next_requested

var _player: Player
var _message_tween: Tween
var _toast_tween: Tween
var _flash_tween: Tween
var _reload_tween: Tween
var _last_health := -1
var _low_health := false
var _pulse := 0.0
var _infinity := "∞"

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _kills_label: Label = %KillsLabel
@onready var _ammo_label: Label = %AmmoLabel
@onready var _weapon_label: Label = %WeaponLabel
@onready var _reload_bar: ProgressBar = %ReloadBar
@onready var _crosshair: Control = %Crosshair
@onready var _message: Label = %Message
@onready var _subtitle: Label = %Subtitle
@onready var _toast: Label = %Toast
@onready var _damage_flash: ColorRect = %DamageFlash
@onready var _touch_controls: Control = %TouchControls
@onready var _switch_button: TouchActionButton = %SwitchButton
@onready var _pause_menu: Control = %PauseMenu
@onready var _settings: Control = %SettingsPanel
@onready var _game_over: Control = %GameOver
@onready var _complete: Control = %LevelComplete
@onready var _complete_stats: Label = %CompleteStats
@onready var _record_label: Label = %RecordLabel
@onready var _next_button: Button = %NextButton


func _ready() -> void:
	%PauseButton.pressed.connect(toggle_pause)
	%ResumeButton.pressed.connect(toggle_pause)
	%SettingsButton.pressed.connect(_open_settings)
	%RestartButton.pressed.connect(_emit.bind(restart_requested))
	%MenuButton.pressed.connect(_emit.bind(menu_requested))
	%GameOverRestartButton.pressed.connect(_emit.bind(restart_requested))
	%GameOverMenuButton.pressed.connect(_emit.bind(menu_requested))
	%NextButton.pressed.connect(_emit.bind(next_requested))
	%CompleteMenuButton.pressed.connect(_emit.bind(menu_requested))
	_settings.closed.connect(_close_settings)
	for overlay in [_pause_menu, _settings, _game_over, _complete]:
		overlay.hide()
	_message.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_toast.modulate.a = 0.0
	_reload_bar.hide()
	var font := _ammo_label.get_theme_font("font")
	if font and not font.has_char("∞".unicode_at(0)):
		_infinity = "--"


func bind_player(player: Player) -> void:
	_player = player
	player.health_changed.connect(set_health)
	player.ammo_changed.connect(_on_ammo_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.reload_started.connect(_on_reload_started)
	player.shot_fired.connect(func(weapon: WeaponData) -> void: _crosshair.kick(weapon.crosshair_kick))
	player.hit_confirmed.connect(_crosshair.show_hit)
	player.picked_up.connect(show_toast)
	set_health(player.health, player.max_health)
	if player.current_weapon:
		_on_weapon_changed(player.current_weapon)
		var state := player.get_ammo(player.current_weapon)
		_on_ammo_changed(player.current_weapon, state.mag, -1 if player.current_weapon.infinite_ammo else state.reserve)


func _process(delta: float) -> void:
	if _player:
		_crosshair.on_target = _player.aim_target != null
		_crosshair.on_head = _crosshair.on_target and _player.aim_is_head
		_crosshair.visible = _player.is_alive()
	# При низком здоровье края экрана пульсируют красным.
	if _low_health and _player and _player.is_alive() and (_flash_tween == null or not _flash_tween.is_running()):
		_pulse += delta * 4.0
		_damage_flash.color.a = 0.08 + 0.06 * sin(_pulse)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Кнопка «Назад» на Android ставит игру на паузу, а не закрывает её.
			toggle_pause()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if is_inside_tree() and not _blocking_overlay_visible():
				set_paused(true)


func toggle_pause() -> void:
	if _settings.visible:
		_close_settings()
		return
	set_paused(not get_tree().paused)


func set_paused(value: bool) -> void:
	if _blocking_overlay_visible():
		return
	get_tree().paused = value
	_pause_menu.visible = value
	_touch_controls.visible = not value


func set_health(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%d" % current
	if _last_health != -1 and current < _last_health:
		_flash_damage()
	_last_health = current
	_low_health = current > 0 and current <= maximum * 0.3
	if not _low_health and (_flash_tween == null or not _flash_tween.is_running()):
		_damage_flash.color.a = 0.0


func set_objective(text: String) -> void:
	_objective_label.text = text


func set_kills(count: int) -> void:
	_kills_label.text = "Убито: %d" % count


func show_message(title: String, subtitle := "") -> void:
	_message.text = title
	_subtitle.text = subtitle
	if subtitle != "" and _objective_label.text == "":
		set_objective(subtitle)
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween().set_parallel(true)
	for label in [_message, _subtitle]:
		label.modulate.a = 0.0
		_message_tween.tween_property(label, "modulate:a", 1.0, 0.25)
	_message_tween.chain().tween_interval(1.8)
	_message_tween.chain().tween_property(_message, "modulate:a", 0.0, 0.5)
	_message_tween.parallel().tween_property(_subtitle, "modulate:a", 0.0, 0.5)


func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func show_game_over() -> void:
	_hide_gameplay()
	_game_over.show()
	get_tree().paused = true


func show_level_complete(title: String, time: float, kills: int, headshots: int, record: bool, has_next: bool) -> void:
	_hide_gameplay()
	%CompleteTitle.text = "%s пройден!" % title
	_complete_stats.text = "Время: %s\nУбито: %d\nХедшоты: %d" % [Game.format_time(time), kills, headshots]
	_record_label.visible = record
	_next_button.visible = has_next
	if not has_next:
		%CompleteTitle.text = "Игра пройдена!"
	_complete.show()
	get_tree().paused = true


func _on_weapon_changed(weapon: WeaponData) -> void:
	_weapon_label.text = weapon.display_name
	_switch_button.text = weapon.short_name
	_reload_bar.hide()


func _on_ammo_changed(_weapon: WeaponData, magazine: int, reserve: int) -> void:
	_ammo_label.text = "%d / %s" % [magazine, _infinity if reserve < 0 else str(reserve)]
	_ammo_label.modulate = Color(1, 0.4, 0.35) if magazine == 0 else Color.WHITE


func _on_reload_started(duration: float) -> void:
	_reload_bar.show()
	_reload_bar.value = 0.0
	if _reload_tween:
		_reload_tween.kill()
	_reload_tween = create_tween()
	_reload_tween.tween_property(_reload_bar, "value", 100.0, duration)
	_reload_tween.tween_callback(_reload_bar.hide)


func _flash_damage() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_damage_flash.color.a = 0.4
	_flash_tween = create_tween()
	_flash_tween.tween_property(_damage_flash, "color:a", 0.0, 0.4)


func _open_settings() -> void:
	_pause_menu.hide()
	_settings.show()


func _close_settings() -> void:
	_settings.hide()
	_pause_menu.show()


func _hide_gameplay() -> void:
	_pause_menu.hide()
	_settings.hide()
	_touch_controls.hide()
	_crosshair.hide()
	_reload_bar.hide()


func _blocking_overlay_visible() -> bool:
	return _game_over.visible or _complete.visible


func _emit(sig: Signal) -> void:
	Audio.play("ui_click")
	sig.emit()
