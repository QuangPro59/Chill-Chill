extends CharacterBody2D

@export var texture: Texture2D
@export var hframes: int = 6
@export var vframes: int = 8
@export var walk_row: int = 2
@export var walk_frames: int = 6
@export var faces_left: bool = true
@export var speed: float = 14.0
## World-space pasture bounds; an empty rectangle uses an area around the spawn.
@export var roam_area: Rect2 = Rect2()
@export var voice: AudioStream
@export_range(0.5, 2.0, 0.05) var voice_pitch: float = 1.0

const ROAM_RADIUS := 64.0
const ROAM_MARGIN := 12.0
const PLAYER_VOICE_DISTANCE := 180.0
const MAX_LIVESTOCK_VOICES := 2

var _spawn_position := Vector2.ZERO
var _roam_bounds := Rect2()
var _target := Vector2.ZERO
var _idle_timer := 0.0
var _walk_timer := 0.0
var _anim_time := 0.0
var _voice_timer := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var voice_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	add_to_group("livestock")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if texture != null:
		sprite.texture = texture
	sprite.hframes = maxi(1, hframes)
	sprite.vframes = maxi(1, vframes)
	sprite.frame = 0
	if voice != null:
		voice_player.stream = voice
	voice_player.stop()
	voice_player.pitch_scale = voice_pitch
	voice_player.volume_db = -15.0
	voice_player.max_distance = 280.0
	voice_player.max_polyphony = 1
	_voice_timer = randf_range(12.0, 28.0)
	visibility_changed.connect(_on_visibility_changed)
	_spawn_position = global_position
	set_roam_area(roam_area)

func set_roam_area(area: Rect2) -> void:
	roam_area = area
	_roam_bounds = area.abs()
	if not _roam_bounds.has_area():
		_roam_bounds = Rect2(
			_spawn_position - Vector2.ONE * ROAM_RADIUS,
			Vector2.ONE * ROAM_RADIUS * 2.0)
	# Keep bodies away from pasture edges, even when a very small area is supplied.
	var inset := Vector2(
		minf(ROAM_MARGIN, _roam_bounds.size.x * 0.5),
		minf(ROAM_MARGIN, _roam_bounds.size.y * 0.5))
	_roam_bounds = Rect2(_roam_bounds.position + inset, _roam_bounds.size - inset * 2.0)
	global_position = _clamp_to_roam_area(global_position)
	_begin_idle()

func _physics_process(delta: float) -> void:
	_update_voice(delta)
	global_position = _clamp_to_roam_area(global_position)
	if _idle_timer > 0.0:
		_idle_timer -= delta
		velocity = Vector2.ZERO
		_animate(delta, Vector2.ZERO)
		return

	_walk_timer -= delta
	var to_target := _target - global_position
	if to_target.length_squared() <= 4.0 or _walk_timer <= 0.0 or speed <= 0.0:
		_begin_idle()
		_animate(delta, Vector2.ZERO)
		return

	# Normalize diagonal movement and avoid overshooting nearby targets.
	velocity = to_target.normalized() * minf(speed, to_target.length() / maxf(delta, 0.0001))
	var previous_position := global_position
	var collided := move_and_slide()
	global_position = _clamp_to_roam_area(global_position)
	var movement := global_position - previous_position
	_animate(delta, movement)
	if collided or movement.length_squared() < 0.0001:
		_begin_idle()

func _clamp_to_roam_area(point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, _roam_bounds.position.x, _roam_bounds.end.x),
		clampf(point.y, _roam_bounds.position.y, _roam_bounds.end.y))

func _begin_idle() -> void:
	velocity = Vector2.ZERO
	_idle_timer = randf_range(1.5, 4.5)
	_pick_target()

func _pick_target() -> void:
	# Sample inside the pasture rather than clamping random directions onto its edges.
	var lower := _roam_bounds.position.max(global_position - Vector2.ONE * ROAM_RADIUS)
	var upper := _roam_bounds.end.min(global_position + Vector2.ONE * ROAM_RADIUS)
	_target = Vector2(randf_range(lower.x, upper.x), randf_range(lower.y, upper.y))
	_walk_timer = randf_range(3.0, 7.0)

func _animate(delta: float, movement: Vector2) -> void:
	if movement.length_squared() < 0.0001:
		_anim_time = 0.0
		sprite.frame = 0
		return
	if absf(movement.x) > 0.0001:
		sprite.flip_h = (movement.x < 0.0) != faces_left
	_anim_time += delta * 6.0
	var first_frame := clampi(walk_row, 0, sprite.vframes - 1) * sprite.hframes
	# Some sheets (the original cow) continue the walk cycle into the next row.
	var frame_count := clampi(walk_frames, 1, sprite.hframes * sprite.vframes - first_frame)
	sprite.frame = first_frame + int(_anim_time) % frame_count

func _update_voice(delta: float) -> void:
	_voice_timer -= delta
	if _voice_timer > 0.0:
		return
	_voice_timer = randf_range(12.0, 28.0)
	if voice_player.stream == null or voice_player.playing or not is_visible_in_tree():
		return
	if not _player_near():
		return
	var playing_count := 0
	for animal in get_tree().get_nodes_in_group("livestock"):
		var audio := animal.get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
		if audio != null and audio.playing:
			playing_count += 1
			if playing_count >= MAX_LIVESTOCK_VOICES:
				return
	voice_player.play()

func _player_near() -> bool:
	for node in get_tree().get_nodes_in_group("farm_players"):
		var character := node as CharacterBody2D
		if character == null or character == self:
			continue
		if character.is_in_group("livestock") or not character.is_visible_in_tree():
			continue
		var distance_squared := character.global_position.distance_squared_to(global_position)
		if distance_squared <= PLAYER_VOICE_DISTANCE * PLAYER_VOICE_DISTANCE:
			return true
	return false

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		voice_player.stop()
