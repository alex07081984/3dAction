class_name Rain
extends Node3D
## Дождь вокруг камеры: капли-штрихи, брызги на земле и шум дождя.
## Под крышей (в домах) капли не идут и шум тише.
## С snow = true вместо дождя медленно падает снег и воет ветер (Аляска).

@export var amount := 600
@export var area := 16.0
@export var volume_db := -13.0
@export var snow := false

var _drops: CPUParticles3D
var _splashes: CPUParticles3D
var _sound: AudioStreamPlayer
var _check := 0.0
var _covered := false


func _ready() -> void:
	amount = maxi(roundi(amount * Game.particle_density()), 100)
	if snow:
		_make_snow()
		return
	_drops = _particles(Vector3(0.015, 0.55, 0.015), Color(0.75, 0.8, 0.9, 0.35), amount)
	_drops.lifetime = 0.9
	_drops.emission_box_extents = Vector3(area, 0.5, area)
	_drops.direction = Vector3(0.08, -1, 0)
	_drops.spread = 2.0
	_drops.initial_velocity_min = 16.0
	_drops.initial_velocity_max = 20.0
	_drops.gravity = Vector3.ZERO
	_splashes = _particles(Vector3(0.06, 0.03, 0.06), Color(0.8, 0.85, 0.95, 0.45), 160)
	_splashes.lifetime = 0.3
	_splashes.emission_box_extents = Vector3(area * 0.8, 0.0, area * 0.8)
	_splashes.direction = Vector3.UP
	_splashes.spread = 35.0
	_splashes.initial_velocity_min = 0.6
	_splashes.initial_velocity_max = 1.3
	_splashes.gravity = Vector3(0, -6, 0)
	_start_sound("res://audio/rain.wav")


## Снежинки: крупнее и медленнее капель, кружатся и сносятся ветром.
func _make_snow() -> void:
	_drops = _particles(Vector3(0.06, 0.06, 0.06), Color(0.95, 0.97, 1.0, 0.85), amount)
	_drops.lifetime = 5.0
	_drops.preprocess = 5.0
	_drops.emission_box_extents = Vector3(area * 1.2, 4.0, area * 1.2)
	_drops.direction = Vector3(0.35, -1, 0.1)
	_drops.spread = 25.0
	_drops.initial_velocity_min = 1.2
	_drops.initial_velocity_max = 2.4
	_drops.gravity = Vector3.ZERO
	_drops.angular_velocity_min = -180.0
	_drops.angular_velocity_max = 180.0
	_drops.scale_amount_min = 0.6
	_drops.scale_amount_max = 1.4
	_splashes = _particles(Vector3(0.02, 0.02, 0.02), Color(1, 1, 1, 0.0), 1)
	_splashes.emitting = false
	_start_sound("res://audio/wind.wav")


func _start_sound(path: String) -> void:
	var source := load(path) as AudioStreamWAV
	if source:
		var stream := source.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.data.size() / 2)
		_sound = AudioStreamPlayer.new()
		_sound.stream = stream
		_sound.volume_db = volume_db
		add_child(_sound)
		_sound.play()


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var ahead := camera.global_position - camera.global_basis.z * 6.0
	_drops.global_position = ahead + Vector3.UP * (5.0 if snow else 9.0)
	_splashes.global_position = Vector3(ahead.x, 0.03, ahead.z)
	_check -= delta
	if _check <= 0.0:
		_check = 0.3
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + Vector3.UP * 30.0, 1)
		var covered := not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		if covered != _covered:
			_covered = covered
			_drops.emitting = not covered
			_splashes.emitting = not covered and not snow
			if _sound:
				create_tween().tween_property(_sound, "volume_db", volume_db - (10.0 if covered else 0.0), 0.5)


func is_raining_here() -> bool:
	return _drops.emitting


func _particles(size: Vector3, color: Color, count: int) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	mesh.material = material
	particles.mesh = mesh
	particles.amount = count
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(particles)
	particles.emitting = true
	return particles
