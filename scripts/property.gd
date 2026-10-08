class_name Property
extends Node3D
## Недвижимость в городе. Пока не куплена — дверь закрыта и висит табличка «Продаётся».
## Купленные улучшения появляются внутри как мебель: узлы Furniture/<id улучшения>.
## Узел Furniture/Base виден сразу после покупки. Spawn — где игрок появляется дома.

@export var property_id := "shack"

@onready var _door: Node = get_node_or_null("Door")
@onready var _sign: Node3D = get_node_or_null("ForSale")
@onready var _furniture: Node = get_node_or_null("Furniture")


func _ready() -> void:
	add_to_group("properties")
	Game.economy_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var owned := Game.owns_property(property_id)
	if _door:
		_door.visible = not owned
		if _door is CSGShape3D:
			(_door as CSGShape3D).use_collision = not owned
	if _sign:
		_sign.visible = not owned
		var label := _sign as Label3D
		if label:
			var item := Game.property(property_id)
			label.text = "ПРОДАЁТСЯ\n%s — $%d" % [item.get("title", ""), int(item.get("price", 0))]
	if _furniture:
		for group in _furniture.get_children():
			if group.name == "Base":
				group.visible = owned
			else:
				group.visible = owned and Game.has_upgrade(property_id, String(group.name))


func get_spawn() -> Node3D:
	return get_node_or_null("Spawn")
