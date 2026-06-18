extends Area2D
class_name Pyroplast

## Collectible currency. Enemies drop 2, bosses drop 10. On touch by the player,
## adds to GameManager and frees itself.

@export var value: int = 1
## Small upward pop + gravity when spawned, so drops scatter a little.
@export var pop_velocity := Vector2(0, -350)

var _velocity: Vector2
var _settle_time := 0.6

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_velocity = pop_velocity + Vector2(randf_range(-120, 120), 0)

func _physics_process(delta: float) -> void:
	if _settle_time > 0.0:
		_settle_time -= delta
		_velocity.y += 900.0 * delta
		position += _velocity * delta
		if _settle_time <= 0.0:
			_velocity = Vector2.ZERO

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameManager.add_pyroplasts(value)
		queue_free()
