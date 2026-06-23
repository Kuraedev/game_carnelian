extends State

## Melee swing: windup -> active (hitbox live) -> recover, then back to the combat state.
## Sets the actor's attack cooldown on exit (also covers being interrupted by a parry/hit).

@export var windup := 0.25
@export var active := 0.18
@export var recover := 0.2
@export var damage := 12.0
@export var cooldown := 1.2
@export var hitbox_offset := 180.0
## Effect animation (in the actor's SpriteFrames) spawned when the swing connects.
@export var fx_anim := "attack_fx"

var _phase := ""
var _t := 0.0

func enter(_msg: Dictionary = {}) -> void:
	_phase = "windup"
	_t = 0.0
	actor.face(actor.dir_to_player())
	if actor.hitbox:
		actor.hitbox.damage = damage
		actor.hitbox.position.x = absf(hitbox_offset) * actor.facing
		actor.hitbox.deactivate()
	actor.play("attack")

func exit() -> void:
	if actor.hitbox:
		actor.hitbox.deactivate()
	actor.attack_cd = cooldown

func physics_update(delta: float) -> void:
	actor.velocity.x = move_toward(actor.velocity.x, 0.0, actor.move_speed)
	_t += delta
	match _phase:
		"windup":
			if _t >= windup:
				_phase = "active"
				if actor.hitbox:
					actor.hitbox.activate()
					FX.spawn(actor.sprite.sprite_frames, fx_anim, actor.hitbox.global_position, actor.facing > 0, absf(actor.scale.x))
		"active":
			if _t >= windup + active:
				_phase = "recover"
				if actor.hitbox:
					actor.hitbox.deactivate()
		"recover":
			if _t >= windup + active + recover:
				sm.transition_to(actor.combat_state)
