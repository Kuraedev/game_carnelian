extends State

## Stand still until a player is detected, then hand off to the actor's combat state.

func enter(_msg: Dictionary = {}) -> void:
	actor.play("idle")

func physics_update(_delta: float) -> void:
	actor.velocity.x = move_toward(actor.velocity.x, 0.0, actor.move_speed)
	if actor.player != null:
		sm.transition_to(actor.combat_state)
