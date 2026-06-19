extends State

## Terminal state: stop moving and play the death animation. The actor (EnemyBase) handles
## loot drops, XP, and freeing itself on a timer after entering this state.

func enter(_msg: Dictionary = {}) -> void:
	actor.velocity.x = 0.0
	actor.play("death")

func physics_update(_delta: float) -> void:
	actor.velocity.x = move_toward(actor.velocity.x, 0.0, actor.move_speed)
