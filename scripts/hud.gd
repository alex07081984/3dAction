class_name Hud
extends CanvasLayer
## Интерфейс: здоровье, номер волны, сообщения, пауза, экран поражения и сенсорное управление.
## Работает и на паузе (process_mode = Always), а сенсорные кнопки на паузе отключаются.

signal restart_requested

var _message_tween: Tween
var _flash_tween: Tween
var _last_health := -1

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _enemies_label: Label = %EnemiesLabel
@onready var _message: Label = %Message
@onready var _damage_flash: ColorRect = %DamageFlash
@onready var _touch_controls: Control = %TouchControls
@onready var _pause_menu: Control = %PauseMenu
@onready var _game_over: Control = %GameOver
@onready var _game_over_label: Label = %GameOverLabel


func _ready() -> void:
	%PauseButton.pressed.connect(toggle_pause)
	%ResumeButton.pressed.connect(toggle_pause)
	%RestartButton.pressed.connect(restart_requested.emit)
	%GameOverRestartButton.pressed.connect(restart_requested.emit)
	_pause_menu.hide()
	_game_over.hide()
	_message.modulate.a = 0.0


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
			# Свернули приложение или пришёл звонок — ставим паузу.
			if is_inside_tree() and not _game_over.visible:
				set_paused(true)


func toggle_pause() -> void:
	set_paused(not get_tree().paused)


func set_paused(value: bool) -> void:
	if _game_over.visible:
		return
	get_tree().paused = value
	_pause_menu.visible = value
	_touch_controls.visible = not value


func set_health(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%d / %d" % [current, maximum]
	if _last_health != -1 and current < _last_health:
		_flash_damage()
	_last_health = current


func set_wave(wave: int) -> void:
	_wave_label.text = "Волна %d" % wave if wave > 0 else "Готовьтесь!"


func set_enemies_left(count: int) -> void:
	_enemies_label.text = "Врагов: %d" % count


func show_message(text: String) -> void:
	_message.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "modulate:a", 1.0, 0.2)
	_message_tween.tween_interval(1.3)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.4)


func show_game_over(wave: int) -> void:
	_game_over_label.text = "Вы погибли\nДошли до волны %d" % wave
	_pause_menu.hide()
	_touch_controls.hide()
	_game_over.show()
	get_tree().paused = true


func _flash_damage() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_damage_flash.color.a = 0.35
	_flash_tween = create_tween()
	_flash_tween.tween_property(_damage_flash, "color:a", 0.0, 0.35)
