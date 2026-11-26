extends Node2D

const HEART_UTIL := preload("res://couple/heart_util.gd")
const LIFETIME := 1.6

var items: Array = []

func _ready() -> void:
	z_index = 3

func spawn(pos: Vector2) -> void:
	items.append({"pos": pos, "age": 0.0, "drift": randf_range(-6.0, 6.0)})

func _process(delta: float) -> void:
	if items.is_empty():
		return
	var alive: Array = []
	for item in items:
		item["age"] += delta
		item["pos"] += Vector2(item["drift"] * delta, -18.0 * delta)
		if item["age"] < LIFETIME:
			alive.append(item)
	items = alive
	queue_redraw()

func _draw() -> void:
	for item in items:
		var fade := 1.0 - float(item["age"]) / LIFETIME
		HEART_UTIL.draw_heart(self, item["pos"], 3.5, Color(1.0, 0.4, 0.55, fade))
