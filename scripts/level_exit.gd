class_name LevelExit
extends Area3D
## Выход с уровня. Если заданы required_zone / required_zones, выход откроется
## только после того, как все эти места с волнами будут зачищены, а боссы — побеждены.

@export var required_zone: Node  ## Место с волнами (WaveZone) или босс (Boss).
@export var required_zones: Array[NodePath] = []

var _open := true
var _waiting: Array[Node] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	if required_zone:
		_waiting.append(required_zone)
	for path in required_zones:
		var zone := get_node_or_null(path)
		if zone and zone.has_signal("cleared"):
			_waiting.append(zone)
	for zone in _waiting:
		zone.connect("cleared", _on_zone_cleared)
	if not _waiting.is_empty():
		_set_open(false)


func is_open() -> bool:
	return _open


func _on_zone_cleared(zone: Node) -> void:
	_waiting.erase(zone)
	if _waiting.is_empty():
		_set_open(true)


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
