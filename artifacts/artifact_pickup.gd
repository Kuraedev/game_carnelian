extends Area2D
class_name ArtifactPickup

## World pickup that grants an Artifact's stat modifiers on touch.
## Visual is a placeholder until art is imported (see _ready).

@export var artifact: Artifact

@onready var placeholder: Polygon2D = $Placeholder
@onready var icon_sprite: Sprite2D = $Icon

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if artifact == null:
		return
	# TODO: swap placeholder for imported artifact art.
	if artifact.icon:
		icon_sprite.texture = artifact.icon
		placeholder.visible = false
	else:
		placeholder.color = artifact.color

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and artifact:
		GameManager.add_artifact(artifact)
		queue_free()
