extends AnimatedSprite2D
class_name OneShotEffect

## Fire-and-forget visual effect: plays its animation once at a spawn point, then frees.
## Spawned via the FX autoload (sprite_frames / animation are set before it enters the tree).

func _ready() -> void:
	animation_finished.connect(queue_free)
	# Safety net so a 1-frame or stuck effect can't linger forever.
	get_tree().create_timer(1.5).timeout.connect(queue_free)
	if sprite_frames:
		play(animation)
