extends Node2D

signal level_changed(level)

const WORLD_SIZE := Vector2(1600, 1040)
const FIELD_ORIGIN := Vector2(744, 296)
const FIELD_COLS := 7
const FIELD_ROWS := 5
const FIELD_STEP := 48
const PLOT_SIZE := Vector2(42, 42)
const SAVE_PATH := "user://harvest_hollow_save.json"
const FARM_SCENE_PATH := "res://world/world.tscn"
const EXIT_GATE := Rect2(0, 380, 62, 200)
const CROPS := ["carrot", "turnip", "berry", "corn", "tomato", "pumpkin"]
const CROP_LABELS := {"carrot": "Cà rốt", "turnip": "Củ cải", "berry": "Dâu", "corn": "Ngô", "tomato": "Cà chua", "pumpkin": "Bí đỏ"}
const CROP_PRICES := {"carrot": 18, "turnip": 24, "berry": 32, "corn": 26, "tomato": 30, "pumpkin": 38}
const CROP_DAYS := {"carrot": 3, "turnip": 4, "berry": 5, "corn": 4, "tomato": 5, "pumpkin": 6}
const CROP_SEASONS := {"carrot": [0, 2], "turnip": [0, 2, 3], "berry": [0, 1], "corn": [1, 2], "tomato": [0, 1], "pumpkin": [2, 3]}
const CROP_BONUS_SEASON := {"carrot": 2, "turnip": 3, "berry": 1, "corn": 1, "tomato": 0, "pumpkin": 2}
const AUTUMN_LEAF_COLORS := [Color("#e9b63c"), Color("#f3ca5e"), Color("#d99a2b")]
const SEASON_NAMES := ["Xuân", "Hạ", "Thu", "Đông"]
const SEASON_DAYS := 7
const SKY_CARD_SCRIPT = preload("res://chill_chill/sky_card.gd")
const TOOL_LABELS := ["Cuốc đất", "Gieo hạt", "Tưới nước", "Thu hoạch"]
const GOLD := Color("#f1c65a")
const PLAYER_COUNT := 2
const PLAYER_NAMES := ["Nông dân (nam)", "Cô vợ (nữ)"]
const PLAYER_START := [Vector2(652, 506), Vector2(612, 506)]
const PLAYER_MARK_COLORS := [Color("#f1c65a"), Color("#7fb2e5")]
const SHORT_TOOL_LABELS := ["Cuốc", "Gieo", "Tưới", "Hái"]
const PLAYER_KEYS := [
    {"left": "move_left", "right": "move_right", "up": "move_up", "down": "move_down", "use": "use_tool", "interact": "interact", "seed": "cycle_seed", "tool0": "tool_1", "tool1": "tool_2", "tool2": "tool_3", "tool3": "tool_4"},
    {"left": "p2_move_left", "right": "p2_move_right", "up": "p2_move_up", "down": "p2_move_down", "use": "p2_use_tool", "interact": "p2_interact", "seed": "p2_cycle_seed", "tool0": "p2_tool_1", "tool1": "p2_tool_2", "tool2": "p2_tool_3", "tool3": "p2_tool_4"}
]

var rng := RandomNumberGenerator.new()
var plant_sheet: Texture2D
var animal_textures: Dictionary = {}
var plots: Array[Dictionary] = []
var animals: Array[Dictionary] = []
var produce := {"carrot": 0, "turnip": 0, "berry": 0, "egg": 0, "milk": 0, "wool": 0}
var seeds := {"carrot": 12, "turnip": 8, "berry": 5}
var day := 1
var hour := 7
var minute := 0
var clock_accumulator := 0.0
var weather := "Nắng"
var coins := 90
var leaving := false
var has_run := false
var feed_bags := 2
var modal_open := false
var coop_enabled := false
var players: Array[Dictionary] = []
var acting := -1
var shop_player := 0
var coop_button: Button
var sound_enabled := true
var music_enabled := true
var rain_phase := 0.0

var sfx_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer
var animal_voice_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var sfx_streams: Dictionary = {}
var sky_card
var camera: Camera2D
var hud_root: Control
var day_label: Label
var time_label: Label
var money_label: Label
var weather_label: Label
var season_label: Label
var energy_label: Label
var inventory_label: Label
var tool_label: Label
var toast_label: Label
var shop_overlay: ColorRect
var shop_info: Label
var seed_buy_button: Button
var sound_button: Button
var music_button: Button

func _ready() -> void:
	rng.randomize()
	_bind_controls()
	_load_assets()
	_make_plots()
	_make_animals()
	_make_players()
	_load_game()
	camera = get_node_or_null("Camera2D") as Camera2D
	for i in range(players.size()):
		var p: Vector2 = players[i]["pos"]
		if EXIT_GATE.has_point(p):
			players[i]["pos"] = PLAYER_START[mini(i, PLAYER_START.size() - 1)]
	if camera != null:
		camera.make_current()
	_build_audio()
	_build_hud()
	_update_camera()
	_refresh_hud()
	has_run = true
	_apply_shared_state()
	queue_redraw()

func _enter_tree() -> void:
	if has_run:
		_apply_shared_state.call_deferred()

func _apply_shared_state() -> void:
	leaving = false
	if FarmState.touched:
		coins = FarmState.money
		day = FarmState.season_index * SEASON_DAYS + clampi(FarmState.day, 1, SEASON_DAYS)
	for i in range(players.size()):
		var p: Vector2 = players[i]["pos"]
		if EXIT_GATE.has_point(p):
			players[i]["pos"] = PLAYER_START[mini(i, PLAYER_START.size() - 1)]
	if camera != null:
		camera.make_current()
	if music_player != null and music_enabled and not music_player.playing:
		music_player.play()
	_refresh_hud()
	queue_redraw()

func _check_farm_exit() -> bool:
	if leaving or players.is_empty():
		return false
	var pos: Vector2 = players[0]["pos"]
	if not EXIT_GATE.has_point(pos):
		return false
	leaving = true
	FarmState.save_from_meadow(coins, _season_index(), _season_day())
	_save_game()
	if music_player != null:
		music_player.stop()
	level_changed.emit(load(FARM_SCENE_PATH))
	return true

func _process(delta: float) -> void:
	if modal_open:
		if Input.is_action_just_pressed("ui_cancel"):
			_close_shop()
		if _action_pressed(shop_player, "seed"):
			_cycle_seed(shop_player)
		if Input.is_action_just_pressed("toggle_music"):
			_toggle_music()
		if Input.is_action_just_pressed("toggle_sound"):
			_toggle_sound()
		return
	for i in range(_active_count()):
		_update_player(i, delta)
	if _check_farm_exit():
		return
	_update_camera()
	_update_animals(delta)
	clock_accumulator += delta
	if clock_accumulator >= 18.0:
		clock_accumulator -= 18.0
		_advance_hour()
	if weather == "Mưa" or weather == "Tuyết" or _season_index() == 2:
		rain_phase += delta * 110.0
	for i in range(_active_count()):
		if modal_open:
			break
		_handle_player_keys(i)
	if Input.is_action_just_pressed("toggle_coop"):
		_toggle_coop()
	if Input.is_action_just_pressed("toggle_sound"):
		_toggle_sound()
	if Input.is_action_just_pressed("toggle_music"):
		_toggle_music()
	_refresh_hud()
	queue_redraw()

func _bind_controls() -> void:
	_add_action("move_left", [KEY_A])
	_add_action("move_right", [KEY_D])
	_add_action("move_up", [KEY_W])
	_add_action("move_down", [KEY_S])
	_add_action("interact", [KEY_E])
	_add_action("use_tool", [KEY_SPACE])
	_add_action("tool_1", [KEY_1])
	_add_action("tool_2", [KEY_2])
	_add_action("tool_3", [KEY_3])
	_add_action("tool_4", [KEY_4])
	_add_action("cycle_seed", [KEY_Q])
	_add_action("p2_move_left", [KEY_LEFT])
	_add_action("p2_move_right", [KEY_RIGHT])
	_add_action("p2_move_up", [KEY_UP])
	_add_action("p2_move_down", [KEY_DOWN])
	_add_action("p2_interact", [KEY_KP_0])
	_add_action("p2_use_tool", [KEY_ENTER, KEY_KP_ENTER])
	_add_action("p2_tool_1", [KEY_KP_1])
	_add_action("p2_tool_2", [KEY_KP_2])
	_add_action("p2_tool_3", [KEY_KP_3])
	_add_action("p2_tool_4", [KEY_KP_4])
	_add_action("p2_cycle_seed", [KEY_KP_ADD])
	_add_action("toggle_sound", [KEY_M])
	_add_action("toggle_music", [KEY_B])
	_add_action("toggle_coop", [KEY_F2])

func _add_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for key_code in keys:
		var event := InputEventKey.new()
		event.keycode = key_code
		event.physical_keycode = key_code
		if not InputMap.action_has_event(action_name, event):
			InputMap.action_add_event(action_name, event)

func _load_assets() -> void:
	plant_sheet = load("res://chill_chill/assets/Plants.png") as Texture2D
	var animal_files := {
		"bò": ["Calf.png", 64, 6],
		"cừu": ["Sheep.png", 32, 6],
		"lợn": ["Piglet.png", 32, 6],
		"gà con": ["Chick.png", 32, 3],
		"gà tây": ["Turkey.png", 32, 6],
		"gà trống": ["Rooster.png", 32, 6],
		"cừu non": ["Lamb.png", 32, 6],
		"bò mộng": ["Bull.png", 64, 6]
	}
	for animal_name in animal_files:
		var data: Array = animal_files[animal_name]
		var texture: Texture2D = load("res://chill_chill/assets/" + str(data[0])) as Texture2D
		var frame_size: int = int(data[1])
		var frame_columns := int(data[2])
		var frame_rows := 4
		if texture != null:
			frame_columns = maxi(1, mini(frame_columns, texture.get_width() / frame_size))
			frame_rows = maxi(1, texture.get_height() / frame_size)
		animal_textures[animal_name] = {
			"texture": texture,
			"frame_size": frame_size,
			"frames": frame_columns,
			"rows": frame_rows
		}

func _make_plots() -> void:
	plots.clear()
	for _i in range(FIELD_COLS * FIELD_ROWS):
		plots.append({"tilled": false, "crop": "", "growth": 0, "watered": false, "winter_ticks": 0})

func _make_animals() -> void:
	animals.clear()
	var starts := [
		["bò", Vector2(302, 676)], ["cừu", Vector2(458, 726)],
		["lợn", Vector2(520, 654)], ["gà con", Vector2(370, 790)],
		["gà tây", Vector2(284, 794)], ["gà trống", Vector2(495, 802)],
		["cừu non", Vector2(420, 640)], ["bò mộng", Vector2(555, 730)]
	]
	for item in starts:
		animals.append({
			"name": item[0], "pos": item[1], "target": item[1],
			"direction": Vector2.DOWN, "timer": rng.randf_range(0.2, 2.0),
			"frame": rng.randf_range(0.0, 1.0), "moving": false,
			"friendship": 0, "last_product_day": 0, "heart_timer": 0.0,
			"voice_timer": rng.randf_range(5.0, 14.0)
		})

func _update_animals(delta: float) -> void:
	for i in range(animals.size()):
		var animal: Dictionary = animals[i]
		animal["heart_timer"] = maxf(0.0, float(animal.get("heart_timer", 0.0)) - delta)
		animal["voice_timer"] = float(animal.get("voice_timer", 8.0)) - delta
		var pos: Vector2 = animal["pos"]
		var target: Vector2 = animal["target"]
		animal["timer"] = float(animal["timer"]) - delta
		var difference := target - pos
		if difference.length() < 5.0 or float(animal["timer"]) <= 0.0:
			if difference.length() >= 5.0 and float(animal["timer"]) > -0.25:
				animal["timer"] = 0.6
			else:
				animal["target"] = Vector2(rng.randf_range(235.0, 585.0), rng.randf_range(620.0, 838.0))
				animal["timer"] = rng.randf_range(1.2, 3.0)
				animal["moving"] = true
				target = animal["target"]
				difference = target - pos
		if difference.length() > 5.0:
			var velocity := difference.normalized()
			pos += velocity * 24.0 * delta
			animal["direction"] = _dominant_direction(velocity)
			animal["moving"] = true
		else:
			animal["moving"] = false
		animal["pos"] = pos
		var metadata: Dictionary = animal_textures[animal["name"]]
		var safe_frame_count: int = maxi(1, mini(2, int(metadata["frames"])))
		animal["frame"] = fposmod(float(animal["frame"]) + delta * (4.0 if animal["moving"] else 1.35), float(safe_frame_count))
		if float(animal["voice_timer"]) <= 0.0:
			_play_animal_voice(_animal_voice(str(animal["name"])))
			animal["voice_timer"] = rng.randf_range(10.0, 22.0)
		animals[i] = animal

func _is_blocked_at(position: Vector2) -> bool:
	var body := Rect2(position.x - 8, position.y - 8, 16, 16)
	return body.intersects(Rect2(226, 204, 276, 188)) or body.intersects(Rect2(1004, 164, 278, 184)) or body.intersects(Rect2(1147, 377, 120, 139))

func _dominant_direction(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if direction.y >= 0.0 else Vector2.UP

func _season_index() -> int:
	return posmod(int(floor(float(day - 1) / float(SEASON_DAYS))), 4)

func _season_day() -> int:
	return posmod(day - 1, SEASON_DAYS) + 1

func _year_number() -> int:
	return int(floor(float(day - 1) / float(SEASON_DAYS * 4))) + 1

func _roll_weather() -> String:
	var roll := rng.randf()
	match _season_index():
		0:
			if roll < 0.28:
				return "Mưa"
			return "Âm u" if roll < 0.43 else "Nắng"
		1:
			if roll < 0.12:
				return "Mưa"
			return "Âm u" if roll < 0.30 else "Nắng"
		2:
			if roll < 0.25:
				return "Mưa"
			return "Âm u" if roll < 0.52 else "Nắng"
		_:
			if roll < 0.48:
				return "Tuyết"
			return "Âm u" if roll < 0.88 else "Nắng"

func _crop_grows_in_season(kind: String, season: int) -> bool:
	return CROP_SEASONS.has(kind) and CROP_SEASONS[kind].has(season)

func _crop_season_text(kind: String) -> String:
	var names: Array[String] = []
	for season in CROP_SEASONS.get(kind, []):
		names.append(str(SEASON_NAMES[season]))
	return "/".join(PackedStringArray(names))

func _draw() -> void:
	_draw_ground()
	_draw_paths()
	_draw_pond()
	_draw_trees()
	_draw_house()
	_draw_animal_pen()
	_draw_crop_field()
	_draw_market_stall()
	_draw_world_decor()
	_draw_actors()
	if weather in ["Mưa", "Tuyết"] or (_season_index() == 2 and hour < 18):
		_draw_weather_particles()
	_draw_action_effects()

func _draw_ground() -> void:
	var season := _season_index()
	var base_colors := [Color("#70a96a"), Color("#6fa65a"), Color("#a69a5c"), Color("#dce7e6")]
	var alternate_colors := [Color("#79b26d"), Color("#78ae60"), Color("#b3a365"), Color("#e9f0ed")]
	var detail_colors := [Color("#a9d076"), Color("#c1c45d"), Color("#d1854f"), Color("#ffffff")]
	for y in range(0, int(WORLD_SIZE.y), 32):
		for x in range(0, int(WORLD_SIZE.x), 32):
			var selector := posmod((x / 32) * 13 + (y / 32) * 7, 7)
			var color: Color = base_colors[season]
			if selector == 0 or selector == 5:
				color = alternate_colors[season]
			draw_rect(Rect2(x, y, 32, 32), color)
			if season == 3 and posmod(x * 3 + y * 5, 13) == 0:
				draw_rect(Rect2(x + 3, y + 5, 19, 13), Color(1, 1, 1, 0.68))
			elif posmod(x + y * 3, 11) == 0:
				draw_rect(Rect2(x + 7, y + 19, 3, 3), detail_colors[season])
			if season == 0 and posmod(x * 7 + y, 17) == 0:
				draw_rect(Rect2(x + 19, y + 9, 4, 3), Color("#f1b1c6"))
			elif season == 1 and posmod(x * 5 + y * 3, 23) == 0:
				draw_rect(Rect2(x + 24, y + 14, 3, 3), Color("#f5d45d"))
			elif season == 2 and posmod(x + y * 5, 19) == 0:
				draw_rect(Rect2(x + 22, y + 6, 5, 3), detail_colors[season])
	# Small deterministic tufts, stones and seasonal flowers make the meadow feel denser.
	for i in range(108):
		var tuft_x := 28 + posmod(i * 137, 1502)
		var tuft_y := 44 + posmod(i * 89, 936)
		if season == 3:
			draw_rect(Rect2(tuft_x, tuft_y, 4, 2), Color("#ffffff"))
			draw_rect(Rect2(tuft_x + 5, tuft_y + 2, 3, 2), Color("#c5d9d8"))
		else:
			draw_rect(Rect2(tuft_x, tuft_y + 4, 3, 5), Color("#4c8247"))
			draw_rect(Rect2(tuft_x + 3, tuft_y + 2, 3, 7), Color("#5d924d"))
			draw_rect(Rect2(tuft_x + 6, tuft_y + 5, 3, 4), Color("#3d7441"))
			if season == 0 and i % 5 == 0:
				draw_rect(Rect2(tuft_x + 2, tuft_y, 3, 3), Color("#f4b8ce"))
			elif season == 1 and i % 7 == 0:
				draw_rect(Rect2(tuft_x + 2, tuft_y, 3, 3), Color("#f6d965"))
			elif season == 2 and i % 4 == 0:
				draw_rect(Rect2(tuft_x + 2, tuft_y + 1, 4, 3), Color("#d8754d"))
	draw_rect(Rect2(0, 0, WORLD_SIZE.x, 18), Color("#456e4a") if season != 3 else Color("#90a9aa"))
	draw_rect(Rect2(0, WORLD_SIZE.y - 18, WORLD_SIZE.x, 18), Color("#456e4a") if season != 3 else Color("#90a9aa"))
	draw_rect(Rect2(0, 0, 18, WORLD_SIZE.y), Color("#456e4a") if season != 3 else Color("#90a9aa"))
	draw_rect(Rect2(WORLD_SIZE.x - 18, 0, 18, WORLD_SIZE.y), Color("#456e4a") if season != 3 else Color("#90a9aa"))
func _draw_paths() -> void:
	var season := _season_index()
	var path_color := Color("#c7a477") if season != 3 else Color("#cbd9d4")
	draw_rect(Rect2(0, 454, WORLD_SIZE.x, 54), Color("#a98155") if season != 3 else Color("#94a8a7"))
	draw_rect(Rect2(0, 458, WORLD_SIZE.x, 46), path_color)
	for x in range(8, int(WORLD_SIZE.x), 38):
		var offset := posmod(x * 7, 9)
		draw_rect(Rect2(x, 462 + offset, 26, 13), Color("#d5b58a") if season != 3 else Color("#e7efec"))
		draw_rect(Rect2(x + 27, 480 - offset, 22, 12), Color("#b99368") if season != 3 else Color("#c0d1cd"))
		if season == 2 and x % 3 == 0:
			draw_rect(Rect2(x + 15, 468 + offset, 5, 3), Color("#d27645"))
		elif season == 0 and x % 4 == 0:
			draw_rect(Rect2(x + 18, 477 - offset, 3, 3), Color("#f1bac8"))
	draw_rect(Rect2(672, 500, 48, 284), Color("#a98155"))
	draw_rect(Rect2(677, 504, 38, 276), path_color)
	for y in range(506, 780, 34):
		draw_rect(Rect2(685, y, 22, 12), Color("#d5b58a") if season != 3 else Color("#e7efec"))
	draw_rect(Rect2(1090, 504, 42, 120), Color("#a98155") if season != 3 else Color("#94a8a7"))
	draw_rect(Rect2(1094, 508, 34, 112), path_color)
func _draw_pond() -> void:
	var season := _season_index()
	var bank := Color("#7eaa63") if season != 3 else Color("#b9d0cd")
	draw_rect(Rect2(1004, 172, 278, 176), Color("#3d7650"))
	draw_rect(Rect2(1014, 164, 258, 172), bank)
	if season == 3:
		draw_rect(Rect2(1023, 173, 239, 150), Color("#9bd2df"))
		draw_rect(Rect2(1032, 179, 221, 136), Color("#b8e5e9"))
		draw_rect(Rect2(1060, 205, 104, 5), Color("#efffff"))
		draw_rect(Rect2(1087, 223, 5, 37), Color("#83b9c7"))
		draw_rect(Rect2(1088, 240, 36, 4), Color("#83b9c7"))
	else:
		var water := Color("#3e9baf") if season == 1 else Color("#478fa2")
		draw_rect(Rect2(1023, 173, 239, 150), water)
		draw_rect(Rect2(1032, 179, 221, 136), Color("#58b5c2") if season != 2 else Color("#69aab0"))
		draw_rect(Rect2(1062, 193, 82, 8), Color("#b8e2d7"))
		draw_rect(Rect2(1161, 224, 60, 6), Color("#c2e5d7"))
		draw_rect(Rect2(1050, 272, 44, 8), Color("#357e91"))
		draw_rect(Rect2(1190, 283, 41, 7), Color("#357e91"))	
	draw_rect(Rect2(1042, 193, 12, 24), Color("#78a956") if season != 2 else Color("#ad7650"))
	draw_rect(Rect2(1232, 278, 16, 28), Color("#78a956") if season != 2 else Color("#ad7650"))
	if season == 3:
		draw_rect(Rect2(1038, 170, 30, 7), Color("#f6ffff"))
		draw_rect(Rect2(1210, 170, 34, 7), Color("#f6ffff"))
func _draw_trees() -> void:
	var spots := [
		[78, 120, 0], [170, 104, 1], [565, 130, 2], [700, 92, 0],
		[877, 110, 1], [1370, 110, 2], [1484, 188, 0], [65, 352, 2],
		[576, 348, 1], [1403, 364, 0], [78, 766, 1], [100, 904, 2],
		[765, 897, 0], [925, 846, 2], [1315, 886, 1], [1502, 793, 0],
		[1347, 632, 2], [878, 626, 1]
	]
	for item in spots:
		_draw_tree(Vector2(item[0], item[1]), int(item[2]))

func _draw_tree(position: Vector2, variant: int) -> void:
	var x := position.x
	var y := position.y
	var season := _season_index()
	var leaf_a: Color = [Color("#4c8951"), Color("#397c49"), Color("#ad6542"), Color("#80979a")][season]
	var leaf_b: Color = [Color("#75ad61"), Color("#5a9c51"), Color("#d18b4b"), Color("#a5b9b7")][season]
	var leaf_c: Color = [Color("#8fc36b"), Color("#7fb758"), Color("#dfad55"), Color("#cbd9d6")][season]
	if variant == 1 and season < 3:
		leaf_a = leaf_a.lightened(0.08)
		draw_rect(Rect2(x + 21, y + 50, 22, 39), Color("#795238"))
		draw_rect(Rect2(x + 24, y + 56, 5, 28), Color("#9b6a42"))
		draw_rect(Rect2(x + 11, y + 37, 21, 5), Color("#795238"))
		draw_rect(Rect2(x + 33, y + 31, 20, 5), Color("#795238"))
	else:
		draw_rect(Rect2(x + 22, y + 47, 22, 43), Color("#795238"))
		draw_rect(Rect2(x + 27, y + 54, 5, 32), Color("#a06a40"))
	# Layered canopy gives the trees a chunky, hand-built pixel silhouette.
	draw_rect(Rect2(x + 6, y + 22, 54, 43), leaf_a)
	draw_rect(Rect2(x + 14, y + 9, 39, 48), leaf_b)
	draw_rect(Rect2(x - 1, y + 32, 31, 25), leaf_a)
	draw_rect(Rect2(x + 35, y + 29, 32, 27), leaf_b)
	draw_rect(Rect2(x + 16, y + 17, 12, 9), leaf_c)
	draw_rect(Rect2(x + 41, y + 23, 10, 8), leaf_c)
	draw_rect(Rect2(x + 27, y + 39, 11, 7), leaf_c)
	if season == 0:
		for p in [Vector2(12, 31), Vector2(42, 15), Vector2(52, 43), Vector2(27, 53)]:
			draw_rect(Rect2(x + p.x, y + p.y, 5, 4), Color("#f1b1c6"))
	elif season == 1 and variant == 2:
		draw_rect(Rect2(x + 15, y + 54, 6, 7), Color("#e8bf52"))
		draw_rect(Rect2(x + 48, y + 45, 6, 7), Color("#e8bf52"))
	elif season == 2:
		for p in [Vector2(8, 42), Vector2(37, 13), Vector2(54, 50)]:
			draw_rect(Rect2(x + p.x, y + p.y, 7, 4), Color("#d65f42"))
	elif season == 3:
		draw_rect(Rect2(x + 7, y + 25, 26, 5), Color("#f2fbf7"))
		draw_rect(Rect2(x + 37, y + 37, 24, 5), Color("#f2fbf7"))
		draw_rect(Rect2(x + 19, y + 10, 25, 4), Color("#f2fbf7"))
	if plant_sheet != null and season in [0, 1]:
		draw_texture_rect_region(plant_sheet, Rect2(x + 49, y + 57, 26, 26), Rect2(0, 288, 48, 48), Color(1, 1, 1, 0.88))
func _draw_house() -> void:
	var season := _season_index()
	draw_rect(Rect2(226, 227, 276, 200), Color("#3d6e42"))
	draw_rect(Rect2(242, 230, 242, 162), Color("#e8d2a2"))
	draw_rect(Rect2(242, 318, 242, 74), Color("#d5b37e"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(226, 232), Vector2(366, 160), Vector2(510, 232),
		Vector2(492, 252), Vector2(366, 190), Vector2(244, 252)
	]), Color("#ae5844"))
	for x in range(248, 486, 32):
		draw_rect(Rect2(x, 255, 4, 136), Color("#b68a59"))
	draw_rect(Rect2(347, 310, 42, 82), Color("#754a35"))
	draw_rect(Rect2(353, 316, 30, 76), Color("#a96b45"))
	draw_rect(Rect2(374, 349, 5, 5), GOLD)
	draw_rect(Rect2(269, 269, 47, 40), Color("#6c9b9e"))
	draw_rect(Rect2(274, 274, 37, 30), Color("#a9d8c7"))
	draw_rect(Rect2(434, 269, 37, 40), Color("#6c9b9e"))
	draw_rect(Rect2(439, 274, 27, 30), Color("#a9d8c7"))
	draw_rect(Rect2(286, 274, 5, 30), Color("#fff0ce"))
	draw_rect(Rect2(449, 274, 5, 30), Color("#fff0ce"))
	draw_rect(Rect2(326, 391, 88, 17), Color("#bd925f"))
	draw_rect(Rect2(339, 408, 7, 14), Color("#865536"))
	draw_rect(Rect2(394, 408, 7, 14), Color("#865536"))
	draw_rect(Rect2(329, 428, 82, 6), Color("#a37c52"))
	draw_rect(Rect2(428, 180, 22, 42), Color("#935248"))
	draw_rect(Rect2(425, 176, 28, 8), Color("#733f37"))
	draw_rect(Rect2(438, 163, 10, 8), Color("#d8d7b2"))
	draw_rect(Rect2(450, 151, 10, 8), Color("#d8d7b2"))
	draw_rect(Rect2(250, 221, 28, 17), Color("#d87b56"))
	draw_rect(Rect2(300, 201, 30, 16), Color("#d87b56"))
	draw_rect(Rect2(386, 201, 30, 16), Color("#d87b56"))
	draw_rect(Rect2(455, 221, 27, 17), Color("#d87b56"))
	if season == 0:
		for x in [278, 300, 424, 447]:
			draw_rect(Rect2(x, 311, 5, 6), Color("#e590a4"))
			draw_rect(Rect2(x + 6, 313, 4, 4), Color("#f3cc62"))
	elif season == 1:
		draw_rect(Rect2(254, 252, 10, 36), Color("#4e8a4a"))
		draw_rect(Rect2(462, 252, 10, 36), Color("#4e8a4a"))
	elif season == 2:
		draw_rect(Rect2(314, 416, 20, 11), Color("#d5904f"))
		draw_rect(Rect2(394, 416, 18, 10), Color("#bd6644"))
	else:
		draw_rect(Rect2(235, 226, 97, 8), Color("#f5ffff"))
		draw_rect(Rect2(402, 220, 89, 8), Color("#f5ffff"))
		draw_rect(Rect2(426, 184, 24, 6), Color("#f5ffff"))
func _draw_animal_pen() -> void:
	draw_rect(Rect2(204, 590, 414, 280), Color("#57894b"))
	draw_rect(Rect2(210, 596, 400, 268), Color("#6c9c53"))
	for i in range(42):
		var grass_x := 222 + posmod(i * 43, 370)
		var grass_y := 610 + posmod(i * 61, 238)
		draw_rect(Rect2(grass_x, grass_y, 3, 7), Color("#4e8146"))
		draw_rect(Rect2(grass_x + 3, grass_y + 3, 3, 4), Color("#82ad57"))
	draw_rect(Rect2(252, 680, 88, 47), Color("#bfa45d"))
	draw_rect(Rect2(450, 790, 86, 38), Color("#c2a45b"))
	draw_rect(Rect2(309, 812, 80, 26), Color("#c9ae69"))
	draw_rect(Rect2(258, 686, 76, 35), Color("#d9be71"))
	draw_rect(Rect2(456, 796, 74, 26), Color("#d9be71"))
	for hay_x in range(266, 328, 14):
		draw_rect(Rect2(hay_x, 691, 6, 26), Color("#efdb92"))
	for hay_x in range(464, 524, 14):
		draw_rect(Rect2(hay_x, 800, 6, 18), Color("#efdb92"))
	for x in range(214, 610, 30):
		if x < 384 or x > 444:
			draw_rect(Rect2(x, 590, 7, 32), Color("#f0d39c"))
			draw_rect(Rect2(x - 2, 588, 11, 5), Color("#8c5737"))
		draw_rect(Rect2(x, 850, 7, 28), Color("#f0d39c"))
		draw_rect(Rect2(x - 2, 848, 11, 5), Color("#8c5737"))
		draw_rect(Rect2(x, 605, 7, 5), Color("#9c6943"))
		draw_rect(Rect2(x, 615, 7, 5), Color("#9c6943"))
	for y in range(620, 850, 30):
		draw_rect(Rect2(204, y, 30, 7), Color("#f0d39c"))
		draw_rect(Rect2(204, y - 2, 5, 11), Color("#8c5737"))
		draw_rect(Rect2(612, y, 25, 7), Color("#f0d39c"))
		draw_rect(Rect2(630, y - 2, 5, 11), Color("#8c5737"))
	draw_rect(Rect2(384, 590, 62, 8), Color("#9b613d"))
	draw_rect(Rect2(384, 614, 62, 8), Color("#9b613d"))
	draw_rect(Rect2(387, 590, 6, 32), Color("#e7c78d"))
	draw_rect(Rect2(437, 590, 6, 32), Color("#e7c78d"))
	draw_rect(Rect2(282, 628, 48, 28), Color("#9b693e"))
	draw_rect(Rect2(289, 621, 34, 9), Color("#d5b36b"))
	draw_rect(Rect2(293, 656, 7, 18), Color("#725039"))
	draw_rect(Rect2(313, 656, 7, 18), Color("#725039"))
	draw_rect(Rect2(480, 628, 48, 28), Color("#9b693e"))
	draw_rect(Rect2(488, 621, 32, 9), Color("#d5b36b"))
	draw_rect(Rect2(490, 656, 7, 18), Color("#725039"))
	draw_rect(Rect2(510, 656, 7, 18), Color("#725039"))
	draw_rect(Rect2(339, 604, 142, 20), Color("#79533c"))
	draw_rect(Rect2(349, 607, 122, 14), Color("#d7bd8c"))
	draw_rect(Rect2(370, 612, 78, 4), Color("#82543a"))
	draw_rect(Rect2(536, 682, 48, 20), Color("#6e513a"))
	draw_rect(Rect2(540, 686, 40, 12), Color("#4d9bb2"))
	draw_rect(Rect2(544, 688, 32, 3), Color("#b9e5df"))

func _draw_crop_field() -> void:
	draw_rect(Rect2(723, 276, 353, 263), Color("#416f45"))
	draw_rect(Rect2(729, 282, 341, 251), Color("#7e9e57"))
	for x in range(732, 1070, 34):
		draw_rect(Rect2(x, 270, 5, 20), Color("#e2c58e"))
		draw_rect(Rect2(x - 2, 269, 9, 4), Color("#8e5d3a"))
		draw_rect(Rect2(x, 286, 5, 5), Color("#9e7048"))
	for y in range(292, 538, 34):
		draw_rect(Rect2(1066, y, 8, 5), Color("#e2c58e"))
		draw_rect(Rect2(1064, y - 2, 12, 9), Color("#8e5d3a"))
	for row in range(FIELD_ROWS):
		for col in range(FIELD_COLS):
			var index := row * FIELD_COLS + col
			var plot: Dictionary = plots[index]
			var pos := FIELD_ORIGIN + Vector2(col * FIELD_STEP, row * FIELD_STEP)
			var rect := Rect2(pos, PLOT_SIZE)
			draw_rect(rect, Color("#6e8a50"))
			if bool(plot["tilled"]):
				draw_rect(Rect2(pos + Vector2(2, 2), PLOT_SIZE - Vector2(4, 4)), Color("#7a4b35"))
				draw_rect(Rect2(pos + Vector2(4, 6), Vector2(34, 3)), Color("#996448"))
				draw_rect(Rect2(pos + Vector2(4, 18), Vector2(34, 3)), Color("#996448"))
				draw_rect(Rect2(pos + Vector2(4, 30), Vector2(34, 3)), Color("#996448"))
				if bool(plot["watered"]):
					draw_rect(Rect2(pos + Vector2(3, 3), Vector2(36, 36)), Color(0.22, 0.64, 0.79, 0.21))
				if str(plot["crop"]) != "":
					_draw_crop(pos + Vector2(21, 22), str(plot["crop"]), int(plot["growth"]))
			else:
				draw_rect(Rect2(pos + Vector2(8, 8), Vector2(5, 4)), Color("#a9a56d"))
				draw_rect(Rect2(pos + Vector2(29, 28), Vector2(4, 5)), Color("#a9a56d"))

func _draw_crop(center: Vector2, kind: String, growth: int) -> void:
	var stage := clampi(growth, 0, 3)
	var season := _season_index()
	var dormant := not _crop_grows_in_season(kind, season)
	var leaf_dark: Color = [Color("#5d9a4b"), Color("#548a45"), Color("#788044"), Color("#607f7a")][season]
	var leaf_light: Color = [Color("#7ebd55"), Color("#72ae4b"), Color("#9ba04c"), Color("#8ba9a6")][season]
	if dormant:
		leaf_dark = leaf_dark.darkened(0.42)
		leaf_light = leaf_light.darkened(0.34)
	draw_rect(Rect2(center.x - 2, center.y - 2, 4, 12), Color("#52703b"))
	if stage == 0:
		draw_rect(Rect2(center.x - 5, center.y - 4, 5, 3), leaf_light)
		draw_rect(Rect2(center.x + 1, center.y - 6, 5, 3), leaf_dark)
		return
	var leaf_size := 5 + stage * 2
	draw_rect(Rect2(center.x - leaf_size - 2, center.y - 2, leaf_size, 4), leaf_dark)
	draw_rect(Rect2(center.x + 2, center.y - 5, leaf_size, 4), leaf_light)
	draw_rect(Rect2(center.x - 2, center.y - 8, 4, 7), leaf_dark)
	if stage >= 2:
		draw_rect(Rect2(center.x - 9, center.y - 8, 6, 4), leaf_light)
		draw_rect(Rect2(center.x + 3, center.y - 11, 7, 4), leaf_dark)
	if stage >= 3:
		if kind == "carrot":
			draw_rect(Rect2(center.x - 3, center.y + 2, 7, 11), Color("#ef923e"))
			draw_rect(Rect2(center.x - 3, center.y + 10, 7, 3), Color("#d87335"))
			draw_rect(Rect2(center.x - 4, center.y, 4, 5), leaf_dark)
		elif kind == "turnip":
			draw_rect(Rect2(center.x - 5, center.y + 2, 11, 9), Color("#e9e0c6"))
			draw_rect(Rect2(center.x - 3, center.y + 9, 5, 4), Color("#b69770"))
		else:
			draw_rect(Rect2(center.x - 5, center.y + 2, 5, 5), Color("#d84f63"))
			draw_rect(Rect2(center.x + 1, center.y + 1, 5, 6), Color("#e76673"))
			draw_rect(Rect2(center.x - 2, center.y + 6, 5, 5), Color("#c53e59"))
			draw_rect(Rect2(center.x - 3, center.y, 3, 3), leaf_dark)
			draw_rect(Rect2(center.x + 2, center.y - 1, 3, 3), leaf_dark)
	if dormant:
		draw_rect(Rect2(center.x - 7, center.y - 12, 14, 3), Color(0.82, 0.94, 0.94, 0.65))
func _draw_market_stall() -> void:
	var season := _season_index()
	var awning_colors := [Color("#bd5546"), Color("#cf7650"), Color("#af6544"), Color("#7893a0")]
	draw_rect(Rect2(1151, 423, 114, 89), Color("#477344"))
	draw_rect(Rect2(1160, 432, 96, 65), Color("#d6b681"))
	draw_rect(Rect2(1153, 409, 108, 22), Color("#6a994e"))
	draw_rect(Rect2(1147, 391, 120, 28), awning_colors[season])
	for x in range(1151, 1263, 24):
		draw_rect(Rect2(x, 393, 12, 24), Color("#f1dfa6"))
	draw_rect(Rect2(1162, 453, 93, 8), Color("#855435"))
	draw_rect(Rect2(1170, 461, 76, 30), Color("#b17440"))
	draw_rect(Rect2(1177, 467, 14, 18), Color("#ef9850"))
	draw_rect(Rect2(1198, 466, 14, 18), Color("#a5bd58"))
	draw_rect(Rect2(1219, 465, 14, 18), Color("#d84f63"))
	draw_rect(Rect2(1240, 466, 9, 18), Color("#e8d9bb"))
	draw_rect(Rect2(1160, 496, 9, 20), Color("#7e5438"))
	draw_rect(Rect2(1246, 496, 9, 20), Color("#7e5438"))
	draw_rect(Rect2(1178, 377, 58, 14), Color("#7d5134"))
	draw_rect(Rect2(1183, 380, 48, 8), Color("#f1dfa6"))
	draw_rect(Rect2(1190, 381, 34, 5), Color("#749c55"))
	if season == 0:
		draw_rect(Rect2(1156, 430, 4, 4), Color("#f2b1c3"))
		draw_rect(Rect2(1252, 430, 4, 4), Color("#f2b1c3"))
	elif season == 3:
		draw_rect(Rect2(1150, 389, 50, 5), Color("#f4ffff"))
		draw_rect(Rect2(1211, 389, 49, 5), Color("#f4ffff"))
func _draw_world_decor() -> void:
	for i in range(18):
		var x := 70 + i * 79
		var y := 966 - posmod(i * 31, 62)
		if plant_sheet != null:
			var source := Rect2(0, 288, 48, 48) if i % 2 == 0 else Rect2(96, 336, 48, 48)
			draw_texture_rect_region(plant_sheet, Rect2(x, y, 32, 32), source)
		else:
			draw_rect(Rect2(x + 6, y + 13, 12, 10), Color("#8fc45f"))
	draw_rect(Rect2(522, 414, 16, 19), Color("#79513a"))
	draw_rect(Rect2(517, 410, 26, 8), Color("#d6c18f"))
	draw_rect(Rect2(511, 407, 38, 7), Color("#8d6040"))
	draw_rect(Rect2(524, 432, 4, 17), Color("#65513b"))
	draw_rect(Rect2(534, 432, 4, 17), Color("#65513b"))
	for i in range(8):
		var x := 84 + i * 42
		draw_rect(Rect2(x, 447, 28, 7), Color("#dcc49a"))
		draw_rect(Rect2(x + 4, 454, 4, 3), Color("#a58a62"))
	draw_rect(Rect2(30, 470, 10, 54), Color("#7a5236"))
	draw_rect(Rect2(4, 438, 80, 34), Color("#8d6040"))
	draw_rect(Rect2(9, 443, 70, 24), Color("#e2c98d"))
	draw_string(ThemeDB.fallback_font, Vector2(14, 460), "← NÔNG TRẠI", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#4a2f18"))

func _draw_actors() -> void:
	var order: Array[Dictionary] = []
	for i in range(animals.size()):
		var animal_pos: Vector2 = animals[i]["pos"]
		order.append({"player": false, "index": i, "depth": animal_pos.y})
	for i in range(_active_count()):
		var player_pos: Vector2 = players[i]["pos"]
		order.append({"player": true, "index": i, "depth": player_pos.y})
	order.sort_custom(func(a, b): return float(a["depth"]) < float(b["depth"]))
	for item in order:
		if bool(item["player"]):
			_draw_player(int(item["index"]))
		else:
			_draw_animal(animals[int(item["index"])])

func _draw_animal(animal: Dictionary) -> void:
	var metadata: Dictionary = animal_textures[animal["name"]]
	var texture: Texture2D = metadata["texture"]
	var frame_size: int = metadata["frame_size"]
	var frame_count: int = maxi(1, mini(2, int(metadata["frames"])))
	var row_count: int = maxi(1, int(metadata.get("rows", 4)))
	var direction: Vector2 = animal["direction"]
	var row := 0
	if direction == Vector2.LEFT:
		row = 1
	elif direction == Vector2.RIGHT:
		row = 2
	elif direction == Vector2.UP:
		row = 3
	# Every source sheet has its guaranteed idle directions in the first four rows.
	# Keeping motion in those rows avoids sampling the optional lower animation rows,
	# which caused several animals to flash transparent while wandering.
	row = clampi(row, 0, mini(3, row_count - 1))
	var frame: int = posmod(int(floor(float(animal["frame"]))), frame_count)
	var pos: Vector2 = animal["pos"]
	var draw_size := float(frame_size) * 1.42
	var rect := Rect2(pos.x - draw_size * 0.5, pos.y - draw_size * 0.78, draw_size, draw_size)
	var region := Rect2(frame * frame_size, row * frame_size, frame_size, frame_size)
	draw_rect(Rect2(pos.x - draw_size * 0.36, pos.y + 2, draw_size * 0.72, 7), Color(0.12, 0.20, 0.13, 0.28))
	if texture != null:
		draw_texture_rect_region(texture, rect, region, Color.WHITE, false)
	else:
		_draw_animal_fallback(pos, str(animal["name"]), draw_size)
	if int(animal.get("heart_timer", 0.0) * 10.0) > 0:
		var heart_y := pos.y - draw_size * 0.85 - fposmod(float(animal["heart_timer"]) * 18.0, 5.0)
		draw_rect(Rect2(pos.x - 5, heart_y, 4, 4), Color("#f28ba0"))
		draw_rect(Rect2(pos.x + 1, heart_y, 4, 4), Color("#f28ba0"))
		draw_rect(Rect2(pos.x - 3, heart_y + 3, 6, 4), Color("#f28ba0"))

func _draw_animal_fallback(pos: Vector2, animal_name: String, draw_size: float) -> void:
	var body_color := Color("#e6d6b6")
	var accent_color := Color("#8a6042")
	if animal_name == "lợn":
		body_color = Color("#e7a3a6")
		accent_color = Color("#c5757e")
	elif animal_name == "bò" or animal_name == "bò mộng":
		body_color = Color("#eee7d5")
		accent_color = Color("#8d633f")
	elif animal_name.contains("gà"):
		body_color = Color("#f6d66f")
		accent_color = Color("#d55345")
	var width := draw_size * 0.56
	draw_rect(Rect2(pos.x - width * 0.5, pos.y - draw_size * 0.58, width, draw_size * 0.37), body_color)
	draw_rect(Rect2(pos.x + width * 0.26, pos.y - draw_size * 0.52, width * 0.28, draw_size * 0.23), accent_color)
	draw_rect(Rect2(pos.x - width * 0.30, pos.y - draw_size * 0.25, width * 0.10, draw_size * 0.16), accent_color)
	draw_rect(Rect2(pos.x + width * 0.20, pos.y - draw_size * 0.25, width * 0.10, draw_size * 0.16), accent_color)
func _draw_player(i: int) -> void:
	var pl: Dictionary = players[i]
	var player_pos: Vector2 = pl["pos"]
	var facing: Vector2 = pl["facing"]
	var moving: bool = pl["moving"]
	var step_clock: float = pl["step_clock"]
	var action_timer: float = pl["action_timer"]
	var action_duration: float = pl["action_duration"]
	var selected_tool: int = pl["tool"]
	var skirt := Color("#8a5e3c") if i == 0 else Color("#2d7480")
	var dress := Color("#4f7fb8") if i == 0 else Color("#c96578")
	var male := i == 0
	if coop_enabled:
		var mark_x := roundf(player_pos.x)
		var mark_y := roundf(player_pos.y) - 56.0
		draw_colored_polygon(PackedVector2Array([Vector2(mark_x - 5.0, mark_y - 5.0), Vector2(mark_x + 5.0, mark_y - 5.0), Vector2(mark_x, mark_y + 2.0)]), PLAYER_MARK_COLORS[i])
	var bob := 0
	if moving and int(step_clock) % 2 == 0:
		bob = -2
	var x := roundf(player_pos.x)
	var y := roundf(player_pos.y)
	var hair := Color("#633b32")
	var hair_light := Color("#a96345")
	var blouse := Color("#f4dfc2")
	draw_rect(Rect2(x - 15, y - 2, 30, 7), Color(0.12, 0.20, 0.14, 0.28))
	if male:
		# Nam: tóc nâu sẫm cắt ngắn, không bím tóc hay hoa.
		draw_rect(Rect2(x - 10, y - 43 + bob, 20, 22), hair)
		draw_rect(Rect2(x - 9, y - 44 + bob, 18, 5), hair)
		draw_rect(Rect2(x - 7, y - 46 + bob, 14, 3), hair_light)
	else:
		# Nữ: tóc dài màu hạt dẻ, bím tóc và kẹp hoa.
		draw_rect(Rect2(x - 10, y - 43 + bob, 20, 24), hair)
		draw_rect(Rect2(x - 13, y - 36 + bob, 5, 19), hair)
		draw_rect(Rect2(x + 8, y - 36 + bob, 5, 20), hair)
		draw_rect(Rect2(x + 10, y - 26 + bob, 5, 9), hair_light)
		draw_rect(Rect2(x + 11, y - 20 + bob, 4, 4), Color("#f2c35d"))
	# Boots, socks and skirt move in alternating steps.
	draw_rect(Rect2(x - 8, y - 12 + bob, 6, 9), Color("#f1d8bb"))
	draw_rect(Rect2(x + 2, y - 12 - bob, 6, 9), Color("#f1d8bb"))
	draw_rect(Rect2(x - 9, y - 5 + bob, 8, 5), Color("#664b3a"))
	draw_rect(Rect2(x + 1, y - 5 - bob, 8, 5), Color("#664b3a"))
	# Shirt + outfit: nam mặc áo sơ mi và quần yếm, nữ mặc váy và tạp dề.
	draw_rect(Rect2(x - 10, y - 28 + bob, 20, 13), blouse)
	draw_rect(Rect2(x - 13, y - 26 + bob, 5, 9), Color("#e9c9a9"))
	draw_rect(Rect2(x + 8, y - 26 + bob, 5, 9), Color("#e9c9a9"))
	if male:
		draw_rect(Rect2(x - 11, y - 18 + bob, 22, 11), Color("#4f7fb8"))
		draw_rect(Rect2(x - 6, y - 26 + bob, 12, 9), Color("#4f7fb8"))
		draw_rect(Rect2(x - 10, y - 18 + bob, 3, 9), Color("#3a6394"))
		draw_rect(Rect2(x + 7, y - 18 + bob, 3, 9), Color("#3a6394"))
		draw_rect(Rect2(x - 4, y - 24 + bob, 2, 2), Color("#e6b45b"))
		draw_rect(Rect2(x + 2, y - 24 + bob, 2, 2), Color("#e6b45b"))
		draw_rect(Rect2(x - 11, y - 8 + bob, 22, 3), Color("#e7c58a"))
	else:
		draw_rect(Rect2(x - 11, y - 18 + bob, 22, 11), skirt)
		draw_rect(Rect2(x - 9, y - 25 + bob, 18, 11), dress)
		draw_rect(Rect2(x - 9, y - 17 + bob, 18, 3), Color("#ab4f67"))
		draw_rect(Rect2(x - 10, y - 18 + bob, 3, 9), Color("#f3e4c5"))
		draw_rect(Rect2(x + 7, y - 18 + bob, 3, 9), Color("#f3e4c5"))
		draw_rect(Rect2(x - 6, y - 24 + bob, 12, 13), Color("#f1d7a8"))
		draw_rect(Rect2(x - 3, y - 22 + bob, 2, 2), Color("#e6b45b"))
		draw_rect(Rect2(x + 2, y - 22 + bob, 2, 2), Color("#e6b45b"))
		draw_rect(Rect2(x - 11, y - 8 + bob, 22, 3), Color("#e7c58a"))
	# Face: hai nhân vật đều đẹp, chỉ khác kiểu tóc và hoa cài.
	draw_rect(Rect2(x - 7, y - 42 + bob, 14, 15), Color("#f0c394"))
	draw_rect(Rect2(x - 9, y - 45 + bob, 18, 7), hair)
	draw_rect(Rect2(x - 7, y - 47 + bob, 14, 4), hair_light)
	if not male:
		draw_rect(Rect2(x - 7, y - 41 + bob, 4, 7), hair)
		draw_rect(Rect2(x + 4, y - 41 + bob, 4, 7), hair)
		draw_rect(Rect2(x + 6, y - 42 + bob, 4, 4), Color("#f0a9bd"))
		draw_rect(Rect2(x + 7, y - 43 + bob, 2, 6), Color("#ffe0e5"))
		draw_rect(Rect2(x - 2, y - 47 + bob, 4, 2), Color("#f7d988"))
	if facing == Vector2.DOWN:
		draw_rect(Rect2(x - 4, y - 35 + bob, 2, 3), Color("#45352e"))
		draw_rect(Rect2(x + 3, y - 35 + bob, 2, 3), Color("#45352e"))
		draw_rect(Rect2(x - 1, y - 30 + bob, 3, 2), Color("#d67d77"))
	elif facing == Vector2.LEFT:
		draw_rect(Rect2(x - 4, y - 35 + bob, 3, 3), Color("#45352e"))
	elif facing == Vector2.RIGHT:
		draw_rect(Rect2(x + 2, y - 35 + bob, 3, 3), Color("#45352e"))
	# Tools are distinct silhouettes and swing/bob while their action is playing.
	var hand_x := x + (13 if facing != Vector2.LEFT else -18)
	var hand_y := y - 24 + bob
	var swing := 0
	if action_timer > 0.0:
		swing = int(sin((action_duration - action_timer) * 24.0) * 4.0)
	if selected_tool == 0:
		draw_rect(Rect2(hand_x, hand_y + swing - 5, 4, 17), Color("#805433"))
		draw_rect(Rect2(hand_x - 4, hand_y + swing - 8, 12, 4), Color("#bac5c2"))
		draw_rect(Rect2(hand_x - 3, hand_y + swing - 10, 7, 3), Color("#dbe3da"))
	elif selected_tool == 1:
		draw_rect(Rect2(hand_x - 2, hand_y - 3, 11, 12), Color("#ba8a4d"))
		draw_rect(Rect2(hand_x, hand_y - 1, 7, 7), Color("#e8c86f"))
		draw_rect(Rect2(hand_x + 2, hand_y - 5, 4, 3), Color("#548b4e"))
	elif selected_tool == 2:
		draw_rect(Rect2(hand_x - 1, hand_y - 4 + swing, 12, 14), Color("#4f98ad"))
		draw_rect(Rect2(hand_x + 1, hand_y - 6 + swing, 8, 4), Color("#e5d5a3"))
		draw_rect(Rect2(hand_x + 7, hand_y - 2 + swing, 5, 4), Color("#327286"))
	else:
		draw_rect(Rect2(hand_x - 2, hand_y, 13, 10), Color("#a06a44"))
		draw_rect(Rect2(hand_x, hand_y + 2, 9, 6), Color("#f1d38b"))
func _draw_weather_particles() -> void:
	var player_pos := _focus_point()
	for i in range(74):
		var x := player_pos.x - 650 + posmod(i * 113 + int(rain_phase * 2.4), 1300)
		var y := player_pos.y - 365 + posmod(i * 67 + int(rain_phase), 720)
		if weather == "Mưa":
			draw_line(Vector2(x, y), Vector2(x - 5, y + 11), Color(0.66, 0.86, 0.93, 0.55), 1.3)
		elif weather == "Tuyết":
			draw_rect(Rect2(x, y, 3, 3), Color(0.97, 1.0, 1.0, 0.88))
			for k in range(3):
				var wx := x + 40 + posmod(k * 97 + int(rain_phase * 3.0), 260)
				draw_line(Vector2(wx, y + 30), Vector2(wx + 24, y + 26), Color(1, 1, 1, 0.25), 1.0)
		elif _season_index() == 2 and i % 2 == 0:
			draw_rect(Rect2(x, y, 5, 3), Color("#d87947"))
			draw_rect(Rect2(x + 4, y - 1, 2, 2), Color("#a6533f"))

func _draw_action_effects() -> void:
	for i in range(_active_count()):
		_draw_player_action(i)

func _draw_player_action(i: int) -> void:
	var pl: Dictionary = players[i]
	var action_timer: float = pl["action_timer"]
	var action_duration: float = pl["action_duration"]
	var action_kind: String = pl["action_kind"]
	var action_target: Vector2 = pl["action_target"]
	if action_timer <= 0.0 or action_duration <= 0.0:
		return
	var progress := 1.0 - action_timer / action_duration
	for k in range(9):
		var spread := float(k % 3 - 1) * (5.0 + progress * 11.0)
		var rise := float(k / 3) * 6.0 + progress * 13.0
		var pos := action_target + Vector2(spread, -rise)
		match action_kind:
			"hoe":
				draw_rect(Rect2(pos, Vector2(3, 3)), Color("#c89455") if k % 2 == 0 else Color("#e3bd77"))
			"seed":
				draw_rect(Rect2(pos, Vector2(2, 2)), Color("#fff2a0") if k % 2 == 0 else Color("#8bc65d"))
			"water":
				draw_rect(Rect2(pos + Vector2(0, progress * 8.0), Vector2(3, 5)), Color(0.47, 0.81, 0.94, 0.78))
			"harvest":
				draw_rect(Rect2(pos, Vector2(4, 4)), Color("#ffe27c") if k % 2 == 0 else Color("#fff5d0"))

func _start_action(i: int, kind: String, duration: float = 0.42) -> void:
	var pl: Dictionary = players[i]
	var pos: Vector2 = pl["pos"]
	var facing: Vector2 = pl["facing"]
	pl["action_kind"] = kind
	pl["action_duration"] = duration
	pl["action_timer"] = duration
	pl["action_target"] = pos + facing * 38.0

func _plot_index_at_target(i: int) -> int:
	var pl: Dictionary = players[i]
	var pos: Vector2 = pl["pos"]
	var facing: Vector2 = pl["facing"]
	var target := pos + facing * 44.0
	for row in range(FIELD_ROWS):
		for col in range(FIELD_COLS):
			var index := row * FIELD_COLS + col
			var rect := Rect2(FIELD_ORIGIN + Vector2(col * FIELD_STEP, row * FIELD_STEP), PLOT_SIZE)
			if rect.grow(7.0).has_point(target):
				return index
	return -1

func _use_tool(i: int) -> void:
	var pl: Dictionary = players[i]
	if int(pl["energy"]) < 2:
		_show_toast("Hết năng lượng — hãy nghỉ ở nhà.")
		_play_sfx("ui")
		return
	var index := _plot_index_at_target(i)
	if index < 0:
		_show_toast("Đứng sát một luống đất rồi dùng công cụ.")
		_play_sfx("ui")
		return
	var plot: Dictionary = plots[index]
	var selected_tool := int(pl["tool"])
	var selected_crop := str(pl["crop"])
	match selected_tool:
		0:
			if bool(plot["tilled"]):
				_show_toast("Luống này đã được xới.")
			else:
				plot["tilled"] = true
				pl["energy"] = int(pl["energy"]) - 2
				_start_action(i, "hoe", 0.48)
				_show_toast("Đất đã tơi xốp. Chọn hạt giống để gieo.")
				_play_sfx("hoe")
		1:
			if not bool(plot["tilled"]):
				_show_toast("Hãy cuốc đất trước khi gieo hạt.")
			elif str(plot["crop"]) != "":
				_show_toast("Luống này đang có cây.")
			elif not _crop_grows_in_season(selected_crop, _season_index()):
				_show_toast(str(CROP_LABELS[selected_crop]) + " hợp mùa " + _crop_season_text(selected_crop) + ".")
			elif int(seeds.get(selected_crop, 0)) <= 0:
				_show_toast("Bạn đã hết " + str(CROP_LABELS[selected_crop]) + ". Ghé quầy hạt giống nhé.")
			else:
				plot["crop"] = selected_crop
				plot["growth"] = 0
				plot["watered"] = false
				plot["winter_ticks"] = 0
				seeds[selected_crop] = int(seeds[selected_crop]) - 1
				pl["energy"] = int(pl["energy"]) - 1
				_start_action(i, "seed", 0.45)
				_show_toast("Đã gieo " + str(CROP_LABELS[selected_crop]) + ". Tưới cây mỗi ngày!")
				_play_sfx("seed")
		2:
			if str(plot["crop"]) == "":
				_show_toast("Luống này chưa có hạt giống.")
			elif not _crop_grows_in_season(str(plot["crop"]), _season_index()):
				_show_toast("Cây này đang nghỉ trái mùa. Có thể trồng lại khi mùa phù hợp trở lại.")
			elif bool(plot["watered"]):
				_show_toast("Cây đã được tưới hôm nay.")
			else:
				plot["watered"] = true
				pl["energy"] = int(pl["energy"]) - 2
				_start_action(i, "water", 0.72)
				_show_toast("Tưới nước xong. Cây sẽ lớn sau khi ngủ.")
				_play_sfx("water")
		3:
			if str(plot["crop"]) == "":
				_show_toast("Chưa có cây nào để thu hoạch.")
			elif int(plot["growth"]) < int(CROP_DAYS[str(plot["crop"])]):
				_show_toast("Cây vẫn đang lớn — hãy tưới rồi ngủ qua ngày.")
			else:
				var kind := str(plot["crop"])
				produce[kind] = int(produce[kind]) + 1
				plot["crop"] = ""
				plot["growth"] = 0
				plot["watered"] = false
				plot["winter_ticks"] = 0
				pl["energy"] = int(pl["energy"]) - 1
				_start_action(i, "harvest", 0.58)
				_show_toast("Thu hoạch " + str(CROP_LABELS[kind]) + "! Mang ra quầy để bán.")
				_play_sfx("harvest")
	plots[index] = plot
	_save_game()
	_refresh_hud()
	queue_redraw()

func _interact(i: int) -> void:
	var pos: Vector2 = players[i]["pos"]
	var nearest_index := -1
	var nearest_distance := 999999.0
	for a in range(animals.size()):
		var distance: float = pos.distance_to(animals[a]["pos"])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = a
	if nearest_index >= 0 and nearest_distance <= 58.0:
		_interact_animal(nearest_index)
		return
	if pos.distance_to(Vector2(1208, 452)) < 100.0:
		_play_sfx("ui")
		_open_shop(i)
		return
	if pos.distance_to(Vector2(368, 420)) < 88.0:
		_sleep()
		return
	if pos.distance_to(Vector2(525, 429)) < 80.0:
		_show_toast("Bảng tin: trồng đúng mùa, chăm vật nuôi và gom xu đổi hạt giống!")
		_play_sfx("ui")
		return
	_show_toast("Không có gì ở gần. Hãy đến quầy, luống cây, chuồng hoặc cửa nhà.")
	_play_sfx("ui")

func _interact_animal(index: int) -> void:
	var animal: Dictionary = animals[index]
	var animal_name := str(animal["name"])
	animal["heart_timer"] = 1.2
	if feed_bags > 0:
		feed_bags -= 1
		animal["friendship"] = int(animal["friendship"]) + 2
		_show_toast("Bạn cho " + animal_name + " ăn. Tình cảm +2 ♥")
	else:
		animal["friendship"] = int(animal["friendship"]) + 1
		_show_toast("Bạn vuốt ve " + animal_name + ". Bé vui vẻ kêu lên! ♥")
	if int(animal["last_product_day"]) < day:
		var product := ""
		if animal_name == "bò":
			product = "milk"
		elif animal_name == "cừu" or animal_name == "cừu non":
			product = "wool"
		elif animal_name == "gà con" or animal_name == "gà trống" or animal_name == "gà tây":
			product = "egg"
		if product != "":
			produce[product] = int(produce[product]) + 1
			animal["last_product_day"] = day
			var product_name := "sữa" if product == "milk" else ("trứng" if product == "egg" else "len")
			_show_toast("Nhận được 1 " + product_name + " từ " + animal_name + "!")
	animals[index] = animal
	_play_animal_voice(_animal_voice(animal_name))
	_save_game()
	_refresh_hud()

func _animal_voice(animal_name: String) -> String:
	if animal_name == "bò":
		return "cow"
	if animal_name == "bò mộng":
		return "bull"
	if animal_name == "cừu" or animal_name == "cừu non":
		return "sheep"
	if animal_name == "lợn":
		return "pig"
	return "bird"
func _open_shop(i: int) -> void:
	shop_player = i
	modal_open = true
	shop_overlay.visible = true
	_update_shop_info()

func _close_shop() -> void:
	modal_open = false
	shop_overlay.visible = false

func _build_shop() -> void:
	shop_overlay = ColorRect.new()
	shop_overlay.color = Color(0.08, 0.14, 0.11, 0.76)
	shop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_overlay.visible = false
	hud_root.add_child(shop_overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(394, 156)
	panel.size = Vector2(492, 410)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#f6e9c9"), Color("#684c36")))
	shop_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "QUẦY NÔNG SẢN"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("#5d4934"))
	heading.add_theme_font_size_override("font_size", 24)
	column.add_child(heading)
	shop_info = Label.new()
	shop_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_info.custom_minimum_size = Vector2(0, 88)
	shop_info.add_theme_color_override("font_color", Color("#5d4934"))
	column.add_child(shop_info)
	_add_shop_button(column, "Bán toàn bộ nông sản", _sell_all)
	seed_buy_button = _add_shop_button(column, "", _buy_seeds)
	_add_shop_button(column, "Mua 3 bó thức ăn  ·  12 xu", _buy_feed)
	_add_shop_button(column, "Đóng cửa hàng", _close_shop)

func _add_shop_button(parent: VBoxContainer, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("#f9f1dc"))
	button.add_theme_stylebox_override("normal", _panel_style(Color("#708d53"), Color("#50613f")))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#8eaa61"), Color("#50613f")))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#526f49"), Color("#50613f")))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _update_shop_info() -> void:
	if shop_info == null:
		return
	var crop := _shop_crop()
	var total := 0
	for kind in produce:
		total += int(produce[kind])
	shop_info.text = "Ví: " + str(coins) + " xu     ·     Hạt " + str(CROP_LABELS[crop]) + ": " + str(seeds[crop]) + "\nMùa trồng: " + _crop_season_text(crop) + "     ·     Trong túi: " + str(total) + " món\nThức ăn: " + str(feed_bags)
	if seed_buy_button != null:
		seed_buy_button.text = "Mua 5 hạt " + str(CROP_LABELS[crop]) + "  ·  18 xu"

func _sell_all() -> void:
	var earned := 0
	for kind in ["carrot", "turnip", "berry"]:
		var price := int(CROP_PRICES[kind])
		if int(CROP_BONUS_SEASON[kind]) == _season_index():
			price += 5
		earned += int(produce[kind]) * price
		produce[kind] = 0
	earned += int(produce["egg"]) * 12
	earned += int(produce["milk"]) * 26
	earned += int(produce["wool"]) * 20
	produce["egg"] = 0
	produce["milk"] = 0
	produce["wool"] = 0
	if earned <= 0:
		_show_toast("Túi hàng đang trống. Hãy thu hoạch cây và chăm vật nuôi.")
	else:
		coins += earned
		_show_toast("Đã bán nông sản, nhận " + str(earned) + " xu!")
		_play_sfx("coin")
	_save_game()
	_refresh_hud()
	_update_shop_info()

func _buy_seeds() -> void:
	var crop := _shop_crop()
	if coins < 18:
		_show_toast("Chưa đủ 18 xu để mua hạt giống.")
		return
	coins -= 18
	seeds[crop] = int(seeds[crop]) + 5
	_show_toast("Đã mua 5 hạt " + str(CROP_LABELS[crop]) + ".")
	_play_sfx("purchase")
	_save_game()
	_refresh_hud()
	_update_shop_info()

func _buy_feed() -> void:
	if coins < 12:
		_show_toast("Chưa đủ 12 xu để mua thức ăn.")
		return
	coins -= 12
	feed_bags += 3
	_show_toast("Đã mua 3 bó thức ăn cho đàn vật nuôi.")
	_play_sfx("purchase")
	_save_game()
	_refresh_hud()
	_update_shop_info()

func _sleep() -> void:
	var old_season := _season_index()
	for i in range(plots.size()):
		var plot: Dictionary = plots[i]
		var kind := str(plot["crop"])
		if kind != "":
			if _crop_grows_in_season(kind, old_season) and (bool(plot["watered"]) or weather == "Mưa"):
				if old_season == 3:
					plot["winter_ticks"] = int(plot.get("winter_ticks", 0)) + 1
					if int(plot["winter_ticks"]) % 2 == 0:
						plot["growth"] = mini(int(plot["growth"]) + 1, int(CROP_DAYS[kind]))
				else:
					plot["growth"] = mini(int(plot["growth"]) + 1, int(CROP_DAYS[kind]))
			plot["watered"] = false
		plots[i] = plot
	day += 1
	hour = 7
	minute = 0
	clock_accumulator = 0.0
	for pl in players:
		pl["energy"] = 100
	weather = _roll_weather()
	if weather == "Mưa":
		for i in range(plots.size()):
			var plot: Dictionary = plots[i]
			if str(plot["crop"]) != "":
				plot["watered"] = true
			plots[i] = plot
	var new_season := _season_index()
	if new_season != old_season:
		_show_toast("Mùa " + str(SEASON_NAMES[new_season]) + " đã đến. Năm " + str(_year_number()) + " bắt đầu!")
	else:
		_show_toast("Ngày " + str(_season_day()) + " mùa " + str(SEASON_NAMES[new_season]) + ". Năng lượng đã hồi phục.")
	_play_sfx("sleep")
	_save_game()
	_refresh_hud()
	queue_redraw()
func _advance_hour() -> void:
	hour += 1
	minute = 0
	if hour >= 22:
		_sleep()
	else:
		_refresh_hud()

func _set_tool(i: int, tool_index: int) -> void:
	players[i]["tool"] = clampi(tool_index, 0, 3)
	_refresh_hud()

func _cycle_seed(i: int) -> void:
	var pl: Dictionary = players[i]
	var current_index := CROPS.find(str(pl["crop"]))
	pl["crop"] = CROPS[(current_index + 1) % CROPS.size()]
	_show_toast("Hạt giống đang chọn: " + str(CROP_LABELS[str(pl["crop"])]))
	_refresh_hud()
	if modal_open:
		_update_shop_info()

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	if sound_button != null:
		sound_button.text = "SFX: BẬT" if sound_enabled else "SFX: TẮT"
	if not sound_enabled and sfx_player != null:
		sfx_player.stop()
	elif sound_enabled:
		_play_sfx("ui")

func _toggle_music() -> void:
	music_enabled = not music_enabled
	if music_button != null:
		music_button.text = "NHẠC: BẬT" if music_enabled else "NHẠC: TẮT"
	if music_player != null:
		music_player.stream_paused = not music_enabled
	if sound_enabled:
		_play_sfx("ui")
func _show_toast(message: String) -> void:
	if toast_label == null:
		return
	if coop_enabled and acting >= 0:
		message = PLAYER_NAMES[acting] + ": " + message
	toast_label.text = message
	toast_label.visible = true
	get_tree().create_timer(2.7).timeout.connect(_hide_toast)

func _hide_toast() -> void:
	if is_instance_valid(toast_label):
		toast_label.visible = false

func _refresh_hud() -> void:
	if day_label == null:
		return
	day_label.text = "NGÀY %02d" % day
	time_label.text = "%02d:%02d" % [hour, minute]
	money_label.text = "✦ %d xu" % coins
	weather_label.text = weather
	season_label.text = "MÙA " + str(SEASON_NAMES[_season_index()]).to_upper() + "  ·  " + str(_season_day()) + "/7  ·  NĂM " + str(_year_number())
	if coop_enabled:
		energy_label.text = "Năng lượng  %s %d%%  ·  %s %d%%" % [PLAYER_NAMES[0], int(players[0]["energy"]), PLAYER_NAMES[1], int(players[1]["energy"])]
		tool_label.text = _player_tool_text(0) + "   |   " + _player_tool_text(1)
	else:
		energy_label.text = "Năng lượng  %d%%" % int(players[0]["energy"])
		tool_label.text = "Công cụ: " + str(TOOL_LABELS[int(players[0]["tool"])]) + "   ·   Hạt: " + str(CROP_LABELS[str(players[0]["crop"])])
	inventory_label.text = "Hạt: " + _seed_summary() + "    ·    Hàng: " + _produce_summary()
	if sky_card != null:
		sky_card.call("set_sky_state", _season_index(), weather, hour)
	if modal_open:
		_update_shop_info()

func _produce_summary() -> String:
	var pieces: Array[String] = []
	var extra_labels := {"egg": "Trứng", "milk": "Sữa", "wool": "Len"}
	for kind in ["carrot", "turnip", "berry", "egg", "milk", "wool"]:
		if int(produce[kind]) > 0:
			var label := str(CROP_LABELS.get(kind, extra_labels.get(kind, kind)))
			pieces.append(label + " " + str(produce[kind]))
	return "—" if pieces.is_empty() else ", ".join(PackedStringArray(pieces))

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	add_child(layer)
	hud_root = Control.new()
	hud_root.name = "HUD"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(hud_root)

	var status_panel := PanelContainer.new()
	status_panel.position = Vector2(20, 16)
	status_panel.size = Vector2(540, 132)
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color("#f5e8c9"), Color("#684c36")))
	hud_root.add_child(status_panel)
	var status_column := VBoxContainer.new()
	status_column.add_theme_constant_override("separation", 3)
	status_panel.add_child(status_column)
	var title := _make_label("CHILL CHILL  ·  NÔNG TRẠI BỐN MÙA", 18, Color("#587646"))
	status_column.add_child(title)
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 12)
	status_column.add_child(stat_row)
	day_label = _make_label("NGÀY 01", 15, Color("#574734"))
	time_label = _make_label("07:00", 15, Color("#574734"))
	money_label = _make_label("✦ 90 xu", 15, Color("#a66b2c"))
	weather_label = _make_label("Nắng", 14, Color("#557e8a"))
	for label in [day_label, time_label, money_label, weather_label]:
		stat_row.add_child(label)
	season_label = _make_label("MÙA XUÂN · 1/7 · NĂM 1", 13, Color("#557346"))
	status_column.add_child(season_label)
	energy_label = _make_label("Năng lượng  100%", 13, Color("#4e7045"))
	status_column.add_child(energy_label)
	inventory_label = _make_label("", 12, Color("#604f3d"))
	status_column.add_child(inventory_label)

	var sky_panel := Panel.new()
	sky_panel.position = Vector2(575, 16)
	sky_panel.size = Vector2(202, 132)
	sky_panel.add_theme_stylebox_override("panel", _panel_style(Color("#f5e8c9"), Color("#684c36")))
	hud_root.add_child(sky_panel)
	sky_card = SKY_CARD_SCRIPT.new()
	sky_card.position = Vector2(9, 9)
	sky_card.size = Vector2(184, 114)
	sky_panel.add_child(sky_card)

	var tools_panel := PanelContainer.new()
	tools_panel.position = Vector2(790, 16)
	tools_panel.size = Vector2(470, 132)
	tools_panel.add_theme_stylebox_override("panel", _panel_style(Color("#f5e8c9"), Color("#684c36")))
	hud_root.add_child(tools_panel)
	var tools_column := VBoxContainer.new()
	tools_column.add_theme_constant_override("separation", 5)
	tools_panel.add_child(tools_column)
	tool_label = _make_label("Công cụ: Cuốc đất", 14, Color("#574734"))
	tools_column.add_child(tool_label)
	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 5)
	tools_column.add_child(tool_row)
	_add_tool_button(tool_row, "Cuốc", 0)
	_add_tool_button(tool_row, "Hạt", 1)
	_add_tool_button(tool_row, "Tưới", 2)
	_add_tool_button(tool_row, "Hái", 3)
	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 8)
	tools_column.add_child(audio_row)
	sound_button = Button.new()
	sound_button.text = "SFX: BẬT"
	sound_button.custom_minimum_size = Vector2(205, 28)
	sound_button.add_theme_font_size_override("font_size", 12)
	sound_button.focus_mode = Control.FOCUS_NONE
	sound_button.pressed.connect(_toggle_sound)
	audio_row.add_child(sound_button)
	music_button = Button.new()
	music_button.text = "NHẠC: BẬT"
	music_button.custom_minimum_size = Vector2(205, 28)
	music_button.add_theme_font_size_override("font_size", 12)
	music_button.focus_mode = Control.FOCUS_NONE
	music_button.pressed.connect(_toggle_music)
	audio_row.add_child(music_button)

	toast_label = _make_label("", 15, Color("#fff6d8"))
	toast_label.position = Vector2(310, 564)
	toast_label.size = Vector2(660, 46)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", _panel_style(Color("#435d3d"), Color("#e7d29d")))
	toast_label.visible = false
	hud_root.add_child(toast_label)
	coop_button = Button.new()
	coop_button.text = _coop_button_text()
	coop_button.position = Vector2(20, 660)
	coop_button.custom_minimum_size = Vector2(250, 34)
	coop_button.add_theme_font_size_override("font_size", 13)
	coop_button.focus_mode = Control.FOCUS_NONE
	coop_button.pressed.connect(_toggle_coop)
	hud_root.add_child(coop_button)
	_build_shop()
func _add_tool_button(parent: HBoxContainer, caption: String, tool_index: int) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(96, 34)
	button.add_theme_font_size_override("font_size", 12)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_set_tool.bind(0, tool_index))
	parent.add_child(button)

func _make_label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _build_audio() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "ChillChillTheme"
	music_player.volume_db = -17.0
	var theme := load("res://chill_chill/assets/chill_chill_theme.wav") as AudioStreamWAV
	if theme != null:
		theme.loop_mode = AudioStreamWAV.LOOP_FORWARD
		theme.loop_begin = 0
		theme.loop_end = int(theme.data.size() / 2)
		music_player.stream = theme
	add_child(music_player)
	music_player.play()

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "FarmActionSounds"
	sfx_player.volume_db = -4.0
	add_child(sfx_player)
	footstep_player = AudioStreamPlayer.new()
	footstep_player.name = "Footsteps"
	footstep_player.volume_db = -13.0
	footstep_player.stream = _make_footstep_stream()
	add_child(footstep_player)
	animal_voice_player = AudioStreamPlayer.new()
	animal_voice_player.name = "AnimalVoices"
	animal_voice_player.volume_db = -7.0
	add_child(animal_voice_player)
	var files := {
		"hoe": "sfx_hoe.wav", "seed": "sfx_seed.wav", "water": "sfx_water.wav",
		"harvest": "sfx_harvest.wav", "coin": "sfx_coin.wav", "purchase": "sfx_purchase.wav",
		"sleep": "sfx_sleep.wav", "ui": "sfx_ui.wav", "cow": "sfx_cow.wav",
		"bull": "sfx_bull.wav", "sheep": "sfx_sheep.wav", "pig": "sfx_pig.wav", "bird": "sfx_bird.wav"
	}
	for key in files:
		sfx_streams[key] = load("res://chill_chill/assets/" + str(files[key]))
func _play_sfx(action: String) -> void:
	if not sound_enabled or sfx_player == null:
		return
	var stream: AudioStream = sfx_streams.get(action, sfx_streams.get("ui"))
	if stream == null:
		return
	if sfx_player.playing:
		sfx_player.stop()
	sfx_player.stream = stream
	sfx_player.play()

func _play_footstep() -> void:
	if not sound_enabled or footstep_player == null or footstep_player.stream == null:
		return
	if footstep_player.playing:
		footstep_player.stop()
	footstep_player.play()

func _play_animal_voice(action: String) -> void:
	if not sound_enabled or animal_voice_player == null:
		return
	var stream: AudioStream = sfx_streams.get(action)
	if stream == null:
		return
	if animal_voice_player.playing:
		animal_voice_player.stop()
	animal_voice_player.stream = stream
	animal_voice_player.play()

func _make_footstep_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := 2425
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var time := float(i) / float(sample_rate)
		var decay := 1.0 - float(i) / float(sample_count)
		var envelope := decay * decay
		var thump := sin(TAU * 118.0 * time) * 0.42 + sin(TAU * 74.0 * time) * 0.16
		var grit := sin(TAU * 1871.0 * time + sin(TAU * 93.0 * time)) * 0.055
		var sample := int(clampf((thump + grit) * envelope * 0.52, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var footstep := AudioStreamWAV.new()
	footstep.format = AudioStreamWAV.FORMAT_16_BITS
	footstep.mix_rate = sample_rate
	footstep.stereo = false
	footstep.data = data
	return footstep
func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var loaded: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (loaded is Dictionary):
		return
	day = int(loaded.get("day", day))
	coins = int(loaded.get("coins", coins))
	feed_bags = int(loaded.get("feed_bags", feed_bags))
	seeds = loaded.get("seeds", seeds)
	produce = loaded.get("produce", produce)
	coop_enabled = bool(loaded.get("coop", false))
	var saved_players: Array = loaded.get("players", [])
	if saved_players.is_empty():
		players[0]["energy"] = int(loaded.get("energy", 100))
	for i in range(mini(saved_players.size(), players.size())):
		if not (saved_players[i] is Dictionary):
			continue
		var saved: Dictionary = saved_players[i]
		var pl: Dictionary = players[i]
		pl["energy"] = clampi(int(saved.get("energy", 100)), 0, 100)
		pl["tool"] = clampi(int(saved.get("tool", 0)), 0, 3)
		var crop := str(saved.get("crop", "carrot"))
		pl["crop"] = crop if CROPS.has(crop) else "carrot"
		var pos_list: Array = saved.get("pos", [])
		if pos_list.size() == 2:
			pl["pos"] = Vector2(float(pos_list[0]), float(pos_list[1]))
	var saved_plots: Array = loaded.get("plots", [])
	for i in range(mini(saved_plots.size(), plots.size())):
		if saved_plots[i] is Dictionary:
			plots[i] = saved_plots[i]
	var saved_friends: Dictionary = loaded.get("friends", {})
	for i in range(animals.size()):
		var animal: Dictionary = animals[i]
		animal["friendship"] = int(saved_friends.get(str(animal["name"]), 0))
		animal["last_product_day"] = int(loaded.get("product_" + str(animal["name"]), 0))
		animals[i] = animal

func _save_game() -> void:
	var friends := {}
	var product_days := {}
	for animal in animals:
		friends[str(animal["name"])] = int(animal["friendship"])
		product_days["product_" + str(animal["name"])] = int(animal["last_product_day"])
	var saved_players: Array = []
	for pl in players:
		var pos: Vector2 = pl["pos"]
		saved_players.append({"energy": int(pl["energy"]), "tool": int(pl["tool"]), "crop": str(pl["crop"]), "pos": [pos.x, pos.y]})
	var saved := {
		"day": day, "coins": coins, "feed_bags": feed_bags,
		"seeds": seeds, "produce": produce, "plots": plots, "friends": friends,
		"coop": coop_enabled, "players": saved_players
	}
	for key in product_days:
		saved[key] = product_days[key]
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(saved))
		file.close()
func _make_players() -> void:
	players.clear()
	for i in range(PLAYER_COUNT):
		players.append({
			"pos": PLAYER_START[i], "facing": Vector2.DOWN, "moving": false,
			"step_clock": 0.0, "last_step_phase": -1,
			"tool": 0, "crop": "carrot", "energy": 100,
			"action_kind": "", "action_timer": 0.0, "action_duration": 0.0,
			"action_target": Vector2.ZERO
		})

func _active_count() -> int:
	return PLAYER_COUNT if coop_enabled else 1

func _focus_point() -> Vector2:
	var total := Vector2.ZERO
	var count := _active_count()
	for i in range(count):
		var pos: Vector2 = players[i]["pos"]
		total += pos
	return total / float(count)

func _clamp_axis(value: float, half: float, world: float) -> float:
	if half * 2.0 >= world:
		return world * 0.5
	return clampf(value, half, world - half)

func _update_camera() -> void:
	if camera == null:
		return
	var view := get_viewport_rect().size
	var zoom_value := 1.16
	if coop_enabled:
		var first: Vector2 = players[0]["pos"]
		var second: Vector2 = players[1]["pos"]
		var gap := (first - second).abs()
		zoom_value = minf((view.x - 260.0) / (gap.x + 160.0), (view.y - 220.0) / (gap.y + 160.0))
		zoom_value = clampf(zoom_value, 0.6, 1.16)
	camera.zoom = Vector2(zoom_value, zoom_value)
	var half := view * 0.5 / zoom_value
	var focus := _focus_point()
	camera.position = Vector2(_clamp_axis(focus.x, half.x, WORLD_SIZE.x), _clamp_axis(focus.y, half.y, WORLD_SIZE.y))

func _toggle_coop() -> void:
	coop_enabled = not coop_enabled
	if coop_enabled:
		var first: Vector2 = players[0]["pos"]
		var second: Vector2 = players[1]["pos"]
		if first.distance_to(second) > 160.0:
			players[1]["pos"] = Vector2(clampf(first.x - 40.0, 48.0, WORLD_SIZE.x - 48.0), first.y)
		_show_toast("Chế độ 2 người đã bật. Người 2 dùng mũi tên và numpad.")
	else:
		_show_toast("Đã tắt chế độ 2 người.")
	if coop_button != null:
		coop_button.text = _coop_button_text()
	_save_game()
	_refresh_hud()
	queue_redraw()

func _coop_button_text() -> String:
	return "CHƠI 2 NGƯỜI: BẬT  (F2)" if coop_enabled else "CHƠI 2 NGƯỜI: TẮT  (F2)"

func _read_direction(i: int) -> Vector2:
	var keys: Dictionary = PLAYER_KEYS[i]
	var direction := Input.get_vector(str(keys["left"]), str(keys["right"]), str(keys["up"]), str(keys["down"]))
	if i == 0 and not coop_enabled:
		var alt: Dictionary = PLAYER_KEYS[1]
		direction = (direction + Input.get_vector(str(alt["left"]), str(alt["right"]), str(alt["up"]), str(alt["down"]))).limit_length(1.0)
	return direction

func _action_pressed(i: int, role: String) -> bool:
	var keys: Dictionary = PLAYER_KEYS[i]
	if Input.is_action_just_pressed(str(keys[role])):
		return true
	if i == 0 and not coop_enabled:
		var alt: Dictionary = PLAYER_KEYS[1]
		return Input.is_action_just_pressed(str(alt[role]))
	return false

func _update_player(i: int, delta: float) -> void:
	var pl: Dictionary = players[i]
	var direction := _read_direction(i)
	pl["moving"] = direction.length() > 0.05
	if bool(pl["moving"]):
		var pos: Vector2 = pl["pos"]
		pl["facing"] = _dominant_direction(direction)
		var movement := direction.normalized() * 172.0 * delta
		var next_x := Vector2(pos.x + movement.x, pos.y)
		var next_y := Vector2(pos.x, pos.y + movement.y)
		if not _is_blocked_at(next_x):
			pos.x = next_x.x
		if not _is_blocked_at(next_y):
			pos.y = next_y.y
		pos.x = clampf(pos.x, 48.0, WORLD_SIZE.x - 48.0)
		pos.y = clampf(pos.y, 48.0, WORLD_SIZE.y - 48.0)
		pl["pos"] = pos
		pl["step_clock"] = float(pl["step_clock"]) + delta * 8.0
		var step_phase := int(float(pl["step_clock"]) / 2.6)
		if step_phase != int(pl["last_step_phase"]):
			pl["last_step_phase"] = step_phase
			_play_footstep()
	else:
		pl["last_step_phase"] = -1
	if float(pl["action_timer"]) > 0.0:
		pl["action_timer"] = maxf(0.0, float(pl["action_timer"]) - delta)

func _handle_player_keys(i: int) -> void:
	acting = i
	for t in range(4):
		if _action_pressed(i, "tool" + str(t)):
			_set_tool(i, t)
	if _action_pressed(i, "seed"):
		_cycle_seed(i)
	if _action_pressed(i, "use"):
		_use_tool(i)
	if _action_pressed(i, "interact"):
		_interact(i)
	acting = -1

func _shop_crop() -> String:
	return str(players[shop_player]["crop"])

func _seed_summary() -> String:
	if not coop_enabled:
		var crop := str(players[0]["crop"])
		return str(CROP_LABELS[crop]) + " × " + str(int(seeds[crop]))
	var pieces: Array[String] = []
	for crop in CROPS:
		pieces.append(str(CROP_LABELS[crop]) + " " + str(int(seeds[crop])))
	return ", ".join(PackedStringArray(pieces))

func _player_tool_text(i: int) -> String:
	return str(PLAYER_NAMES[i]) + ": " + str(SHORT_TOOL_LABELS[int(players[i]["tool"])]) + " · " + str(CROP_LABELS[str(players[i]["crop"])])
