extends Control

@export var player: Node2D

const GOLD := Color(0.93, 0.75, 0.36)
const WOOD := Color(0.13, 0.09, 0.06, 0.96)
const CREAM := Color(1.0, 0.94, 0.8)

var normal_slot: StyleBoxFlat
var clicked_slot: StyleBoxFlat
var has_player: bool = false
var _selected_index := -1

@onready var grid_container := $SlotsRect/SlotsGrid
@onready var buy_label := $ShopRect/BuyButton/Label
@onready var sell_label := $ShopRect/SellButton/Label
@onready var slots := grid_container.get_children()
@onready var selected_crop_label: Label = $SelectedCrop

func _ready() -> void:
	has_player = is_instance_valid(player)
	_apply_theme()
	for index in range(slots.size()):
		var slot: Button = slots[index]
		slot.custom_minimum_size = Vector2(34, 38)
		slot.clip_contents = true
		slot.toggle_mode = true
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.disabled = not has_player
		slot.pressed.connect(select_slot.bind(index))

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(4, 3)
		icon.size = Vector2(26, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if has_player and index < player.crop_strnames.size():
			icon.texture = _crop_icon(player.crop_strnames[index])
		slot.add_child(icon)

		var count := Label.new()
		count.name = "Count"
		count.position = Vector2(2, 22)
		count.size = Vector2(30, 16)
		count.text = "0"
		count.clip_text = true
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 11)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count)

	$ShopRect/BuyButton.disabled = not has_player
	$ShopRect/SellButton.disabled = not has_player
	$ShopRect/BuyButton.pressed.connect(_on_buy_pressed)
	$ShopRect/SellButton.pressed.connect(_on_sell_pressed)
	select_slot(0)
	_refresh_counts()

func _apply_theme() -> void:
	theme = Theme.new()
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = 12
	theme.set_color("font_color", "Label", CREAM)
	theme.set_constant("outline_size", "Label", 0)
	normal_slot = _box(Color(0.08, 0.055, 0.035, 0.98), Color(0.46, 0.33, 0.16))
	clicked_slot = _box(Color(0.32, 0.22, 0.09), GOLD)
	theme.set_stylebox("normal", "Button", normal_slot)
	theme.set_stylebox("pressed", "Button", clicked_slot)
	theme.set_stylebox("hover_pressed", "Button", clicked_slot)
	theme.set_stylebox("hover", "Button", _box(Color(0.23, 0.16, 0.08), GOLD))
	theme.set_stylebox("disabled", "Button", normal_slot)
	var background := _box(WOOD, GOLD)
	background.set_corner_radius_all(8)
	$Backdrop.add_theme_stylebox_override("panel", background)
	selected_crop_label.add_theme_color_override("font_color", GOLD)

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style

func _crop_icon(crop_name: StringName) -> Texture2D:
	var scene := CropsPreloader.get_resource(crop_name) as PackedScene
	if scene == null:
		return null
	# Read only the exported texture; no gameplay Crop enters the UI tree.
	var state := scene.get_state()
	for property_index in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, property_index) == &"vegetable_texture":
			return state.get_node_property_value(0, property_index) as Texture2D
	return null

func reset_slot_selection() -> void:
	for slot in slots:
		slot.set_pressed_no_signal(false)

func select_slot(index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	if has_player and index >= player.crop_strnames.size():
		return
	reset_slot_selection()
	slots[index].set_pressed_no_signal(true)
	_selected_index = index
	selected_crop_label.text = "Đang chọn: %s" % slots[index].tooltip_text
	if has_player:
		player.selected_crop = player.crop_strnames[index]

func _process(_delta: float) -> void:
	if not has_player or not is_instance_valid(player):
		return
	var index: int = player.crop_strnames.find(player.selected_crop)
	if index != _selected_index:
		select_slot(index)
	_refresh_counts()

func _refresh_counts() -> void:
	if not has_player:
		return
	for index in range(mini(slots.size(), player.crop_strnames.size())):
		var stock_key := String(player.crop_strnames[index]) + "_stock"
		var text := str(int(player.player_data.get(stock_key, 0)))
		var count: Label = slots[index].get_node("Count")
		if count.text != text:
			count.text = text

func _on_buy_pressed():
	if not has_player:
		return
	var info: Dictionary = player.crop_info(player.selected_crop)
	if player.player_data.money >= info.seed_cost:
		player.player_data.money -= info.seed_cost
		var stock_key := String(player.selected_crop) + "_stock"
		if player.player_data.has(stock_key):
			player.player_data[stock_key] += 1
		player._toast("Đã mua 1 nông sản (-%d xu)" % info.seed_cost, Color(0.7, 0.85, 1.0))
	else:
		player._toast("Không đủ tiền!", Color(1.0, 0.45, 0.4))
	_refresh_counts()

func _on_sell_pressed():
	if not has_player:
		return
	var total := 0
	for key in player.player_data.keys():
		var key_str := String(key)
		if key_str.ends_with("_stock") and int(player.player_data[key]) > 0:
			var species_name := StringName(key_str.trim_suffix("_stock"))
			if player.crop_strnames.has(species_name):
				total += player.crop_info(species_name).selling_price * int(player.player_data[key])
				player.player_data[key] = 0
	if total > 0:
		player.player_data.money += total
		player._toast("Đã bán nông sản +%d xu" % total, Color(1.0, 0.85, 0.3))
	else:
		player._toast("Không có nông sản để bán", Color(1.0, 0.75, 0.3))
	_refresh_counts()
