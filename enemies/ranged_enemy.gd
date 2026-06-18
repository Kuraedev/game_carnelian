extends EnemyBase

## Keeps a preferred distance from the player and fires parryable projectiles on cooldown.

@export var projectile_scene: PackedScene
@export var preferred_distance := 650.0
@export var too_close := 380.0
@export var shoot_cooldown := 1.6
@export var projectile_damage := 10.0
@export var projectile_speed := 750.0

@onready var muzzle: Marker2D = $Muzzle

var _cd := 0.0
var _shooting := false
var _shoot_t := 0.0

func _enemy_physics(delta: float) -> void:
	if _cd > 0.0:
		_cd -= delta

	if player == null:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		_play("idle")
		return

	var dx := player.global_position.x - global_position.x
	facing = 1 if dx > 0.0 else -1
	var dist := absf(dx)

	if _shooting:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		_shoot_t -= delta
		if _shoot_t <= 0.0:
			_shooting = false
			_fire()
			_cd = shoot_cooldown
		return

	if dist < too_close:
		velocity.x = -facing * move_speed
		_play("walk")
	elif dist > preferred_distance:
		velocity.x = facing * move_speed
		_play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		if _cd <= 0.0:
			_shooting = true
			_shoot_t = 0.25
			_play("shoot")
		else:
			_play("idle")

func _fire() -> void:
	if projectile_scene == null or player == null:
		return
	var p := projectile_scene.instantiate()
	get_parent().add_child(p)
	p.global_position = muzzle.global_position
	var dir := (player.global_position - muzzle.global_position).normalized()
	p.setup(dir, projectile_speed, projectile_damage)

func _disable_attacks() -> void:
	_shooting = false
