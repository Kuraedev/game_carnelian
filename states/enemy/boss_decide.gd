extends State

## Boss combat brain: when off cooldown, swing melee if the player is close, else fire a
## ranged volley. While on cooldown it repositions toward the player.

@export var melee_range := 360.0
@export var attack_state := "attack"
@export var ranged_state := "shoot"

func physics_update(_delta: float) -> void:
	if actor.player == null:
		sm.transition_to("idle")
		return
	actor.face(actor.dir_to_player())
	var dist := actor.distance_to_player()
	if actor.attack_cd <= 0.0:
		if dist <= melee_range:
			sm.transition_to(attack_state)
		else:
			sm.transition_to(ranged_state)
	elif dist > melee_range:
		actor.velocity.x = actor.facing * actor.move_speed
		actor.play("walk")
	else:
		actor.velocity.x = move_toward(actor.velocity.x, 0.0, actor.move_speed)
		actor.play("idle")
