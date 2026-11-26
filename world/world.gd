extends Node2D

signal level_changed(level_name)

# Public Variables
const SEASONS := Global.SEASONS
const MONTHS := Global.MONTHS
const WEATHER := Global.WEATHER
const MED_TEMP: Dictionary = {
	MONTHS.JANUARY: 4,
	MONTHS.FEBRUARY: 4,
	MONTHS.MARCH: 7,
	MONTHS.APRIL: 9,
	MONTHS.MAY: 13,
	MONTHS.JUNE: 16,
	MONTHS.JULY: 18,
	MONTHS.AUGUST: 18,
	MONTHS.SEPTEMBER: 15,
	MONTHS.OCTOBER: 11,
	MONTHS.NOVEMBER: 7,
	MONTHS.DECEMBER: 4
}
const SEASON_FX_SCRIPT := preload("res://season/season_fx.gd")
const COOP_SCRIPT := preload("res://coop/coop_manager.gd")
const COUPLE_SCRIPT := preload("res://couple/couple_manager.gd")
const MEADOW_SCENE_PATH := "res://chill_chill/main.tscn"
const SEASON_FIRST_MONTH := [MONTHS.FEBRUARY, MONTHS.MAY, MONTHS.AUGUST, MONTHS.NOVEMBER]
const QTY_REPLENISH_NITROGEN: int = 20
const P_GEOM_DISTRIB: float = 0.005
const P_PROPAGATION: float = 0.50
## Should be written/read by the save system if implemented.
#var world_data: Dictionary = {
#	"year": 1,
#	"season": SEASONS.SPRING,
#	"month": MONTHS.MARCH,
#	"temperature": 12,
#	"weather" : WEATHER.CLEAR
#}
var year: int = 1
var season := SEASONS.SPRING
var month := MONTHS.MARCH
var temperature: int = MED_TEMP[MONTHS.MARCH]
var weather := WEATHER.CLEAR

# Onready variables
## DocString
@onready var tilemap: TileMap = $WorldTileMap
@onready var player: Node2D = $ClickingPlayerCharacter
@onready var transition_screen: Control = $GeneralUI/MonthTransition
@onready var hud: CanvasLayer = $HUD

# Called when the node enters the scene tree for the first time.
var season_fx
var coop
var couple

func _ready():
	## Should load data here if loading a save file
	season_fx = SEASON_FX_SCRIPT.new()
	add_child(season_fx)
	move_child(season_fx, 0)
	season_fx.setup(self)
	coop = COOP_SCRIPT.new()
	add_child(coop)
	couple = COUPLE_SCRIPT.new()
	add_child(couple)
	_prepare_outdoor_land()
	_prepare_building_sites()
	_populate_herd()
	for child in get_children():
		if child is CharacterBody2D:
			child.add_to_group("outdoor")
			child.collision_layer = 4
			child.collision_mask = 5
		elif child is Area2D:
			child.collision_mask = 2
	$HUD/NextMonthButton.theme = $HUD/HotBar.theme
	_build_interiors()
	get_viewport().size_changed.connect(configure_camera)

const ROOM_NODES := {"house": "HouseInterior", "barn": "BarnInterior", "big_house": "BigHouseInterior"}
const ROOM_DOORS := {"house": "HouseDoor", "barn": "BarnDoor", "big_house": "BigHouseDoor"}
const ROOM_NAMES := {"house": "NHÀ NHỎ", "barn": "CHUỒNG VẬT NUÔI", "big_house": "NGÔI NHÀ CHUNG"}
var interior_mode := ""
var leaving_farm := false
var active_room: Node2D
var resting_positions := {}
var interior_controls: VBoxContainer
var interaction_button: Button
var room_label: Label
var interaction_actor: CharacterBody2D
var interior_voice: AudioStreamPlayer

func _players() -> Array:
	var result: Array = [player.optional_char]
	if coop != null and coop.enabled and is_instance_valid(coop.p2):
		result.append(coop.p2)
	return result

const OUTDOOR_BOUNDS := Rect2i(0, 0, 1536, 800)
const ESTATE := Rect2(1056, 64, 480, 528)
const PASTURES := [Rect2(544, 80, 272, 128), Rect2(544, 224, 160, 128), Rect2(736, 224, 144, 128), Rect2(544, 368, 336, 80)]
const HERD := [["Cow", 6, 0, 8.0], ["Bull", 3, 0, 9.0], ["Calf", 6, 0, 12.0], ["Sheep", 6, 1, 10.0], ["Lamb", 5, 1, 13.0], ["Piglet", 6, 2, 11.0], ["Rooster", 3, 3, 12.0], ["Chick", 7, 3, 16.0], ["Turkey", 5, 3, 10.0]]

func _prepare_outdoor_land() -> void:
	_paint_ground(Rect2(960, -96, 640, 896), 0)
	for y in range(-5, 51, 2):
		for x in range(63, 101, 2):
			var cell := Vector2i(x, y)
			var point := tilemap.map_to_local(cell)
			if ESTATE.grow(24).has_point(point) or Rect2(928, 264, 176, 144).has_point(point):
				continue
			tilemap.set_cell(tilemap.LAYERS.obstacles, cell, 22, Vector2i.ZERO)
	_paint_ground(ESTATE, 0)
	_paint_ground(Rect2(928, 288, 144, 96), 0)
	_paint_ground(Rect2(528, 48, 352, 400), 0)
	for path in [Rect2(880, 160, 48, 336), Rect2(896, 320, 464, 48), Rect2(1328, 304, 48, 112), Rect2(1168, 400, 224, 48), Rect2(528, 208, 400, 16), Rect2(704, 224, 32, 128), Rect2(528, 352, 400, 16)]:
		_paint_ground(path, 1)
		tilemap.building_areas.append(path)
	tilemap.building_areas.append(ESTATE)
	$OutdoorDecor/Scarecrow.position = Vector2(640, 512)
	$OutdoorDecor/Mushroom1.position = Vector2(1112, 504)
	$OutdoorDecor/Flowers1.position = Vector2(1160, 380)
	for point in [Vector2(1112, 140), Vector2(1472, 140), Vector2(1120, 500), Vector2(1464, 500)]:
		var tree: Sprite2D = $OutdoorDecor/Tree1.duplicate()
		tree.position = point
		$OutdoorDecor.add_child(tree)
	for point in [Vector2(1160, 468), Vector2(1216, 468), Vector2(1392, 468), Vector2(1440, 380)]:
		var flowers: Sprite2D = $OutdoorDecor/Flowers1.duplicate()
		flowers.position = point
		$OutdoorDecor.add_child(flowers)
	for point in [Vector2(1144, 272), Vector2(1456, 272), Vector2(1216, 528), Vector2(1376, 528)]:
		var bush: Sprite2D = $OutdoorDecor/Bush1.duplicate()
		bush.position = point
		$OutdoorDecor.add_child(bush)
	_place_outdoor_sign("NHÀ CHUNG →", Vector2(944, 294))

func _paint_ground(area: Rect2, terrain: int) -> void:
	var first := tilemap.local_to_map(area.position)
	var last := tilemap.local_to_map(area.end - Vector2.ONE)
	var cells: Array[Vector2i] = []
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			tilemap.erase_cell(tilemap.LAYERS.obstacles, cell)
			tilemap.erase_cell(tilemap.LAYERS.dirt, cell)
			cells.append(cell)
	tilemap.set_cells_terrain_connect(tilemap.LAYERS.ground, cells, 0, terrain)

func _fence_pasture(area: Rect2, gate: Rect2) -> void:
	var first := tilemap.local_to_map(area.position)
	var last := tilemap.local_to_map(area.end - Vector2.ONE)
	var cells: Array[Vector2i] = []
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if x != first.x and x != last.x and y != first.y and y != last.y:
				continue
			var cell := Vector2i(x, y)
			if not gate.has_point(tilemap.map_to_local(cell)):
				cells.append(cell)
	tilemap.set_cells_terrain_connect(tilemap.LAYERS.obstacles, cells, 1, 0)

func _populate_herd() -> void:
	_fence_pasture(Rect2(1072, 80, 448, 496), Rect2(1056, 320, 48, 64))
	var pens := [[], [], [], []]
	for definition in HERD:
		var species: String = definition[0]
		var template: CharacterBody2D = get_node(species)
		var members := find_children(species + "*", "CharacterBody2D", false, false)
		while members.size() < definition[1]:
			var animal: CharacterBody2D = load(template.scene_file_path).instantiate()
			animal.name = species + str(members.size() + 1)
			for property in ["texture", "hframes", "vframes", "walk_row", "walk_frames", "faces_left", "voice", "voice_pitch"]:
				animal.set(property, template.get(property))
			add_child(animal)
			members.append(animal)
		for animal in members:
			animal.speed = definition[3]
			animal.set_meta("species", species)
			pens[definition[2]].append(animal)
	var labels := ["BÒ & BÊ", "CỪU & CỪU CON", "HEO CON", "GIA CẦM"]
	for index in range(PASTURES.size()):
		var area: Rect2 = PASTURES[index]
		tilemap.building_areas.append(area)
		_fence_pasture(area, Rect2(area.get_center().x - 16, area.end.y - 16, 32, 32))
		_place_outdoor_sign(labels[index], Vector2(area.position.x + 12, area.position.y - 14))
		var columns: int = [5, 4, 3, 8][index]
		var rows := ceili(float(pens[index].size()) / columns)
		var inset := area.grow(-24)
		for number in range(pens[index].size()):
			var animal: CharacterBody2D = pens[index][number]
			animal.global_position = inset.position + Vector2((float(number % columns) + 0.5) / columns * inset.size.x, (floorf(float(number) / columns) + 0.5) / rows * inset.size.y)
			animal.set_roam_area(area.grow(-8))

func _place_outdoor_sign(text: String, point: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = point
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("fff2c7"))
	label.add_theme_color_override("font_outline_color", Color("30220e"))
	label.add_theme_constant_override("outline_size", 3)
	$OutdoorDecor.add_child(label)

func _prepare_building_sites() -> void:
	var sites := []
	for entry in [[$HouseExterior, $HouseDoor], [$BarnExterior, $BarnDoor], [$BigHouseExterior, $BigHouseDoor]]:
		var exterior: Sprite2D = entry[0]
		var door: Area2D = entry[1]
		var dimensions := exterior.region_rect.size * exterior.scale
		var footprint := Rect2(exterior.position - dimensions * 0.5, dimensions)
		tilemap.building_areas.append(footprint)
		sites.append(footprint.grow(20))
		sites.append(Rect2(door.position + Vector2(-48, -16), Vector2(96, 112)))
		var native_size := exterior.region_rect.size
		_add_room_collision(exterior, Rect2(-native_size.x * 0.5 + 12, 12, native_size.x - 24, native_size.y * 0.5 - 26))
	sites.append(Rect2($MeadowPortal.position + Vector2(-110, -65), Vector2(134, 130)))
	for cell in tilemap.get_used_cells(tilemap.LAYERS.obstacles):
		var position_in_world := tilemap.to_global(tilemap.map_to_local(cell))
		for site in sites:
			if site.has_point(position_in_world):
				tilemap.erase_cell(tilemap.LAYERS.obstacles, cell)
				break

func _build_interiors() -> void:
	for room in $Interiors.get_children():
		room.get_node("DoorArea").collision_mask = 2
		var dimensions: Vector2 = room.get_node("Floor").texture.get_size()
		var backdrop := Polygon2D.new()
		backdrop.color = Color("171e21")
		backdrop.z_index = -5
		backdrop.polygon = PackedVector2Array([Vector2(-800, -600), Vector2(1200, -600), Vector2(1200, 800), Vector2(-800, 800)])
		room.add_child(backdrop)
		_add_room_collision(room, Rect2(0, 0, dimensions.x, 26))
		_add_room_collision(room, Rect2(0, dimensions.y - 4, dimensions.x, 8))
		_add_room_collision(room, Rect2(-4, 0, 8, dimensions.y))
		_add_room_collision(room, Rect2(dimensions.x - 4, 0, 8, dimensions.y))
		for item in room.get_children():
			if item is Sprite2D and item.name not in ["Floor", "Rug"]:
				var footprint := Vector2(18, 10)
				if String(item.name).begins_with("Bed"):
					footprint = Vector2(26, 30)
				elif item.name == "Table":
					footprint = Vector2(46, 24)
				elif "shelf" in String(item.name).to_lower():
					footprint = Vector2(32, 18)
				_add_room_collision(room, Rect2(item.position + Vector2(0, 10) - footprint * 0.5, footprint))
	interior_controls = VBoxContainer.new()
	interior_controls.visible = false
	interior_controls.theme = $HUD/HotBar.theme
	interior_controls.add_theme_constant_override("separation", 8)
	hud.add_child(interior_controls)
	interior_controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	interior_controls.offset_left = -150
	interior_controls.offset_right = 150
	interior_controls.offset_top = -65
	interior_controls.offset_bottom = -8
	room_label = Label.new()
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_label.add_theme_font_size_override("font_size", 13)
	interior_controls.add_child(room_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	interior_controls.add_child(buttons)
	interaction_button = Button.new()
	interaction_button.custom_minimum_size = Vector2(182, 30)
	interaction_button.add_theme_font_size_override("font_size", 13)
	interaction_button.focus_mode = Control.FOCUS_NONE
	interaction_button.pressed.connect(func(): interact(interaction_actor))
	buttons.add_child(interaction_button)
	var exit_button := Button.new()
	exit_button.text = "Ra ngoài"
	exit_button.custom_minimum_size = Vector2(110, 30)
	exit_button.add_theme_font_size_override("font_size", 13)
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.pressed.connect(exit_interior)
	buttons.add_child(exit_button)
	interior_voice = AudioStreamPlayer.new()
	interior_voice.volume_db = -12
	add_child(interior_voice)

func _add_room_collision(room: Node2D, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.position = rect.get_center()
	body.add_child(collision)
	room.add_child(body)

func _set_outdoor_visible(value: bool) -> void:
	for node in [tilemap, $OutdoorDecor, $HouseExterior, $BarnExterior, $BigHouseExterior, $BigSign, $MeadowPortal]:
		node.visible = value
	for animal in get_tree().get_nodes_in_group("outdoor"):
		animal.visible = value
		animal.set_physics_process(value)
	$HUD/HotBar.visible = value
	$HUD/NextMonthButton.visible = value
	season_fx.panel.visible = value
	season_fx.particles.visible = value
	season_fx.tint.visible = value
	season_fx.hide_toast()
	interior_controls.visible = not value
	if coop.enabled:
		coop.marker_one.visible = value
		coop.marker_two.visible = value

func _move_players(destination: Vector2) -> void:
	# The walker is a child of the click controller: reset its local offset after moving the parent.
	player.global_position = destination
	player.optional_char.position = Vector2.ZERO
	player.optional_char.velocity = Vector2.ZERO
	if coop.enabled and is_instance_valid(coop.p2):
		coop.p2.global_position = destination + Vector2(24, 0)
		coop.p2.velocity = Vector2.ZERO

func enter_interior(mode: String) -> void:
	if interior_mode != "" or not ROOM_NODES.has(mode):
		return
	interior_mode = mode
	active_room = $Interiors.get_node(ROOM_NODES[mode])
	for room in $Interiors.get_children():
		room.visible = room == active_room
	$Interiors.visible = true
	_move_players(active_room.get_node("Spawn").global_position)
	_set_outdoor_visible(false)
	player.set_process_unhandled_input(false)
	room_label.text = ROOM_NAMES[mode]
	coop.refresh_context()
	configure_camera()

func exit_interior() -> void:
	if interior_mode == "":
		return
	for character in resting_positions.keys():
		_stand_up(character)
	var destination: Vector2 = get_node(ROOM_DOORS[interior_mode]).global_position + Vector2(0, 30)
	interior_mode = ""
	active_room = null
	$Interiors.visible = false
	_move_players(destination)
	_set_outdoor_visible(true)
	player.set_process_unhandled_input(true)
	coop.refresh_context()
	configure_camera()

func configure_camera() -> void:
	if not is_inside_tree():
		return
	var camera: Camera2D = coop.cam if coop.enabled else player.optional_char.get_node("Camera2D")
	camera.enabled = true
	camera.top_level = interior_mode != ""
	if interior_mode != "":
		var dimensions: Vector2 = active_room.get_node("Floor").texture.get_size()
		var view := get_viewport_rect().size
		var zoom_value := minf(1.5, minf((view.x - 64) / dimensions.x, (view.y - 112) / dimensions.y))
		camera.limit_left = -100000
		camera.limit_top = -100000
		camera.limit_right = 100000
		camera.limit_bottom = 100000
		camera.zoom = Vector2.ONE * zoom_value
		camera.global_position = active_room.global_position + dimensions * 0.5
	else:
		camera.limit_left = OUTDOOR_BOUNDS.position.x
		camera.limit_top = OUTDOOR_BOUNDS.position.y
		camera.limit_right = OUTDOOR_BOUNDS.end.x
		camera.limit_bottom = OUTDOOR_BOUNDS.end.y
		camera.zoom = Vector2.ONE
		camera.global_position = player.optional_char.global_position
		if coop.enabled:
			camera.global_position = (coop.p1.global_position + coop.p2.global_position) * 0.5
	camera.make_current()
	camera.reset_smoothing()
	camera.force_update_scroll()

func _interaction_target(character: CharacterBody2D) -> Node2D:
	var nearest: Node2D
	var distance := 44.0
	for item in active_room.get_children():
		if not item is Sprite2D or item.name in ["Floor", "Rug"] or String(item.name).begins_with("Plant"):
			continue
		var next_distance := character.global_position.distance_to(item.global_position + Vector2(0, 12))
		if next_distance < distance:
			distance = next_distance
			nearest = item
	return nearest

func _interaction_text(target: Node2D) -> String:
	var item_name := String(target.name)
	if item_name.begins_with("Bed"):
		return "Nghỉ ngơi"
	if item_name.begins_with("Chair"):
		return "Ngồi xuống"
	if item_name.ends_with("In"):
		return "Cho vật nuôi ăn"
	return "Xem kho nông trại"

func interact(character: CharacterBody2D) -> void:
	if interior_mode == "" or character == null:
		return
	if resting_positions.has(character):
		_stand_up(character)
		return
	var target := _interaction_target(character)
	if target == null:
		return
	var action := _interaction_text(target)
	if action in ["Nghỉ ngơi", "Ngồi xuống"]:
		for other in resting_positions:
			if other.global_position.distance_to(target.global_position + Vector2(0, 4)) < 8:
				season_fx.show_toast("Chỗ này đang có người ngồi.")
				return
		resting_positions[character] = character.global_position
		character.set_physics_process(false)
		character.velocity = Vector2.ZERO
		character.global_position = target.global_position + Vector2(0, 4)
		character.anim.play("down_idle")
		season_fx.show_toast("Đang nghỉ ngơi trong ngôi nhà chung.", Color(1, 0.85, 0.65))
	elif action == "Cho vật nuôi ăn":
		var sound := "res://chill_chill/assets/sfx_sheep.wav"
		if target.name == "PigIn":
			sound = "res://chill_chill/assets/sfx_pig.wav"
		elif target.name == "ChickIn":
			sound = "res://chill_chill/assets/sfx_bird.wav"
		interior_voice.stream = load(sound)
		interior_voice.play()
		season_fx.show_toast("Vật nuôi đã được cho ăn.", Color(0.7, 1, 0.65))
	else:
		var total := 0
		for crop_name in player.crop_strnames:
			total += int(player.player_data[String(crop_name) + "_stock"])
		season_fx.show_toast("Kho: %d nông sản · %d xu" % [total, player.player_data.money])

func _stand_up(character: CharacterBody2D) -> void:
	if not resting_positions.has(character):
		return
	character.global_position = resting_positions[character]
	character.set_physics_process(true)
	resting_positions.erase(character)

func _process(_delta: float) -> void:
	if interior_mode == "":
		return
	for character in resting_positions.keys():
		var prefix := "p2_" if character.player_id == 2 else "p1_"
		if not coop.enabled:
			prefix = "ui_"
		if Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down") != Vector2.ZERO:
			_stand_up(character)
	interaction_actor = null
	interaction_button.text = "Tương tác"
	for character in _players():
		if resting_positions.has(character):
			interaction_actor = character
			interaction_button.text = "Đứng dậy"
			break
		var target := _interaction_target(character)
		if target != null:
			interaction_actor = character
			interaction_button.text = _interaction_text(target)
			break
	interaction_button.disabled = interaction_actor == null
	if not coop.enabled and Input.is_action_just_pressed("p1_plant"):
		interact(player.optional_char)

func _on_house_door_body_entered(body: Node2D) -> void:
	if body in _players():
		enter_interior.call_deferred("house")

func _on_barn_door_body_entered(body: Node2D) -> void:
	if body in _players():
		enter_interior.call_deferred("barn")

func _on_bighouse_door_body_entered(body: Node2D) -> void:
	if body in _players():
		enter_interior.call_deferred("big_house")

func _on_interior_door_body_entered(body: Node2D) -> void:
	if body in _players():
		exit_interior.call_deferred()

func _on_meadow_portal_body_entered(body: Node2D) -> void:
	if leaving_farm or body not in _players() or interior_mode != "":
		return
	# Cached Area2D overlaps can emit again when the farm is reattached.
	var portal_shape: RectangleShape2D = $MeadowPortal/CollisionShape2D.shape
	var feet: Vector2 = $MeadowPortal.to_local(body.global_position + Vector2(0, 11))
	if not Rect2(-portal_shape.size * 0.5, portal_shape.size).grow(8).has_point(feet):
		return
	leaving_farm = true
	_leave_for_meadow.call_deferred()

func _leave_for_meadow() -> void:
	FarmState.save_from_farm(int(player.player_data.money), int(season))
	_move_players($MeadowPortal.global_position + Vector2(-110, 0))
	level_changed.emit(load(MEADOW_SCENE_PATH))

func _enter_tree() -> void:
	leaving_farm = false
	if player != null and FarmState.touched:
		_apply_shared_state.call_deferred()

func _apply_shared_state() -> void:
	player.player_data.money = FarmState.money
	@warning_ignore("int_as_enum_without_cast")
	season = FarmState.season_index + 1
	@warning_ignore("int_as_enum_without_cast")
	month = SEASON_FIRST_MONTH[FarmState.season_index]
	temperature = _random_temperature(month)
	if season_fx != null:
		season_fx.refresh(false)
	var portal: Area2D = $MeadowPortal
	var walker: Node2D = player.optional_char
	for character in _players():
		if character.global_position.distance_to(portal.global_position) < 100.0:
			_move_players(portal.global_position + Vector2(-110, 0))
			break
	configure_camera()

func time_skip() -> void:
	
	hud.hide()
	transition_screen.animation_player.play("fade_in_out")
	#get_tree().paused = true
	
	# Crops and soil changes for the month
	for coords in tilemap.soildata_instances:
		var soildata: SoilData = tilemap.soildata_instances[coords]
		# If the field cell has a crop
		if tilemap.crop_instances.has(coords):
			var crop: Crop = tilemap.crop_instances[coords]
			crop.grow(_compute_growth(crop, soildata))
			soildata.total_nitrogen -= crop.nitrogen_consumption
			soildata.current_crop = crop
			#_propagate_disease()
			if crop.sick == false:
				crop.sick = _gamble_sick(soildata)
				print(crop.sick)
			else:
				_propagate_disease(coords, crop.family)
		# If the field is bare, during fallow for exemple
		else:
			soildata.total_nitrogen += QTY_REPLENISH_NITROGEN
			soildata.current_crop = null
	# Money and game over handling
	var costs := _money_costs()
	transition_screen.season_tag.text = season_fx.SEASON_NAMES[clampi(int(season), 1, 4)]
	transition_screen.food_tag.text = "-%d" % costs.food
	transition_screen.taxes_tag.text = "-%d" % costs.taxes
	transition_screen.random_tag.text = "0"
	# Changing to new month
	_advance_calendar()
	temperature = _random_temperature(month)
	_roll_weather()
	season_fx.refresh()
	couple.on_month()
	
	await transition_screen.exited
	hud.show()

func _advance_calendar() -> void:
	# Seasons
	if month in [MONTHS.MAY, MONTHS.AUGUST, MONTHS.NOVEMBER]:
		@warning_ignore("int_as_enum_without_cast")
		season += 1
	elif month == MONTHS.FEBRUARY:
		season = SEASONS.SPRING
	# Months & Year
	if month == MONTHS.DECEMBER:
		month = MONTHS.JANUARY
		year += 1
	else:
		@warning_ignore("int_as_enum_without_cast")
		month += 1
	
const MONTHLY_FOOD_COST: int = 20

func _money_costs() -> Dictionary:
	var food := MONTHLY_FOOD_COST
	@warning_ignore("integer_division")
	var taxes := int(player.player_data.money) / 20
	player.player_data.money = maxi(0, int(player.player_data.money) - food - taxes)
	return {"food": food, "taxes": taxes}
	
## Compute the growth for the plant given crop and soil data
func _compute_growth(crop: Crop, soildata: SoilData) -> int:
	# Parameters:
	# - Current world temperature (before change)
	# every degree above baseline = 1 GDD, multiplied by 30 days
	# https://en.wikipedia.org/wiki/Growing_degree-day
	# - Current nitrogen level (if > 3*consumption: 1,
	# if bewteen 1c et 3c: 0.8, if below 1c: 0.3
	# THIS TIERING IS NOT BASED ON REAL CONCEPT/DATA
	# - is the plant sick (0.8 factor)
	var days := 30 #90 IF SEASON
	var delta_T := temperature - crop.baseline_temperature
	var sick_factor := 0.8 if crop.sick else 1.0
	var NO3_ratio := float(soildata.total_nitrogen) / crop.nitrogen_consumption
	var NO3_factor: float
	if NO3_ratio >= 3 or NO3_ratio < 0: # negative is consumption also is
		NO3_factor = 1.0
	elif 1 <= NO3_ratio and NO3_ratio < 3:
		NO3_factor = 0.8
	else:
		NO3_factor = 0.3
	# print(days, " ", delta_T, " ", sick_factor, " ", NO3_factor)
	var growth: int = round(days*delta_T*sick_factor*NO3_factor)
	return growth

## Pick a random temperature from a certain month, based on the medium
## temperature for the month and a variation that follows an uniform law.
func _random_temperature(current_month: MONTHS) -> int:
	var med_temp: int = MED_TEMP[current_month]
	return med_temp + randi_range(-2, 2)

## Uses the cumulative distribution function of a geometric distribution.
## With k the `total_month_unchanged` & p probability of getting sick 1st month:
## P("getting sick") = 1 - (1-p)**k
func _gamble_sick(soildata: SoilData) -> bool:
	var proba := 1 - pow((1-P_GEOM_DISTRIB), soildata.total_month_unchanged)
	return randf() < proba

const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

func _propagate_disease(cell: Vector2i, family: Crop.FAMILIES) -> void:
	for offset in NEIGHBOR_OFFSETS:
		var neighbor_cell := cell + offset
		if not tilemap.crop_instances.has(neighbor_cell):
			continue
		var neighbor_crop: Crop = tilemap.crop_instances[neighbor_cell]
		if not neighbor_crop.sick and neighbor_crop.family == family:
			neighbor_crop.sick = Global.bernoulli(P_PROPAGATION)
		

## Chọn thời tiết cho tháng mới theo mùa (chỉ là hiệu ứng hình ảnh).
func _roll_weather() -> void:
	var roll := randf()
	if season == SEASONS.SPRING:
		weather = WEATHER.RAIN if roll < 0.40 else WEATHER.CLEAR
	elif season == SEASONS.SUMMER:
		if roll < 0.15:
			weather = WEATHER.DROUGHT
		elif roll < 0.40:
			weather = WEATHER.RAIN
		else:
			weather = WEATHER.CLEAR
	elif season == SEASONS.FALL:
		weather = WEATHER.RAIN if roll < 0.45 else WEATHER.CLEAR
	else:
		if roll < 0.55:
			weather = WEATHER.SNOW
		elif roll < 0.75:
			weather = WEATHER.FROST
		else:
			weather = WEATHER.CLEAR
