class_name AttackHelicopter
extends CharacterBody3D
## Босс «Боевой вертолёт»: кружит вокруг вертолёта героя, поливает очередями
## (перед очередью — красный лазер) и пускает ракетные залпы. Ракеты мигают и пищат,
## их можно сбить пулемётом. Три фазы: с каждой дымит сильнее и злее стреляет,
## в конце, горя и вращаясь, падает в залив.

signal destroyed(heli: AttackHelicopter)

const WORLD_MASK := 1
const PLAYER_MASK := 2

@export var boss_name := "Боевой вертолёт"
@export var phases := 3
@export var phase_health := 1300.0
@export var reward := 900
@export var orbit_radius := 32.0
@export var gun_damage := 5
@export var missile_damage := 20
@export_range(0.0, 1.0) var accuracy := 0.55

var active := false
var defeated := false
var phase := 1
var health := 0.0

var _player: Player
var _orbit := 0.0
var _orbit_dir := 1.0
var _time := 0.0
var _gun_timer := 2.5
var _aim_left := 0.0
var _burst_left := 0
var _burst_timer := 0.0
var _missile_timer := 7.0
var _flip_timer := 9.0
var _transition := 0.0
var _falling := false
var _fall_time := 0.0
var _phase_max := 0.0
var _rotor: Node3D
var _tail_rotor: Node3D
var _gun: Node3D
var _laser: MeshInstance3D
var _smoke: Array[Node3D] = []
var _sound: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("vehicles")
	collision_layer = 4
	collision_mask = 0
	_phase_max = phase_health * Game.enemy_health_multiplier()
	health = _phase_max
	gun_damage = roundi(gun_damage * Game.enemy_damage_multiplier())
	missile_damage = roundi(missile_damage * Game.enemy_damage_multiplier())
	_build()
	visible = false
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Босс вылетает: показывается полоса здоровья, начинается бой.
func activate() -> void:
	if active or defeated:
		return
	active = true
	visible = true
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		var away := global_position - _player.global_position
		_orbit = atan2(away.z, away.x)
	if _sound:
		_sound.play()
	_hud("show_message", boss_name, "Босс! Сбивайте его ракеты очередью")
	_update_bar()
	Audio.play_music("music_combat")


func take_hit(damage: float, point: Vector3, direction: Vector3) -> void:
	if not active or defeated:
		return
	Fx.sparks(point, -direction)
	if _transition > 0.0:
		return
	health -= damage
	if health <= 0.0:
		if phase < phases:
			_next_phase()
		else:
			_die()
			return
	_update_bar()


func get_phase_fraction() -> float:
	return clampf(health / maxf(_phase_max, 1.0), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_time += delta
	if _rotor:
		_rotor.rotate_y(32.0 * delta)
		_tail_rotor.rotate_x(40.0 * delta)
	if _falling:
		_fall(delta)
		return
	if not active or not is_instance_valid(_player):
		return
	_transition -= delta
	_fly(delta)
	if not _player.is_alive():
		_show_laser(false)
		return
	_shoot_logic(delta)
	_missile_logic(delta)


# --- Полёт ----------------------------------------------------------------------

func _fly(delta: float) -> void:
	_flip_timer -= delta
	if _flip_timer <= 0.0:
		_flip_timer = randf_range(7.0, 11.0)
		_orbit_dir = -_orbit_dir
	_orbit += _orbit_dir * (0.22 + 0.05 * phase) * delta
	var center := _player.global_position
	var radius := orbit_radius + 6.0 * sin(_time * 0.5)
	var goal := center + Vector3(cos(_orbit), 0.0, sin(_orbit)) * radius + Vector3.UP * (6.0 + 4.0 * sin(_time * 0.7))
	var previous := global_position
	global_position = global_position.lerp(goal, 1.0 - exp(-0.9 * delta))
	var motion := (global_position - previous) / maxf(delta, 0.001)
	# Нос смотрит на героя, корпус наклоняется по ходу движения.
	var to_player := center - global_position
	var yaw := atan2(-to_player.x, -to_player.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-3.0 * delta))
	var local := global_basis.inverse() * motion
	rotation.x = lerpf(rotation.x, clampf(-local.z * 0.02, -0.3, 0.3), 1.0 - exp(-3.0 * delta))
	rotation.z = lerpf(rotation.z, clampf(-local.x * 0.03, -0.35, 0.35), 1.0 - exp(-3.0 * delta))


func _fall(delta: float) -> void:
	_fall_time += delta
	rotate_y(5.0 * delta)
	global_position += Vector3(0, -9.0 - _fall_time * 6.0, 0) * delta
	if global_position.y <= 1.0 or _fall_time > 3.5:
		_falling = false
		Fx.explosion(global_position, 10.0)
		Fx.explosion(global_position + Vector3(2, 1, 0), 6.0)
		Audio.play_at("explosion", global_position, 10.0, 0.7)
		if is_instance_valid(_player):
			_player.camera_rig.shake(0.8)
		visible = false
		destroyed.emit(self)
		get_tree().call_group("level", "on_vehicle_destroyed", self)
		queue_free()


# --- Пулемёт и ракеты ----------------------------------------------------------------

func _shoot_logic(delta: float) -> void:
	if _burst_left > 0:
		_burst_timer -= delta
		_show_laser(false)
		if _burst_timer <= 0.0:
			_burst_timer = 0.08
			_burst_left -= 1
			_fire_gun()
		return
	if _aim_left > 0.0:
		_aim_left -= delta
		_show_laser(true)
		if _aim_left <= 0.0:
			_burst_left = 6 + 2 * phase
			_burst_timer = 0.0
		return
	_show_laser(false)
	_gun_timer -= delta
	if _gun_timer <= 0.0 and _transition <= 0.0:
		_gun_timer = randf_range(2.6, 3.6) - 0.4 * phase
		_aim_left = 0.9


func _fire_gun() -> void:
	var muzzle := _gun.global_position
	var target := _player.global_position + Vector3.UP * 1.2
	var distance := muzzle.distance_to(target)
	var will_hit := randf() < accuracy * clampf(1.25 - distance / 70.0, 0.3, 1.0)
	var aim := target
	if not will_hit:
		var side := (target - muzzle).cross(Vector3.UP).normalized()
		aim += side * randf_range(1.0, 2.5) * (1.0 if randf() < 0.5 else -1.0) + Vector3.UP * randf_range(-1.0, 1.5)
	var direction := (aim - muzzle).normalized()
	var end := muzzle + direction * 120.0
	var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(muzzle, end, WORLD_MASK | PLAYER_MASK, [get_rid()]))
	if hit:
		end = hit.position
		if hit.collider is Player and will_hit:
			(hit.collider as Player).take_damage(gun_damage, global_position)
		elif not (hit.collider is Player):
			Fx.sparks(end, hit.normal)
	Fx.tracer(muzzle, end, Color(1.0, 0.45, 0.25))
	Fx.muzzle_flash(muzzle, direction)
	Audio.play_at("rifle", muzzle, 2.0, 0.8)


func _missile_logic(delta: float) -> void:
	_missile_timer -= delta
	if _missile_timer > 0.0 or _transition > 0.0:
		return
	_missile_timer = randf_range(7.5, 9.0) - phase
	var count := 1 + phase
	var parent := get_parent()
	for i in count:
		get_tree().create_timer(0.35 * i, false).timeout.connect(_launch_missile.bind(parent, i))
	_hud("show_toast", "Ракеты! Сбейте их очередью")


func _launch_missile(parent: Node, index: int) -> void:
	if not active or defeated or not is_instance_valid(_player):
		return
	var side := 1.6 if index % 2 == 0 else -1.6
	var from := global_transform * Vector3(side, -0.6, -1.0)
	var target := _player.global_position + Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 2.0), randf_range(-1.5, 1.5))
	Rocket.launch(parent, from, target - from, 22.0, 3.5, 0.0, missile_damage, self, true)


# --- Фазы ---------------------------------------------------------------------------

func _next_phase() -> void:
	phase += 1
	health = _phase_max
	_transition = 1.2
	_aim_left = 0.0
	_burst_left = 0
	_show_laser(false)
	accuracy = minf(accuracy + 0.06, 0.85)
	# С каждой фазой дымит сильнее, а потом и горит.
	var spot := Vector3(0.8 if phase == 2 else -0.8, 0.9, 1.2)
	_smoke.append(Fx.fire(self, spot, 1.2 if phase >= 3 else 0.7, phase >= 3))
	Fx.explosion(global_transform * spot, 3.0)
	Game.slow_motion(0.5, 0.3)
	_hud("show_message", "%s подбит!" % boss_name, "Фаза %d из %d" % [phase, phases])
	_update_bar()


func _die() -> void:
	defeated = true
	active = false
	_falling = true
	_show_laser(false)
	var bonus := roundi(reward * Game.reward_multiplier())
	Game.add_money(bonus)
	_smoke.append(Fx.fire(self, Vector3(0, 0.8, 0), 1.8))
	Fx.explosion(global_position, 5.0)
	Game.slow_motion(1.4, 0.2)
	_hud("hide_boss")
	_hud("show_message", "%s сбит!" % boss_name, "Премия: $%d" % bonus)
	get_tree().call_group("level", "register_kill", false)


func _update_bar() -> void:
	if active and not defeated:
		_hud("update_boss", boss_name, get_phase_fraction(), phase, phases)


func _show_laser(on: bool) -> void:
	_laser.visible = on and is_instance_valid(_player)
	if not _laser.visible:
		return
	var from := _gun.global_position
	var to := _player.global_position + Vector3.UP * 1.2
	var length := from.distance_to(to)
	_laser.global_transform = Transform3D(Basis.looking_at(to - from), (from + to) * 0.5)
	_laser.scale = Vector3(1.0, 1.0, length)
	if _aim_left < 0.3:
		_laser.visible = int(_aim_left * 30.0) % 2 == 0


func _hud(method: String, a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null) -> void:
	var args := [a, b, c, d].filter(func(value: Variant) -> bool: return value != null)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method(method):
		hud.callv(method, args)


# --- Модель --------------------------------------------------------------------------

func _build() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 2.4, 9.0)
	shape.shape = box
	shape.position = Vector3(0, 0.4, 0.8)
	add_child(shape)
	var dark := Color(0.32, 0.34, 0.3)
	var glass := Color(0.05, 0.07, 0.09)
	var parts := [
		[Vector3(1.8, 1.7, 4.2), Vector3(0, 0.5, 0), dark],  # фюзеляж
		[Vector3(1.4, 1.1, 1.6), Vector3(0, 0.75, -2.6), glass],  # кабина
		[Vector3(0.5, 0.6, 5.0), Vector3(0, 0.8, 4.4), dark],  # хвостовая балка
		[Vector3(0.15, 1.6, 1.2), Vector3(0, 1.5, 6.6), dark],  # киль
		[Vector3(4.2, 0.15, 0.9), Vector3(0, 0.1, 0.2), dark],  # крылышки
		[Vector3(0.45, 0.45, 1.6), Vector3(1.9, -0.15, 0.2), Color(0.3, 0.3, 0.28)],  # ракетные блоки
		[Vector3(0.45, 0.45, 1.6), Vector3(-1.9, -0.15, 0.2), Color(0.3, 0.3, 0.28)],
		[Vector3(0.12, 0.12, 2.6), Vector3(0.6, -0.55, 0), dark],  # полозья
		[Vector3(0.12, 0.12, 2.6), Vector3(-0.6, -0.55, 0), dark],
		[Vector3(0.6, 0.2, 0.2), Vector3(0, 1.45, 0), dark],  # втулка винта
	]
	for part in parts:
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = part[0]
		cube.material = _mat(part[2])
		mesh.mesh = cube
		mesh.position = part[1]
		add_child(mesh)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 1.6, 0)
	add_child(_rotor)
	for angle in [0.0, PI / 2]:
		var blade := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(11.0, 0.06, 0.4)
		cube.material = _mat(Color(0.08, 0.08, 0.08))
		blade.mesh = cube
		blade.rotation.y = angle
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rotor.add_child(blade)
	_tail_rotor = Node3D.new()
	_tail_rotor.position = Vector3(0.35, 1.5, 6.7)
	add_child(_tail_rotor)
	var tail_blade := MeshInstance3D.new()
	var tail_cube := BoxMesh.new()
	tail_cube.size = Vector3(0.05, 2.2, 0.25)
	tail_cube.material = _mat(Color(0.08, 0.08, 0.08))
	tail_blade.mesh = tail_cube
	_tail_rotor.add_child(tail_blade)
	_gun = Node3D.new()
	_gun.position = Vector3(0, -0.3, -3.6)
	add_child(_gun)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.18, 0.18, 1.0)
	barrel_mesh.material = _mat(Color(0.05, 0.05, 0.05))
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0, 0, 0.3)
	_gun.add_child(barrel)
	# Навигационные огни (красный и зелёный, мигают), освещённая кабина и прожектор —
	# чтобы ночью вертолёт было видно издалека.
	for side in [-1.0, 1.0]:
		var nav := MeshInstance3D.new()
		var dot := SphereMesh.new()
		dot.radius = 0.25
		dot.height = 0.5
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(1, 0.1, 0.1) if side < 0 else Color(0.2, 1, 0.3)
		dot.material = glow
		nav.mesh = dot
		nav.position = Vector3(2.2 * side, 0.1, 0.2)
		add_child(nav)
		var blink := nav.create_tween().set_loops()
		blink.tween_property(nav, "visible", false, 0.5)
		blink.tween_property(nav, "visible", true, 0.5)
	var cabin_glow := OmniLight3D.new()
	cabin_glow.light_color = Color(1.0, 0.3, 0.2)
	cabin_glow.light_energy = 2.5
	cabin_glow.omni_range = 9.0
	cabin_glow.position = Vector3(0, 0.2, -2.6)
	add_child(cabin_glow)
	var search := SpotLight3D.new()
	search.light_color = Color(1.0, 0.95, 0.85)
	search.light_energy = 6.0
	search.spot_range = 80.0
	search.spot_angle = 12.0
	search.position = Vector3(0, -0.7, -3.4)
	search.rotation.x = -0.35
	add_child(search)
	var lens := MeshInstance3D.new()
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.3
	lens_mesh.bottom_radius = 0.3
	lens_mesh.height = 0.15
	var bright := StandardMaterial3D.new()
	bright.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bright.albedo_color = Color(1, 1, 0.9)
	lens_mesh.material = bright
	lens.mesh = lens_mesh
	lens.position = Vector3(0, -0.7, -3.45)
	lens.rotation.x = PI / 2
	add_child(lens)
	_laser = MeshInstance3D.new()
	var beam := BoxMesh.new()
	beam.size = Vector3(0.04, 0.04, 1.0)
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1.0, 0.1, 0.1, 0.8)
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material = red
	_laser.mesh = beam
	_laser.top_level = true
	_laser.visible = false
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_laser)
	var stream := load("res://audio/helicopter.wav") as AudioStreamWAV
	if stream:
		var loop := stream.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = int(loop.data.size() / 2)
		_sound = AudioStreamPlayer3D.new()
		_sound.stream = loop
		_sound.volume_db = 4.0
		_sound.unit_size = 25.0
		add_child(_sound)


static func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	material.metallic = 0.3
	return material
