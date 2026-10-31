extends Node
## Звуки (автозагрузка Audio). Файлы лежат в res://audio/<имя>.wav.
##   Audio.play("pistol")                 — звук «у уха» игрока (интерфейс, свои выстрелы)
##   Audio.play_at("enemy_shot", позиция) — звук в 3D-пространстве
##   Audio.play_music("music_combat")     — музыка (зациклена, треки сменяются плавно)

const MAX_VOICES := 24

const MUSIC_DB := -11.0

var _cache := {}
var _voices := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _wanted_music := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func play(sound: String, volume_db := 0.0, pitch := 1.0, jitter := 0.05) -> void:
	var stream := _stream(sound)
	if stream == null or _voices >= MAX_VOICES:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(1.0 - jitter, 1.0 + jitter)
	_start(player)


func play_at(sound: String, position: Vector3, volume_db := 0.0, pitch := 1.0, jitter := 0.08) -> void:
	var stream := _stream(sound)
	if stream == null or _voices >= MAX_VOICES:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = 6.0
	player.max_distance = 70.0
	player.pitch_scale = pitch * randf_range(1.0 - jitter, 1.0 + jitter)
	player.position = position
	_start(player)


## Включить музыку. Если в настройках музыка выключена, трек запомнится до включения.
func play_music(track: String) -> void:
	_wanted_music = track
	if not bool(Game.settings.get("music", true)):
		_fade_out_music()
		return
	if track == _music_name and is_instance_valid(_music):
		return
	var source := _stream(track) as AudioStreamWAV
	if source == null:
		return
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.data.size() / 2)
	_fade_out_music()
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = -40.0
	add_child(_music)
	_music.play()
	_music_name = track
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, 1.2)


func stop_music() -> void:
	_wanted_music = ""
	_fade_out_music()


func set_music_enabled(on: bool) -> void:
	Game.set_setting("music", on)
	if on and _wanted_music != "":
		play_music(_wanted_music)
	elif not on:
		_fade_out_music()


func current_music() -> String:
	return _music_name


func _fade_out_music() -> void:
	if is_instance_valid(_music):
		var old := _music
		var tween := create_tween()
		tween.tween_property(old, "volume_db", -40.0, 0.8)
		tween.tween_callback(old.queue_free)
	_music = null
	_music_name = ""


func _start(player: Node) -> void:
	_voices += 1
	add_child(player)
	player.finished.connect(_on_finished.bind(player))
	player.play()


func _on_finished(player: Node) -> void:
	_voices -= 1
	player.queue_free()


func _stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var path := "res://audio/%s.wav" % sound
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sound]
