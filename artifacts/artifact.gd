extends Resource
class_name Artifact

## Data-only artifact definition. Stat boosts are applied via GameManager.add_artifact()
## which funnels stat_modifiers into PlayerStats.
## NOTE: `icon` is intentionally left for the user's art import — until then the pickup
## shows a colored placeholder tinted by `color`.

@export var display_name: String = "Artifact"
@export var icon: Texture2D
## e.g. {"damage": 5.0, "max_hp": 25.0, "move_speed": 40.0}
@export var stat_modifiers: Dictionary = {}
## Placeholder tint used by ArtifactPickup until real icon art is imported.
@export var color: Color = Color(0.5, 0.8, 1.0)
