extends CharacterBody2D

enum State { DORMANT, ENTRANCE, IDLE, WALK, TRIPLE_ATTACK, JUMP, FALL_ATTACK, HIT, DEFEATED }

const FRAME_ROOT = "res://美术资源/boss序列帧/"
const ANIMATION_SOURCES = {
	&"entrance": ["帧_出场从天而降", 4, 5.0, false],
	&"idle": ["帧_站立", 4, 6.0, true],
	&"walk": ["帧_走路", 6, 10.0, true],
	&"triple_attack": ["帧_三连斩击", 8, 9.0, false],
	&"jump": ["帧_跳跃", 4, 8.0, false],
	&"fall_attack": ["帧_下落斩击", 4, 10.0, false],
	&"hit": ["帧_硬直", 4, 12.0, false]
}
const TRIPLE_HIT_FRAMES = [1, 4, 6]
const TRIPLE_DAMAGE = [14.0, 16.0, 22.0]

@export var player_path: NodePath
@export var trigger_x = 3072.0
@export var ground_y = 648.0
@export var landing_distance = 300.0
@export var fall_height = 900.0
@export var fall_duration = 0.72
@export var max_health = 300.0
@export var walk_speed = 165.0
@export var gravity = 1500.0
@export var triple_attack_range = 230.0
@export var jump_min_range = 320.0
@export var jump_max_range = 560.0
@export var jump_velocity = -560.0
@export var jump_horizontal_speed = 460.0
@export var fall_horizontal_speed = 320.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var metal_audio: AudioStreamPlayer2D = $MetalImpactAudio
@onready var dialogue: Label = $DialogueLayer/Dialogue
@onready var health_bar: ProgressBar = $DialogueLayer/BossHealthBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var player
var health = 0.0
var state: State = State.DORMANT
var facing = -1
var triggered = false
var landed = false
var entrance_animation_finished = false
var fall_attack_landed = false
var fall_animation_finished = false
var action_cooldown = 0.0
var attack_hits: Dictionary = {}

func _ready() -> void:
	player = get_node_or_null(player_path)
	add_to_group("boss")
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.hide()
	_configure_animations()
	animated_sprite.animation_changed.connect(_update_frame_offset)
	animated_sprite.frame_changed.connect(_update_frame_offset)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	dialogue.hide()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	match state:
		State.DORMANT:
			if player.global_position.x >= trigger_x:
				_start_entrance()
		State.ENTRANCE:
			return
		State.JUMP:
			velocity.x = facing * jump_horizontal_speed
			_apply_gravity(delta)
			move_and_slide()
		State.FALL_ATTACK:
			_update_fall_attack(delta)
		State.TRIPLE_ATTACK:
			velocity.x = 0.0
			_apply_gravity(delta)
			_update_triple_attack()
			move_and_slide()
		State.HIT, State.DEFEATED:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			_apply_gravity(delta)
			move_and_slide()
		State.IDLE, State.WALK:
			_update_ai(delta)
			_apply_gravity(delta)
			move_and_slide()

func _configure_animations() -> void:
	var frames = SpriteFrames.new()
	frames.clear_all()
	for animation_name: StringName in ANIMATION_SOURCES:
		var source: Array = ANIMATION_SOURCES[animation_name]
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, source[3])
		frames.set_animation_speed(animation_name, source[2])
		for frame_index in range(source[1]):
			var path = FRAME_ROOT + "%s/frame_%02d.png" % [source[0], frame_index + 1]
			frames.add_frame(animation_name, load(path) as Texture2D)
	animated_sprite.sprite_frames = frames
	animated_sprite.animation = &"idle"
	_update_frame_offset()

func _start_entrance() -> void:
	triggered = true
	state = State.ENTRANCE
	visible = true
	health_bar.show()
	position = Vector2(minf(player.global_position.x + landing_distance, 4300.0), ground_y - fall_height)
	animated_sprite.play(&"entrance")
	_update_frame_offset()
	player.begin_boss_intro()
	var fall_tween = create_tween()
	fall_tween.tween_property(self, "position:y", ground_y, fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_callback(_land)

func _land() -> void:
	landed = true
	collision_shape.set_deferred("disabled", false)
	metal_audio.play()
	player.play_boss_intro_impact(global_position.x)
	if entrance_animation_finished:
		state = State.IDLE
		animated_sprite.play(&"idle")
	await get_tree().create_timer(0.9).timeout
	_show_dialogue()

func _update_ai(delta: float) -> void:
	if player.health <= 0.0 or player.is_in_boss_intro():
		velocity.x = 0.0
		action_cooldown = maxf(action_cooldown, 0.6)
		_play_loop(&"idle")
		state = State.IDLE
		return
	_face_player()
	action_cooldown = maxf(0.0, action_cooldown - delta)
	var distance = absf(player.global_position.x - global_position.x)
	if action_cooldown <= 0.0:
		if distance <= triple_attack_range:
			_start_triple_attack()
			return
		if distance >= jump_min_range and distance <= jump_max_range:
			_start_jump_combo()
			return
	if distance > triple_attack_range * 0.85:
		state = State.WALK
		velocity.x = facing * walk_speed
		_play_loop(&"walk")
	else:
		state = State.IDLE
		velocity.x = 0.0
		_play_loop(&"idle")

func _face_player() -> void:
	var offset = player.global_position.x - global_position.x
	if is_zero_approx(offset):
		return
	facing = 1 if offset > 0.0 else -1
	animated_sprite.flip_h = facing > 0

func _play_loop(animation_name: StringName) -> void:
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)

func _start_triple_attack() -> void:
	_face_player()
	state = State.TRIPLE_ATTACK
	velocity.x = 0.0
	attack_hits.clear()
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(&"triple_attack")

func _update_triple_attack() -> void:
	var hit_index = TRIPLE_HIT_FRAMES.find(animated_sprite.frame)
	if hit_index < 0 or attack_hits.has(animated_sprite.frame):
		return
	attack_hits[animated_sprite.frame] = true
	_hit_player_forward(250.0 if hit_index == 2 else 225.0, TRIPLE_DAMAGE[hit_index])

func _start_jump_combo() -> void:
	_face_player()
	state = State.JUMP
	velocity.y = jump_velocity
	velocity.x = facing * jump_horizontal_speed
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(&"jump")

func _start_fall_attack() -> void:
	if state != State.JUMP:
		return
	state = State.FALL_ATTACK
	fall_attack_landed = false
	fall_animation_finished = false
	velocity.y = maxf(velocity.y, 120.0)
	animated_sprite.play(&"fall_attack")

func _update_fall_attack(delta: float) -> void:
	velocity.x = 0.0 if fall_attack_landed else facing * fall_horizontal_speed
	velocity.y += 2200.0 * delta
	move_and_slide()
	if is_on_floor() and not fall_attack_landed:
		fall_attack_landed = true
		velocity.x = 0.0
		_hit_player_area(320.0, 30.0)
		if fall_animation_finished:
			_finish_action()

func _hit_player_forward(attack_range: float, damage: float) -> void:
	var offset = player.global_position - global_position
	if absf(offset.y) > 190.0:
		return
	if offset.x * facing >= -30.0 and absf(offset.x) <= attack_range:
		player.take_hit(damage, global_position.x)

func _hit_player_area(attack_range: float, damage: float) -> void:
	var offset = player.global_position - global_position
	if absf(offset.x) <= attack_range and absf(offset.y) <= 210.0:
		player.take_hit(damage, global_position.x)

func take_hit(damage: float, source_x: float = 0.0) -> void:
	if state == State.DORMANT or state == State.ENTRANCE or state == State.DEFEATED:
		return
	health = maxf(0.0, health - damage)
	health_bar.value = health
	if source_x != 0.0:
		facing = 1 if source_x > global_position.x else -1
		animated_sprite.flip_h = facing > 0
		velocity.x = 120.0 if global_position.x >= source_x else -120.0
	state = State.DEFEATED if health <= 0.0 else State.HIT
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(&"hit")
	animated_sprite.frame = 0

func _finish_action() -> void:
	state = State.IDLE
	velocity.x = 0.0
	action_cooldown = 1.0
	animated_sprite.play(&"idle")

func _apply_gravity(delta: float) -> void:
	if not is_on_floor() or velocity.y < 0.0:
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"entrance":
		entrance_animation_finished = true
		if landed:
			state = State.IDLE
			animated_sprite.play(&"idle")
		return
	match state:
		State.JUMP:
			_start_fall_attack()
		State.TRIPLE_ATTACK:
			_finish_action()
		State.FALL_ATTACK:
			fall_animation_finished = true
			if fall_attack_landed:
				_finish_action()
			else:
				animated_sprite.pause()
		State.HIT:
			state = State.IDLE
			action_cooldown = 0.35
			animated_sprite.play(&"idle")
		State.DEFEATED:
			_fall_dead()

func _fall_dead() -> void:
	animated_sprite.pause()
	velocity.x = 0.0
	var fall_tween = create_tween()
	fall_tween.set_parallel(true)
	fall_tween.tween_property(animated_sprite, "rotation", -facing * PI * 0.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(animated_sprite, "modulate", Color(0.5, 0.16, 0.16, 1.0), 0.6)

func _update_frame_offset() -> void:
	if animated_sprite.sprite_frames == null:
		return
	var texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	if texture != null:
		animated_sprite.offset = Vector2(0.0, -texture.get_height() * 0.5)

func _show_dialogue() -> void:
	dialogue.modulate.a = 0.0
	dialogue.show()
	create_tween().tween_property(dialogue, "modulate:a", 1.0, 0.2)
	await get_tree().create_timer(3.2).timeout
	dialogue.hide()
