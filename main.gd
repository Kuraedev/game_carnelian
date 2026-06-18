extends Node2D

## Stage root. Wires the fall/kill zone to the player's Health so falling out of the
## level is lethal (which routes through the normal death flow + HUD death panel).

@onready var kill_zone: Area2D = $KillZone

func _ready() -> void:
	kill_zone.body_entered.connect(_on_kill_zone_entered)

func _on_kill_zone_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var hp: Health = body.get_node_or_null("Health")
		if hp:
			hp.take_damage(hp.max_health * 2.0)
