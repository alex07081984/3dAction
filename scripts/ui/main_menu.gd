extends Node3D
## Главное меню: «Играть» (продолжить с последнего открытого уровня), выбор уровня
## с рекордами, настройки и выход. На фоне крутится герой с дробовиком.

@onready var _hero: Node3D = $Hero
@onready var _main: Control = %MainButtons
@onready var _levels: Control = %LevelsPanel
@onready var _level_list: VBoxContainer = %LevelList
@onready var _settings: Control = %SettingsPanel
@onready var _play_button: Button = %PlayButton


func _ready() -> void:
	Audio.play_music("music_menu")
	_hero.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	get_tree().paused = false
	Engine.time_scale = 1.0
	%PlayButton.pressed.connect(_on_play)
	%LevelsButton.pressed.connect(_show_levels)
	%SettingsButton.pressed.connect(_show_settings)
	%QuitButton.pressed.connect(get_tree().quit)
	%BackButton.pressed.connect(_show_main)
	_settings.closed.connect(_show_main)
	# Сменили язык в настройках — подписи, собранные кодом, пересобираем.
	Game.settings_changed.connect(_refresh_texts)
	_refresh_texts()
	_show_main()


func _refresh_texts() -> void:
	var next := mini(Game.unlocked_levels, Game.LEVELS.size()) - 1
	if Game.latest_city() >= 0:
		_play_button.text = tr("В город")
	elif next == 0 and Game.records.is_empty():
		_play_button.text = tr("Играть")
	else:
		_play_button.text = tr("Продолжить: %s") % Game.level_title(next)
	%MoneyLabel.text = "$ %d" % Game.money
	_build_level_list()


func _process(delta: float) -> void:
	_hero.rotate_y(delta * 0.4)
	var model := _hero.get_node("Model") as BlockyCharacter
	model.animate(delta, 0.0, true, 0.1)


func _on_play() -> void:
	Audio.play("ui_click")
	if Game.latest_city() >= 0:
		Game.go_to_town()
	else:
		# Продолжаем с последнего открытого уровня.
		Game.start_level(mini(Game.unlocked_levels, Game.LEVELS.size()) - 1)


func _build_level_list() -> void:
	for child in _level_list.get_children():
		child.queue_free()
	for index in Game.LEVELS.size():
		for episode in Game.EPISODES:
			if int(episode.first) == index:
				var header := Label.new()
				header.text = tr(episode.title)
				header.add_theme_font_size_override("font_size", 26)
				header.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
				_level_list.add_child(header)
		var button := Button.new()
		button.custom_minimum_size = Vector2(720, 56)
		var title := Game.level_title(index)
		if Game.is_level_unlocked(index):
			var record: Variant = Game.records.get(index)
			button.text = "%d. %s" % [index + 1, title]
			if not Game.is_city(index) and Game.tier_of(index) > 0:
				button.text += "   · " + tr("сложность %d") % (Game.tier_of(index) + 1)
			if record is Dictionary:
				button.text += "   · " + tr("рекорд %s") % Game.format_time(record.time)
			if Game.stars_of(index) > 0:
				button.text += "   · " + tr("звёзды %d/3") % Game.stars_of(index)
			if Game.is_city(index) and Game.is_liberated(index):
				button.text = "%d. %s   · %s" % [index + 1, title, tr("ваша база")]
			button.pressed.connect(Game.start_level.bind(index))
		else:
			button.text = "%d. %s   (%s)" % [index + 1, title, tr("закрыт")]
			button.disabled = true
		_level_list.add_child(button)


func _show_main() -> void:
	_main.show()
	_levels.hide()
	_settings.hide()


func _show_levels() -> void:
	Audio.play("ui_click")
	_main.hide()
	_levels.show()


func _show_settings() -> void:
	Audio.play("ui_click")
	_main.hide()
	_settings.show()
