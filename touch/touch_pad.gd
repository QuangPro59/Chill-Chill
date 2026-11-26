extends Control

const JOY_RADIUS := 34.0
const KNOB_RADIUS := 13.0
const BUTTON_RADIUS := 15.0
const DEADZONE := 0.25
const SLOTS := [Vector2(58, -26), Vector2(92, -52), Vector2(50, -76)]

var joysticks: Array = []
var buttons: Array = []
var pending_release: Array = []

func _ready() -> void:
	add_to_group("touch_pad")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func add_joystick(side: String, left_actions: Array, right_actions: Array, up_actions: Array, down_actions: Array, color: Color) -> void:
	joysticks.append({
		"side": side,
		"color": color,
		"visible": true,
		"left": left_actions,
		"right": right_actions,
		"up": up_actions,
		"down": down_actions,
		"touch": -1,
		"vec": Vector2.ZERO,
	})

func add_button(side: String, slot: int, caption: String, action: String, color: Color) -> void:
	buttons.append({
		"side": side,
		"slot": slot,
		"caption": caption,
		"action": action,
		"color": color,
		"visible": true,
		"touch": -1,
	})

func set_side_visible(side: String, value: bool) -> void:
	for joy in joysticks:
		if joy["side"] == side:
			joy["visible"] = value
			if not value:
				_release_joystick(joy)
	for btn in buttons:
		if btn["side"] == side:
			btn["visible"] = value
			btn["touch"] = -1
	queue_redraw()

func blocks(point: Vector2) -> bool:
	for joy in joysticks:
		if joy["visible"] and point.distance_to(_joy_center(joy["side"])) <= JOY_RADIUS * 1.7:
			return true
	for btn in buttons:
		if btn["visible"] and point.distance_to(_button_center(btn)) <= BUTTON_RADIUS * 1.4:
			return true
	return false

func _joy_center(side: String) -> Vector2:
	var view := get_viewport_rect().size
	if side == "left":
		return Vector2(62.0, view.y - 118.0)
	return Vector2(view.x - 62.0, view.y - 118.0)

func _button_center(btn: Dictionary) -> Vector2:
	var offset: Vector2 = SLOTS[btn["slot"]]
	if btn["side"] == "right":
		offset.x = -offset.x
	return _joy_center(btn["side"]) + offset

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_down(event.index, event.position)
		else:
			_on_up(event.index)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position)

func _on_down(index: int, point: Vector2) -> void:
	for joy in joysticks:
		if joy["visible"] and joy["touch"] == -1 and point.distance_to(_joy_center(joy["side"])) <= JOY_RADIUS * 1.7:
			joy["touch"] = index
			_update_joystick(joy, point)
			return
	for btn in buttons:
		if btn["visible"] and btn["touch"] == -1 and point.distance_to(_button_center(btn)) <= BUTTON_RADIUS * 1.4:
			btn["touch"] = index
			Input.action_press(btn["action"])
			pending_release.append({"action": btn["action"], "frames": 3})
			queue_redraw()
			return

func _on_drag(index: int, point: Vector2) -> void:
	for joy in joysticks:
		if joy["touch"] == index:
			_update_joystick(joy, point)

func _on_up(index: int) -> void:
	for joy in joysticks:
		if joy["touch"] == index:
			_release_joystick(joy)
	for btn in buttons:
		if btn["touch"] == index:
			btn["touch"] = -1
	queue_redraw()

func _update_joystick(joy: Dictionary, point: Vector2) -> void:
	var v: Vector2 = (point - _joy_center(joy["side"])) / JOY_RADIUS
	if v.length() > 1.0:
		v = v.normalized()
	joy["vec"] = v
	_set_actions(joy["left"], maxf(-v.x, 0.0) if absf(v.x) > DEADZONE else 0.0)
	_set_actions(joy["right"], maxf(v.x, 0.0) if absf(v.x) > DEADZONE else 0.0)
	_set_actions(joy["up"], maxf(-v.y, 0.0) if absf(v.y) > DEADZONE else 0.0)
	_set_actions(joy["down"], maxf(v.y, 0.0) if absf(v.y) > DEADZONE else 0.0)
	queue_redraw()

func _release_joystick(joy: Dictionary) -> void:
	joy["touch"] = -1
	joy["vec"] = Vector2.ZERO
	_set_actions(joy["left"], 0.0)
	_set_actions(joy["right"], 0.0)
	_set_actions(joy["up"], 0.0)
	_set_actions(joy["down"], 0.0)
	queue_redraw()

func _set_actions(names: Array, strength: float) -> void:
	for action_name in names:
		if strength > 0.0:
			Input.action_press(action_name, strength)
		else:
			Input.action_release(action_name)

func _process(_delta: float) -> void:
	var still_pending: Array = []
	for item in pending_release:
		item["frames"] -= 1
		if item["frames"] <= 0:
			Input.action_release(item["action"])
		else:
			still_pending.append(item)
	pending_release = still_pending

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED:
		for joy in joysticks:
			_release_joystick(joy)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for joy in joysticks:
		if not joy["visible"]:
			continue
		var center: Vector2 = _joy_center(joy["side"])
		var col: Color = joy["color"]
		draw_circle(center, JOY_RADIUS, Color(col.r, col.g, col.b, 0.16))
		draw_arc(center, JOY_RADIUS, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.55), 1.5)
		var knob: Vector2 = center + joy["vec"] * JOY_RADIUS * 0.7
		draw_circle(knob, KNOB_RADIUS, Color(col.r, col.g, col.b, 0.5))
	for btn in buttons:
		if not btn["visible"]:
			continue
		var pos: Vector2 = _button_center(btn)
		var bcol: Color = btn["color"]
		var alpha := 0.6 if btn["touch"] != -1 else 0.25
		draw_circle(pos, BUTTON_RADIUS, Color(bcol.r, bcol.g, bcol.b, alpha))
		draw_arc(pos, BUTTON_RADIUS, 0.0, TAU, 28, Color(bcol.r, bcol.g, bcol.b, 0.7), 1.5)
		draw_string(font, pos + Vector2(-BUTTON_RADIUS, 3.5), btn["caption"], HORIZONTAL_ALIGNMENT_CENTER, BUTTON_RADIUS * 2.0, 9, Color(1, 1, 1, 0.95))
