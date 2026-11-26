extends Control

const SEASONS := ["XUÂN", "HẠ", "THU", "ĐÔNG"]
const TOP_COLORS := [
	Color("#72c9e7"), Color("#4b9ed4"), Color("#899eb8"), Color("#a9d1e7")
]
const LOW_COLORS := [
	Color("#d6efcf"), Color("#fee1a0"), Color("#f6c47e"), Color("#e3f4ef")
]
const HILL_COLORS := [
	Color("#71b664"), Color("#53a064"), Color("#bf875b"), Color("#dcece6")
]

var season_index := 0
var weather_kind := "Nắng"
var clock_hour := 8
var cloud_phase := 0.0

func set_sky_state(season: int, weather: String, hour: int) -> void:
	season_index = posmod(season, 4)
	weather_kind = weather
	clock_hour = hour
	queue_redraw()

func _process(delta: float) -> void:
	cloud_phase += delta * 7.0
	queue_redraw()

func _draw() -> void:
	var top: Color = TOP_COLORS[season_index]
	var low: Color = LOW_COLORS[season_index]
	var hill: Color = HILL_COLORS[season_index]
	if clock_hour >= 19 or clock_hour < 6:
		top = top.darkened(0.48)
		low = low.darkened(0.30)
	for y in range(0, 88, 8):
		var t := float(y) / 88.0
		var color: Color = top.lerp(low, t)
		if weather_kind == "Âm u" or weather_kind == "Mưa" or weather_kind == "Tuyết":
			color = color.darkened(0.16)
		draw_rect(Rect2(0, y, 186, 8), color)
	# Distant hills and a little lake give the card an actual horizon.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 58), Vector2(30, 41), Vector2(53, 55),
		Vector2(82, 36), Vector2(116, 58), Vector2(146, 44),
		Vector2(186, 57), Vector2(186, 88), Vector2(0, 88)
	]), hill)
	draw_rect(Rect2(0, 69, 186, 19), hill.darkened(0.12))
	draw_rect(Rect2(112, 72, 74, 11), Color("#70c6d0") if season_index != 3 else Color("#9bd6e5"))
	draw_rect(Rect2(120, 76, 36, 2), Color(0.88, 0.96, 0.92, 0.75))
	if season_index == 3:
		draw_rect(Rect2(0, 67, 186, 3), Color("#f6ffff"))
	# Sun or moon shifts with the farm clock.
	var celestial_x := 17 + posmod(clock_hour * 8 + 16, 145)
	if clock_hour >= 19:
		draw_rect(Rect2(celestial_x, 14, 11, 11), Color("#f7f0c9"))
		draw_rect(Rect2(celestial_x + 5, 11, 3, 3), Color("#fff9df"))
		for p in [Vector2(28, 20), Vector2(78, 13), Vector2(150, 24), Vector2(164, 39)]:
			draw_rect(Rect2(p, Vector2(2, 2)), Color("#f7f4d9"))
	else:
		var sun_color := Color("#ffe98a") if season_index != 2 else Color("#ffd179")
		draw_rect(Rect2(celestial_x, 16, 15, 15), sun_color)
		draw_rect(Rect2(celestial_x + 4, 12, 7, 3), sun_color)
		draw_rect(Rect2(celestial_x + 4, 31, 7, 3), sun_color)
	# Slow pixel clouds drift across the sky.
	var cloud_a := fposmod(cloud_phase, 228.0) - 35.0
	var cloud_b := fposmod(cloud_phase * 0.62 + 92.0, 228.0) - 35.0
	_draw_cloud(cloud_a, 25, Color("#f5fbf1"))
	_draw_cloud(cloud_b, 42, Color("#ecf5ef"))
	if weather_kind == "Mưa":
		for i in range(18):
			var rx := posmod(i * 19 + int(cloud_phase * 2.0), 186)
			var ry := 52 + posmod(i * 13 + int(cloud_phase * 3.0), 25)
			draw_rect(Rect2(rx, ry, 2, 6), Color("#bbdef1"))
	elif weather_kind == "Tuyết":
		for i in range(22):
			var sx := posmod(i * 29 + int(cloud_phase * 1.2), 186)
			var sy := 49 + posmod(i * 17 + int(cloud_phase * 2.0), 35)
			draw_rect(Rect2(sx, sy, 3, 3), Color("#ffffff"))
	# Seasonal accents are visible in the foreground of the miniature scene.
	if season_index == 0:
		for p in [Vector2(25, 71), Vector2(44, 78), Vector2(91, 68), Vector2(170, 77)]:
			draw_rect(Rect2(p, Vector2(3, 3)), Color("#f6b1c3"))
	elif season_index == 1:
		draw_rect(Rect2(17, 78, 5, 4), Color("#f6d64d"))
	elif season_index == 2:
		for p in [Vector2(32, 69), Vector2(71, 79), Vector2(154, 72)]:
			draw_rect(Rect2(p, Vector2(4, 3)), Color("#d86c45"))
	else:
		for p in [Vector2(23, 77), Vector2(64, 73), Vector2(103, 80), Vector2(165, 76)]:
			draw_rect(Rect2(p, Vector2(4, 3)), Color("#f5ffff"))
	var font: Font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(7, 12), SEASONS[season_index] + "  ·  " + weather_kind.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 172, 10, Color("#263b42"))

func _draw_cloud(x: float, y: float, color: Color) -> void:
	var px := int(roundf(x))
	draw_rect(Rect2(px + 6, y + 2, 21, 8), color)
	draw_rect(Rect2(px + 11, y - 2, 11, 6), color)
	draw_rect(Rect2(px, y + 5, 10, 5), color)
	draw_rect(Rect2(px + 23, y + 5, 9, 5), color)
