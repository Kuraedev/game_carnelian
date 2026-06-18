extends Area2D
class_name Hurtbox

## Defensive volume tied to a Health node. Resolves incoming hits through the
## block / parry / i-frame rules and forwards damage to Health.

signal hit_taken(hitbox: Hitbox)   ## Took real damage — owner should enter HURT + i-frames.
signal parried(hitbox: Hitbox)     ## Negated a hit during the parry window.
signal blocked(hitbox: Hitbox)     ## Mitigated a hit while blocking.

@export var health_path: NodePath
## Fraction of damage still taken while blocking (0 = perfect block, 0.25 = 25% leaks through).
@export var block_damage_multiplier: float = 0.25

var health: Health
var is_invulnerable: bool = false
var is_blocking: bool = false
var is_parrying: bool = false
## +1 facing right, -1 facing left. Block/parry only work against hits from the faced side.
var facing: int = 1

func _ready() -> void:
	if health_path:
		health = get_node(health_path)

func receive_hit(hitbox: Hitbox) -> void:
	if is_invulnerable:
		return

	var from_front := _is_hit_from_front(hitbox)

	if is_parrying and from_front:
		parried.emit(hitbox)
		_notify_attacker(hitbox)
		return

	if is_blocking and from_front:
		var reduced := hitbox.damage * block_damage_multiplier
		if health and reduced > 0.0:
			health.take_damage(reduced)
		blocked.emit(hitbox)
		return

	if health:
		health.take_damage(hitbox.damage)
	hit_taken.emit(hitbox)

## True when the attacker is on the side this entity is currently facing.
func _is_hit_from_front(hitbox: Hitbox) -> bool:
	if hitbox.attacker == null:
		return true
	var dir := signf(hitbox.attacker.global_position.x - global_position.x)
	return dir == 0.0 or int(dir) == facing

## Tell the attacker it was parried (projectiles destroy themselves, melee enemies stagger).
func _notify_attacker(hitbox: Hitbox) -> void:
	var attacker := hitbox.attacker
	if attacker == null:
		return
	if attacker.has_method("on_parried"):
		attacker.on_parried()
	elif attacker.has_method("on_staggered"):
		attacker.on_staggered()
