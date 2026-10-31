extends Control
## Прицел в центре экрана: расходится при выстреле, краснеет, когда на враге,
## и показывает крестик попадания (красный и крупнее — при хедшоте).

var on_target := false
var on_head := false
## Вид через оптический прицел: чёрное кольцо вокруг круга, тонкие нити и деления.
var scoped := false

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
	if scoped:
		_draw_scope()
		return
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


func _draw_scope() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	var outside := size.length()
	# Всё вне круга — чёрное: толстая дуга от края круга до углов экрана.
	draw_arc(center, radius + outside * 0.5, 0.0, TAU, 96, Color.BLACK, outside + 2.0)
	draw_arc(center, radius, 0.0, TAU, 96, Color(0.05, 0.05, 0.05), 6.0)
	# Лёгкое затемнение к краю линзы.
	draw_arc(center, radius - 14.0, 0.0, TAU, 96, Color(0, 0, 0, 0.35), 26.0)
	var line := Color(0.02, 0.02, 0.02, 0.95)
	var red := Color(1.0, 0.2, 0.15) if on_target else Color(0.9, 0.9, 0.9, 0.9)
	var gap := 14.0 + _spread * 0.5
	# Толстые нити от края и тонкие к центру.
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var d: Vector2 = direction
		draw_line(center + d * radius, center + d * radius * 0.45, line, 6.0)
		draw_line(center + d * radius * 0.45, center + d * gap, line, 1.6)
		for k in range(1, 5):
			var mark: Vector2 = center + d * (gap + k * radius * 0.08)
			var side := Vector2(-d.y, d.x) * (6.0 if k % 2 == 0 else 3.5)
			draw_line(mark - side, mark + side, line, 1.6)
	draw_circle(center, 2.6, Color(1, 0.9, 0.3) if on_head else red)
	if _hit_timer > 0.0:
		var hit_color := Color(1, 0.15, 0.1) if _hit_head else Color.WHITE
		for diagonal in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var d2: Vector2 = diagonal.normalized()
			draw_line(center + d2 * 10.0, center + d2 * 24.0, hit_color, 3.0)
