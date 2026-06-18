extends Area2D
class_name Projectile

## Straight-flying enemy projectile carrying a Hitbox. Frees on terrain, on hitting a
## hurtbox, on lifetime end, or when parried (parry destroys it).

@onready var hitbox: Hitbox = $Hitbox

@export var lifetime := 4.0

var _dir := Vector2.RIGHT
var _speed := 750.0
var _damage := 10.0

func setup(dir: Vector2, speed: float, damage: float) -> void:
	_dir = dir.normalized()
	_speed = speed
	_damage = damage

func _ready() -> void:
	hitbox.attacker = self
	hitbox.damage = _damage
	hitbox.activate()
	hitbox.area_entered.connect(_on_hitbox_area)
	body_entered.connect(_on_body_entered)
	rotation = _dir.angle()

func _physics_process(delta: float) -> void:
	position += _dir * _speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_hitbox_area(area: Area2D) -> void:
	# Hit (or got blocked by) a hurtbox — let the hit resolve this frame, then vanish.
	if area is Hurtbox:
		call_deferred("queue_free")

func _on_body_entered(_body: Node) -> void:
	# Hit terrain.
	call_deferred("queue_free")

## Called by Hurtbox when the player parries this projectile.
func on_parried() -> void:
	call_deferred("queue_free")
