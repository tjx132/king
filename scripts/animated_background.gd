extends AnimatedSprite2D

const FRAME_PATH = "res://美术资源/动态背景图序列帧/序列帧/月夜山水_%03d.png"
const FRAME_COUNT = 61

@export var frames_per_second = 12.0
@export var background_height = 720.0
@export var player_path: NodePath

var player: CharacterBody2D
var was_moving = false

func _ready() -> void:
	player = get_node_or_null(player_path) as CharacterBody2D
	var frames = SpriteFrames.new()
	frames.add_animation(&"background")
	frames.set_animation_loop(&"background", true)
	frames.set_animation_speed(&"background", frames_per_second)
	for frame_index in range(FRAME_COUNT):
		var texture = load(FRAME_PATH % frame_index) as Texture2D
		if texture != null:
			frames.add_frame(&"background", texture)
	if frames.get_frame_count(&"background") == 0:
		push_error("无法加载动态背景")
		return
	sprite_frames = frames
	animation = &"background"
	frame = 0
	var frame_size = frames.get_frame_texture(&"background", 0).get_size()
	scale = Vector2.ONE * background_height / frame_size.y

func _process(_delta: float) -> void:
	var is_moving = is_instance_valid(player) and absf(player.velocity.x) > 1.0
	if is_moving == was_moving:
		return
	was_moving = is_moving
	if is_moving:
		play(&"background")
	else:
		pause()
