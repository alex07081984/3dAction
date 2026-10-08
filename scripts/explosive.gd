class_name Explosive
extends RigidBody3D
## Взрывоопасный предмет: красная бочка или газовый баллон.
## Бочка от слабой пули загорается и через пару секунд взрывается, от мощной — сразу.
## Пробитый баллон шипит, срывается с места, летит как ракета и взрывается.
## Взрыв ранит всех вокруг (и игрока!), отрывает руки и ноги и поджигает соседние бочки.

enum Kind { BARREL, CYLINDER }

const WORLD_MASK := 1

@export var kind := Kind.BARREL
@export var health := 25.0  ## Сколько урона выдерживает, прежде чем взорваться сразу.
@export var blast_radius := 6.0
@export var blast_damage := 150.0  ## Урон врагам в центре взрыва.
@export var player_damage := 45  ## Урон игроку в центре взрыва.
@export var fuse_time := 2.2  ## Сколько горит подстреленная бочка.
@export var leak_time := 0.45  ## Сколько баллон шипит, прежде чем сорваться с места.
@export var flight_time := 1.6  ## Сколько баллон летит до взрыва.
@export var thrust := 30.0  ## Ускорение улетающего баллона.

var exploded := false

var _burning := false
var _leaking := false
var _flying := false
var _timer := 0.0
var _effect: Node3D
var _flight_age := 0.0


func _ready() -> void:
	add_to_group("explosives")
	collision_layer = 1
	collision_mask = 1 | 8
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


## Попадание пули или дроби.
func take_hit(damage: float, point: Vector3, direction: Vector3) -> void:
	if exploded:
		return
	health -= damage
	if kind == Kind.BARREL:
		if health <= 0.0:
			explode()
		elif not _burning:
			_ignite(point)
	elif not _leaking and not _flying:
		_start_leak(point, direction)
	elif health <= -40.0:
		explode()


## Рядом рванул другой взрыв.
func chain_react(from: Vector3) -> void:
	if exploded:
		return
	if kind == Kind.CYLINDER and not _flying:
		_launch((global_position - from).normalized())
		_timer = minf(_timer, 0.9)
	else:
		explode()


func explode() -> void:
	if exploded or not is_inside_tree():
		return
	exploded = true
	var center := global_transform * Vector3(0, 0.45 if kind == Kind.BARREL else 0.5, 0)
	blast(self, center, blast_radius, blast_damage, player_damage)
	queue_free()


## Взрыв в точке: урон врагам и игроку, цепная реакция, разлёт обломков.
static func blast(source: Node3D, center: Vector3, radius: float, damage: float, damage_to_player: int) -> void:
	var tree := source.get_tree()
	Fx.explosion(center, radius)
	Audio.play_at("explosion", center, 6.0, 1.0, 0.1)
	var space := source.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for node in tree.get_nodes_in_group("explosives"):
		exclude.append((node as CollisionObject3D).get_rid())

	for node in tree.get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var target := enemy.global_position + Vector3.UP
		var distance := center.distance_to(target)
		if distance > radius or _blocked(space, center, target, exclude):
			continue
		var closeness := 1.0 - distance / radius
		enemy.apply_blast(damage * (0.25 + 0.75 * closeness), center, 5.0 + 9.0 * closeness)

	var player := tree.get_first_node_in_group("player") as Player
	if player and player.is_alive():
		var target := player.global_position + Vector3.UP
		var distance := center.distance_to(target)
		if distance < radius and not _blocked(space, center, target, exclude):
			player.take_damage(maxi(roundi(damage_to_player * (0.3 + 0.7 * (1.0 - distance / radius))), 1), center)
		if distance < radius * 4.0:
			player.camera_rig.shake(0.9 * (1.0 - distance / (radius * 4.0)))

	for node in tree.get_nodes_in_group("explosives"):
		var other := node as Explosive
		if other == null or other == source or other.exploded:
			continue
		var distance := center.distance_to(other.global_position)
		if distance < radius * 0.85:
			tree.create_timer(0.12 + distance * 0.05, false).timeout.connect(other.chain_react.bind(center))

	for body: RigidBody3D in BlockyCharacter.get_debris():
		var offset := body.global_position - center
		if offset.length() < radius and not body.freeze:
			body.apply_central_impulse((offset.normalized() + Vector3.UP * 0.6) * body.mass * 8.0 * (1.0 - offset.length() / radius))
	tree.call_group("enemies", "hear_noise", center, 35.0)


static func _blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK, exclude)
	return not space.intersect_ray(query).is_empty()


func _physics_process(delta: float) -> void:
	if exploded:
		return
	if _burning or _leaking or _flying:
		_timer -= delta
	if _leaking and _timer <= 0.0:
		_launch(-global_basis.z)
	elif _flying:
		_flight_age += delta
		# Тяга вдоль оси баллона, как у ракеты, и немного вращения — летит непредсказуемо.
		apply_central_force(global_basis.y * thrust * mass)
		apply_torque(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * mass * 0.6)
		if _timer <= 0.0:
			explode()
	elif _burning and _timer <= 0.0:
		explode()


func _ignite(point: Vector3) -> void:
	_burning = true
	_timer = fuse_time
	_effect = Fx.fire(self, Vector3(0, 1.0, 0))
	Audio.play_at("fire", global_position + Vector3.UP, -2.0)
	Fx.sparks(point, Vector3.UP)


func _start_leak(point: Vector3, direction: Vector3) -> void:
	_leaking = true
	_timer = leak_time
	_effect = Fx.gas_jet(self, Vector3(0, 1.3, 0), Vector3(0, 0.3, 1).normalized())
	Audio.play_at("hiss", global_position + Vector3.UP, 0.0)
	Fx.sparks(point, -direction)


func _launch(push: Vector3) -> void:
	if _flying:
		return
	_leaking = false
	_flying = true
	_timer = flight_time
	_flight_age = 0.0
	freeze = false
	collision_mask = 1 | 4 | 8
	if is_instance_valid(_effect):
		_effect.queue_free()
	# Сопло внизу: огонь бьёт назад, баллон летит вперёд (вверх по своей оси).
	var flames := Fx.fire(self, Vector3(0, -0.1, 0), 0.6, false)
	flames.rotation.x = PI
	_effect = flames
	push.y = 0.0
	apply_central_impulse((push.normalized() * 2.0 + Vector3.UP * 3.0) * mass)
	angular_velocity = Vector3(randf_range(-3, 3), randf_range(-2, 2), randf_range(-3, 3))
	Audio.play_at("hiss", global_position + Vector3.UP, 4.0, 1.4)


func _on_body_entered(body: Node) -> void:
	if _flying and _flight_age > 0.25 and (linear_velocity.length() > 5.0 or body is Enemy):
		explode()
