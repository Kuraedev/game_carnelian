extends Resource
class_name PlayerStats

## Mutable player stat block. Level-ups and artifacts funnel through apply_modifier()
## so there is one place that drives HP / damage / speed.

signal changed

@export var max_hp: float = 100.0
@export var damage: float = 20.0
@export var move_speed: float = 600.0
## Multiplier on attack timing (windup/active/recovery). >1 = faster swings.
@export var attack_speed: float = 1.0

func apply_modifier(stat: String, amount: float) -> void:
	match stat:
		"max_hp":
			max_hp += amount
		"damage":
			damage += amount
		"move_speed":
			move_speed += amount
		"attack_speed":
			attack_speed += amount
		_:
			push_warning("PlayerStats: unknown stat '%s'" % stat)
	changed.emit()

## Returns an independent copy so a run can mutate stats without touching the saved resource.
func duplicate_stats() -> PlayerStats:
	var s := PlayerStats.new()
	s.max_hp = max_hp
	s.damage = damage
	s.move_speed = move_speed
	s.attack_speed = attack_speed
	return s
