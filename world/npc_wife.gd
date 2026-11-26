extends Node2D
## Người vợ trong nhà lớn: vẽ tay pixel, thở nhẹ và có trái tim nhỏ bên trên.

var time := 0.0

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var bob := int(round(sin(time * 2.2) * 1.5))
	var x := 0
	var y := bob
	var hair := Color("#633b32")
	var hair_light := Color("#a96345")
	var blouse := Color("#f4dfc2")
	var skirt := Color("#2d7480")
	var dress := Color("#c96578")
	draw_rect(Rect2(x - 14, y - 2, 28, 6), Color(0.12, 0.20, 0.14, 0.28))
	# Tóc dài màu hạt dẻ với bím tóc và kẹp hoa.
	draw_rect(Rect2(x - 10, y - 43, 20, 24), hair)
	draw_rect(Rect2(x - 13, y - 36, 5, 19), hair)
	draw_rect(Rect2(x + 8, y - 36, 5, 20), hair)
	draw_rect(Rect2(x + 10, y - 26, 5, 9), hair_light)
	draw_rect(Rect2(x + 11, y - 20, 4, 4), Color("#f2c35d"))
	# Giày.
	draw_rect(Rect2(x - 8, y - 12, 6, 9), Color("#f1d8bb"))
	draw_rect(Rect2(x + 2, y - 12, 6, 9), Color("#f1d8bb"))
	draw_rect(Rect2(x - 9, y - 5, 8, 5), Color("#664b3a"))
	draw_rect(Rect2(x + 1, y - 5, 8, 5), Color("#664b3a"))
	# Áo và váy.
	draw_rect(Rect2(x - 10, y - 28, 20, 13), blouse)
	draw_rect(Rect2(x - 13, y - 26, 5, 9), Color("#e9c9a9"))
	draw_rect(Rect2(x + 8, y - 26, 5, 9), Color("#e9c9a9"))
	draw_rect(Rect2(x - 11, y - 18, 22, 11), skirt)
	draw_rect(Rect2(x - 9, y - 25, 18, 11), dress)
	draw_rect(Rect2(x - 9, y - 17, 18, 3), Color("#ab4f67"))
	draw_rect(Rect2(x - 6, y - 24, 12, 13), Color("#f1d7a8"))
	draw_rect(Rect2(x - 3, y - 22, 2, 2), Color("#e6b45b"))
	draw_rect(Rect2(x + 2, y - 22, 2, 2), Color("#e6b45b"))
	# Mặt, mái tóc dài và hoa hồng cài tóc.
	draw_rect(Rect2(x - 7, y - 42, 14, 15), Color("#f0c394"))
	draw_rect(Rect2(x - 9, y - 45, 18, 7), hair)
	draw_rect(Rect2(x - 7, y - 47, 14, 4), hair_light)
	draw_rect(Rect2(x - 7, y - 41, 4, 7), hair)
	draw_rect(Rect2(x + 4, y - 41, 4, 7), hair)
	draw_rect(Rect2(x + 6, y - 42, 4, 4), Color("#f0a9bd"))
	draw_rect(Rect2(x + 7, y - 43, 2, 6), Color("#ffe0e5"))
	# Mắt vui và miệng cười.
	draw_rect(Rect2(x - 4, y - 35, 2, 3), Color("#45352e"))
	draw_rect(Rect2(x + 3, y - 35, 2, 3), Color("#45352e"))
	draw_rect(Rect2(x - 1, y - 30, 3, 2), Color("#d67d77"))
	# Trái tim nhỏ nhấp nhô.
	var heart_y := y - 58 + int(round(sin(time * 3.0) * 2.0))
	draw_rect(Rect2(x - 3, heart_y, 2, 2), Color(0.98, 0.45, 0.55))
	draw_rect(Rect2(x + 1, heart_y, 2, 2), Color(0.98, 0.45, 0.55))
	draw_rect(Rect2(x - 2, heart_y + 2, 4, 2), Color(0.98, 0.45, 0.55))
	draw_rect(Rect2(x - 1, heart_y + 4, 2, 1), Color(0.9, 0.3, 0.4))
