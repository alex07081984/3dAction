class_name TravelPoint
extends Interactable
## Аэропорт (или гидросамолёт): перелёт в другой эпизод. Если город того эпизода
## уже освобождён — прилетаем на его базу, иначе — на первый непройденный уровень.

@export var episode := 2  ## Номер эпизода, куда летим.


func get_prompt() -> String:
	var title := Game.episode_title(episode)
	if not active:
		if Game.is_episode_open(episode):
			return tr("Перелёт: %s — сначала доберитесь поездом") % title
		return tr("Перелёт: %s — пока закрыто") % title
	return tr("Перелёт: %s") % title


func get_button_text() -> String:
	return "Лететь"


func interact(player: Player) -> void:
	if not active:
		return
	super.interact(player)
	Audio.play("ui_click")
	Game.travel(episode)
