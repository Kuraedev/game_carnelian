extends State

## Ranged attack: windup -> fire `count` projectiles (interval apart) -> recover.
## Used by the ranged enemy (count 1) and the boss volley (count 3, with spread).

@export var windup := 0.3
@export var count := 1
@export var interval := 0.18
@export var recover := 0.3
@export var damage := 10.0
@export var speed := 750.0
@export var spread_deg := 0.0
@export var cooldown := 1.6

var _phase := ""
var _t := 0.0
var _left := 0
var _interval_t := 0.0

func enter(_msg: Dictionary = {}) -> void:
	_phase = "windup"
	_t = 0.0
	_left = count
	_interval_t = 0.0
	actor.face(actor.dir_to_player())
	actor.play("shoot")

func exit() -> void:
	actor.attack_cd = cooldown

func physics_update(delta: float) -> void:
	actor.velocity.x = move_toward(actor.velocity.x, 0.0, actor.move_speed)
	_t += delta
	match _phase:
		"windup":
			if _t >= windup:
				_phase = "fire"
		"fire":
			_interval_t -= delta
			if _interval_t <= 0.0 and _left > 0:
				_fire_one()
				_left -= 1
				_interval_t = interval
			if _left <= 0:
				_phase = "recover"
				_t = 0.0
		"recover":
			if _t >= recover:
				sm.transition_to(actor.combat_state)

func _fire_one() -> void:
	if actor.projectile_scene == null or actor.muzzle == null:
		return
	var p := actor.projectile_scene.instantiate()
	actor.get_parent().add_child(p)
	p.global_position = actor.muzzle.global_position
	var target: Vector2 = actor.player.global_position if actor.player else actor.muzzle.global_position + Vector2(actor.facing * 1000.0, 0)
	var dir := (target - actor.muzzle.global_position).normalized()
	if spread_deg > 0.0:
		dir = dir.rotated(deg_to_rad(randf_range(-spread_deg, spread_deg)))
	p.setup(dir, speed, damage)
