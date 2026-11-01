extends Control
## Звёзды за уровень (1–3), нарисованные многоугольниками — шрифту символ ★ не нужен.

var stars := 0:
	set(value):
		stars = clampi(value, 0, 3)
		queue_redraw()


func _draw() -> void:
	var radius := minf(size.y * 0.45, size.x / 7.0)
	var gap := radius * 2.3
	var center := Vector2(size.x * 0.5 - gap, size.y * 0.5)
	for i in 3:
		var points := PackedVector2Array()
		for k in 10:
			var angle := -PI / 2.0 + k * PI / 5.0
			var r := radius if k % 2 == 0 else radius * 0.45
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
		var filled := i < stars
		draw_colored_polygon(points, Color(1, 0.8, 0.2) if filled else Color(0.25, 0.25, 0.28, 0.9))
		points.append(points[0])
		draw_polyline(points, Color(0.1, 0.05, 0.0, 0.9), 2.0)
		center.x += gap
