extends CharacterBody2D
class_name EnemyBase

## Enemy actor. Generic concerns live here (gravity, Health/Hurtbox, aggro detection, hurt
## knockback, loot/XP, death). Behaviour is driven by a child StateMachine whose State nodes
## call the helpers below. Melee/ranged/boss differ only by which states their scene contains.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var detection: Area2D = get_node_or_null("DetectionArea")
@onready var hitbox: Hitbox = get_node_or_null("Hitbox")
@onready var muzzle: Marker2D = get_node_or_null("Muzzle")
@onready var state_machine: StateMachine = get_node_or_null("StateMachine")

@export var move_speed := 220.0
@export var pyroplast_drop := 2
@export var xp_reward := 5
@export var artifact_drop_chance := 0.15
@export var pyroplast_scene: PackedScene
@export var artifact_pickup_scene: PackedScene
@export var artifact_pool: Array = []
@export var projectile_scene: PackedScene
## State entered when the player is first detected ("position" for normal enemies, "decide" for the boss).
@export var combat_state := "position"
## Boss sets this so its death ends the stage.
@export var triggers_stage_clear := false

var facing := -1
var player: Node2D = null
var attack_cd := 0.0
var _dead := false
var _iframe_time := 0.0

func _ready() -> void:
	add_to_group("enemy")
	hurtbox.health = health
	hurtbox.hit_taken.connect(_on_hit_taken)
	health.died.connect(_on_died)
	if hitbox:
		hitbox.attacker = self
		hitbox.deactivate()
	if detection:
		detection.body_entered.connect(_on_detect_entered)
		detection.body_exited.connect(_on_detect_exited)
	if state_machine:
		state_machine.setup(self)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if _iframe_time > 0.0:
		_iframe_time -= delta
		if _iframe_time <= 0.0:
			hurtbox.is_invulnerable = false
	if attack_cd > 0.0:
		attack_cd -= delta
	if state_machine:
		state_machine.physics_update(delta)
	move_and_slide()
	_update_facing()

# --- helpers used by states -------------------------------------------------

func play(anim: String) -> void:
	# Only (re)start when the animation actually changes, so a finished non-looping anim
	# (attack/hurt/death) holds its last frame instead of restarting every frame.
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim:
			sprite.play(anim)

func face(dir: int) -> void:
	if dir != 0:
		facing = dir

func dir_to_player() -> int:
	if player == null:
		return facing
	return 1 if player.global_position.x > global_position.x else -1

func distance_to_player() -> float:
	if player == null:
		return INF
	return absf(player.global_position.x - global_position.x)

func _update_facing() -> void:
	sprite.flip_h = facing > 0
	hurtbox.facing = facing

# --- detection --------------------------------------------------------------

func _on_detect_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body

func _on_detect_exited(body: Node) -> void:
	if body == player:
		player = null

# --- damage / stagger / death ----------------------------------------------

func _on_hit_taken(hb: Hitbox) -> void:
	if _dead:
		return
	hurtbox.is_invulnerable = true
	_iframe_time = 0.18
	var dir := -float(facing)
	if hb.attacker:
		var d := signf(global_position.x - hb.attacker.global_position.x)
		if d != 0.0:
			dir = d
	if state_machine and state_machine.states.has("hurt"):
		state_machine.transition_to("hurt", {"vx": dir * hb.knockback, "vy": -hb.knockback * 0.3})
	else:
		velocity.x = dir * hb.knockback
		velocity.y = -hb.knockback * 0.3
		play("hurt")

## Called by the Hurtbox when the player parries this enemy's attack.
func on_staggered() -> void:
	if _dead:
		return
	if state_machine and state_machine.states.has("stagger"):
		state_machine.transition_to("stagger")

func _on_died() -> void:
	if _dead:
		return
	_dead = true
	hurtbox.is_invulnerable = true
	hurtbox.set_deferred("monitorable", false)
	if state_machine and state_machine.states.has("dead"):
		state_machine.transition_to("dead")
	else:
		play("death")
	_drop_loot()
	GameManager.add_xp(xp_reward)
	if triggers_stage_clear:
		# Let the boss death animation finish before ending the stage; leave the boss
		# on screen (frozen on its last frame) under the stage-clear screen.
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
			await sprite.animation_finished
		GameManager.clear_stage()
		return
	await get_tree().create_timer(0.6).timeout
	queue_free()

func _drop_loot() -> void:
	var parent := get_parent()
	if pyroplast_scene and parent:
		for i in pyroplast_drop:
			var p := pyroplast_scene.instantiate()
			parent.add_child(p)
			p.global_position = global_position
	if artifact_pickup_scene and parent and not artifact_pool.is_empty() \
			and randf() < artifact_drop_chance:
		var a := artifact_pickup_scene.instantiate()
		a.artifact = artifact_pool.pick_random()
		parent.add_child(a)
		a.global_position = global_position
