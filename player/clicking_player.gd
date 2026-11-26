extends Node2D

const MAX_PLAYER_PLANT_DIST : float = 100
const crop_strnames: Array[StringName] = [
	&"beet",
	&"potato",
	&"tomato",
	&"french_beans",
	&"pumpkin",
	&"carrot",
	&"onion",
	&"cauliflower",
	&"turnip",
	&"wheat",
	&"grape",
	&"berry",
	&"orange",
]

# get the player 
@export var optional_char: CharacterBody2D

var selected_crop: StringName
var has_character: bool
var in_range : bool = true
## Extra characters (player 2 in local co-op) that can also reach the mouse cursor.
var extra_chars : Array = []
## Temporary solution for player data: a dictionary that keeps everything.
## Should be copied by the save system if implemented.
var player_data: Dictionary = {
	# Crop stocks
	"beet_stock": 0,
	"potato_stock": 0,
	"tomato_stock": 0,
	"french_beans_stock": 0,
	"pumpkin_stock": 0,
	"carrot_stock": 0,
	"onion_stock": 0,
	"cauliflower_stock": 0,
	"turnip_stock": 0,
	"wheat_stock": 0,
	"grape_stock": 0,
	"berry_stock": 0,
	"orange_stock": 0,
	# Money
	"money": 500,
	# Cows (producers) and manure (product)
	"cows": 0,
	"manure_stock": 0
}

# TileMap reference
@onready var tile_map: TileMap = $"../WorldTileMap"
@onready var hotbar = $"../HUD/HotBar"

func _ready() -> void:
	selected_crop = crop_strnames[0]
	has_character = optional_char is CharacterBody2D
	if not has_character: 
		print("ClickingPlayer chưa gắn nhân vật, tạm dùng tầm với vô hạn.")
	

func _process(_delta) -> void:
	pass

func _unhandled_input(event) -> void:
	# Only check for range if character present.
	if event is InputEventMouse:
		_handle_mouse_click(event)
	elif event is InputEventKey:
		_handle_key_press(event)
	
## Docstring
func _handle_mouse_click(event: InputEventMouse) -> void:
	var pad = get_tree().get_first_node_in_group("touch_pad")
	if pad != null and pad.visible and pad.blocks(event.position):
		return
	if has_character:
		in_range = is_mouse_in_range()
	if not in_range:
		tile_map.set_tile_selector(tile_map.DEFAULT_SELECTOR_POS)
		return
	# get mouse position and convert it to tilemap coords
	var mouse_pos = get_global_mouse_position()
	var tile_mouse_pos = tile_map.local_to_map(mouse_pos)
	# Handle the event
	if event is InputEventMouseMotion:
		tile_map.set_tile_selector(tile_mouse_pos)
	elif event.is_action_pressed("add_crop"):
		var info: Dictionary = crop_info(selected_crop)
		if player_data.money >= info.seed_cost:
			player_data.money -= info.seed_cost
			tile_map.add_crop(tile_mouse_pos, selected_crop)
			SoundHandler.play_sound(0)
		else:
			_toast("Không đủ tiền mua hạt giống!", Color(1.0, 0.45, 0.4))
	elif event.is_action_pressed("remove_crop"):
		var crop: Crop = tile_map.get_crop(tile_mouse_pos)
		if crop:
			var harvest_result: Dictionary = crop.harvest()
			player_data.money += harvest_result.money
			if harvest_result.stock != "":
				if player_data.has(harvest_result.stock):
					player_data[harvest_result.stock] += 1
					_toast("Thu hoạch +1 nông sản, +%d xu" % harvest_result.money, Color(0.6, 1.0, 0.5))
				else:
					_toast("Thu hoạch +%d xu" % harvest_result.money, Color(0.6, 1.0, 0.5))
			else:
				_toast("Cây chưa chín, mất hạt giống!", Color(1.0, 0.75, 0.3))
		tile_map.remove_crop(tile_mouse_pos)
		SoundHandler.play_sound(1)

## Docstring
func _handle_key_press(event: InputEventKey) -> void:
	if event.is_action_pressed("grow_crops"):
		for crop in tile_map.crop_instances.values():
			crop.grow(67)
	else:
		# Check for numerical keys
		for i in range(1, crop_strnames.size() + 1):
			if event.is_action_pressed(str("slot_", i)):
				selected_crop = crop_strnames[i - 1]
				hotbar.select_slot(i - 1)

## Cached pricing info (seed cost / selling price) per crop species.
var _crop_info := {}

func crop_info(crop_name: StringName) -> Dictionary:
	if not _crop_info.has(crop_name):
		var instance: Crop = CropsPreloader.get_resource(crop_name).instantiate()
		_crop_info[crop_name] = {
			"seed_cost": instance.seed_cost,
			"selling_price": instance.selling_price,
		}
		instance.free()
	return _crop_info[crop_name]

func _toast(text: String, color: Color = Color(1, 1, 1)) -> void:
	var hud_panel = get_tree().get_first_node_in_group("hud_panel")
	if hud_panel != null and hud_panel.has_method("show_toast"):
		hud_panel.show_toast(text, color)

## Docstring
func is_mouse_in_range() -> bool:	# gets the mouse pos and calculates the distance of it to the player
	var mouse_pos = get_global_mouse_position()
	if mouse_pos.distance_to(optional_char.global_position) < MAX_PLAYER_PLANT_DIST:
		return true
	for other in extra_chars:
		if is_instance_valid(other) and mouse_pos.distance_to(other.global_position) < MAX_PLAYER_PLANT_DIST:
			return true
	return false
