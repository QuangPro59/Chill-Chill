extends Node

const PLAYER_SCENE := preload("res://player/player_character.tscn")
const MARKER_SCRIPT := preload("res://coop/coop_marker.gd")
const TOUCH_SCRIPT := preload("res://touch/touch_pad.gd")
const P1_TINT := Color(0.78, 0.88, 1.0)
const P2_TINT := Color(1.0, 0.8, 0.9)
const CROP_LABELS := {
	"beet": "Củ dền",
	"potato": "Khoai tây",
	"tomato": "Cà chua",
	"french_beans": "Đậu cove",
	"pumpkin": "Bí ngô",
	"carrot": "Cà rốt",
	"onion": "Hành tây",
	"cauliflower": "Súp lơ",
	"turnip": "Củ cải",
	"wheat": "Lúa mì",
	"grape": "Nho",
	"berry": "Dâu",
	"orange": "Cam",
}

var auto_enable := true
var world
var clicker
var tile_map
var hotbar
var p1
var p2
var cam: Camera2D
var marker_one: Node2D
var marker_two: Node2D
var enabled := false
var p2_crop_index := 0
var hud: CanvasLayer
var info_label: Label
var touch_layer: CanvasLayer
var pad: Control
var is_touch := false

func _ready() -> void:
	world = get_parent()
	clicker = world.get_node("ClickingPlayerCharacter")
	tile_map = world.get_node("WorldTileMap")
	hotbar = world.get_node("HUD/HotBar")
	p1 = clicker.get_node("PlayerCharacter")
	is_touch = _detect_touch()
	_bind_actions()
	_build_hud()
	_build_touch()
	_refresh_hud()
	if auto_enable:
		call_deferred("toggle")

func _detect_touch() -> bool:
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		return true
	return bool(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false))

func _bind_actions() -> void:
	_add_action("p1_left", [KEY_A])
	_add_action("p1_right", [KEY_D])
	_add_action("p1_up", [KEY_W])
	_add_action("p1_down", [KEY_S])
	_add_action("p1_plant", [KEY_E])
	_add_action("p1_remove", [KEY_Q])
	_add_action("p1_next", [KEY_C])
	_add_action("p1_prev", [KEY_Z])
	_add_action("p2_left", [KEY_LEFT])
	_add_action("p2_right", [KEY_RIGHT])
	_add_action("p2_up", [KEY_UP])
	_add_action("p2_down", [KEY_DOWN])
	_add_action("p2_plant", [KEY_SLASH, KEY_KP_0])
	_add_action("p2_remove", [KEY_PERIOD, KEY_KP_PERIOD])
	_add_action("p2_next", [KEY_BRACKETRIGHT, KEY_KP_ADD])
	_add_action("p2_prev", [KEY_BRACKETLEFT, KEY_KP_SUBTRACT])

func _add_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for key_code in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key_code
		if not InputMap.action_has_event(action_name, event):
			InputMap.action_add_event(action_name, event)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 1
	add_child(hud)
	info_label = Label.new()
	info_label.position = Vector2(6, 24)
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	info_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	info_label.add_theme_constant_override("outline_size", 4)
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(info_label)

func _build_touch() -> void:
	touch_layer = CanvasLayer.new()
	touch_layer.layer = 4
	add_child(touch_layer)
	pad = TOUCH_SCRIPT.new()
	touch_layer.add_child(pad)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_joystick("left", ["p1_left", "ui_left"], ["p1_right", "ui_right"], ["p1_up", "ui_up"], ["p1_down", "ui_down"], P1_TINT)
	pad.add_joystick("right", ["p2_left"], ["p2_right"], ["p2_up"], ["p2_down"], P2_TINT)
	pad.add_button("left", 0, "Trồng", "p1_plant", P1_TINT)
	pad.add_button("left", 1, "Nhổ", "p1_remove", P1_TINT)
	pad.add_button("left", 2, "Đổi cây", "p1_next", P1_TINT)
	pad.add_button("right", 0, "Trồng", "p2_plant", P2_TINT)
	pad.add_button("right", 1, "Nhổ", "p2_remove", P2_TINT)
	pad.add_button("right", 2, "Đổi cây", "p2_next", P2_TINT)
	pad.visible = is_touch

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		toggle()

func toggle() -> void:
	enabled = not enabled
	if enabled:
		_enable()
	else:
		_disable()
	_refresh_hud()

func _enable() -> void:
	p1.coop_active = true
	p1.modulate = P1_TINT
	p2 = PLAYER_SCENE.instantiate()
	p2.player_id = 2
	var p2_camera = p2.get_node_or_null("Camera2D")
	if p2_camera != null:
		p2.remove_child(p2_camera)
		p2_camera.free()
	p2.modulate = Color.WHITE
	p2.z_index = 1
	world.add_child(p2)
	p2.global_position = p1.global_position + Vector2(24, 0)
	clicker.extra_chars = [p2]
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	world.add_child(cam)
	cam.global_position = (p1.global_position + p2.global_position) * 0.5
	cam.make_current()
	var p1_camera = p1.get_node_or_null("Camera2D")
	if p1_camera != null:
		p1_camera.enabled = false
	var tile_size: Vector2i = tile_map.tile_set.tile_size
	marker_one = _make_marker(P1_TINT, Vector2(tile_size))
	marker_two = _make_marker(P2_TINT, Vector2(tile_size))
	refresh_context()
	world.configure_camera()

func _make_marker(color: Color, cell_size: Vector2) -> Node2D:
	var marker := Node2D.new()
	marker.set_script(MARKER_SCRIPT)
	marker.z_index = 2
	marker.cell_size = cell_size
	marker.marker_color = color
	world.add_child(marker)
	return marker

func _disable() -> void:
	p1.coop_active = false
	p1.modulate = Color(1, 1, 1)
	clicker.extra_chars = []
	var p1_camera = p1.get_node_or_null("Camera2D")
	if p1_camera != null:
		p1_camera.enabled = true
		p1_camera.make_current()
	if cam != null:
		cam.queue_free()
		cam = null
	if marker_one != null:
		marker_one.queue_free()
		marker_one = null
	if marker_two != null:
		marker_two.queue_free()
		marker_two = null
	if p2 != null:
		world._stand_up(p2)
		p2.queue_free()
		p2 = null
	refresh_context()
	world.configure_camera()

func _process(delta: float) -> void:
	if not enabled or p2 == null:
		return
	if world.interior_mode != "":
		if Input.is_action_just_pressed("p1_plant"):
			world.interact(p1)
		if Input.is_action_just_pressed("p2_plant"):
			world.interact(p2)
		return
	_update_camera(delta)
	var cell_one := _front_cell(p1)
	var cell_two := _front_cell(p2)
	marker_one.global_position = tile_map.to_global(tile_map.map_to_local(cell_one))
	marker_two.global_position = tile_map.to_global(tile_map.map_to_local(cell_two))
	if Input.is_action_just_pressed("p1_next"):
		_cycle_p1(1)
	if Input.is_action_just_pressed("p1_prev"):
		_cycle_p1(-1)
	if Input.is_action_just_pressed("p1_plant"):
		_plant(cell_one, clicker.selected_crop)
	if Input.is_action_just_pressed("p1_remove"):
		_remove(cell_one)
	if Input.is_action_just_pressed("p2_next"):
		_cycle_p2(1)
	if Input.is_action_just_pressed("p2_prev"):
		_cycle_p2(-1)
	if Input.is_action_just_pressed("p2_plant"):
		_plant(cell_two, clicker.crop_strnames[p2_crop_index])
	if Input.is_action_just_pressed("p2_remove"):
		_remove(cell_two)

func _update_camera(delta: float) -> void:
	var a: Vector2 = p1.global_position
	var b: Vector2 = p2.global_position
	cam.global_position = (a + b) * 0.5
	var view := get_viewport().get_visible_rect().size
	var span := Vector2(absf(a.x - b.x) + 160.0, absf(a.y - b.y) + 120.0)
	var target := clampf(minf(view.x / span.x, view.y / span.y), 0.7, 1.0)
	var next := lerpf(cam.zoom.x, target, clampf(delta * 4.0, 0.0, 1.0))
	cam.zoom = Vector2(next, next)

func _front_cell(player) -> Vector2i:
	var feet: Vector2 = player.global_position + Vector2(0, 12) + player.facing * 14.0
	return tile_map.local_to_map(tile_map.to_local(feet))

func _cycle_p1(step: int) -> void:
	var count: int = clicker.crop_strnames.size()
	var index: int = clicker.crop_strnames.find(clicker.selected_crop)
	hotbar.select_slot(posmod(index + step, count))
	_refresh_hud()

func _cycle_p2(step: int) -> void:
	var count: int = clicker.crop_strnames.size()
	p2_crop_index = posmod(p2_crop_index + step, count)
	_refresh_hud()

func _plant(cell: Vector2i, crop_name: StringName) -> void:
	var had: bool = tile_map.crop_instances.has(cell)
	tile_map.add_crop(cell, crop_name)
	if not had and tile_map.crop_instances.has(cell):
		SoundHandler.play_sound(0)

func _remove(cell: Vector2i) -> void:
	if tile_map.crop_instances.has(cell):
		tile_map.remove_crop(cell)
		SoundHandler.play_sound(1)

func refresh_context() -> void:
	var outdoors: bool = world.interior_mode == ""
	if marker_one != null:
		marker_one.visible = outdoors
	if marker_two != null:
		marker_two.visible = outdoors
	for button in pad.buttons:
		button.caption = "Trồng" if outdoors else "Dùng"
		if int(button.slot) == 1:
			button.caption = "Nhổ"
		elif int(button.slot) == 2:
			button.caption = "Đổi cây"
		button.visible = (outdoors or int(button.slot) == 0) and (button.side == "left" or enabled)
	pad.queue_redraw()

func _refresh_hud() -> void:
	pad.set_side_visible("right", enabled)
	refresh_context()
	info_label.text = ""
