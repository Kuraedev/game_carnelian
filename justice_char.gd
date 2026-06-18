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
const HITBOX_OFFSET := 220.0

# --- combat tuning (seconds; windup/active/recover scale with stats.attack_speed) ---
const COMBO_WINDOW := 0.45
const ATTACK_WINDUP := 0.08
const ATTACK_ACTIVE := 0.14
const ATTACK_RECOVER := 0.18
const PARRY_WINDOW := 0.15
const HURT_TIME := 0.25
const IFRAME_TIME := 0.5
const MAX_COMBO := 3

enum State { NORMAL, ATTACKING, BLOCKING, HURT, DEAD }

var state: State = State.NORMAL
var facing := -1
var combo_index := 0
var _attack_phase := ""

# Time accumulators / countdowns (deterministic, no Timer nodes needed).
var _state_time := 0.0
var _combo_time := 0.0
var _parry_time := 0.0
var _hurt_time := 0.0
var _iframe_time := 0.0

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
		State.NORMAL:
			_state_normal()
		State.ATTACKING:
			_state_attacking(delta)
		State.BLOCKING:
			_state_blocking()
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, stats.move_speed)

	move_and_slide()
	_update_animation()

func _tick_timers(delta: float) -> void:
	if _combo_time > 0.0:
		_combo_time -= delta
		if _combo_time <= 0.0:
			combo_index = 0
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
	elif Input.is_action_just_pressed("block") and is_on_floor():
		_start_block()

func _state_attacking(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, stats.move_speed)
	_state_time += delta
	var spd := maxf(0.1, stats.attack_speed)
	match _attack_phase:
		"windup":
			if _state_time >= ATTACK_WINDUP / spd:
				_attack_phase = "active"
				_state_time = 0.0
				hitbox.activate()
		"active":
			if _state_time >= ATTACK_ACTIVE / spd:
				_attack_phase = "recover"
				_state_time = 0.0
				hitbox.deactivate()
		"recover":
			if _state_time >= ATTACK_RECOVER / spd:
				_end_attack()

func _state_blocking() -> void:
	velocity.x = move_toward(velocity.x, 0.0, stats.move_speed)
	if not Input.is_action_pressed("block"):
		_end_block()

func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, stats.move_speed)
	_hurt_time -= delta
	if _hurt_time <= 0.0:
		state = State.NORMAL

# --- Attack -----------------------------------------------------------------

func _start_attack() -> void:
	state = State.ATTACKING
	combo_index = mini(combo_index + 1, MAX_COMBO)
	_attack_phase = "windup"
	_state_time = 0.0
	velocity.x = 0.0
	hitbox.deactivate()
	_play("attack_%d" % combo_index)

func _end_attack() -> void:
	hitbox.deactivate()
	if combo_index >= MAX_COMBO:
		combo_index = 0
		_combo_time = 0.0
	else:
		_combo_time = COMBO_WINDOW
	state = State.NORMAL

# --- Block / Parry ----------------------------------------------------------

func _start_block() -> void:
	state = State.BLOCKING
	velocity.x = 0.0
	hurtbox.is_blocking = true
	hurtbox.is_parrying = true
	_parry_time = PARRY_WINDOW
	_play("block")

func _end_block() -> void:
	hurtbox.is_blocking = false
	hurtbox.is_parrying = false
	_parry_time = 0.0
	state = State.NORMAL

func _on_parry_success(_hb: Hitbox) -> void:
	# Reward a clean parry with brief invulnerability; stays in BLOCKING if still held.
	hurtbox.is_invulnerable = true
	_iframe_time = 0.2
	_play("parry")

# --- Damage / death ---------------------------------------------------------

func _on_hit_taken(hb: Hitbox) -> void:
	if state == State.DEAD:
		return
	state = State.HURT
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
	_play("hurt")

func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	hurtbox.is_invulnerable = true
	hitbox.deactivate()
	_play("death")
	GameManager.notify_player_died()

# --- Helpers ----------------------------------------------------------------

func _update_facing() -> void:
	# Original art faces left, so flip when facing right (facing > 0).
	sprite.flip_h = facing > 0
	hurtbox.facing = facing
	hitbox.position.x = HITBOX_OFFSET * facing

func _update_animation() -> void:
	if state != State.NORMAL:
		return
	if not is_on_floor():
		_play("jump")
	elif Input.is_action_pressed("uidown"):
		_play("crouch")
	elif absf(velocity.x) > 1.0:
		_play("walk")
	else:
		_play("idle")

func _play(anim: String) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim or not sprite.is_playing():
			sprite.play(anim)
