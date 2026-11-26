extends RefCounted

static func draw_heart(canvas: CanvasItem, center: Vector2, s: float, color: Color) -> void:
	canvas.draw_circle(center + Vector2(-s * 0.5, -s * 0.3), s * 0.6, color)
	canvas.draw_circle(center + Vector2(s * 0.5, -s * 0.3), s * 0.6, color)
	var tip := PackedVector2Array([
		center + Vector2(-s * 1.05, -s * 0.1),
		center + Vector2(s * 1.05, -s * 0.1),
		center + Vector2(0.0, s * 1.2),
	])
	canvas.draw_colored_polygon(tip, color)
