class_name LevelExit
extends Area3D
## Выход с уровня. Если заданы required_zone / required_zones, выход откроется
## только после того, как все эти места с волнами будут зачищены.

@export var required_zone: WaveZone
@export var required_zones: Array[NodePath] = []

var _open := true
var _waiting: Array[WaveZone] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	if required_zone:
		_waiting.append(required_zone)
	for path in required_zones:
		var zone := get_node_or_null(path) as WaveZone
		if zone:
			_waiting.append(zone)
	for zone in _waiting:
		zone.cleared.connect(_on_zone_cleared)
	if not _waiting.is_empty():
		_set_open(false)


func _on_zone_cleared(zone: WaveZone) -> void:
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
