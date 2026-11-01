class_name TrainStation
extends Interactable
## Вокзал: поезд в другой город (эпизод). Поездка — отдельный уровень на идущем поезде.
## После неё маршрут открыт и для самолёта (быстро и без боя).

@export var episode := 2  ## Номер эпизода, куда идёт поезд.


func get_prompt() -> String:
	var city := Game.city_name(episode)
	if not active:
		return "Поезд: %s — пока закрыто" % city
	return "Поезд: %s · бой в вагонах, награда в конце" % city


func get_button_text() -> String:
	return "Ехать"


func interact(player: Player) -> void:
	if not active:
		return
	super.interact(player)
	Audio.play("ui_click")
	Game.start_travel(episode)
