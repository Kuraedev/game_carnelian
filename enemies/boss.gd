extends EnemyBase

## End-of-stage boss. Alternates a melee swing (in range) and a ranged volley (at distance),
## enrages at 50% HP (faster cooldowns), and triggers the stage-clear flow on death.

@onready var hitbox: Hitbox = $Hitbox
@onready var muzzle: Marker2D = $Muzzle

@export var projectile_scene: PackedScene
@export var melee_range := 360.0
@export var melee_damage := 18.0
@export var projectile_damage := 14.0
@export var projectile_speed := 800.0
@export var attack_cooldown := 1.8
@export var volley_count := 3

var _hitbox_offset := 260.0
var _cd := 0.0
var _busy := false
var _phase := ""
var _t := 0.0
var _enraged := false
var _volley_left := 0
var _volley_t := 0.0

func _enemy_ready() -> void:
	hitbox.attacker = self
	hitbox.damage = melee_damage
	hitbox.deactivate()
	_hitbox_offset = absf(hitbox.position.x)
	health.health_changed.connect(_on_health_changed)

func _on_health_changed(cur: float, mx: float) -> void:
	if not _enraged and cur <= mx * 0.5:
		_enraged = true
		attack_cooldown *= 0.6
		move_speed *= 1.25

func _enemy_physics(delta: float) -> void:
	if _cd > 0.0:
		_cd -= delta

	if _busy:
		_process_attack(delta)
		return

	if player == null:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		_play("idle")
		return

	var dx := player.global_position.x - global_position.x
	facing = 1 if dx > 0.0 else -1
	var dist := absf(dx)

	if _cd <= 0.0:
		if dist <= melee_range:
			_start_melee()
		else:
			_start_ranged()
	elif dist > melee_range:
		velocity.x = facing * move_speed
		_play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		_play("idle")

func _start_melee() -> void:
	_busy = true
	_phase = "m_windup"
	_t = 0.0
	hitbox.position.x = _hitbox_offset * facing
	_play("attack")

func _start_ranged() -> void:
	_busy = true
	_phase = "r_windup"
	_t = 0.0
	_volley_left = volley_count
	_volley_t = 0.0
	_play("shoot")

func _process_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	_t += delta
	match _phase:
		"m_windup":
			if _t >= 0.35:
				_phase = "m_active"
				_t = 0.0
				hitbox.activate()
		"m_active":
			if _t >= 0.2:
				_phase = "m_recover"
				_t = 0.0
				hitbox.deactivate()
		"m_recover":
			if _t >= 0.3:
				_end_attack()
		"r_windup":
			if _t >= 0.3:
				_phase = "r_fire"
				_t = 0.0
		"r_fire":
			_volley_t -= delta
			if _volley_t <= 0.0 and _volley_left > 0:
				_fire_one()
				_volley_left -= 1
				_volley_t = 0.18
			if _volley_left <= 0:
				_phase = "r_recover"
				_t = 0.0
		"r_recover":
			if _t >= 0.3:
				_end_attack()

func _end_attack() -> void:
	_busy = false
	hitbox.deactivate()
	_cd = attack_cooldown

func _fire_one() -> void:
	if projectile_scene == null:
		return
	var p := projectile_scene.instantiate()
	get_parent().add_child(p)
	p.global_position = muzzle.global_position
	var target := player.global_position if player else muzzle.global_position + Vector2(facing * 1000.0, 0)
	var dir := (target - muzzle.global_position).normalized().rotated(deg_to_rad(randf_range(-8.0, 8.0)))
	p.setup(dir, projectile_speed, projectile_damage)

func _disable_attacks() -> void:
	_busy = false
	hitbox.deactivate()

func _on_death() -> void:
	GameManager.clear_stage()
