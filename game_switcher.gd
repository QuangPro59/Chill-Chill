extends Node

const MENU_SCENE := "res://launcher/launcher.tscn"
const CHILL_SCENE := "res://chill_chill/main.tscn"
const SEASONS_SCENE := "res://game.tscn"
const CHILL_RESOLUTION := Vector2i(1280, 720)
const SEASONS_RESOLUTION := Vector2i(640, 360)

var current := "seasons"
var hint_layer: CanvasLayer
var hint_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hint()

func _input(_event: InputEvent) -> void:
	pass

func open_menu() -> void:
	current = "menu"
	get_tree().paused = false
	SoundHandler.stop_music()
	_set_resolution(CHILL_RESOLUTION, Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	hint_label.visible = false
	get_tree().change_scene_to_file(MENU_SCENE)

func open_chill() -> void:
	current = "chill"
	get_tree().paused = false
	SoundHandler.stop_music()
	_set_resolution(CHILL_RESOLUTION, Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	get_tree().change_scene_to_file(CHILL_SCENE)
	_show_hint()

func open_seasons() -> void:
	current = "seasons"
	get_tree().paused = false
	_set_resolution(SEASONS_RESOLUTION, Window.CONTENT_SCALE_MODE_VIEWPORT)
	SoundHandler.can_play = true
	SoundHandler.play_music()
	get_tree().change_scene_to_file(SEASONS_SCENE)
	_show_hint()

func _set_resolution(size: Vector2i, mode: Window.ContentScaleMode) -> void:
	var window := get_window()
	window.content_scale_mode = mode
	window.content_scale_size = size
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

func _build_hint() -> void:
	hint_layer = CanvasLayer.new()
	hint_layer.layer = 100
	add_child(hint_layer)
	hint_label = Label.new()
	hint_label.text = "F10: về menu chọn game"
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint_label.add_theme_constant_override("outline_size", 4)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint_label.offset_top = 6
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.visible = false
	hint_layer.add_child(hint_label)

func _show_hint() -> void:
	if OS.has_feature("mobile"):
		return
	hint_label.visible = true
	hint_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(hint_label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(func() -> void: hint_label.visible = false)
