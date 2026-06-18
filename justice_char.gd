extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D

const SPEED = 600.0
const JUMP_VELOCITY = -800.0

func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction = Input.get_axis("uileft", "uiright")
	if direction:
		velocity.x = direction * SPEED
		sprite.flip_h = direction > 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_update_animation()

func _update_animation():
	if not is_on_floor():
		sprite.play("jump")
	elif Input.is_action_pressed("uidown"):
		sprite.play("crouch")
	elif velocity.x != 0:
		sprite.play("walk")
	else:
		sprite.play("idle")
		
