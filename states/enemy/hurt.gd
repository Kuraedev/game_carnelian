extends State

## Brief knockback reaction when struck. Velocity is passed in via the transition message.

@export var duration := 0.15

var _t := 0.0

func enter(msg: Dictionary = {}) -> void:
	_t = duration
	actor.play("hurt")
	if msg.has("vx"):
		actor.velocity.x = msg["vx"]
	if msg.has("vy"):
		actor.velocity.y = msg["vy"]

func physics_update(delta: float) -> void:
	actor.velocity.x = move_toward(actor.velocity.x, 0.0, actor.move_speed * 2.0)
	_t -= delta
	if _t <= 0.0:
		sm.transition_to(actor.combat_state if actor.player else "idle")
