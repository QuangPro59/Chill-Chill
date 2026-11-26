extends CanvasLayer
## Hiệu ứng bốn mùa + thời tiết cho thế giới Seasons Gone.
## - Lớp hạt trên màn hình (mưa, tuyết, lá rụng, hoa, sương).
## - Bảng thông tin nông trại vẽ tay: khung gỗ bo góc viền vàng, icon chip,
##   tiền xu nảy khi thay đổi, toast dạng hộp thoại, banner khi sang mùa mới.

const SEASON_NAMES := ["", "Xuân", "Hạ", "Thu", "Đông"]
const WEATHER_NAMES := ["Nắng", "Mưa", "Tuyết", "Sương giá", "Hạn hán"]
const SEASON_TINTS := [
	Color(1.0, 1.0, 1.0),
	Color(0.97, 1.0, 0.97),
	Color(1.0, 0.97, 0.88),
	Color(1.0, 0.86, 0.74),
	Color(0.8, 0.88, 1.0),
]
const WEATHER_TINTS := [
	Color(1.0, 1.0, 1.0),
	Color(0.82, 0.88, 0.98),
	Color(0.9, 0.94, 1.0),
	Color(0.85, 0.92, 1.0),
	Color(1.0, 0.93, 0.78),
]
const SEASON_ACCENT := [
	Color(0.83, 0.63, 0.3),
	Color(0.55, 0.85, 0.42),
	Color(0.98, 0.8, 0.25),
	Color(0.93, 0.5, 0.2),
	Color(0.55, 0.75, 1.0),
]
const GOLD := Color(0.93, 0.75, 0.36)
const WOOD := Color(0.13, 0.09, 0.06, 0.94)

var world
var tint: CanvasModulate
var particles: Control
var panel: Control
var season_icon: Control
var weather_icon: Control
var coin_icon: Control
var season_label: Label
var weather_label: Label
var money_label: Label
var toast: Control
var toast_label: Label
var toast_accent := Color(1, 1, 1)
var _toast_tween: Tween
var banner: Label
var _money_timer := 0.0
var _last_money := -1
var _last_season := -1

## Khung bảng thông tin: khung gỗ bo góc, viền vàng, đinh tán góc.
class HudPanel extends Control:
	var accent := Color(0.83, 0.63, 0.3)
	var _body: StyleBoxFlat
	var _glare: StyleBoxFlat
	var _chip: StyleBoxFlat

	func _init() -> void:
		_body = StyleBoxFlat.new()
		_body.bg_color = Color(0.13, 0.09, 0.06, 0.94)
		_body.border_color = accent
		_body.set_border_width_all(2)
		_body.set_corner_radius_all(11)
		_glare = StyleBoxFlat.new()
		_glare.bg_color = Color(1, 1, 1, 0.05)
		_glare.set_border_width_all(0)
		_glare.set_corner_radius_all(8)
		_chip = StyleBoxFlat.new()
		_chip.bg_color = Color(0.06, 0.045, 0.03, 0.9)
		_chip.border_color = Color(1, 1, 1, 0.07)
		_chip.set_border_width_all(1)
		_chip.set_corner_radius_all(6)

	func _draw() -> void:
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0, 0, 0, 0.38)
		shadow.set_corner_radius_all(11)
		shadow.set_border_width_all(0)
		draw_style_box(shadow, Rect2(Vector2(2, 4), size))
		_body.border_color = accent
		draw_style_box(_body, Rect2(Vector2.ZERO, size))
		draw_style_box(_glare, Rect2(Vector2(4, 4), Vector2(size.x - 8, size.y * 0.42)))
		for c in [Vector2(9, 9), Vector2(size.x - 9, 9), Vector2(9, size.y - 9), Vector2(size.x - 9, size.y - 9)]:
			draw_circle(c, 2.2, GOLD)
			draw_circle(c, 1.3, Color(0.55, 0.38, 0.1))
		draw_line(Vector2(14, 24), Vector2(size.x - 14, 24), Color(accent.r, accent.g, accent.b, 0.55), 1.0)
		draw_line(Vector2(14, 25), Vector2(size.x - 14, 25), Color(1, 1, 1, 0.06), 1.0)

## Icon vẽ tay trong chip nền tối.
class HudIcon extends Control:
	var kind := "season"
	var value := 0

	func _draw() -> void:
		var c := size * 0.5
		var chip := StyleBoxFlat.new()
		chip.bg_color = Color(0.06, 0.045, 0.03, 0.9)
		chip.border_color = Color(1, 1, 1, 0.07)
		chip.set_border_width_all(1)
		chip.set_corner_radius_all(6)
		draw_style_box(chip, Rect2(Vector2.ZERO, size))
		c += Vector2(0, 0.5)
		if kind == "coin":
			draw_circle(c, 6.6, Color(0.62, 0.42, 0.1))
			draw_circle(c, 5.6, Color(0.98, 0.8, 0.24))
			draw_circle(c + Vector2(-1.8, -1.8), 1.4, Color(1, 0.95, 0.6))
			draw_rect(Rect2(c + Vector2(-1.2, -3.0), Vector2(2.4, 6.0)), Color(0.82, 0.6, 0.12))
		elif kind == "season":
			match value:
				1:
					for off in [Vector2(-3, -3), Vector2(3, -3), Vector2(-3, 3), Vector2(3, 3)]:
						draw_circle(c + off, 2.5, Color(1.0, 0.55, 0.75))
					draw_circle(c, 2.4, Color(1.0, 0.9, 0.3))
				2:
					draw_circle(c, 4.6, Color(1.0, 0.85, 0.2))
					draw_line(c + Vector2(0, -7), c + Vector2(0, 7), Color(0.98, 0.75, 0.1), 1.4)
					draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), Color(0.98, 0.75, 0.1), 1.4)
				3:
					draw_colored_polygon(PackedVector2Array([
						c + Vector2(-6, 0), c + Vector2(0, -5), c + Vector2(6, 0), c + Vector2(0, 5)]),
						Color(0.95, 0.58, 0.12))
					draw_line(c + Vector2(-3, -1), c + Vector2(3, 1), Color(0.5, 0.28, 0.05), 1.2)
					draw_line(c + Vector2(-2, 2), c + Vector2(2, 4), Color(0.5, 0.28, 0.05), 1.2)
				4:
					for ang in [0.0, TAU / 6.0, TAU / 3.0]:
						var d := Vector2(cos(ang), sin(ang)) * 6.0
						draw_line(c - d, c + d, Color(0.88, 0.96, 1.0), 1.6)
					draw_circle(c, 1.6, Color(1, 1, 1))
		elif kind == "weather":
			match value:
				0:
					draw_circle(c, 4.2, Color(1.0, 0.9, 0.3))
					draw_line(c + Vector2(0, -7), c + Vector2(0, 7), Color(1.0, 0.85, 0.2), 1.4)
					draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), Color(1.0, 0.85, 0.2), 1.4)
				1:
					draw_circle(c + Vector2(-2, -3), 3.2, Color(0.78, 0.83, 0.9))
					draw_circle(c + Vector2(3, -2), 2.6, Color(0.78, 0.83, 0.9))
					draw_rect(Rect2(c + Vector2(-5, -2), Vector2(11, 4)), Color(0.72, 0.78, 0.86))
					draw_line(c + Vector2(-3, 4), c + Vector2(-4, 7), Color(0.45, 0.65, 1.0), 1.5)
					draw_line(c + Vector2(1, 4), c + Vector2(0, 7), Color(0.45, 0.65, 1.0), 1.5)
					draw_line(c + Vector2(4, 4), c + Vector2(3, 7), Color(0.45, 0.65, 1.0), 1.5)
				2:
					for ang in [0.0, TAU / 6.0, TAU / 3.0]:
						var d := Vector2(cos(ang), sin(ang)) * 6.0
						draw_line(c - d, c + d, Color(1, 1, 1), 1.6)
					draw_circle(c, 1.5, Color(0.9, 0.96, 1))
				3:
					draw_colored_polygon(PackedVector2Array([
						c + Vector2(0, -6), c + Vector2(5, 0), c + Vector2(0, 6), c + Vector2(-5, 0)]),
						Color(0.75, 0.9, 1.0, 0.92))
					draw_circle(c + Vector2(0, -3), 1.3, Color(1, 1, 1, 0.8))
				4:
					draw_circle(c, 4.4, Color(1.0, 0.6, 0.2))
					draw_line(c + Vector2(-7, 2), c + Vector2(-4, 5), Color(1.0, 0.5, 0.1), 1.6)
					draw_line(c + Vector2(7, 2), c + Vector2(4, 5), Color(1.0, 0.5, 0.1), 1.6)

	func refresh_icon() -> void:
		queue_redraw()

## Hộp toast dưới màn hình: nền tối bo góc, viền vàng, thanh màu bên trái.
class ToastBox extends Control:
	var accent := Color(1, 1, 1)
	var _box: StyleBoxFlat

	func _init() -> void:
		_box = StyleBoxFlat.new()
		_box.bg_color = Color(0.1, 0.07, 0.05, 0.95)
		_box.border_color = GOLD
		_box.set_border_width_all(2)
		_box.set_corner_radius_all(10)

	func _draw() -> void:
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0, 0, 0, 0.4)
		shadow.set_border_width_all(0)
		shadow.set_corner_radius_all(10)
		draw_style_box(shadow, Rect2(Vector2(2, 3), size))
		_box.border_color = accent
		draw_style_box(_box, Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(Vector2(4, 8), Vector2(3, size.y - 16)), accent)
		draw_rect(Rect2(Vector2(size.x - 7, 8), Vector2(3, size.y - 16)), accent)

func setup(target_world) -> void:
	world = target_world
	layer = 1
	tint = CanvasModulate.new()
	tint.color = Color(1.0, 1.0, 1.0)
	world.add_child(tint)
	particles = Control.new()
	particles.set_script(load("res://season/season_particles.gd"))
	particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(particles)
	particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_hud()
	add_to_group("hud_panel")
	refresh(false)

func _build_hud() -> void:
	panel = HudPanel.new()
	panel.position = Vector2(8, 6)
	panel.size = Vector2(250, 104)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var title := Label.new()
	title.text = "NÔNG TRẠI"
	title.position = Vector2(12, 4)
	title.add_theme_font_override("font", ThemeDB.fallback_font)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 1)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)
	season_icon = HudIcon.new()
	season_icon.kind = "season"
	weather_icon = HudIcon.new()
	weather_icon.kind = "weather"
	coin_icon = HudIcon.new()
	coin_icon.kind = "coin"
	season_label = _make_label(Color(1, 1, 1, 0.96))
	weather_label = _make_label(Color(0.85, 0.92, 1.0, 0.96))
	money_label = _make_label(Color(1.0, 0.86, 0.35, 0.98))
	var y := 28
	for row in [[season_icon, season_label], [weather_icon, weather_label], [coin_icon, money_label]]:
		var icon: Control = row[0]
		icon.position = Vector2(12, y)
		icon.size = Vector2(22, 22)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lab: Label = row[1]
		lab.position = Vector2(42, y)
		lab.size = Vector2(194, 22)
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.clip_text = true
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		panel.add_child(lab)
		y += 24
	toast = ToastBox.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.modulate.a = 0.0
	add_child(toast)
	# The toolbar starts 74 px above the bottom; leave a 10 px gap.
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_left = -200.0
	toast.offset_top = -136.0
	toast.offset_right = 200.0
	toast.offset_bottom = -84.0
	toast_label = Label.new()
	toast_label.add_theme_font_override("font", ThemeDB.fallback_font)
	toast_label.add_theme_font_size_override("font_size", 13)
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast_label.add_theme_constant_override("outline_size", 1)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.max_lines_visible = 2
	toast_label.clip_text = true
	toast_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toast_label.position = Vector2(14, 6)
	toast_label.size = Vector2(372, 40)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(toast_label)
	banner = Label.new()
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_override("font", ThemeDB.fallback_font)
	banner.add_theme_font_size_override("font_size", 26)
	banner.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	banner.add_theme_constant_override("outline_size", 2)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	add_child(banner)

func _make_label(color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", ThemeDB.fallback_font)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 1)
	return l

func hide_toast() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast.modulate.a = 0.0

func show_toast(text: String, color: Color = Color(1, 1, 1)) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_accent = color
	toast.accent = color
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast.queue_redraw()
	toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.18)
	_toast_tween.tween_interval(1.7)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)

func refresh(animate: bool = true) -> void:
	var s: int = clampi(int(world.season), 1, 4)
	var w: int = clampi(int(world.weather), 0, 4)
	var target: Color = SEASON_TINTS[s] * WEATHER_TINTS[w]
	if animate:
		var tween := create_tween()
		tween.tween_property(tint, "color", target, 1.6)
	else:
		tint.color = target
	particles.set_mode(_particle_mode(s, w))
	season_label.text = "Mùa %s · Tháng %d · Năm %d" % [SEASON_NAMES[s], int(world.month), int(world.year)]
	weather_label.text = "%s · %d°C" % [WEATHER_NAMES[w], int(world.temperature)]
	panel.accent = SEASON_ACCENT[s]
	panel.queue_redraw()
	season_icon.value = s
	season_icon.refresh_icon()
	weather_icon.value = w
	weather_icon.refresh_icon()
	coin_icon.refresh_icon()
	if s != _last_season:
		if _last_season != -1:
			_show_banner("—  Mùa %s đã đến  —" % SEASON_NAMES[s], s)
		_last_season = s
	_refresh_money()

func _show_banner(text: String, s: int) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	banner.text = text
	banner.add_theme_color_override("font_color", Color(1, 1, 1).lerp(SEASON_ACCENT[s], 0.45))
	banner.position = Vector2(0.0, maxf(vp.y * 0.24, panel.position.y + panel.size.y + 10.0))
	banner.size = Vector2(vp.x, 40.0)
	banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(banner, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.6)
	tween.tween_property(banner, "modulate:a", 0.0, 1.0)

func _refresh_money() -> void:
	if world == null or world.player == null:
		return
	var money: int = int(world.player.player_data.get("money", 0))
	if money != _last_money:
		money_label.text = "%d xu" % money
		if _last_money >= 0:
			money_label.pivot_offset = money_label.size * 0.5
			money_label.scale = Vector2(1.08, 1.08)
			var tween := create_tween()
			tween.tween_property(money_label, "scale", Vector2(1, 1), 0.35)
		_last_money = money

func _process(delta: float) -> void:
	_money_timer += delta
	if _money_timer >= 0.25:
		_money_timer = 0.0
		_refresh_money()

func _particle_mode(s: int, w: int) -> String:
	if w == 1:
		return "rain"
	if w == 2:
		return "snow"
	if w == 3:
		return "frost"
	if s == 3:
		return "leaves"
	if s == 1 and w == 0:
		return "petals"
	if s == 4:
		return "snow"
	return "none"
