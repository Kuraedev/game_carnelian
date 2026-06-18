extends Area2D
class_name Hitbox

## Offensive volume. Disabled by default — call activate() during an attack's active frames
## and deactivate() afterwards.
##
## Collision layer/mask convention (see project.godot [layer_names]):
##   - Player attacks: layer = player_hitbox (6),  mask = enemy_hurtbox (5)
##   - Enemy attacks:  layer = enemy_hitbox (7),   mask = player_hurtbox (4)
## So a Hitbox only ever overlaps the opposing Hurtbox.

@export var damage: float = 10.0
@export var knockback: float = 200.0
## The entity performing the attack (CharacterBody2D / projectile). Defaults to the parent.
## Used for knockback direction and parry callbacks (on_parried / on_staggered).
@export var attacker_path: NodePath

var attacker: Node2D
var _already_hit: Array[Node] = []

func _ready() -> void:
	attacker = get_node(attacker_path) if attacker_path else get_parent() as Node2D
	monitoring = false
	area_entered.connect(_on_area_entered)

## Enable the hitbox for one attack swing. Each Hurtbox is only struck once per activation.
func activate() -> void:
	_already_hit.clear()
	monitoring = true
	# Catch hurtboxes already overlapping at the moment of activation.
	call_deferred("_scan_overlaps")

func deactivate() -> void:
	monitoring = false

func _scan_overlaps() -> void:
	if not monitoring:
		return
	for area in get_overlapping_areas():
		_on_area_entered(area)

func _on_area_entered(area: Area2D) -> void:
	if not monitoring:
		return
	if area is Hurtbox and not _already_hit.has(area):
		_already_hit.append(area)
		(area as Hurtbox).receive_hit(self)
