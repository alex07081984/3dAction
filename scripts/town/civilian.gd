class_name Civilian
extends CharacterBody3D
## Прохожий на базе: гуляет по тротуару туда-сюда, от выстрелов и взрывов убегает.
## За попадание в мирного жителя — штраф.

const PENALTY := 50

var from_point := Vector3.ZERO
var to_point := Vector3.ZERO
var model: BlockyCharacter

var _forward := true
var _pause := 0.0
var _panic := 0.0
var _flee := Vector3.FORWARD
var _stuck := 0.0
var _dead := false


func _ready() -> void:
	add_to_group("civilians")
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	model = BlockyCharacter.new()
	model.random_look = true
	model.weapon = ""
	model.build = ["normal", "normal", "normal", "thin", "fat"].pick_random()
	model.outfit = ["coat", "coat", "jacket", "suit", "hoodie", "shirt"].pick_random()
	model.jacket_color = [Color(0.34, 0.3, 0.24), Color(0.12, 0.12, 0.13), Color(0.22, 0.2, 0.24), Color(0.28, 0.22, 0.18)].pick_random()
	model.shirt_color = [Color(0.8, 0.8, 0.78), Color(0.3, 0.35, 0.45), Color(0.5, 0.15, 0.12), Color(0.25, 0.3, 0.25)].pick_random()
	model.pants_color = [Color(0.13, 0.13, 0.15), Color(0.25, 0.22, 0.2), Color(0.18, 0.2, 0.28)].pick_random()
	if randf() < 0.4:
		model.hat = "fedora"
	add_child(model)
	_pause = randf_range(0.0, 2.0)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	var direction := Vector3.ZERO
	var speed := 0.0
	if _panic > 0.0:
		_panic -= delta
		direction = _flee
		speed = 4.2
	elif _pause > 0.0:
		_pause -= delta
	else:
		var offset := (to_point if _forward else from_point) - global_position
		offset.y = 0.0
		if offset.length() < 0.6:
			_pause = randf_range(0.5, 3.0)
			_forward = not _forward
		else:
			direction = offset.normalized()
			speed = 1.3
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	if speed > 0.0:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-8.0 * delta))
		# Упёрся в столб или в игрока — разворачивается.
		_stuck = _stuck + delta if get_real_velocity().length() < speed * 0.3 else 0.0
		if _stuck > 0.6:
			_stuck = 0.0
			_forward = not _forward
			_flee = _flee.rotated(Vector3.UP, PI * randf_range(0.5, 1.5))
	model.animate(delta, Vector2(velocity.x, velocity.z).length() / 2.0, false)


## Рядом стреляют или взорвалось — бежит прочь.
func panic(from: Vector3, radius: float) -> void:
	if _dead or global_position.distance_to(from) > radius:
		return
	var away := global_position - from
	away.y = 0.0
	_flee = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	if _panic <= 0.0 and randf() < 0.5:
		Audio.play_at("scream", global_position + Vector3.UP * 1.6, -6.0, randf_range(1.05, 1.3))
	_panic = randf_range(4.0, 6.0)


func take_hit(damage: float, point: Vector3, direction: Vector3) -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("civilians")
	collision_layer = 0
	model.break_apart(BlockyCharacter.Death.GIB if damage >= 60.0 else BlockyCharacter.Death.FALL, direction, 4.0)
	Fx.blood(point, direction, 20)
	Audio.play_at("death", point)
	Game.add_money(-mini(PENALTY, Game.money))
	get_tree().call_group("hud", "show_toast", tr("Мирный житель! −$%d") % PENALTY)
	queue_free()


func is_alive() -> bool:
	return not _dead
