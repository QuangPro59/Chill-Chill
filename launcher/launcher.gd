extends Control

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("#2f4a36")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(480, 0)
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := Label.new()
	title.text = "Chill Chill  x  Seasons Gone"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#f1c65a"))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Chọn game muốn chơi"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	box.add_child(subtitle)

	_add_button(box, "1 · Chill Chill — nông trại bốn mùa, chơi 2 người", GameSwitcher.open_chill)
	_add_button(box, "2 · Seasons Gone — luân canh, chu trình nitơ", GameSwitcher.open_seasons)
	_add_button(box, "Thoát", get_tree().quit)

	var hint := Label.new()
	hint.text = "Đang chơi, nhấn F10 để quay lại menu này"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			GameSwitcher.open_chill()
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			GameSwitcher.open_seasons()

func _add_button(parent: Control, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	parent.add_child(button)
