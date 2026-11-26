extends Node

const SAVE_PATH := "user://couple_save.json"
const HEARTS_SCRIPT := preload("res://couple/couple_hearts.gd")
const LOVE_BAR_SCRIPT := preload("res://couple/love_bar.gd")
const CLOSE_DISTANCE := 56.0
const LOVE_PER_LEVEL := 100.0
const LEVEL_GIFT := 50
const MONTH_LOVE := 10.0

var world
var coop
var clicker
var love := 0.0
var level := 1
var names: Array = ["Anh", "Em"]
var has_save := false
var hearts_node: Node2D
var hud: CanvasLayer
var toast_label: Label
var name_labels: Array = [null, null]
var heart_timer := 0.0
var save_timer := 0.0

func _ready() -> void:
	world = get_parent()
	coop = world.coop
	clicker = world.get_node("ClickingPlayerCharacter")
	_load()
	level = 1 + int(love / LOVE_PER_LEVEL)
	hearts_node = Node2D.new()
	hearts_node.set_script(HEARTS_SCRIPT)
	world.add_child(hearts_node)
	_build_hud()
	if not has_save:
		_show_name_dialog()

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 1
	add_child(hud)
	var bar := Control.new()
	bar.set_script(LOVE_BAR_SCRIPT)
	hud.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.manager = self
	toast_label = Label.new()
	toast_label.add_theme_font_size_override("font_size", 14)
	toast_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.9))
	toast_label.add_theme_color_override("font_outline_color", Color(0.3, 0.0, 0.1, 0.9))
	toast_label.add_theme_constant_override("outline_size", 5)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.visible = false
	hud.add_child(toast_label)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_top = 40.0
	toast_label.offset_left = -200.0
	toast_label.offset_right = 200.0

func _process(delta: float) -> void:
	if coop == null or not coop.enabled or coop.p2 == null:
		return
	_ensure_labels()
	var a: Vector2 = coop.p1.global_position
	var b: Vector2 = coop.p2.global_position
	if a.distance_to(b) < CLOSE_DISTANCE:
		_add_love(delta)
		heart_timer -= delta
		if heart_timer <= 0.0:
			heart_timer = 1.4
			hearts_node.spawn((a + b) * 0.5 + Vector2(0.0, -14.0))
	save_timer += delta
	if save_timer > 15.0:
		save_timer = 0.0
		_save()

func on_month() -> void:
	_add_love(MONTH_LOVE)
	if coop != null and coop.enabled and coop.p1 != null:
		hearts_node.spawn(coop.p1.global_position + Vector2(0.0, -20.0))

func _add_love(amount: float) -> void:
	var before := int(love / LOVE_PER_LEVEL)
	love += amount
	var after := int(love / LOVE_PER_LEVEL)
	if after > before:
		level = 1 + after
		clicker.player_data["money"] += LEVEL_GIFT
		_show_toast("Tình yêu lên cấp %d! Quà tặng: +%d tiền" % [level, LEVEL_GIFT])
		_save()

func _show_toast(message: String) -> void:
	toast_label.text = message
	toast_label.visible = true
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(toast_label.hide)

func _ensure_labels() -> void:
	var players: Array = [coop.p1, coop.p2]
	for i in range(2):
		var existing = name_labels[i]
		if existing != null and is_instance_valid(existing) and existing.get_parent() == players[i]:
			existing.text = str(names[i])
			continue
		var label := Label.new()
		label.text = str(names[i])
		label.position = Vector2(-20.0, -36.0)
		label.custom_minimum_size = Vector2(40.0, 0.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("outline_size", 3)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		players[i].add_child(label)
		name_labels[i] = label

func _show_name_dialog() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Hai bạn tên là gì?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var edit_one := LineEdit.new()
	edit_one.text = str(names[0])
	edit_one.max_length = 12
	edit_one.custom_minimum_size = Vector2(200.0, 26.0)
	box.add_child(edit_one)
	var edit_two := LineEdit.new()
	edit_two.text = str(names[1])
	edit_two.max_length = 12
	edit_two.custom_minimum_size = Vector2(200.0, 26.0)
	box.add_child(edit_two)
	var ok := Button.new()
	ok.text = "Bắt đầu"
	ok.custom_minimum_size = Vector2(0.0, 28.0)
	box.add_child(ok)
	ok.pressed.connect(_confirm_names.bind(edit_one, edit_two, layer))
	get_tree().paused = true

func _confirm_names(edit_one: LineEdit, edit_two: LineEdit, layer: CanvasLayer) -> void:
	var first := edit_one.text.strip_edges()
	var second := edit_two.text.strip_edges()
	names = [first if first != "" else "Anh", second if second != "" else "Em"]
	has_save = true
	layer.queue_free()
	get_tree().paused = false
	_save()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	love = float(data.get("love", 0.0))
	var saved_names = data.get("names", names)
	if typeof(saved_names) == TYPE_ARRAY and saved_names.size() >= 2:
		names = [str(saved_names[0]), str(saved_names[1])]
	has_save = true

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"love": love, "names": names}))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if has_save:
			_save()
