extends Control
## Кровь на экране после убийства в упор: красные кляксы с подтёками медленно стекают и тают.

const LIFETIME := 1.6

var _splats: Array = []  # {"pos", "radius", "drops": [[offset, radius]], "age"}


func _process(delta: float) -> void:
	if _splats.is_empty():
		return
	for splat in _splats:
		splat.age += delta
		splat.pos.y += delta * 18.0
	_splats = _splats.filter(func(splat: Dictionary) -> bool: return splat.age < LIFETIME)
	queue_redraw()


## Брызги на экран: чем больше strength (0–1), тем больше клякс.
func splash(strength := 1.0) -> void:
	if not Game.gore():
		return
	var count := clampi(roundi(2 + strength * 4), 1, 7)
	for i in count:
		var drops := []
		for k in randi_range(3, 7):
			drops.append([Vector2(randf_range(-1.6, 1.6), randf_range(-1.2, 1.8)), randf_range(0.12, 0.35)])
		_splats.append({
			"pos": Vector2(randf_range(0.08, 0.92) * size.x, randf_range(0.1, 0.85) * size.y),
			"radius": randf_range(28.0, 70.0) * (0.7 + strength * 0.5),
			"drops": drops,
			"age": 0.0,
		})
	queue_redraw()


func get_splat_count() -> int:
	return _splats.size()


func _draw() -> void:
	for splat in _splats:
		var alpha := clampf(1.0 - splat.age / LIFETIME, 0.0, 1.0) * 0.8
		var color := Color(0.45, 0.0, 0.0, alpha)
		var radius: float = splat.radius
		draw_circle(splat.pos, radius, color)
		for drop in splat.drops:
			var offset: Vector2 = drop[0]
			draw_circle(splat.pos + offset * radius, radius * float(drop[1]), color)
		# Подтёк вниз.
		draw_rect(Rect2(splat.pos + Vector2(-radius * 0.12, 0), Vector2(radius * 0.24, radius * (1.0 + splat.age))), color)
