extends State

## Move to keep the player within a preferred distance band, then trigger an attack.
## Melee uses min_dist=0 (close in and swing). Ranged uses a band (back off if too close,
## approach if too far, fire when inside the band).

@export var min_dist := 0.0
@export var max_dist := 260.0
@export var attack_state := "attack"

func physics_update(_delta: float) -> void:
	if actor.player == null:
		sm.transition_to("idle")
		return
	actor.face(actor.dir_to_player())
	var dist := actor.distance_to_player()
	if dist > max_dist:
		actor.velocity.x = actor.facing * actor.move_speed
		actor.play("walk")
	elif dist < min_dist:
		actor.velocity.x = -actor.facing * actor.move_speed
		actor.play("walk")
	else:
		actor.velocity.x = move_toward(actor.velocity.x, 0.0, actor.move_speed)
		if actor.attack_cd <= 0.0:
			sm.transition_to(attack_state)
		else:
			actor.play("idle")
