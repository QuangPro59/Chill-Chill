extends Node2D

var cell_size := Vector2(16, 16)
var marker_color := Color(0.45, 0.75, 1.0, 0.95)

func _draw() -> void:
	var rect := Rect2(-cell_size * 0.5, cell_size)
	draw_rect(rect, Color(marker_color.r, marker_color.g, marker_color.b, 0.18), true)
	draw_rect(rect, marker_color, false, 1.0)
