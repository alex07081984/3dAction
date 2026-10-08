extends Control
## Прицел в центре экрана: расходится при выстреле, краснеет, когда на враге,
## и показывает крестик попадания (красный и крупнее — при хедшоте).

var on_target := false
var on_head := false

var _spread := 0.0
var _hit_timer := 0.0
var _hit_head := false
var _hit_kill := false


func _process(delta: float) -> void:
	_spread = move_toward(_spread, 0.0, delta * 70.0)
	_hit_timer -= delta
	queue_redraw()


func kick(amount: float) -> void:
	_spread = minf(_spread + amount, 40.0)


func show_hit(headshot: bool, killed: bool) -> void:
	_hit_timer = 0.3 if headshot or killed else 0.18
	_hit_head = headshot
	_hit_kill = killed


func _draw() -> void:
	var center := size * 0.5
	var color := Color(1.0, 0.25, 0.2) if on_target else Color(1, 1, 1, 0.9)
	var gap := 9.0 + _spread
	var length := 12.0
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var from: Vector2 = center + direction * gap
		var to: Vector2 = center + direction * (gap + length)
		draw_line(from, to, Color(0, 0, 0, 0.6), 5.0)
		draw_line(from, to, color, 2.5)
	draw_circle(center, 3.0, Color(0, 0, 0, 0.6))
	draw_circle(center, 2.0, Color(1, 0.9, 0.3) if on_head else color)

	if _hit_timer > 0.0:
		var hit_color := Color(1, 0.15, 0.1) if _hit_head else Color.WHITE
		var inner := 8.0 if not _hit_kill else 10.0
		var outer := 18.0 if not (_hit_head or _hit_kill) else 26.0
		for diagonal in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var d: Vector2 = diagonal.normalized()
			draw_line(center + d * inner, center + d * outer, hit_color, 3.5)
