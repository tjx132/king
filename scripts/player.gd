extends CharacterBody2D

enum State { IDLE, RUN, JUMP, DASH, ATTACK, SKILL, SHEATH, HIT, BLOCK, BOSS_BLOCK, HEAVY_HIT, HEAVY_HOLD, HEAVY_RECOVER, DEFEATED }

const SWORD_SCAR = preload("res://scripts/sword_scar.gd")
const ANIMATION_DATA_PATH = "res://美术资源/角色序列帧/动画数据.json"
const FRAME_ROOT = "res://美术资源/角色序列帧/"
const ANIMATION_SOURCES = {
	&"idle": "站立",
	&"run": "奔跑",
	&"jump": "跳跃",
	&"dash": "短距冲刺",
	&"skill": "拔剑斩闪",
	&"draw_upslash": "拔剑上劈",
	&"downslash": "下劈",
	&"spin_slash": "转身横斩",
	&"sheath": "收剑",
	&"hit": "受击硬直",
	&"heavy_hit": "重击跪地滑退",
	&"block": "格挡"
}
const ATTACK_ANIMATIONS = [&"draw_upslash", &"downslash", &"spin_slash"]
const ATTACK_DAMAGE = [18.0, 20.0, 28.0]
const SKILL_DAMAGE = 45.0
const BLOCK_GUARD_FRAME = 4
const DASH_DURATION = 0.5
const DASH_GHOST_INTERVAL = 0.075
const DASH_GHOST_LIFETIME = 0.3
const SKILL_MOTION_DURATION = 0.225
const SKILL_TRAIL_LIFETIME = 0.4
const HEAVY_HIT_SLIDE_DURATION = 0.255
const HEAVY_HIT_RECOVER_SPEED = 1.15
const BLADE_EXTENSIONS = {
	&"draw_upslash": {
		4: [Vector2(190, 181), 29.0, 44.0],
		5: [Vector2(237, 12), -39.0, 52.0],
		6: [Vector2(237, 12), -39.0, 52.0],
		7: [Vector2(238, 14), -39.0, 52.0]
	},
	&"downslash": {
		3: [Vector2(185, 143), 62.0, 42.0],
		4: [Vector2(220, 207), 35.0, 44.0],
		5: [Vector2(224, 194), 25.0, 44.0]
	},
	&"spin_slash": {
		7: [Vector2(229, 96), -2.0, 56.0],
		8: [Vector2(229, 104), 4.0, 56.0],
		9: [Vector2(239, 192), 43.0, 48.0]
	},
	&"skill": {
		4: [Vector2(231, 21), -37.0, 52.0],
		5: [Vector2(235, 15), -39.0, 52.0],
		6: [Vector2(234, 97), 0.0, 60.0],
		7: [Vector2(240, 95), 0.0, 60.0]
	}
}

@export var move_speed = 360.0
@export var acceleration = 2200.0
@export var deceleration = 2600.0
@export var jump_velocity = -600.0
@export var gravity = 1400.0
@export var fall_gravity_multiplier = 1.2
@export var dash_distance = 1020.0
@export var skill_distance = 1600.0
@export var run_animation_speed = 1.15
@export var attack_animation_speed = 1.5
@export var hit_animation_speed = 2.5
@export var boss_intro_slide_distance = 630.0
@export var boss_intro_hold_duration = 3.0
@export var max_health = 100.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var blade_extension: Polygon2D = $BladeExtension
@onready var sword_drag_audio: AudioStreamPlayer2D = $SwordDragAudio
@onready var health_bar: ProgressBar = $UILayer/PlayerHealthBar
@onready var death_screen = $DeathScreen
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var state: State = State.IDLE
var health = 0.0
var facing = 1
var jump_count = 0
var boss_collision_ignored = false
var attack_step = 0
var attack_queued = false
var attack_hit_done = false
var dash_ghost_timer = 0.0
var skill_motion_remaining = 0.0
var heavy_hit_slide_remaining = 0.0
var heavy_hit_scrape_started = false
var heavy_hit_hold_remaining = 0.0
var heavy_hit_breath_time = 0.0
var intro_scar
var skill_trail: Line2D
var skill_trail_glow: Line2D

func _ready() -> void:
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	_configure_animations()
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play(&"idle")

func _process(_delta: float) -> void:
	_update_blade_extension()
	_update_attack_hit()

func _physics_process(delta: float) -> void:
	_handle_actions()
	match state:
		State.DASH:
			_update_dash(delta)
		State.ATTACK, State.SHEATH, State.HIT, State.BLOCK, State.DEFEATED:
			_update_ground_action(delta)
		State.BOSS_BLOCK:
			_update_boss_block(delta)
		State.HEAVY_HIT:
			_update_heavy_hit(delta)
		State.HEAVY_HOLD:
			_update_heavy_hit_hold(delta)
		State.HEAVY_RECOVER:
			_update_ground_action(delta)
		State.SKILL:
			_update_skill(delta)
		_:
			_update_free_movement(delta)
	move_and_slide()
	if boss_collision_ignored and state != State.DASH and state != State.SKILL:
		_restore_boss_collision_when_clear()
	if state == State.SKILL and absf(velocity.x) > 0.0:
		_record_skill_trail()
	if state == State.IDLE or state == State.RUN or state == State.JUMP:
		_update_locomotion()

func _handle_actions() -> void:
	if state == State.HIT or state >= State.BOSS_BLOCK:
		return
	if state == State.BLOCK:
		_update_block()
		return
	if state == State.ATTACK or state == State.SHEATH:
		var direction = Input.get_axis(&"move_left", &"move_right")
		if direction * facing < 0.0:
			_cancel_attack()
			facing = 1 if direction > 0.0 else -1
			animated_sprite.flip_h = facing < 0
		if is_on_floor() and Input.is_action_just_pressed(&"jump"):
			_cancel_attack()
		elif Input.is_action_just_pressed(&"dash"):
			_cancel_attack()
			_start_dash()
		elif is_on_floor() and Input.is_action_just_pressed(&"skill"):
			_cancel_attack()
			_start_skill()
		if state == State.ATTACK and Input.is_action_just_pressed(&"attack") and attack_step < ATTACK_ANIMATIONS.size():
			attack_queued = true
		return
	if state == State.DASH or state == State.SKILL:
		return
	if not is_on_floor():
		if Input.is_action_just_pressed(&"attack"):
			_start_attack(1)
		elif Input.is_action_just_pressed(&"dash"):
			_start_dash()
		return
	if Input.is_action_just_pressed(&"attack"):
		_start_attack(1)
	elif Input.is_action_just_pressed(&"skill"):
		_start_skill()
	elif Input.is_action_just_pressed(&"dash"):
		_start_dash()
	elif Input.is_action_just_pressed(&"block"):
		_start_block()

func _update_free_movement(delta: float) -> void:
	var direction = Input.get_axis(&"move_left", &"move_right")
	if direction != 0.0:
		facing = 1 if direction > 0.0 else -1
		animated_sprite.flip_h = facing < 0
	var target_speed = direction * move_speed
	var rate = acceleration if direction != 0.0 else deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	if is_on_floor():
		jump_count = 0
		if Input.is_action_just_pressed(&"jump"):
			_perform_jump()
		else:
			velocity.y = 0.0
	else:
		if jump_count == 0:
			jump_count = 1
		if Input.is_action_just_pressed(&"jump") and jump_count < 2:
			_perform_jump()
		_apply_gravity(delta)

func _perform_jump() -> void:
	velocity.y = jump_velocity
	jump_count += 1
	state = State.JUMP
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(&"jump")
	animated_sprite.frame = 0

func _update_ground_action(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	_apply_gravity(delta)

func _update_boss_block(delta: float) -> void:
	_update_ground_action(delta)
	if animated_sprite.frame >= BLOCK_GUARD_FRAME and animated_sprite.is_playing():
		animated_sprite.pause()

func _update_heavy_hit(delta: float) -> void:
	if animated_sprite.frame >= 3 and not heavy_hit_scrape_started:
		heavy_hit_scrape_started = true
		sword_drag_audio.play()
		_create_heavy_hit_scar()
	if animated_sprite.frame >= 4 and heavy_hit_slide_remaining > 0.0:
		var step = minf(boss_intro_slide_distance / HEAVY_HIT_SLIDE_DURATION * delta, heavy_hit_slide_remaining)
		velocity.x = -facing * step / maxf(delta, 0.0001)
		heavy_hit_slide_remaining -= step
		if is_instance_valid(intro_scar):
			intro_scar.progress = 1.0 - heavy_hit_slide_remaining / boss_intro_slide_distance
	else:
		velocity.x = 0.0
	_apply_gravity(delta)

func _update_heavy_hit_hold(delta: float) -> void:
	velocity.x = 0.0
	heavy_hit_hold_remaining = maxf(0.0, heavy_hit_hold_remaining - delta)
	heavy_hit_breath_time += delta
	var breath = sin(heavy_hit_breath_time * 10.0)
	animated_sprite.scale = Vector2(1.0 - breath * 0.006, 1.0 + breath * 0.015)
	_apply_gravity(delta)
	if heavy_hit_hold_remaining <= 0.0:
		_start_heavy_hit_recovery()

func _update_dash(delta: float) -> void:
	velocity.x = facing * dash_distance / DASH_DURATION
	velocity.y = 0.0
	dash_ghost_timer -= delta
	if dash_ghost_timer <= 0.0:
		_spawn_dash_afterimage()
		dash_ghost_timer = DASH_GHOST_INTERVAL

func _update_skill(delta: float) -> void:
	if animated_sprite.frame >= 6 and skill_motion_remaining > 0.0:
		var step = minf(skill_distance / SKILL_MOTION_DURATION * delta, skill_motion_remaining)
		velocity.x = facing * step / maxf(delta, 0.0001)
		skill_motion_remaining -= step
	else:
		velocity.x = 0.0
	_apply_gravity(delta)

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		var multiplier = fall_gravity_multiplier if velocity.y > 0.0 else 1.0
		velocity.y += gravity * multiplier * delta

func _update_locomotion() -> void:
	if not is_on_floor():
		state = State.JUMP
		_play_animation(&"jump")
	elif absf(velocity.x) > 1.0:
		state = State.RUN
		_play_animation(&"run")
	else:
		state = State.IDLE
		_play_animation(&"idle")

func _play_animation(animation_name: StringName) -> void:
	animated_sprite.speed_scale = run_animation_speed if animation_name == &"run" else 1.0
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

func take_hit(damage: float = 10.0, source_x: float = 0.0) -> void:
	if state == State.HIT or state == State.BLOCK or state >= State.BOSS_BLOCK:
		return
	health = maxf(0.0, health - damage)
	health_bar.value = health
	_fade_skill_trail()
	attack_step = 0
	attack_queued = false
	velocity.x = 0.0
	if source_x != 0.0:
		velocity.x = 140.0 if global_position.x >= source_x else -140.0
	state = State.DEFEATED if health <= 0.0 else State.HIT
	animated_sprite.speed_scale = hit_animation_speed
	animated_sprite.play(&"hit")
	animated_sprite.frame = 0

func is_in_boss_intro() -> bool:
	return state >= State.BOSS_BLOCK and state <= State.HEAVY_RECOVER

func _fall_dead() -> void:
	animated_sprite.pause()
	velocity.x = 0.0
	var fall_tween = create_tween()
	fall_tween.set_parallel(true)
	fall_tween.tween_property(animated_sprite, "rotation", -facing * PI * 0.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(animated_sprite, "modulate", Color(0.55, 0.16, 0.18, 1.0), 0.55)
	fall_tween.chain().tween_interval(0.35)
	fall_tween.chain().tween_callback(death_screen.show_death)

func begin_boss_intro() -> void:
	_fade_skill_trail()
	state = State.BOSS_BLOCK
	attack_step = 0
	attack_queued = false
	velocity = Vector2.ZERO
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(&"block")
	animated_sprite.frame = 0

func play_boss_intro_impact(source_x: float) -> void:
	if state != State.BOSS_BLOCK:
		return
	facing = 1 if source_x >= global_position.x else -1
	animated_sprite.flip_h = facing < 0
	state = State.HEAVY_HIT
	velocity.x = 0.0
	heavy_hit_slide_remaining = boss_intro_slide_distance
	heavy_hit_scrape_started = false
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(&"heavy_hit")
	animated_sprite.frame = 0

func _cancel_attack() -> void:
	state = State.IDLE
	attack_step = 0
	attack_queued = false
	animated_sprite.speed_scale = 1.0

func _start_attack(step: int) -> void:
	state = State.ATTACK
	attack_step = step
	attack_queued = false
	attack_hit_done = false
	velocity.x = 0.0
	animated_sprite.speed_scale = attack_animation_speed
	animated_sprite.play(ATTACK_ANIMATIONS[step - 1])

func _start_skill() -> void:
	state = State.SKILL
	_ignore_boss_collision()
	velocity.x = 0.0
	attack_hit_done = false
	skill_motion_remaining = skill_distance
	animated_sprite.speed_scale = 1.0
	_create_skill_trail()
	animated_sprite.play(&"skill")

func _start_dash() -> void:
	state = State.DASH
	_ignore_boss_collision()
	velocity.x = 0.0
	dash_ghost_timer = 0.0
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(&"dash")

func _ignore_boss_collision() -> void:
	boss_collision_ignored = true
	set_collision_mask_value(2, false)

func _restore_boss_collision_when_clear() -> void:
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = 2
	query.exclude = [get_rid()]
	if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return
	boss_collision_ignored = false
	set_collision_mask_value(2, true)

func _start_block() -> void:
	state = State.BLOCK
	velocity.x = 0.0
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(&"block")

func _update_block() -> void:
	if Input.is_action_pressed(&"block"):
		if animated_sprite.frame >= BLOCK_GUARD_FRAME and animated_sprite.is_playing():
			animated_sprite.pause()
	elif not animated_sprite.is_playing():
		animated_sprite.play(&"block")
		animated_sprite.frame = BLOCK_GUARD_FRAME + 1

func _start_heavy_hit_recovery() -> void:
	state = State.HEAVY_RECOVER
	velocity.x = 0.0
	animated_sprite.scale = Vector2.ONE
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(&"heavy_hit", -HEAVY_HIT_RECOVER_SPEED, true)

func _start_sheath() -> void:
	state = State.SHEATH
	attack_step = 0
	attack_queued = false
	velocity.x = 0.0
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(&"sheath")

func _on_animation_finished() -> void:
	match state:
		State.ATTACK:
			if attack_queued and attack_step < ATTACK_ANIMATIONS.size():
				_start_attack(attack_step + 1)
			else:
				_start_sheath()
		State.SKILL:
			_fade_skill_trail()
			_start_sheath()
		State.DASH:
			state = State.IDLE
			velocity.x = 0.0
			_update_locomotion()
		State.SHEATH:
			state = State.IDLE
			attack_step = 0
			_update_locomotion()
		State.HEAVY_HIT:
			heavy_hit_slide_remaining = 0.0
			if is_instance_valid(intro_scar):
				intro_scar.progress = 1.0
			state = State.HEAVY_HOLD
			velocity.x = 0.0
			heavy_hit_hold_remaining = boss_intro_hold_duration
			heavy_hit_breath_time = 0.0
			animated_sprite.frame = 9
			animated_sprite.pause()
		State.HEAVY_RECOVER:
			animated_sprite.scale = Vector2.ONE
			state = State.IDLE
			_update_locomotion()
		State.HIT, State.BLOCK:
			state = State.IDLE
			_update_locomotion()
		State.DEFEATED:
			_fall_dead()

func _create_heavy_hit_scar() -> void:
	if is_instance_valid(intro_scar):
		intro_scar.queue_free()
	intro_scar = SWORD_SCAR.new()
	intro_scar.length = boss_intro_slide_distance
	intro_scar.direction = -facing
	get_parent().add_child(intro_scar)
	intro_scar.global_position = global_position + Vector2(0.0, -3.0)

func _spawn_dash_afterimage() -> void:
	var ghost = Sprite2D.new()
	ghost.texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	ghost.centered = animated_sprite.centered
	ghost.offset = animated_sprite.offset
	ghost.flip_h = animated_sprite.flip_h
	ghost.scale = animated_sprite.scale
	ghost.z_index = -1
	ghost.modulate = Color(0.55, 0.78, 1.0, 0.34)
	get_parent().add_child(ghost)
	ghost.global_position = animated_sprite.global_position
	_fade_effect(ghost, DASH_GHOST_LIFETIME)

func _create_skill_trail() -> void:
	_fade_skill_trail()
	skill_trail_glow = _make_skill_trail_line(22.0, Color(0.25, 0.75, 1.0, 0.22), 0)
	skill_trail = _make_skill_trail_line(6.0, Color(0.75, 0.95, 1.0, 0.9), 1)
	_record_skill_trail()

func _make_skill_trail_line(line_width: float, color: Color, layer: int) -> Line2D:
	var line = Line2D.new()
	line.width = line_width
	line.default_color = color
	line.z_index = layer
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	var width_curve = Curve.new()
	width_curve.add_point(Vector2(0.0, 0.0))
	width_curve.add_point(Vector2(0.12, 1.0))
	width_curve.add_point(Vector2(0.82, 0.8))
	width_curve.add_point(Vector2(1.0, 0.0))
	line.width_curve = width_curve
	get_parent().add_child(line)
	return line

func _record_skill_trail() -> void:
	if not is_instance_valid(skill_trail) or not is_instance_valid(skill_trail_glow):
		return
	var point = global_position + Vector2(72.0 * facing, -124.0)
	var points = skill_trail.points
	if not points.is_empty() and points[-1].distance_to(point) < 1.0:
		return
	points.append(point)
	skill_trail.points = points
	skill_trail_glow.points = points

func _fade_skill_trail() -> void:
	if is_instance_valid(skill_trail):
		_fade_effect(skill_trail, SKILL_TRAIL_LIFETIME)
	if is_instance_valid(skill_trail_glow):
		_fade_effect(skill_trail_glow, SKILL_TRAIL_LIFETIME)
	skill_trail = null
	skill_trail_glow = null

func _fade_effect(node: CanvasItem, duration: float) -> void:
	var tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.tween_callback(node.queue_free)

func _update_attack_hit() -> void:
	if attack_hit_done or (state != State.ATTACK and state != State.SKILL):
		return
	var active_frames: Dictionary = BLADE_EXTENSIONS.get(animated_sprite.animation, {})
	if not active_frames.has(animated_sprite.frame):
		return
	var boss = get_tree().get_first_node_in_group("boss")
	if not is_instance_valid(boss) or not boss.triggered or boss.health <= 0.0:
		return
	var offset = boss.global_position - global_position
	var attack_range = 280.0 if state == State.SKILL else 235.0
	if absf(offset.y) > 210.0 or offset.x * facing < -35.0 or absf(offset.x) > attack_range:
		return
	attack_hit_done = true
	var damage = SKILL_DAMAGE if state == State.SKILL else ATTACK_DAMAGE[attack_step - 1]
	boss.take_hit(damage, global_position.x)

func _update_blade_extension() -> void:
	var animation_name = animated_sprite.animation
	if not BLADE_EXTENSIONS.has(animation_name):
		blade_extension.hide()
		return
	var frame_extensions: Dictionary = BLADE_EXTENSIONS[animation_name]
	if not frame_extensions.has(animated_sprite.frame):
		blade_extension.hide()
		return
	var extension_data: Array = frame_extensions[animated_sprite.frame]
	var tip: Vector2 = extension_data[0]
	var angle: float = extension_data[1]
	var length: float = extension_data[2]
	blade_extension.show()
	blade_extension.position = Vector2((tip.x - 128.0) * facing, tip.y - 236.0)
	blade_extension.rotation = deg_to_rad(angle * facing)
	blade_extension.scale = Vector2(facing * length / 64.0, 1.0)

func _configure_animations() -> void:
	var json_text = FileAccess.get_file_as_string(ANIMATION_DATA_PATH)
	var data = JSON.parse_string(json_text)
	if not data is Dictionary:
		push_error("无法读取角色动画数据")
		return
	var sprite_frames = SpriteFrames.new()
	sprite_frames.clear_all()
	if sprite_frames.has_animation(&"default"):
		sprite_frames.remove_animation(&"default")
	for animation_name: StringName in ANIMATION_SOURCES:
		var source_name: String = ANIMATION_SOURCES[animation_name]
		var source: Dictionary = data["animations"][source_name]
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, 1000.0)
		sprite_frames.set_animation_loop(animation_name, source.get("loop", false))
		for frame_data: Dictionary in source["frames"]:
			var texture = load(FRAME_ROOT + frame_data["file"]) as Texture2D
			sprite_frames.add_frame(animation_name, texture, float(frame_data["durationMs"]))
	animated_sprite.sprite_frames = sprite_frames
