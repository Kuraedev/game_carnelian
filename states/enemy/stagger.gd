extends State

## Stunned after the player parries this enemy's attack. Can't act for `duration`.

@export var duration := 0.6

var _t := 0.0

func enter(_msg: Dictionary = {}) -> void:
	_t = duration
	actor.play("hurt")

func physics_update(delta: float) -> void:
	actor.velocity.x = move_toward(actor.velocity.x, 0.0, actor.move_speed)
	_t -= delta
	if _t <= 0.0:
		sm.transition_to(actor.combat_state if actor.player else "idle")
