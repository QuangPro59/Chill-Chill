extends Node

var failures: Array[String] = []
var test_scripts: Array[GDScript] = []
var game: Node
var world: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _check(condition: bool, message: String) -> void:
	print("PASS " if condition else "FAIL ", message)
	if not condition:
		failures.append(message)

func _run() -> void:
	var run_id := str(int(Time.get_unix_time_from_system())) + "_" + str(Time.get_ticks_usec())
	for path in ["res://couple/couple_manager.gd", "res://chill_chill/main.gd"]:
		var script := load(path) as GDScript
		script.source_code = script.source_code.replace("user://couple_save.json", "res://debug_shots/couple_test_" + run_id + ".json").replace("user://harvest_hollow_save.json", "res://debug_shots/meadow_test_" + run_id + ".json")
		_check(script.reload() == OK, "Isolated test save path: " + path)
		test_scripts.append(script)
	game = load("res://game.tscn").instantiate()
	get_tree().root.add_child.call_deferred(game)
	await _frames(6)
	await _shot("title_fixed.png")
	_check(game.current_level.find_child("SeasonsGoneLogoTransparent", true, false) == null, "SG logo removed")
	await _click(game.current_level.get_node("CanvasLayer/Control/MainMenuContainer/Play"))
	await _frames(12)
	_check(game.current_path == "res://world/world.tscn", "Play button opens farm")
	if game.current_path != "res://world/world.tscn":
		get_tree().quit(2)
		return
	world = game.current_level
	await _shot("names_dialog.png")
	_check(get_tree().paused, "Fresh save opens name dialog")
	var name_fields: Array = world.couple.find_children("*", "LineEdit", true, false)
	name_fields[0].text = "An"
	name_fields[1].text = "Hà"
	for node in world.couple.find_children("*", "Button", true, false):
		if node.text == "Bắt đầu":
			await _click(node)
			break
	await _frames(12)
	_check(not get_tree().paused and world.couple.has_save, "Name confirmation resumes game")
	var saved_couple = test_scripts[0].new()
	saved_couple._load()
	_check(saved_couple.names == ["An", "Hà"], "Saved custom names preserved")
	saved_couple.free()
	_check(world.coop.enabled and world.coop.p2 != null, "Two controllable players spawned")
	_check(world.coop.p1.anim.sprite_frames != world.coop.p2.anim.sprite_frames, "Player two has distinct female frames")
	for animation in ["down_idle", "up_idle", "left_idle", "right_idle", "walk_down", "walk_up", "walk_left", "walk_right"]:
		_check(world.coop.p2.anim.sprite_frames.has_animation(animation), "Female animation " + animation)
	await _shot("farm_fixed.png")
	if "overview" in OS.get_cmdline_user_args():
		get_window().size = Vector2i(1600, 800)
		await _frames(4)
		world.coop.set_process(false)
		world.get_node("HUD").hide()
		world.season_fx.hide()
		world.couple.hud.hide()
		var overview_camera: Camera2D = world.coop.cam
		overview_camera.limit_left = -100000
		overview_camera.limit_top = -100000
		overview_camera.limit_right = 100000
		overview_camera.limit_bottom = 100000
		overview_camera.zoom = Vector2(0.44, 0.44)
		overview_camera.global_position = Vector2(768, 344)
		overview_camera.reset_smoothing()
		await _frames(5)
		await _shot("farm_overview.png")
		get_node("/root/SoundHandler").stop_music()
		await _frames(10)
		get_tree().quit()
		return
	await _estate_herd_test()
	var hotbar = world.get_node("HUD/HotBar")
	var money_before: int = world.player.player_data.money
	for index in range(hotbar.slots.size()):
		await _click(hotbar.slots[index])
		_check(world.player.selected_crop == world.player.crop_strnames[index], "Toolbar mouse selection " + str(index))
		_check(hotbar.slots[index].get_global_rect().end.x <= 640, "Toolbar slot in viewport " + str(index))
	_check(world.player.player_data.money == money_before, "UI clicks do not plant behind toolbar")
	await _key(KEY_C, 0.06)
	_check(world.player.selected_crop == world.player.crop_strnames[0], "Keyboard cycles crop selection")
	await _shop_test(hotbar)
	world.coop.pad.visible = true
	_check(world.coop.pad._joy_center("left").y + world.coop.pad.JOY_RADIUS < hotbar.get_global_rect().position.y, "Touch controls do not cover toolbar")
	await _shot("touch_toolbar.png")
	world.coop.pad.visible = false
	world._move_players(world.get_node("BigHouseDoor").global_position + Vector2(-24, 56))
	world.configure_camera()
	await _frames(4)
	await _walk_to_mode(KEY_UP, "big_house")
	_check(world.interior_mode == "big_house", "Player two walks through big-house door")
	if world.interior_mode != "big_house":
		await _shot("door_failure.png")
		get_tree().quit(2)
		return
	await _frames(8)
	var room: Node2D = world.active_room
	var spawn: Vector2 = room.get_node("Spawn").global_position
	_check(world.coop.p1.global_position.distance_to(spawn) < 3, "Player one teleports once without parent offset")
	_check(world.coop.p2.global_position.distance_to(spawn) < 40, "Player two enters the same room")
	_check(get_viewport().get_camera_2d() == world.coop.cam, "Co-op camera stays active indoors")
	_check(world.coop.cam.global_position.distance_to(room.global_position + Vector2(240, 87)) < 1, "Camera centers inside house")
	_check(not world.get_node("MeadowPortal").is_visible_in_tree(), "Outdoor sign hidden inside")
	_check(not hotbar.visible, "Farming toolbar hidden indoors")
	await _shot("bighouse_fixed.png")
	get_window().size = Vector2i(1024, 768)
	await _frames(8)
	var room_center_on_screen: Vector2 = get_viewport().get_canvas_transform() * (room.global_position + Vector2(240, 87))
	_check(room_center_on_screen.distance_to(get_viewport().get_visible_rect().size * 0.5) < 2, "Indoor camera adapts to resized window")
	get_window().size = Vector2i(1280, 720)
	await _frames(8)
	var pos1: Vector2 = world.coop.p1.global_position
	var pos2: Vector2 = world.coop.p2.global_position
	await _key(KEY_A, 0.25)
	await _key(KEY_RIGHT, 0.25)
	_check(world.coop.p1.global_position.x < pos1.x - 8, "Male can walk indoors")
	_check(world.coop.p2.global_position.x > pos2.x + 8, "Female can walk indoors")
	var crops_before: int = world.tilemap.crop_instances.size()
	world.coop.p1.global_position = room.global_position + Vector2(36, 103)
	world.coop.p2.global_position = room.global_position + Vector2(80, 103)
	await _frames(4)
	await _key(KEY_E, 0.08)
	await _key(KEY_SLASH, 0.08)
	_check(world.resting_positions.size() == 2, "Both players use separate beds")
	_check(world.tilemap.crop_instances.size() == crops_before, "Indoor actions do not plant crops")
	await _shot("beds_fixed.png")
	await _key(KEY_S, 0.16)
	await _key(KEY_DOWN, 0.16)
	_check(world.resting_positions.is_empty(), "Movement gets both players out of bed")
	world.coop.p1.global_position = room.global_position + Vector2(18, 145)
	await _key(KEY_A, 0.65)
	_check(world.coop.p1.global_position.x >= room.global_position.x + 8, "Left wall blocks walking out of floor")
	world.coop.p2.global_position = room.global_position + Vector2(240, 92)
	await _walk_to_mode(KEY_UP, "")
	_check(world.interior_mode == "", "Female walks through exit and brings both outside")
	_check(world.coop.cam.limit_left == 0 and world.coop.cam.zoom.x <= 1.01, "Outdoor camera limits restored")
	_check(hotbar.visible and world.coop.marker_one.visible, "Toolbar and crop markers restored")
	await _shot("outside_again.png")
	for mode in ["house", "barn", "big_house"]:
		world._move_players(world.get_node(world.ROOM_DOORS[mode]).global_position + Vector2(0, 56))
		world.configure_camera()
		await _walk_to_mode(KEY_W, mode)
		_check(world.interior_mode == mode, "Male enters " + mode)
		if world.interior_mode != mode:
			print("DOOR DIAGNOSTIC ", mode, " p1=", world.coop.p1.global_position, " door=", world.get_node(world.ROOM_DOORS[mode]).global_position, " physics=", world.coop.p1.is_physics_processing(), " input=", world.coop.p1.input_vector)
			for collision in range(world.coop.p1.get_slide_collision_count()):
				print("COLLIDER ", world.coop.p1.get_slide_collision(collision).get_collider())
			await _shot("failed_" + mode + ".png")
			continue
		if mode == "barn":
			world.coop.p2.global_position = world.active_room.global_position + Vector2(160, 138)
			await _frames(3)
			await _key(KEY_SLASH, 0.06)
			_check(world.interior_voice.playing, "Female feeds barn animal with sound")
			await _shot("barn_fixed.png")
			world.coop.pad.visible = true
			var touch_button: Dictionary = world.coop.pad.buttons[3]
			world.interior_voice.stop()
			await _touch(world.coop.pad._button_center(touch_button))
			_check(world.interior_voice.playing, "Touch action feeds animal")
			world.coop.pad.visible = false
		if mode == "big_house":
			await _key(KEY_F2, 0.06)
			_check(not world.coop.enabled, "Switch to solo indoors")
			_check(get_viewport().get_camera_2d() == world.player.optional_char.get_node("Camera2D"), "Solo camera shows room")
			await _key(KEY_F2, 0.06)
			_check(world.coop.enabled, "Restore two players indoors")
			_check(not world.coop.marker_one.visible, "No outdoor markers after indoor co-op toggle")
		await _click(world.interior_controls.get_child(1).get_child(1))
		_check(world.interior_mode == "", "Exit button works for " + mode)
	world._move_players(world.get_node("MeadowPortal").global_position + Vector2(-65, 0))
	world.configure_camera()
	await _key(KEY_RIGHT, 0.8)
	await _frames(10)
	_check(game.current_path == "res://chill_chill/main.tscn", "Walk through meadow portal")
	if game.current_path != "res://chill_chill/main.tscn":
		print("PORTAL DIAGNOSTIC p1=", world.coop.p1.global_position, " portal=", world.get_node("MeadowPortal").global_position)
		await _shot("failed_portal.png")
	if game.current_path == "res://chill_chill/main.tscn":
		await _shot("meadow_fixed.png")
		game.current_level.players[0]["pos"] = Vector2(90, 480)
		await _key(KEY_A, 0.5)
		await _frames(15)
		_check(game.current_level == world, "Farm scene reused on return")
		_check(get_tree().get_nodes_in_group("livestock").size() == 47, "Returning from meadow does not duplicate the herd")
		_check(get_viewport().get_camera_2d() == world.coop.cam, "Farm co-op camera restored after travel")
		_check(world.coop.p1.global_position.distance_to(world.get_node("MeadowPortal").global_position) >= 100, "No portal bounce after return")
		await _shot("farm_return.png")
	get_node("/root/SoundHandler").stop_music()
	await _frames(10)
	print("VERIFICATION COMPLETE: ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)

func _estate_herd_test() -> void:
	var herd := get_tree().get_nodes_in_group("livestock")
	_check(herd.size() == 47, "Expanded herd has 47 animals")
	for definition in world.HERD:
		var count := 0
		for animal in herd:
			if animal.get_meta("species") == definition[0]:
				count += 1
		_check(count == definition[1], "Herd count " + definition[0] + ": " + str(count))
	_check(world.ESTATE.has_point(world.get_node("BigHouseExterior").position), "Large house is on separate eastern plot")
	_check(world.coop.p1.is_in_group("farm_players") and world.coop.p2.is_in_group("farm_players"), "Both players recognized for livestock sounds")
	_check(world.coop.cam.limit_right == 1536, "Camera reaches expanded eastern map")
	var outside_pens := false
	var excessive_speed := false
	var starting_positions := {}
	for animal in herd:
		starting_positions[animal] = animal.global_position
		_check(animal.voice_player.stream != null, "Livestock voice assigned: " + String(animal.name))
	world._move_players(Vector2(904, 344))
	world.configure_camera()
	_key_event(KEY_D, true)
	_key_event(KEY_RIGHT, true)
	for frame in range(360):
		await get_tree().physics_frame
		for animal in herd:
			outside_pens = outside_pens or not animal.roam_area.has_point(animal.global_position)
			excessive_speed = excessive_speed or animal.velocity.length() > animal.speed + 0.01
		if world.coop.p1.global_position.x >= 1280:
			break
	_key_event(KEY_D, false)
	_key_event(KEY_RIGHT, false)
	await _frames(8)
	_check(world.coop.p1.global_position.x >= 1275 and world.coop.p2.global_position.x >= 1290, "Both players walk east across connecting road and estate gate")
	_check(not outside_pens, "All 47 animals stay inside their pastures while roaming")
	_check(not excessive_speed, "Animal movement remains normalized and speed-limited")
	var moved_species := {}
	for animal in herd:
		if animal.global_position.distance_to(starting_positions[animal]) > 1:
			moved_species[animal.get_meta("species")] = true
	_check(moved_species.size() == 9, "All nine animal types animate and roam")
	var estate_view: Vector2 = get_viewport().get_canvas_transform() * world.coop.p1.global_position
	_check(get_viewport().get_visible_rect().has_point(estate_view), "Outdoor camera keeps players visible on estate")
	await _shot("estate_play.png")
	for animal in herd:
		animal.voice_player.stop()
		animal._voice_timer = 0
		animal._update_voice(0)
	_check(_playing_herd_voices(herd) == 0, "Livestock stay quiet when both players are far away")
	_key_event(KEY_A, true)
	_key_event(KEY_LEFT, true)
	for frame in range(360):
		await get_tree().physics_frame
		if world.coop.p1.global_position.x <= 904:
			break
	_key_event(KEY_A, false)
	_key_event(KEY_LEFT, false)
	await _frames(4)
	_check(world.coop.p1.global_position.x <= 910 and world.coop.p2.global_position.x < 950, "Both players walk back to farm without boundary obstruction")
	world._move_players(Vector2(640, 140))
	await _frames(3)
	for animal in herd:
		animal.voice_player.stop()
		animal._voice_timer = 1000
	for animal in herd:
		animal._voice_timer = 0
		animal._update_voice(0)
	_check(_playing_herd_voices(herd) == 2, "Nearby livestock play at most two voices together")
	world.enter_interior("big_house")
	_check(_playing_herd_voices(herd) == 0, "Entering a house silences outdoor livestock")
	var all_hidden := true
	for animal in herd:
		all_hidden = all_hidden and not animal.visible and not animal.is_physics_processing()
	_check(all_hidden, "All added livestock hidden and paused indoors")
	world.exit_interior()
	await _frames(4)
	_check(world.coop.p1.global_position.distance_to(world.get_node("BigHouseDoor").global_position + Vector2(0, 30)) < 2, "House exit returns to relocated eastern door")
	_check(not world.tilemap._can_place_crop(Vector2i(75, 28)), "Cannot plant crops in residential yard")
	_check(not world.tilemap._can_place_crop(Vector2i(38, 10)), "Cannot plant crops in livestock pen")
	await _key(KEY_F2, 0.06)
	_check(not world.coop.enabled and get_viewport().get_camera_2d().limit_right == 1536, "Solo camera also reaches eastern estate")
	await _key(KEY_F2, 0.06)
	world._move_players(Vector2(1440, 430))
	_key_event(KEY_D, true)
	await _key(KEY_RIGHT, 1.5)
	_key_event(KEY_D, false)
	_check(world.coop.p1.global_position.x < 1500 and world.coop.p2.global_position.x < 1500, "Estate perimeter fence blocks both players from leaving the lawn")
	world._move_players(Vector2(480, 350))
	world.configure_camera()
	await _frames(4)

func _playing_herd_voices(herd: Array[Node]) -> int:
	var count := 0
	for animal in herd:
		if animal.voice_player.playing:
			count += 1
	return count

func _shop_test(hotbar: Control) -> void:
	var buy: Button = hotbar.get_node("ShopRect/BuyButton")
	var sell: Button = hotbar.get_node("ShopRect/SellButton")
	if buy == null or sell == null:
		_check(false, "Shop buttons discoverable")
		return
	var before: int = world.player.player_data.money
	await _click(buy)
	_check(world.player.player_data.beet_stock == 1, "Buy updates selected crop stock")
	_check(world.player.player_data.money < before, "Buy charges correct account")
	await _frames(20)
	await _shot("toolbar_stock.png")
	await _click(sell)
	_check(world.player.player_data.beet_stock == 0, "Sell clears stock")
	world.player.player_data.money = 0
	await _click(buy)
	_check(world.player.player_data.beet_stock == 0, "Cannot buy without money")
	world.player.player_data.money = before

func _walk_to_mode(key: Key, mode: String) -> void:
	_key_event(key, true)
	for i in range(100):
		await get_tree().physics_frame
		if world.interior_mode == mode:
			break
	_key_event(key, false)
	await _frames(4)

func _key(key: Key, seconds: float) -> void:
	_key_event(key, true)
	await get_tree().create_timer(seconds).timeout
	_key_event(key, false)
	await _frames(3)

func _key_event(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await _frames(2)

func _touch(point: Vector2) -> void:
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await _frames(2)

func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func _shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://debug_shots/" + filename))
	print("SCREENSHOT ", filename, " ", image.get_size())
