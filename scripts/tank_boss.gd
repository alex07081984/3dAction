class_name TankBoss
extends CharacterBody3D
## Босс «Танк» (радарная станция на Аляске). Ездит по площадке между точками TankPath,
## башня следит за героем. Перед выстрелом пушки — красный лазер: самое время сделать рывок.
## Вблизи бьёт из пулемёта, а если стоять перед ним — задавит.
## Броня: спереди пули почти не берут, с боков — вполсилы, в корму — больнее.
## РПГ, гранаты, бочки и цистерны бьют в полную силу. Три фазы: с каждой дымит сильнее,
## приходит подмога; в конце башню срывает взрывом.

signal destroyed(tank: TankBoss)

const WORLD_MASK := 1
const PLAYER_MASK := 2

@export var boss_name := "Танк"
@export var phases := 3
@export var phase_health := 850.0
@export var reward := 1200
@export var completes_level := true
@export var move_speed := 3.2
@export var shell_damage := 35
@export var gun_damage := 4
@export var path_points: NodePath  ## Узел с Marker3D — куда ездит танк.
@export var henchman_points: NodePath  ## Узел с Marker3D — откуда приходит подмога.
@export var henchman_scene: PackedScene
@export var heavy_scene: PackedScene

var active := false
var defeated := false
var phase := 1
var health := 0.0

var _player: Player
var _phase_max := 0.0
var _turret: Node3D
var _barrel_tip: Node3D
var _mg: Node3D
var _laser: MeshInstance3D
var _target_index := 0
var _wait := 0.0
var _stuck := 0.0
var _last_position := Vector3.ZERO
var _cannon_timer := 3.0
var _aim_left := 0.0
var _gun_timer := 2.0
var _burst_left := 0
var _burst_timer := 0.0
var _transition := 0.0
var _crush_cooldown := 0.0
var _hint_shown := false
var _smoke: Array[Node3D] = []
var _sound: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("vehicles")
	add_to_group("bosses")
	collision_layer = 4
	collision_mask = 1
	_phase_max = phase_health * Game.enemy_health_multiplier()
	health = _phase_max
	shell_damage = roundi(shell_damage * Game.enemy_damage_multiplier())
	gun_damage = roundi(gun_damage * Game.enemy_damage_multiplier())
	_build()


func get_phase_fraction() -> float:
	return clampf(health / maxf(_phase_max, 1.0), 0.0, 1.0)


## Бой начинается: полоса здоровья, музыка, танк выезжает.
func activate() -> void:
	if active or defeated:
		return
	active = true
	_player = get_tree().get_first_node_in_group("player") as Player
	_hud("show_message", boss_name + "!", "Бейте в корму или из РПГ, от выстрела пушки — рывок")
	Audio.play_music("music_combat")
	Audio.play_at("explosion", global_position, 0.0, 0.5)
	if _sound:
		_sound.play()
	_update_bar()


## Пуля: броня зависит от того, куда попали (перед, бок, корма).
func take_hit(damage: float, point: Vector3, direction: Vector3) -> void:
	if defeated:
		return
	if not active:
		activate()
	var local := global_basis.inverse() * (point - global_position)
	var armor := 0.6
	if local.z < -1.6:
		armor = 0.3
	elif local.z > 1.6:
		armor = 1.5
	Fx.sparks(point, -direction)
	if armor < 0.5 and not _hint_shown:
		_hint_shown = true
		_hud("show_toast", "Лоб танка пули не берут — заходите в корму или берите РПГ")
	_damage(damage * armor)


## Взрыв (РПГ, граната, бочка, цистерна) — в полную силу.
func take_blast(damage: float, _origin: Vector3, _direction: Vector3) -> void:
	if defeated:
		return
	if not active:
		activate()
	_damage(damage)


func _damage(amount: float) -> void:
	if _transition > 0.0:
		return
	health -= amount
	if health <= 0.0:
		if phase < phases:
			_next_phase()
		else:
			_die()
			return
	_update_bar()


func _physics_process(delta: float) -> void:
	if defeated:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		return
	if not active:
		if _player.is_alive() and global_position.distance_to(_player.global_position) < 70.0 and _sees_player():
			activate()
		_apply_gravity(delta)
		move_and_slide()
		return
	_transition -= delta
	_crush_cooldown -= delta
	_drive(delta)
	_aim_turret(delta)
	if _player.is_alive():
		_cannon(delta)
		_machine_gun(delta)
		_crush()
	else:
		_show_laser(false)


# --- Езда --------------------------------------------------------------------------

func _drive(delta: float) -> void:
	var holder := get_node_or_null(path_points)
	var points := holder.get_children() if holder else []
	_apply_gravity(delta)
	if points.is_empty() or _wait > 0.0:
		_wait -= delta
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		move_and_slide()
		return
	var target := (points[_target_index % points.size()] as Node3D).global_position
	var to := target - global_position
	to.y = 0.0
	if to.length() < 2.0:
		_next_point(points.size())
		return
	# Корпус поворачивается медленно, едет туда, куда смотрит.
	var wanted := atan2(-to.x, -to.z)
	rotation.y = rotate_toward(rotation.y, wanted, deg_to_rad(40.0 + 10.0 * phase) * delta)
	var facing := absf(wrapf(wanted - rotation.y, -PI, PI)) < 0.5
	var forward := -global_basis.z
	var speed := move_speed * (1.0 + 0.25 * (phase - 1)) if facing else 0.0
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	move_and_slide()
	# Упёрся — едем к другой точке.
	_stuck += delta
	if _stuck > 2.0:
		if global_position.distance_to(_last_position) < 1.0 and facing:
			_next_point(points.size())
		_stuck = 0.0
		_last_position = global_position


func _next_point(count: int) -> void:
	_target_index = (_target_index + 1 + randi() % maxi(count - 1, 1)) % count
	_wait = randf_range(0.6, 1.6)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = 0.0


func _aim_turret(delta: float) -> void:
	var to := _player.global_position - _turret.global_position
	var wanted := atan2(-to.x, -to.z) - rotation.y
	_turret.rotation.y = rotate_toward(_turret.rotation.y, wanted, deg_to_rad(45.0 + 15.0 * phase) * delta)


func _turret_on_target() -> bool:
	var to := _player.global_position - _turret.global_position
	var aim := -_turret.global_basis.z
	return Vector2(aim.x, aim.z).angle_to(Vector2(to.x, to.z)) < 0.08


func _sees_player() -> bool:
	var from := global_position + Vector3.UP * 2.5
	var to := _player.global_position + Vector3.UP * 1.3
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK, [get_rid()])).is_empty()


func _cannon(delta: float) -> void:
	if _aim_left > 0.0:
		_aim_left -= delta
		_show_laser(true)
		if _aim_left <= 0.0:
			_fire_shell()
		return
	_show_laser(false)
	_cannon_timer -= delta
	if _cannon_timer <= 0.0 and _transition <= 0.0 and _turret_on_target() and _sees_player():
		_cannon_timer = randf_range(4.5, 6.0) - 0.8 * (phase - 1)
		_aim_left = 1.2 - 0.15 * (phase - 1)


func _fire_shell() -> void:
	_show_laser(false)
	var from := _barrel_tip.global_position
	var target := _player.global_position + Vector3.UP * 0.8
	# Снаряд ранит героя и поджигает бочки рядом, а своих (и сам танк) не трогает.
	Rocket.launch(get_parent(), from, target - from, 45.0, 4.5, 0.0, shell_damage, self, true)
	Fx.muzzle_flash(from, (target - from).normalized())
	Fx.smoke_cloud(from)
	Audio.play_at("explosion", from, 2.0, 1.4)
	if is_instance_valid(_player):
		_player.camera_rig.shake(0.35)
	# Откат ствола.
	var tween := _turret.create_tween()
	tween.tween_property(_turret, "position:z", 0.5, 0.05)
	tween.tween_property(_turret, "position:z", 0.0, 0.4)


func _machine_gun(delta: float) -> void:
	var distance := global_position.distance_to(_player.global_position)
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_timer = 0.09
			_burst_left -= 1
			_fire_mg()
		return
	_gun_timer -= delta
	if _gun_timer <= 0.0 and distance < 28.0 and _sees_player():
		_gun_timer = randf_range(2.0, 3.0)
		_burst_left = 6 + 2 * phase


func _fire_mg() -> void:
	var muzzle := _mg.global_position
	var target := _player.global_position + Vector3.UP * 1.2
	var will_hit := randf() < 0.45 and not _player.is_dodging()
	var aim := target if will_hit else target + Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 1.0), randf_range(-1.5, 1.5))
	var direction := (aim - muzzle).normalized()
	var end := muzzle + direction * 60.0
	var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(muzzle, end, WORLD_MASK | PLAYER_MASK, [get_rid()]))
	if hit:
		end = hit.position
		if hit.collider is Player and will_hit:
			(hit.collider as Player).take_damage(gun_damage, global_position)
		elif not hit.collider is Player:
			Fx.sparks(end, hit.normal)
	Fx.tracer(muzzle, end, Color(1.0, 0.45, 0.25))
	Audio.play_at("rifle", muzzle, 0.0, 0.85)


## Стоять перед едущим танком — значит попасть под гусеницы.
func _crush() -> void:
	if _crush_cooldown > 0.0 or Vector2(velocity.x, velocity.z).length() < 0.8:
		return
	var local := global_basis.inverse() * (_player.global_position - global_position)
	if absf(local.x) < 2.3 and local.z > -4.2 and local.z < 3.4 and absf(local.y) < 2.0:
		_crush_cooldown = 1.2
		_player.take_damage(roundi(30 * Game.enemy_damage_multiplier()), global_position)
		var away := (_player.global_position - global_position)
		away.y = 0.0
		_player.knockback(away.normalized() * 10.0 + Vector3.UP * 4.0)
		_hud("show_toast", "Не стойте перед танком!")


# --- Фазы и гибель ----------------------------------------------------------------------

func _next_phase() -> void:
	phase += 1
	health = _phase_max
	_transition = 1.4
	_aim_left = 0.0
	_show_laser(false)
	var spot := Vector3(0.9 if phase == 2 else -0.9, 1.6, 2.2)
	_smoke.append(Fx.fire(self, spot, 1.0 if phase >= 3 else 0.6, phase >= 3))
	Fx.explosion(global_transform * spot, 3.0)
	Game.slow_motion(0.5, 0.3)
	_hud("show_message", "%s подбит!" % boss_name, "Фаза %d из %d · подмога!" % [phase, phases])
	_spawn_henchmen()
	_update_bar()


func _spawn_henchmen() -> void:
	var holder := get_node_or_null(henchman_points)
	if holder == null or henchman_scene == null:
		return
	var points := holder.get_children()
	var count := 2 + phase + Game.current_tier
	for i in count:
		var scene := heavy_scene if i == 0 and phase >= phases and heavy_scene else henchman_scene
		var point := points[i % points.size()] as Node3D
		var henchman := scene.instantiate() as Enemy
		henchman.alerted = true
		henchman.hold_position = false
		henchman.drop_health_chance = 0.5
		henchman.drop_ammo_chance = 0.45
		get_parent().add_child(henchman)
		henchman.global_position = point.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		henchman.reset_physics_interpolation()


func _die() -> void:
	defeated = true
	active = false
	_show_laser(false)
	velocity = Vector3.ZERO
	var bonus := roundi(reward * Game.reward_multiplier())
	Game.add_money(bonus)
	Game.slow_motion(1.4, 0.2)
	_hud("hide_boss")
	_hud("show_message", "%s уничтожен!" % boss_name, "Премия: $%d" % bonus)
	get_tree().call_group("level", "register_kill", false)
	Fx.explosion(global_position + Vector3.UP * 1.5, 8.0)
	Audio.play_at("explosion", global_position, 10.0, 0.7)
	# Башню срывает и подбрасывает, корпус горит.
	var start := _turret.position
	var tween := _turret.create_tween()
	tween.tween_property(_turret, "position", start + Vector3(0.6, 6.0, 1.0), 0.6).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_turret, "rotation", Vector3(0.8, _turret.rotation.y + 2.5, 0.4), 0.6)
	tween.tween_property(_turret, "position", start + Vector3(2.5, -0.4, 3.0), 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: Fx.explosion(_turret.global_position, 4.0))
	var burnt := StandardMaterial3D.new()
	burnt.albedo_color = Color(0.07, 0.065, 0.06)
	for child in find_children("*", "MeshInstance3D", true, false):
		if child != _laser:
			(child as MeshInstance3D).material_override = burnt
	Fx.fire(self, Vector3(0, 1.8, 0), 2.0)
	if _sound:
		_sound.stop()
	destroyed.emit(self)
	get_tree().call_group("level", "on_vehicle_destroyed", self)


func _update_bar() -> void:
	if active and not defeated:
		_hud("update_boss", boss_name, get_phase_fraction(), phase, phases)


func _show_laser(on: bool) -> void:
	_laser.visible = on and is_instance_valid(_player)
	if not _laser.visible:
		return
	var from := _barrel_tip.global_position
	var to := _player.global_position + Vector3.UP * 1.0
	_laser.global_transform = Transform3D(Basis.looking_at(to - from), (from + to) * 0.5)
	_laser.scale = Vector3(1.6, 1.6, from.distance_to(to))
	if _aim_left < 0.35:
		_laser.visible = int(_aim_left * 30.0) % 2 == 0


func _hud(method: String, a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null) -> void:
	var args := [a, b, c, d].filter(func(value: Variant) -> bool: return value != null)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method(method):
		hud.callv(method, args)


# --- Модель --------------------------------------------------------------------------------

func _build() -> void:
	var hull_shape := CollisionShape3D.new()
	var hull_box := BoxShape3D.new()
	hull_box.size = Vector3(3.8, 1.6, 6.6)
	hull_shape.shape = hull_box
	hull_shape.position = Vector3(0, 1.0, 0)
	add_child(hull_shape)
	var turret_shape := CollisionShape3D.new()
	var turret_box := BoxShape3D.new()
	turret_box.size = Vector3(2.6, 1.0, 2.8)
	turret_shape.shape = turret_box
	turret_shape.position = Vector3(0, 2.3, 0.3)
	add_child(turret_shape)
	var camo := Color(0.22, 0.24, 0.18)
	var dark := Color(0.12, 0.12, 0.12)
	for part in [[Vector3(3.4, 1.0, 6.2), Vector3(0, 1.15, 0), camo],
			[Vector3(0.8, 1.0, 6.6), Vector3(-1.9, 0.55, 0), dark],
			[Vector3(0.8, 1.0, 6.6), Vector3(1.9, 0.55, 0), dark],
			[Vector3(3.4, 0.4, 1.0), Vector3(0, 1.3, -3.2), camo.darkened(0.15)],
			[Vector3(2.6, 0.5, 0.6), Vector3(0, 1.45, 3.2), Color(0.3, 0.3, 0.28)],
			[Vector3(0.6, 0.15, 0.6), Vector3(1.2, 1.7, 2.6), Color(0.85, 0.75, 0.3)]]:
		_add_mesh(self, part[0], part[1], part[2])
	for i in 6:
		_add_mesh(self, Vector3(0.85, 0.6, 0.6), Vector3(-1.9, 0.45, -2.5 + i), Color(0.2, 0.2, 0.2))
		_add_mesh(self, Vector3(0.85, 0.6, 0.6), Vector3(1.9, 0.45, -2.5 + i), Color(0.2, 0.2, 0.2))
	_turret = Node3D.new()
	_turret.name = "Turret"
	_turret.position = Vector3.ZERO
	add_child(_turret)
	_add_mesh(_turret, Vector3(2.4, 0.9, 2.6), Vector3(0, 2.1, 0.3), camo.darkened(0.08))
	_add_mesh(_turret, Vector3(1.0, 0.3, 1.0), Vector3(0.5, 2.7, 0.8), camo.darkened(0.2))
	_add_mesh(_turret, Vector3(0.28, 0.28, 3.8), Vector3(0, 2.15, -2.8), dark)
	_add_mesh(_turret, Vector3(0.42, 0.42, 0.5), Vector3(0, 2.15, -4.6), dark)
	_add_mesh(_turret, Vector3(0.12, 0.12, 1.0), Vector3(-0.6, 2.85, 0.2), dark)
	var star := Label3D.new()
	star.text = "БАНДА"
	star.pixel_size = 0.008
	star.font_size = 48
	star.modulate = Color(0.75, 0.08, 0.05)
	star.position = Vector3(1.22, 2.1, 0.3)
	star.rotation.y = PI / 2
	_turret.add_child(star)
	_barrel_tip = Node3D.new()
	_barrel_tip.position = Vector3(0, 2.15, -5.0)
	_turret.add_child(_barrel_tip)
	_mg = Node3D.new()
	_mg.position = Vector3(-0.6, 2.85, -0.4)
	_turret.add_child(_mg)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.9, 0.7)
	lamp.light_energy = 2.0
	lamp.omni_range = 9.0
	lamp.position = Vector3(0, 3.2, 0)
	add_child(lamp)
	# Фары: видно издалека, куда едет танк.
	for x in [-1.2, 1.2]:
		var headlight := MeshInstance3D.new()
		var lens := BoxMesh.new()
		lens.size = Vector3(0.45, 0.3, 0.1)
		var bright := StandardMaterial3D.new()
		bright.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bright.albedo_color = Color(1, 0.95, 0.8)
		lens.material = bright
		headlight.mesh = lens
		headlight.position = Vector3(x, 1.4, -3.75)
		add_child(headlight)
	var beam_light := SpotLight3D.new()
	beam_light.light_color = Color(1.0, 0.95, 0.85)
	beam_light.light_energy = 5.0
	beam_light.spot_range = 40.0
	beam_light.spot_angle = 30.0
	beam_light.position = Vector3(0, 1.6, -3.9)
	beam_light.rotation.x = -0.15
	add_child(beam_light)
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
	var stream := load("res://audio/engine.wav") as AudioStreamWAV
	if stream:
		var loop := stream.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = int(loop.data.size() / 2)
		_sound = AudioStreamPlayer3D.new()
		_sound.stream = loop
		_sound.pitch_scale = 0.55
		_sound.volume_db = 6.0
		_sound.unit_size = 14.0
		add_child(_sound)


static func _add_mesh(parent: Node3D, size: Vector3, center: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	material.metallic = 0.3
	box.material = material
	mesh.mesh = box
	mesh.position = center
	parent.add_child(mesh)
	return mesh
