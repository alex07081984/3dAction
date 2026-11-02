class_name HeliLevel
extends Level
## Уровень на вертолёте: герой стоит у пулемёта в открытой двери, вертолёт летит сам
## по точкам из узла Flight. На точке с метаданными zone он зависает, развернувшись
## дверью к цели, пока не зачищено место с волнами; на точке boss вылетает боевой
## вертолёт. Победа над ним завершает уровень. Если героя давно не ранили,
## он понемногу перевязывается (аптечка в кабине).

## Слой 6: невидимые стенки кабины (Helicopter/CameraShell), в них упирается только камера.
const CABIN_CAMERA_LAYER := 32

@export var cruise_speed := 15.0
@export var door_limit_deg := 85.0  ## Насколько можно отвернуться от двери.

var _heli: Node3D
var _rotor: Node3D
var _points: Array[Node] = []
var _index := 0
var _speed := 0.0
var _yaw := 0.0
var _bob := 0.0
var _calm := 0.0
var _hp_seen := 0
var _boss: AttackHelicopter
var _sound: AudioStreamPlayer


func _ready() -> void:
	super._ready()
	_heli = $Helicopter
	_rotor = $Helicopter/Rotor
	_points = $Flight.get_children()
	_yaw = _heli.rotation.y
	_boss = get_node_or_null("AttackHelicopter") as AttackHelicopter
	# Камера держится внутри кабины: за спиной героя стенка, сверху крыша.
	player.mount_to($Helicopter/Seat, 2.0)
	player.camera_rig.set_obstacle_mask(1 | CABIN_CAMERA_LAYER, 0.15)
	player.camera_rig.set_yaw(_door_yaw())
	hud.set_mounted(true)
	_hp_seen = player.health
	player.health_changed.connect(_on_health)
	var stream := load("res://audio/helicopter.wav") as AudioStreamWAV
	if stream:
		var loop := stream.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = int(loop.data.size() / 2)
		_sound = AudioStreamPlayer.new()
		_sound.stream = loop
		_sound.volume_db = -10.0
		add_child(_sound)
		_sound.play()


## Сколько точек маршрута пройдено (для тестов и отладки).
func get_waypoint_index() -> int:
	return _index


## Перенести вертолёт к точке маршрута (тесты).
func jump_to_waypoint(index: int) -> void:
	_index = clampi(index, 0, _points.size() - 1)
	_heli.global_position = (_points[_index] as Node3D).global_position
	_speed = 0.0
	_heli.reset_physics_interpolation()


func is_hovering() -> bool:
	return _speed < 0.5 and _index < _points.size()


func _physics_process(delta: float) -> void:
	_rotor.rotate_y(30.0 * delta)
	_bob += delta
	var target_yaw := _yaw
	var focus := Vector3.INF
	if _index < _points.size():
		var point := _points[_index] as Node3D
		var to := point.global_position - _heli.global_position
		var distance := to.length()
		if distance < 1.0:
			var hold := _hold_reason(point)
			if hold.is_finite():
				focus = hold
				_speed = 0.0
			else:
				_index += 1
		else:
			# Разгон и торможение у точек, где надо зависнуть.
			var wanted := float(point.get_meta("speed", cruise_speed))
			if point.has_meta("zone") or point.has_meta("boss"):
				wanted = minf(wanted, maxf(distance * 0.8, 3.0))
			_speed = move_toward(_speed, wanted, 6.0 * delta)
			_heli.global_position += to / distance * minf(_speed * delta, distance)
			target_yaw = atan2(-to.x, -to.z)
	if focus.is_finite():
		# Зависли: разворачиваемся дверью (правым бортом) к цели.
		var to_focus := focus - _heli.global_position
		target_yaw = atan2(-to_focus.x, -to_focus.z) + PI / 2.0
	var previous := _yaw
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-1.1 * delta))
	var turn := wrapf(_yaw - previous, -PI, PI)
	_heli.rotation = Vector3(-_speed * 0.006 + sin(_bob * 1.3) * 0.02, _yaw,
			clampf(-turn / maxf(delta, 0.001) * 0.25, -0.25, 0.25) + sin(_bob * 0.9) * 0.015)
	# Камера поворачивается вместе с вертолётом и не уходит за кабину.
	var rig := player.camera_rig
	var relative := wrapf(rig.get_yaw() + turn - _door_yaw(), -PI, PI)
	var limit := deg_to_rad(door_limit_deg)
	rig.set_yaw(_door_yaw() + clampf(relative, -limit, limit))
	_heal(delta)


## Почему вертолёт висит на этой точке: центр зоны с волнами или боевой вертолёт.
func _hold_reason(point: Node3D) -> Vector3:
	if point.has_meta("zone"):
		var zone := get_node_or_null(point.get_meta("zone")) as WaveZone
		if zone and not zone.done:
			if not zone.active and is_instance_valid(player) and player.is_alive():
				zone.start()
			return (zone.get_node("Spawns") as Node3D).global_position if zone.has_node("Spawns") else zone.global_position
	if point.has_meta("boss") and is_instance_valid(_boss) and not _boss.defeated:
		_boss.activate()
		return _boss.global_position
	return Vector3.INF


func _door_yaw() -> float:
	return _yaw - PI / 2.0


func _heal(delta: float) -> void:
	_calm += delta
	if _calm > 5.0 and player.is_alive() and player.health < player.max_health:
		_calm = 4.0
		_hp_seen = mini(player.health + 4, player.max_health)
		player.health = _hp_seen
		player.health_changed.emit(player.health, player.max_health)


func _on_health(current: int, _maximum: int) -> void:
	if current < _hp_seen:
		_calm = 0.0
	_hp_seen = current


## Боевой вертолёт сбит — уровень пройден.
func on_vehicle_destroyed(_vehicle: Node) -> void:
	Audio.play_music("music_explore")
	get_tree().create_timer(3.0, false).timeout.connect(complete)
