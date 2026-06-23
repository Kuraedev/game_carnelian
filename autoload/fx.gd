extends Node

## Spawns fire-and-forget visual effects into the current scene. Effect frames live as
## extra animations inside the character/enemy SpriteFrames, so an attack just calls:
##   FX.spawn(sprite.sprite_frames, "attack_fx", world_pos, facing > 0, 1.0)

const ONE_SHOT: PackedScene = preload("res://effects/one_shot_effect.tscn")

func spawn(frames: SpriteFrames, anim: String, pos: Vector2, flip: bool = false, scl: float = 1.0) -> void:
	if frames == null or not frames.has_animation(anim):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var e := ONE_SHOT.instantiate()
	e.sprite_frames = frames
	e.animation = StringName(anim)
	e.flip_h = flip
	e.scale = Vector2(scl, scl)
	scene.add_child(e)
	e.global_position = pos
