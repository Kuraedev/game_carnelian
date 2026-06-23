extends CharacterBody2D

## Player controller + combat state machine.
## Combat is driven programmatically (code hitboxes + timers) so it works before any
## attack/block/hurt sprites exist. Animations are played by name and guarded by
## has_animation(), so importing frames named per the contract below makes them appear
## with no code change:
##   attack_1, attack_2, attack_3, block, parry, hurt, death  (+ idle/walk/jump/crouch)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox

## Optional inspector-assigned stats; a default block is created if left empty.
@export var stats: PlayerStats

const JUMP_VELOCITY := -800.0

## How far in front of the player the attack hitbox sits (tune per character sprite size).
@export var hitbox_offset := 140.0

## If true, dodge always goes backward (away from facing) regardless of input — a backstep.
## If false, dodge goes in the input direction (or backward when neutral) — a roll.
@export var dodge_backwards := false

## Vertical offset (negative = up from the feet origin) of the chest — enemies aim ranged
## attacks here instead of at the ground.
@export var chest_offset := -120.0

## World point enemies should aim at (chest height, not the feet/ground).
func aim_point() -> Vector2:
	return global_position + Vector2(0, chest_offset)

# --- combat tuning ---
# Each attack lasts the length of its animation (clamped), so the swing plays fully and
# the chain reads clearly. The hitbox is live for the middle portion of that window.
const ATTACK_MIN_DUR := 0.32
const ATTACK_MAX_DUR := 2.5     ## high enough that long swings (e.g. 23-frame finishers) play fully
const ATTACK_ACTIVE_START := 0.25   ## fraction of the attack where the hitbox turns on
const ATTACK_ACTIVE_END := 0.65     ## fraction where it turns off
const ATTACK_MOVE_MULT := 0.55      ## movement speed while attacking (vs normal)
const PARRY_WINDOW := 0.15
const HURT_TIME := 0.25
const IFRAME_TIME := 0.5
const MAX_COMBO := 3
const DODGE_TIME := 0.35
const DODGE_SPEED_MULT := 1.7

enum PlayerState { NORMAL, ATTACKING, BLOCKING, DODGE, HURT, DEAD }

var state: PlayerState = PlayerState.NORMAL
var facing := -1
var combo_index := 0
var _attack_phase := ""
var _attack_dur := 0.4
var _attack_buffered := false

# Time accumulators / countdowns (deterministic, no Timer nodes needed).
var _state_time := 0.0
var _parry_time := 0.0
var _hurt_time := 0.0
var _iframe_time := 0.0
var _dodge_time := 0.0
var _dodge_dir := 1.0

func _ready() -> void:
	if stats == null:
		stats = PlayerStats.new()
	GameManager.register_player_stats(stats)
	stats.stats_changed.connect(_apply_stats)
	_apply_stats()

	hurtbox.health = health
	hurtbox.hit_taken.connect(_on_hit_taken)
	hurtbox.parried.connect(_on_parry_success)
	health.died.connect(_on_died)

	hitbox.attacker = self
	hitbox.deactivate()
	_update_facing()

func _apply_stats() -> void:
	var old_max := health.max_health
	health.set_max_health(stats.max_hp, false)
	var delta := health.max_health - old_max
	if delta > 0.0:
		health.heal(delta)
	hitbox.damage = stats.damage

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	_tick_timers(delta)

	match state:
		PlayerState.NORMAL:
			_state_normal()
		PlayerState.ATTACKING:
			_state_attacking(delta)
		PlayerState.BLOCKING:
			_state_blocking()
		PlayerState.DODGE:
			_state_dodge(delta)
		PlayerState.HURT:
			_state_hurt(delta)
		PlayerState.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, stats.move_speed)

	move_and_slide()
	_update_animation()

func _tick_timers(delta: float) -> void:
	if _parry_time > 0.0:
		_parry_time -= delta
		if _parry_time <= 0.0:
			hurtbox.is_parrying = false
	if _iframe_time > 0.0:
		_iframe_time -= delta
		if _iframe_time <= 0.0:
			hurtbox.is_invulnerable = false

# --- States -----------------------------------------------------------------

func _state_normal() -> void:
	var direction := Input.get_axis("uileft", "uiright")
	if direction != 0.0:
		velocity.x = direction * stats.move_speed
		facing = 1 if direction > 0.0 else -1
		_update_facing()
	else:
		velocity.x = move_toward(velocity.x, 0.0, stats.move_speed)

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed("attack"):
		_start_attack()
	elif Input.is_action_just_pressed("dodge") and is_on_floor():
		_start_dodge()
	elif Input.is_action_just_pressed("block") and is_on_floor():
		_start_block()

func _state_attacking(delta: float) -> void:
	# Keep mobile while attacking (at reduced speed) instead of stopping dead.
	var direction := Input.get_axis("uileft", "uiright")
	if direction != 0.0:
		velocity.x = direction * stats.move_speed * ATTACK_MOVE_MULT
		facing = 1 if direction > 0.0 else -1
		_update_facing()
	else:
		velocity.x = move_toward(velocity.x, 0.0, stats.move_speed)
	# Buffer a press during the swing so clicking (or holding) chains 1 -> 2 -> 3 in order.
	if Input.is_action_just_pressed("attack"):
		_attack_buffered = true
	_state_time += delta
	match _attack_phase:
		"windup":
			if _state_time >= _attack_dur * ATTACK_ACTIVE_START:
				_attack_phase = "active"
				hitbox.activate()
		"active":
			if _state_time >= _attack_dur * ATTACK_ACTIVE_END:
				_attack_phase = "recover"
				hitbox.deactivate()
		"recover":
			if _state_time >= _attack_dur:
				_end_attack()

func _state_blocking() -> void:
	velocity.x = move_toward(velocity.x, 0.0, stats.move_speed)
	if not Input.is_action_pressed("block"):
		_end_block()

func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, stats.move_speed)
	_hurt_time -= delta
	if _hurt_time <= 0.0:
		state = PlayerState.NORMAL

# --- Dodge (roll with i-frames) ---------------------------------------------

func _start_dodge() -> void:
	state = PlayerState.DODGE
	_dodge_time = DODGE_TIME
	hurtbox.is_invulnerable = true
	_iframe_time = DODGE_TIME
	if dodge_backwards:
		_dodge_dir = float(-facing)
	else:
		var dir := Input.get_axis("uileft", "uiright")
		_dodge_dir = signf(dir) if dir != 0.0 else float(-facing)
	_play("dodge", true)

func _state_dodge(delta: float) -> void:
	velocity.x = _dodge_dir * stats.move_speed * DODGE_SPEED_MULT
	_dodge_time -= delta
	if _dodge_time <= 0.0:
		state = PlayerState.NORMAL

# --- Attack -----------------------------------------------------------------

func _start_attack() -> void:
	state = PlayerState.ATTACKING
	combo_index = mini(combo_index + 1, MAX_COMBO)
	_attack_phase = "windup"
	_state_time = 0.0
	_attack_buffered = false
	hitbox.deactivate()
	var anim := "attack_%d" % combo_index
	# Attack lasts as long as its animation (clamped), scaled by attack_speed.
	_attack_dur = clampf(_anim_duration(anim) / maxf(0.1, stats.attack_speed), ATTACK_MIN_DUR, ATTACK_MAX_DUR)
	_play(anim, true)

func _end_attack() -> void:
	hitbox.deactivate()
	# Continue the chain (next combo step) if attack was pressed/held during the swing.
	var keep_going := (_attack_buffered or Input.is_action_pressed("attack")) and combo_index < MAX_COMBO
	_attack_buffered = false
	if keep_going:
		_start_attack()
	else:
		combo_index = 0
		state = PlayerState.NORMAL

func _anim_duration(anim: String) -> float:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		var count := sprite.sprite_frames.get_frame_count(anim)
		var speed := sprite.sprite_frames.get_animation_speed(anim)
		if count > 0 and speed > 0.0:
			return float(count) / speed
	return 0.4

# --- Block / Parry ----------------------------------------------------------

func _start_block() -> void:
	state = PlayerState.BLOCKING
	velocity.x = 0.0
	hurtbox.is_blocking = true
	hurtbox.is_parrying = true
	_parry_time = PARRY_WINDOW
	_play("block")

func _end_block() -> void:
	hurtbox.is_blocking = false
	hurtbox.is_parrying = false
	_parry_time = 0.0
	state = PlayerState.NORMAL

func _on_parry_success(_hb: Hitbox) -> void:
	# Reward a clean parry with brief invulnerability; stays in BLOCKING if still held.
	hurtbox.is_invulnerable = true
	_iframe_time = 0.2
	_play("parry", true)

# --- Damage / death ---------------------------------------------------------

func _on_hit_taken(hb: Hitbox) -> void:
	if state == PlayerState.DEAD:
		return
	state = PlayerState.HURT
	_hurt_time = HURT_TIME
	hurtbox.is_invulnerable = true
	_iframe_time = IFRAME_TIME
	hurtbox.is_blocking = false
	hurtbox.is_parrying = false

	var dir := -float(facing)
	if hb.attacker:
		var d := signf(global_position.x - hb.attacker.global_position.x)
		if d != 0.0:
			dir = d
	velocity.x = dir * hb.knockback
	velocity.y = -hb.knockback * 0.4
	_play("hurt", true)

func _on_died() -> void:
	state = PlayerState.DEAD
	velocity = Vector2.ZERO
	hurtbox.is_invulnerable = true
	hitbox.deactivate()
	_play("death", true)
	# Let the death animation play out before the death screen pauses the game.
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		await sprite.animation_finished
	GameManager.notify_player_died()

# --- Helpers ----------------------------------------------------------------

func _update_facing() -> void:
	# Original art faces left, so flip when facing right (facing > 0).
	sprite.flip_h = facing > 0
	hurtbox.facing = facing
	hitbox.position.x = hitbox_offset * facing

func _update_animation() -> void:
	if state != PlayerState.NORMAL:
		return
	if not is_on_floor():
		_play("jump")
	elif Input.is_action_pressed("uidown"):
		_play("crouch")
	elif absf(velocity.x) > 1.0:
		_play("walk")
	else:
		_play("idle")

## Play an animation by name (guarded). `restart` forces it to replay from frame 0 —
## used for one-shot moves (attack/dodge/parry/hurt/death). Looping/idle anims pass false
## so a finished non-looping anim (e.g. jump) HOLDS its last frame instead of restarting.
func _play(anim: String, restart: bool = false) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		if restart or sprite.animation != anim:
			sprite.play(anim)
