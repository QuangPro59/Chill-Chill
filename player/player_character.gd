extends CharacterBody2D

#Variables for controlling player movement
var input_vector = Vector2.ZERO
const speed : float = 80.0

#Variables for local co-op (player 1 uses WASD only while co-op is active)
var player_id : int = 1
var coop_active : bool = false
var facing : Vector2 = Vector2.DOWN

#variables for controlling player animations
@onready var anim : AnimatedSprite2D = $AnimatedSprite2D
var direction : String = "down_idle"

const FEMALE_PALETTE = {
	"o": Color("493343"), "h": Color("603a35"),
	"b": Color("87543e"), "l": Color("b87d50"),
	"s": Color("f4cca5"), "d": Color("dca080"),
	"r": Color("e9949b"), "p": Color("df759a"),
	"P": Color("f7b2c6"), "t": Color("429c94"),
	"T": Color("7bcab5"), "v": Color("306a70"),
	"w": Color("fff1d7"), "g": Color("efbe5d"),
}
const FEMALE_HEADS = {
	"down": [
		"....oooooo....", "..oobllllboo..", ".obllllllllbo.",
		"obbbllllbbbbbo", "obbbbhhhhbbbbo", "obbhsssssshbbo",
		"obhsssssssshbo", "ohssosssosssho", "ohssosssosssho",
		"ohsrrssssrrsho", ".ohhssddsshhho", "..oohddddhoo..",
	],
	"up": [
		"....oooooo....", "..oobllllboo..", ".obllllllllbo.",
		"obbbllllbbbbbo", "obbbblblbbbbbo", "ohbbblblbbbbho",
		"ohbbblblbbbbho", "ohhbbblbbbbhho", ".ohhbbbbbbhho.",
		".ohhhbbbbhhho.", "..ohhhbbhhho..", "...ohhhhhho...",
	],
	"right": [
		"....oooooo....", "..oobllllboo..", ".obllllllllbo.",
		".obbbllllbbbo.", "ohbbbbhhhhhho.", "ohbbbhssssso..",
		"ohbbbhssosso..", "ohbbbhssossso.", "ohbbbhssrrso..",
		"ohhbbhssssdo..", ".ohhbhdddho...", "..ohhhddho....",
	],
}
const FEMALE_DRESSES = {
	"down": [
		"...owddwo...", "..opPwwPpo..", ".opPPppPPpo.",
		"..oppppppo..", "..ovTTTTvo..", ".ovtTTTttvo.",
		".otTTttttto.", "ovtTTtttttvo", ".ovwwwwwwvo.",
	],
	"up": [
		"...ohddho...", "..opPppPpo..", ".opPPppPPpo.",
		"..oppppppo..", "..ovTwwTvo..", ".ovtTTTttvo.",
		".otTTttttto.", "ovtTTtttttvo", ".ovwwwwwwvo.",
	],
	"right": [
		"....odwo....", "...opPPpo...", "...opPPpo...",
		"...oppppo...", "...ovTTvo...", "..ovTTttvo..",
		"..otTTttvo..", ".ovtTTtttvo.", "..ovwwwwvo..",
	],
}
const FEMALE_ARM = ["opo", "oPo", "oso", "odo", ".o."]
const FEMALE_BOOT = ["oso", "odo", "oho", "obo", "ooo"]
const FEMALE_BRAID = [".oh.", "oblo", "olbo", "oblo", "olbo", ".oo.", ".pp.", ".hb.", ".o.."]
const FEMALE_FLOWER = ["..P..", ".PwP.", "PwgwP", ".PwP.", "..P.."]


func _ready():
	if player_id == 2:
		anim.sprite_frames = _create_female_frames()
		anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim.play("down_idle")


func _create_female_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for view in ["down", "up", "left", "right"]:
		var idle_name: StringName = view + "_idle"
		var walk_name: StringName = "walk_" + view
		var resting_texture := _create_female_texture(view, 0)
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 4.0)
		frames.set_animation_loop(idle_name, true)
		frames.add_frame(idle_name, resting_texture)
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, 8.0)
		frames.set_animation_loop(walk_name, true)
		for step in [1, 0, -1, 0]:
			var texture := resting_texture if step == 0 else _create_female_texture(view, step)
			frames.add_frame(walk_name, texture)
	return frames


func _create_female_texture(view: String, step: int) -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var side := view == "left" or view == "right"
	var pattern_view := "right" if side else view
	var bob := int(step != 0)
	var left_foot := 14 - step * 2 if side else 12
	var right_foot := 16 + step * 2 if side else 18
	_stamp_female_pixels(image, Vector2i(left_foot, 24 - int(step == 1)), FEMALE_BOOT)
	_stamp_female_pixels(image, Vector2i(right_foot, 24 - int(step == -1)), FEMALE_BOOT)
	if side:
		_stamp_female_pixels(image, Vector2i(12 - step, 17 - bob), FEMALE_ARM)
	else:
		_stamp_female_pixels(image, Vector2i(8, 17 - bob + step), FEMALE_ARM)
		_stamp_female_pixels(image, Vector2i(21, 17 - bob - step), FEMALE_ARM)
	_stamp_female_pixels(image, Vector2i(10, 16 - bob), FEMALE_DRESSES[pattern_view])
	if side:
		_stamp_female_pixels(image, Vector2i(17 + step, 17 - bob), FEMALE_ARM)
	_stamp_female_pixels(image, Vector2i(9, 4 - bob), FEMALE_HEADS[pattern_view])
	var braid_position := Vector2i(20, 13 - bob)
	var flower_position := Vector2i(19, 5 - bob)
	if view == "up":
		braid_position = Vector2i(14, 14 - bob)
		flower_position.x = 8
	elif side:
		braid_position = Vector2i(10, 12 - bob)
		flower_position.x = 10
	braid_position.x += step
	_stamp_female_pixels(image, braid_position, FEMALE_BRAID)
	_stamp_female_pixels(image, flower_position, FEMALE_FLOWER)
	if view == "left":
		image.flip_x()
	return ImageTexture.create_from_image(image)


func _stamp_female_pixels(image: Image, origin: Vector2i, rows: Array) -> void:
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var pixel := row.substr(x, 1)
			if pixel != ".":
				image.set_pixelv(origin + Vector2i(x, y), FEMALE_PALETTE[pixel])


#player physics
func _physics_process(_delta):
	move_player()
	idle_animations()
	walk_animations()
	move_and_slide()



#----- ACTIONS -----
#--------------------
func move_player():
	var act_left := "ui_left"
	var act_right := "ui_right"
	var act_up := "ui_up"
	var act_down := "ui_down"
	if player_id == 2:
		act_left = "p2_left"
		act_right = "p2_right"
		act_up = "p2_up"
		act_down = "p2_down"
	elif coop_active:
		act_left = "p1_left"
		act_right = "p1_right"
		act_up = "p1_up"
		act_down = "p1_down"
	input_vector.x = Input.get_action_strength(act_right) - Input.get_action_strength(act_left)
	input_vector.y = Input.get_action_strength(act_down) - Input.get_action_strength(act_up)
	input_vector = input_vector.normalized()
	if input_vector != Vector2.ZERO:
		if absf(input_vector.x) > absf(input_vector.y):
			facing = Vector2(signf(input_vector.x), 0.0)
		else:
			facing = Vector2(0.0, signf(input_vector.y))
	if input_vector != Vector2.ZERO:
		velocity = input_vector * speed
	else:
		velocity = Vector2.ZERO


#----- ANIMATIONS -----
#----------------------


#Sets up walking animations for player character
func walk_animations():
	if velocity.x < 0:
		anim.play("walk_left")
		direction = "left"
	elif velocity.x > 0:
		anim.play("walk_right")
		direction = "right"
	elif velocity.y < 0:
		anim.play("walk_up")
		direction = "up"
	elif velocity.y > 0:
		anim.play("walk_down")
		direction = "down"
	else:
		pass


#Sets up idle animations for when the player isn't moving
func idle_animations():
	if velocity == Vector2.ZERO and direction == "left":
			anim.play("left_idle")
	elif velocity == Vector2.ZERO and direction == "right":
			anim.play("right_idle")
	elif velocity == Vector2.ZERO and direction == "up":
			anim.play("up_idle")
	elif velocity == Vector2.ZERO and direction == "down":
			anim.play("down_idle")
	else:
		pass
