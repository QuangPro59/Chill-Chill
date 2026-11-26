extends Node

const MEADOW_SCENE_PATH := "res://chill_chill/main.tscn"
const FARM_RESOLUTION := Vector2i(640, 360)
const MEADOW_RESOLUTION := Vector2i(1280, 720)

var current_level: Node
var current_path := ""
var levels := {}

func _ready() -> void:
	randomize()
	current_level = $TitleScreen
	current_path = "res://title_screen.tscn"
	levels[current_path] = current_level
	current_level.level_changed.connect(switch_scene, CONNECT_DEFERRED)

## Đổi khu vực chơi; cảnh đã ghé qua được giữ nguyên trạng thái thay vì tạo lại.
func switch_scene(level: PackedScene) -> void:
	var key := level.resource_path
	if key == current_path:
		return
	var next_level: Node
	if levels.has(key):
		next_level = levels[key]
	else:
		next_level = level.instantiate()
		levels[key] = next_level
		next_level.level_changed.connect(switch_scene, CONNECT_DEFERRED)
	var from_path := current_path
	remove_child(current_level)
	current_level = next_level
	current_path = key
	_apply_area(from_path, key)
	add_child(current_level)

func _exit_tree() -> void:
	for level in levels.values():
		if is_instance_valid(level) and level.get_parent() == null:
			level.free()
	levels.clear()

func _apply_area(from_path: String, to_path: String) -> void:
	var window := get_window()
	if to_path == MEADOW_SCENE_PATH:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_size = MEADOW_RESOLUTION
		SoundHandler.stop_music()
	else:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		window.content_scale_size = FARM_RESOLUTION
		if from_path == MEADOW_SCENE_PATH:
			SoundHandler.can_play = true
			SoundHandler.play_music()
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
