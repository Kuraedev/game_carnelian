extends CharacterBody2D
class_name EnemyBase

## Shared enemy behaviour: gravity, Health/Hurtbox wiring, aggro detection, hurt/stagger/death,
## and loot drops (Pyroplasts + chance artifact). Melee/ranged/boss override the hooks:
##   _enemy_ready(), _enemy_physics(delta), _disable_attacks(), _on_death().

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var detection: Area2D = get_node_or_null("DetectionArea")

@export var move_speed := 220.0
@export var pyroplast_drop := 2
@export var xp_reward := 5
@export var artifact_drop_chance := 0.15
@export var pyroplast_scene: PackedScene
@export var artifact_pickup_scene: PackedScene
@export var artifact_pool: Array = []

var facing := -1
var player: Node2D = null
var _dead := false
var _iframe_time := 0.0
var _stagger_time := 0.0

func _ready() -> void:
	add_to_group("enemy")
	hurtbox.health = health
	hurtbox.hit_taken.connect(_on_hit_taken)
	health.died.connect(_on_died)
	if detection:
		detection.body_entered.connect(_on_detect_entered)
		detection.body_exited.connect(_on_detect_exited)
	_enemy_ready()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if _iframe_time > 0.0:
		_iframe_time -= delta
		if _iframe_time <= 0.0:
			hurtbox.is_invulnerable = false

	if _dead:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		move_and_slide()
		return

	if _stagger_time > 0.0:
		_stagger_time -= delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		move_and_slide()
		return

	_enemy_physics(delta)
	move_and_slide()
	_update_facing()

# --- overridable hooks ------------------------------------------------------

func _enemy_ready() -> void:
	pass

func _enemy_physics(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed)

func _disable_attacks() -> void:
	pass

func _on_death() -> void:
	pass

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
	velocity.x = dir * hb.knockback
	velocity.y = -hb.knockback * 0.3
	_play("hurt")

## Called by Hurtbox when the player parries this enemy's attack.
func on_staggered() -> void:
	if _dead:
		return
	_stagger_time = 0.6
	_disable_attacks()
	_play("hurt")

func _on_died() -> void:
	if _dead:
		return
	_dead = true
	hurtbox.is_invulnerable = true
	hurtbox.set_deferred("monitorable", false)
	_disable_attacks()
	_play("death")
	_drop_loot()
	GameManager.add_xp(xp_reward)
	_on_death()
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

# --- helpers ----------------------------------------------------------------

func _update_facing() -> void:
	if absf(velocity.x) > 1.0:
		facing = 1 if velocity.x > 0.0 else -1
	sprite.flip_h = facing > 0
	hurtbox.facing = facing

func _play(anim: String) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim or not sprite.is_playing():
			sprite.play(anim)
