extends EnemyBase

## Chases the player and performs a windup→active→recover melee swing in range.
## Its swing is parryable (parry triggers on_staggered via the base class).

@onready var hitbox: Hitbox = $Hitbox

@export var attack_range := 260.0
@export var attack_damage := 12.0
@export var attack_cooldown := 1.2
@export var windup := 0.25
@export var active := 0.18
@export var recover := 0.2

var _hitbox_offset := 180.0
var _cd := 0.0
var _attacking := false
var _phase := ""
var _t := 0.0

func _enemy_ready() -> void:
	hitbox.attacker = self
	hitbox.damage = attack_damage
	hitbox.deactivate()
	_hitbox_offset = absf(hitbox.position.x)

func _enemy_physics(delta: float) -> void:
	if _cd > 0.0:
		_cd -= delta

	if _attacking:
		_process_attack(delta)
		return

	if player == null:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		_play("idle")
		return

	var dx := player.global_position.x - global_position.x
	facing = 1 if dx > 0.0 else -1
	if absf(dx) > attack_range:
		velocity.x = facing * move_speed
		_play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		if _cd <= 0.0:
			_start_attack()
		else:
			_play("idle")

func _start_attack() -> void:
	_attacking = true
	_phase = "windup"
	_t = 0.0
	hitbox.position.x = _hitbox_offset * facing
	_play("attack")

func _process_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	_t += delta
	match _phase:
		"windup":
			if _t >= windup:
				_phase = "active"
				_t = 0.0
				hitbox.activate()
		"active":
			if _t >= active:
				_phase = "recover"
				_t = 0.0
				hitbox.deactivate()
		"recover":
			if _t >= recover:
				_attacking = false
				_cd = attack_cooldown

func _disable_attacks() -> void:
	_attacking = false
	hitbox.deactivate()
