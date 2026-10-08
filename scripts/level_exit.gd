class_name LevelExit
extends Area3D
## Выход с уровня. Если задана required_zone, выход откроется только после неё.

@export var required_zone: WaveZone

var _open := true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	if required_zone:
		_set_open(false)
		required_zone.cleared.connect(func(_zone: WaveZone) -> void: _set_open(true))


func _set_open(value: bool) -> void:
	_open = value
	for child in get_children():
		if child is Node3D and not child is CollisionShape3D:
			child.visible = value
	if value:
		for body in get_overlapping_bodies():
			_on_body_entered(body)


func _on_body_entered(body: Node) -> void:
	if _open and body is Player and (body as Player).is_alive():
		get_tree().call_group("level", "complete")
