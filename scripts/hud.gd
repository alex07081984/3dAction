class_name Hud
extends CanvasLayer
## Интерфейс шутера: здоровье, патроны, прицел, сообщения, пауза с настройками,
## экраны поражения и прохождения уровня, сенсорное управление.
## Работает и на паузе (process_mode = Always), а сенсорные кнопки на паузе отключаются.

signal restart_requested
signal menu_requested
signal next_requested
signal town_requested

var _player: Player
var _message_tween: Tween
var _toast_tween: Tween
var _flash_tween: Tween
var _reload_tween: Tween
var _last_health := -1
var _low_health := false
var _pulse := 0.0
var _infinity := "∞"
var _money_tween: Tween
var _entrance_level := -1
var _property_id := ""
var _banner_tween: Tween
var _travel_episode := 2

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
@onready var _money_label: Label = %MoneyLabel
@onready var _money_popup: Label = %MoneyPopup
@onready var _interact_button: TouchActionButton = %InteractButton
@onready var _interact_prompt: Label = %InteractPrompt
@onready var _entrance_panel: Control = %EntrancePanel
@onready var _property_panel: Control = %PropertyPanel
@onready var _upgrade_list: VBoxContainer = %UpgradeList


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
	%TownButton.pressed.connect(_emit.bind(town_requested))
	%GameOverTownButton.pressed.connect(_emit.bind(town_requested))
	%EntranceStartButton.pressed.connect(_start_entrance)
	%EntranceCancelButton.pressed.connect(_close_panels)
	%PropertyCloseButton.pressed.connect(_close_panels)
	%PropertyBuyButton.pressed.connect(_buy_property)
	%TravelTrainButton.pressed.connect(_start_travel.bind("train"))
	%TravelCarButton.pressed.connect(_start_travel.bind("chase"))
	%TravelCancelButton.pressed.connect(_close_panels)
	_settings.closed.connect(_close_settings)
	add_to_group("hud")
	for overlay in [_pause_menu, _settings, _game_over, _complete, _entrance_panel, _property_panel, %TravelPanel]:
		overlay.hide()
	set_town_available(false)
	Game.economy_changed.connect(_update_money)
	Game.settings_changed.connect(_apply_noir)
	_apply_noir()
	_update_money()
	_money_popup.modulate.a = 0.0
	_message.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_toast.modulate.a = 0.0
	_reload_bar.hide()
	%Banner.modulate.a = 0.0
	update_combo(0, 1)
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
	player.grenades_changed.connect(_on_grenades_changed)
	_on_grenades_changed(player.grenades)
	player.scope_changed.connect(_on_scope_changed)
	player.rage_changed.connect(_on_rage_changed)
	_on_rage_changed(player.rage, player.is_raging())
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
		# Кнопка «Действие» появляется, когда игрок стоит в зоне входа или у двери.
		var zone := _player.interactable
		var show_action := is_instance_valid(zone) and _player.is_alive()
		if show_action:
			_interact_prompt.text = zone.get_prompt()
			_interact_button.text = zone.get_button_text()
		_interact_prompt.visible = show_action
		_interact_button.visible = show_action and zone.active
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
	if _entrance_panel.visible or _property_panel.visible or %TravelPanel.visible:
		_close_panels()
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


## Полоса здоровья босса: имя, фаза и доля здоровья в текущей фазе.
func update_boss(boss_name: String, fraction: float, phase: int, phases: int, status := "") -> void:
	%BossBar.visible = true
	%BossName.text = "%s · фаза %d из %d%s" % [boss_name, phase, phases, ("  (%s)" % status) if status != "" else ""]
	%BossHealth.value = fraction * 100.0


func hide_boss() -> void:
	%BossBar.visible = false


func set_kills(count: int) -> void:
	_kills_label.text = "Убито: %d" % count


func set_kills_visible(value: bool) -> void:
	_kills_label.visible = value


func _apply_noir() -> void:
	%NoirFilter.visible = bool(Game.settings.get("noir", true))


## Кнопки «В город» показываются, когда город уже освобождён.
func set_town_available(value: bool) -> void:
	%TownButton.visible = value
	%GameOverTownButton.visible = value
	%RestartButton.visible = not (Game.is_city(Game.current_level) and Game.is_liberated(Game.current_level))


func show_money_popup(amount: int) -> void:
	if amount <= 0:
		return
	_money_popup.text = "+$%d" % amount
	if _money_tween:
		_money_tween.kill()
	_money_popup.modulate.a = 1.0
	_money_tween = create_tween()
	_money_tween.tween_interval(0.8)
	_money_tween.tween_property(_money_popup, "modulate:a", 0.0, 0.4)


# --- Город: входы на уровни и недвижимость ---------------------------------------------

func show_entrance(level_index: int) -> void:
	_entrance_level = level_index
	var title: String = Game.LEVELS[level_index].title
	%EntranceTitle.text = title
	var tier := Game.tier_of(level_index)
	var text := "Сложность: %d из %d\nНаграда за прохождение: $%d\nДеньги за убийства: ×%.1f" % [
			tier + 1, Game.MAX_TIER + 1, Game.level_reward(level_index), Game.reward_multiplier(tier)]
	var record: Variant = Game.records.get(level_index)
	if record is Dictionary:
		text += "\nРекорд: %s" % Game.format_time(record.time)
	%EntranceInfo.text = text
	_open_panel(_entrance_panel)


## Дорога в другой город: выбор — поезд или машина.
func show_travel(episode: int) -> void:
	_travel_episode = episode
	%TravelTitle.text = "Дорога: %s" % Game.city_name(episode)
	var plane := " Самолётом этот маршрут уже открыт — аэропорт." if Game.has_traveled(Game.latest_episode(), episode) else ""
	%TravelInfo.text = "Поезд — пробиться через вагоны к паровозу, на крышах опасны тоннели.\n" + \
			"Машина — рулите и отстреливайтесь от погони: мотоциклы, машины банды и вертолёт." + plane
	_open_panel(%TravelPanel)


func _start_travel(mode: String) -> void:
	Audio.play("ui_click")
	_close_panels()
	Game.start_travel(_travel_episode, mode)


func show_property(property_id: String) -> void:
	_property_id = property_id
	_refresh_property()
	_open_panel(_property_panel)


func _refresh_property() -> void:
	var item := Game.property(_property_id)
	var owned := Game.owns_property(_property_id)
	%PropertyTitle.text = item.title
	var buy := %PropertyBuyButton as Button
	buy.visible = not owned
	if owned:
		%PropertyInfo.text = "Это ваше жильё. Улучшения видны внутри и работают на всех заданиях.\nДеньги: $%d" % Game.money
	elif not Game.is_property_available(_property_id):
		%PropertyInfo.text = "Сначала купите жильё попроще."
		buy.disabled = true
		buy.text = "Недоступно"
	else:
		%PropertyInfo.text = "Цена: $%d\nУ вас: $%d" % [int(item.price), Game.money]
		buy.disabled = Game.money < int(item.price)
		buy.text = "Купить за $%d" % int(item.price)
	for child in _upgrade_list.get_children():
		child.queue_free()
	if not owned:
		return
	for upgrade in item.upgrades:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var label := Label.new()
		label.text = "%s\n%s" % [upgrade.title, upgrade.text]
		label.custom_minimum_size = Vector2(380, 0)
		label.add_theme_font_size_override("font_size", 22)
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 70)
		if Game.has_upgrade(_property_id, upgrade.id):
			button.text = "Куплено"
			button.disabled = true
		else:
			button.text = "$%d" % int(upgrade.price)
			button.disabled = Game.money < int(upgrade.price)
			button.pressed.connect(_buy_upgrade.bind(upgrade.id))
		row.add_child(button)
		_upgrade_list.add_child(row)


func _buy_property() -> void:
	if Game.buy_property(_property_id):
		Audio.play("weapon_pickup")
		show_toast("Куплено: %s!" % Game.property(_property_id).title)
	_refresh_property()


func _buy_upgrade(upgrade_id: String) -> void:
	if Game.buy_upgrade(_property_id, upgrade_id):
		Audio.play("pickup")
	_refresh_property()


func _start_entrance() -> void:
	Audio.play("ui_click")
	_close_panels()
	Game.start_level(_entrance_level)


func _open_panel(panel: Control) -> void:
	Audio.play("ui_click")
	get_tree().paused = true
	_touch_controls.hide()
	panel.show()


func _close_panels() -> void:
	_entrance_panel.hide()
	_property_panel.hide()
	%TravelPanel.hide()
	get_tree().paused = false
	_touch_controls.show()


func _update_money() -> void:
	_money_label.text = "$ %d" % Game.money


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


func show_level_complete(heading: String, time: float, kills: int, headshots: int, reward: int, record: bool,
		next_text: String) -> void:
	_hide_gameplay()
	%CompleteTitle.text = heading
	_complete_stats.text = "Время: %s\nУбито: %d · хедшоты: %d\nНаграда: $%d (всего $%d)" % [
			Game.format_time(time), kills, headshots, reward, Game.money]
	_record_label.visible = record
	_next_button.visible = next_text != ""
	_next_button.text = next_text
	_complete.show()
	get_tree().paused = true


func _on_grenades_changed(count: int) -> void:
	%GrenadeButton.text = "Гран %d" % count


func _on_weapon_changed(weapon: WeaponData) -> void:
	_weapon_label.text = weapon.display_name
	_switch_button.text = weapon.short_name
	_reload_bar.hide()
	# Кнопка оптики видна только у снайперской винтовки.
	%ScopeButton.visible = weapon.scope_fov > 0.0


## Герой у пулемёта в вертолёте: прыжок и рывок не нужны, джойстик — только если им рулят (погоня).
func set_mounted(value: bool, steering := false) -> void:
	for path in ["Joystick", "JumpButton", "DodgeButton"]:
		var node := _touch_controls.get_node_or_null(path) as Control
		if node:
			node.visible = not value or (steering and path == "Joystick")


func _on_rage_changed(value: float, active: bool) -> void:
	%RageBar.value = value
	%RageButton.visible = value >= 100.0 and not active
	%RageTint.visible = active


## Серия убийств: «КОМБО ×2 · 4» под полосой здоровья (пока множитель есть).
func update_combo(count: int, multiplier: int) -> void:
	var label := %ComboLabel as Label
	if multiplier < 2:
		label.text = ("Серия: %d" % count) if count >= 2 else ""
		label.modulate = Color(1, 1, 1, 0.75)
		return
	label.text = "КОМБО ×%d · %d" % [multiplier, count]
	label.modulate = Color.WHITE


## Крупная надпись посреди экрана: «ХЕДШОТ!», «ДВОЙНОЕ!»…
func show_banner(text: String, color := Color(1, 0.85, 0.3)) -> void:
	var banner := %Banner as Label
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	if _banner_tween:
		_banner_tween.kill()
	banner.modulate.a = 1.0
	banner.scale = Vector2(1.6, 1.6)
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(0.6)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.35)


func get_banner_text() -> String:
	return (%Banner as Label).text if (%Banner as Label).modulate.a > 0.01 else ""


## Кровь на экране (убийство в упор).
func blood_splash(strength := 1.0) -> void:
	%BloodSplash.splash(strength)


## Звёзды и подробности на экране победы.
func show_stars(stars: int, accuracy: float, best_combo: int) -> void:
	%StarRating.stars = stars
	_complete_stats.text += "\nМеткость: %d%% · лучшая серия: %d" % [roundi(accuracy * 100.0), best_combo]


func _on_scope_changed(on: bool) -> void:
	_crosshair.scoped = on
	%ScopeButton.text = "Без\nоптики" if on else "Прицел"


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
	%RageTint.hide()


func _blocking_overlay_visible() -> bool:
	return _game_over.visible or _complete.visible or _entrance_panel.visible or _property_panel.visible \
			or %TravelPanel.visible


func _emit(sig: Signal) -> void:
	Audio.play("ui_click")
	sig.emit()
