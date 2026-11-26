extends "res://animals/farm_animal.gd"

func _init() -> void:
	hframes = 3
	vframes = 2
	walk_row = 0
	walk_frames = 5
	faces_left = false

func _ready() -> void:
	# The shared movement code owns Sprite2D.frame, not the legacy animation tracks.
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		animation_player.stop()
		animation_player.active = false
	super._ready()
