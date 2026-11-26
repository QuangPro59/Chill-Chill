extends Control

var mode := "none"
var items: Array = []
var time := 0.0
var wind := 0.0

const LEAF_COLORS := [
	Color(0.96, 0.80, 0.16),
	Color(0.98, 0.89, 0.38),
	Color(0.93, 0.62, 0.10),
	Color(0.84, 0.47, 0.08),
]
var LEAF_SHAPE := PackedVector2Array([
	Vector2(-2.6, 0.0), Vector2(0.0, -1.6), Vector2(2.6, 0.0), Vector2(0.0, 1.6),
])

func set_mode(new_mode: String) -> void:
	if new_mode == mode and not items.is_empty():
		return
	mode = new_mode
	items.clear()
	var count := 0
	if mode == "rain":
		count = 130
	elif mode == "snow":
		count = 140
	elif mode == "frost":
		count = 40
	elif mode == "leaves":
		count = 46
	elif mode == "petals":
		count = 16
	var area := _area()
	for i in count:
		items.append(_make_item(area, true))
	queue_redraw()

func _area() -> Vector2:
	return get_viewport_rect().size

func _make_item(area: Vector2, scatter: bool) -> Dictionary:
	var pos := Vector2(randf() * area.x, -10.0)
	if scatter:
		pos.y = randf() * area.y
	var vel := Vector2.ZERO
	if mode == "rain":
		pos.x = randf() * (area.x + 80.0)
		vel = Vector2(-30.0, 260.0 + randf() * 80.0)
	elif mode == "snow":
		vel = Vector2(randf_range(-6.0, 6.0), 24.0 + randf() * 30.0)
	elif mode == "frost":
		vel = Vector2(randf_range(-4.0, 4.0), 10.0 + randf() * 14.0)
	elif mode == "leaves":
		vel = Vector2(randf_range(4.0, 22.0), 22.0 + randf() * 24.0)
	else:
		vel = Vector2(randf_range(5.0, 25.0), 18.0 + randf() * 20.0)
	return {
		"pos": pos,
		"vel": vel,
		"phase": randf() * TAU,
		"sway_speed": randf_range(1.4, 3.2),
		"size": 1.0 + randf(),
		"tone": randf(),
		"rot": randf() * TAU,
		"spin": randf_range(-3.0, 3.0),
	}

func _process(delta: float) -> void:
	if items.is_empty():
		return
	time += delta
	var base_wind := 0.0
	var gust := 0.0
	var wind_factor := 0.2
	match mode:
		"snow":
			base_wind = 24.0
			gust = 40.0
			wind_factor = 1.0
		"leaves":
			base_wind = 12.0
			gust = 26.0
			wind_factor = 0.9
		"frost":
			base_wind = 6.0
			gust = 8.0
			wind_factor = 0.5
	wind = base_wind + (sin(time * 0.55) * 0.6 + sin(time * 1.63 + 1.3) * 0.4) * gust
	var area := _area()
	size = area
	for item in items:
		item["phase"] += delta * item["sway_speed"]
		item["rot"] += item["spin"] * delta
		var sway := 0.0
		if mode != "rain":
			var amp := 22.0 if mode == "leaves" else 14.0
			sway = sin(item["phase"]) * amp
		item["pos"] += (item["vel"] + Vector2(sway + wind * wind_factor, 0.0)) * delta
		var p: Vector2 = item["pos"]
		if p.y > area.y + 12.0 or p.x < -30.0 or p.x > area.x + 30.0:
			var fresh := _make_item(area, false)
			item["pos"] = fresh["pos"]
	queue_redraw()

func _draw() -> void:
	for item in items:
		var p: Vector2 = item["pos"]
		var s: float = item["size"]
		var t: float = item["tone"]
		if mode == "rain":
			draw_line(p, p + Vector2(-2.0, 7.0), Color(0.7, 0.82, 1.0, 0.65), 1.0)
		elif mode == "snow" or mode == "frost":
			draw_circle(p, 0.9 * s, Color(1.0, 1.0, 1.0, 0.92))
			if t > 0.72:
				draw_line(p + Vector2(-1.6 * s, 0.0), p + Vector2(1.6 * s, 0.0), Color(1.0, 1.0, 1.0, 0.55), 1.0)
				draw_line(p + Vector2(0.0, -1.6 * s), p + Vector2(0.0, 1.6 * s), Color(1.0, 1.0, 1.0, 0.55), 1.0)
		elif mode == "leaves":
			draw_set_transform(p, item["rot"], Vector2(s, s))
			draw_colored_polygon(LEAF_SHAPE, LEAF_COLORS[int(t * LEAF_COLORS.size()) % LEAF_COLORS.size()])
			draw_line(Vector2(-1.6, 0.0), Vector2(1.6, 0.0), Color(0.45, 0.26, 0.05, 0.8), 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif mode == "petals":
			draw_rect(Rect2(p, Vector2(2.0, 2.0)), Color(1.0, 0.7 + t * 0.2, 0.8, 0.95))
	if mode == "snow" and absf(wind) > 34.0:
		var strength := clampf((absf(wind) - 34.0) / 30.0, 0.0, 1.0)
		var dir := signf(wind)
		for i in 7:
			var y := fmod(float(i) * 53.0 + time * 90.0, size.y)
			var x := fmod(float(i) * 173.0 + time * 260.0 * dir, size.x + 60.0) - 30.0
			draw_line(Vector2(x, y), Vector2(x + dir * (14.0 + 10.0 * strength), y - 2.0), Color(1.0, 1.0, 1.0, 0.28 * strength), 1.0)
