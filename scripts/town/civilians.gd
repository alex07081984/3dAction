class_name Civilians
extends Node3D
## Прохожие в освобождённом городе. Каждый гуляет по своему отрезку тротуара.
## Отрезки строятся вдоль улиц; занятые столбами, деревьями и заборами — пропускаются.

@export var count := 16
@export var streets: Array[float] = [-36.0, 0.0, 36.0]
@export var blocks: Array[Vector2] = [Vector2(-60, -41), Vector2(-31, -5), Vector2(5, 31), Vector2(41, 60)]
@export var offset := 6.2  ## Расстояние от оси улицы до линии, по которой ходят.


func _ready() -> void:
	if not Game.town_liberated:
		return
	await get_tree().physics_frame
	var segments := []
	for street in streets:
		for side in [-1.0, 1.0]:
			for block in blocks:
				var line: float = street + side * offset
				segments.append([Vector3(line, 0.05, block.x + 1.5), Vector3(line, 0.05, block.y - 1.5)])
				segments.append([Vector3(block.x + 1.5, 0.05, line), Vector3(block.y - 1.5, 0.05, line)])
	segments.shuffle()
	var spawned := 0
	for segment in segments:
		if spawned >= count:
			break
		if not _is_free(segment[0], segment[1]):
			continue
		var civilian := Civilian.new()
		civilian.from_point = segment[0]
		civilian.to_point = segment[1]
		add_child(civilian)
		civilian.global_position = segment[0].lerp(segment[1], randf())
		civilian.reset_physics_interpolation()
		spawned += 1


func _is_free(a: Vector3, b: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for height in [0.4, 1.4]:
		var query := PhysicsRayQueryParameters3D.create(a + Vector3.UP * height, b + Vector3.UP * height, 1)
		if not space.intersect_ray(query).is_empty():
			return false
	for point in [a, b, (a + b) * 0.5]:
		var down := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point + Vector3.DOWN, 1)
		if space.intersect_ray(down).is_empty():
			return false
	return true
