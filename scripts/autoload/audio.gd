extends Node
## Звуки (автозагрузка Audio). Файлы лежат в res://audio/<имя>.wav.
##   Audio.play("pistol")                 — звук «у уха» игрока (интерфейс, свои выстрелы)
##   Audio.play_at("enemy_shot", позиция) — звук в 3D-пространстве

const MAX_VOICES := 24

var _cache := {}
var _voices := 0


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
