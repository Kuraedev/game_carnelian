extends Node
class_name Health

## Single source of truth for an entity's hit points.
## Attach as a child of any player/enemy/boss and wire a Hurtbox to it.

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0

var current_health: float

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

## Change the maximum (e.g. from a level-up / artifact). Optionally refill to full.
func set_max_health(value: float, refill: bool = false) -> void:
	max_health = maxf(1.0, value)
	if refill:
		current_health = max_health
	current_health = minf(current_health, max_health)
	health_changed.emit(current_health, max_health)

func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func is_alive() -> bool:
	return current_health > 0.0
