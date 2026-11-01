class_name TrainStation
extends Interactable
## Дорога в другой город (эпизод): поездом (бой в вагонах) или машиной (погоня по шоссе).
## После любой поездки маршрут открыт и для самолёта (быстро и без боя).

@export var episode := 2  ## Номер эпизода, куда ведёт дорога.


func get_prompt() -> String:
	var city := Game.city_name(episode)
	if not active:
		return "Дорога: %s — пока закрыто" % city
	return "Дорога: %s · поезд или машина" % city


func get_button_text() -> String:
	return "В путь"


func interact(player: Player) -> void:
	if not active:
		return
	super.interact(player)
	get_tree().call_group("hud", "show_travel", episode)
