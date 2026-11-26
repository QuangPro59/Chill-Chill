extends Control

const HEART_UTIL := preload("res://couple/heart_util.gd")

var manager

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if manager == null:
		return
	var view := get_viewport_rect().size
	var bar_width := 90.0
	var x := view.x * 0.5 - bar_width * 0.5 + 8.0
	var y := 7.0
	HEART_UTIL.draw_heart(self, Vector2(x - 10.0, y + 3.0), 5.0, Color(1.0, 0.4, 0.55))
	draw_rect(Rect2(x, y, bar_width, 6.0), Color(0, 0, 0, 0.45))
	var ratio := fposmod(manager.love, 100.0) / 100.0
	draw_rect(Rect2(x, y, bar_width * ratio, 6.0), Color(1.0, 0.45, 0.6))
	draw_rect(Rect2(x, y, bar_width, 6.0), Color(1, 1, 1, 0.7), false, 1.0)
	var text := "Gắn kết Lv %d" % manager.level
	draw_string(ThemeDB.fallback_font, Vector2(x, y + 19.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.95))
