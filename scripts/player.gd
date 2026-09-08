class_name PlayerController
extends CharacterBody3D

## Horizontal movement speed in world units per second.
@export_range(0.0, 100.0, 0.1, "or_greater") var move_speed: float = 10.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var movement_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	velocity.x = movement_input.x * move_speed
	velocity.z = movement_input.y * move_speed

	move_and_slide()
