class_name PropertyDoor
extends Interactable
## Дверь недвижимости: покупка, а после покупки — меню улучшений.

@export var property_id := "shack"


func get_prompt() -> String:
	var item := Game.property(property_id)
	if Game.owns_property(property_id):
		return "%s — ваше жильё" % item.title
	if not Game.is_property_available(property_id):
		return "%s — сначала купите жильё попроще" % item.title
	return "%s — продаётся за $%d" % [item.title, int(item.price)]


func get_button_text() -> String:
	return "Улучшить" if Game.owns_property(property_id) else "Купить"


func interact(player: Player) -> void:
	super.interact(player)
	get_tree().call_group("hud", "show_property", property_id)
