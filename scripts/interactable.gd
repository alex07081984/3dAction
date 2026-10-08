class_name Interactable
extends Area3D
## Зона действия: когда игрок внутри, на экране появляется кнопка «Действие»
## (на ПК — клавиша E). Наследники меняют подпись и то, что происходит при нажатии.

signal interacted(player: Player)

@export var prompt := "Действие"
@export var button_text := "Войти"
@export var active := true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_prompt() -> String:
	return prompt


func get_button_text() -> String:
	return button_text


func interact(player: Player) -> void:
	interacted.emit(player)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		(body as Player).set_interactable(self)


func _on_body_exited(body: Node) -> void:
	if body is Player:
		(body as Player).clear_interactable(self)
