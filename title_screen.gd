extends Node

#Variables to control what is displaying on the screen
@onready var main_menu_container = %MainMenuContainer
@onready var options_container = %OptionsContainer
@onready var bg_pan = $AnimationPlayer


signal level_changed(level_name)

@export var world_level: PackedScene = load("res://world/world.tscn")

#Sets up panning background and correct buttons displayed
func _ready():
	bg_pan.play("bg_panning")
	main_menu_container.visible = true
	options_container.visible = false
	if OS.has_feature("mobile"):
		var quit_button = main_menu_container.get_node_or_null("Quit")
		if quit_button != null:
			quit_button.visible = false
	var subtitle := Label.new()
	subtitle.text = "Nông trại thư giãn cho hai người"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.85, 0.9))
	subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	subtitle.add_theme_constant_override("outline_size", 4)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_menu_container.get_parent().add_child(subtitle)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle.offset_top = -26.0
	subtitle.offset_left = -200.0
	subtitle.offset_right = 200.0

# --------- PLAY BUTTON ---------
#--------------------------------

## Switches from main menu to main scene when player presses play button
func _on_play_pressed():
	emit_signal("level_changed", world_level)
	#get_tree().change_scene_to_file()

# --------- OPTIONS CONTROL ---------
#------------------------------------

#Hides main menu and opens options menu when options button is pressed
func _on_options_pressed():
	main_menu_container.visible = false
	options_container.visible = true

#Hides options menu and returns view to main menu when back button is pressed
func _on_options_back_pressed():
	main_menu_container.visible = true
	options_container.visible = false

#Toggles game music on and off
func _on_music_button_toggled(button_pressed):
	if button_pressed:
		SoundHandler.can_play = false
		SoundHandler.stop_music()
	else:
		SoundHandler.can_play = true
		SoundHandler.play_music()

# --------- EXIT BUTTON ---------
#--------------------------------

#Will close and exit the game when the exit button is pressed
func _on_quit_pressed():
	get_tree().quit()
