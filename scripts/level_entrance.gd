class_name LevelEntrance
extends Interactable
## Вход на уровень из города (люк в подземку, вход в метро, дверь небоскрёба, ворота особняка).
## Работает, только когда город освобождён. Каждое прохождение повышает сложность и награду.

@export var level_index := 0


func get_prompt() -> String:
	var title: String = Game.LEVELS[level_index].title
	if not active:
		return "%s — закрыто" % title
	return "%s · сложность %d · награда $%d" % [title, Game.tier_of(level_index) + 1, Game.level_reward(level_index)]


func get_button_text() -> String:
	return "Войти"


func interact(player: Player) -> void:
	if not active:
		return
	super.interact(player)
	get_tree().call_group("hud", "show_entrance", level_index)
