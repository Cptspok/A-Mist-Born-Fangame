extends Node

@export var chase_speed: float = 3.0
@export var return_speed: float = 2.5
@export var reposition_speed: float = 2.0
@export_range(0.05, 1.0, 0.05) var home_stopping_distance: float = 0.2
@onready var actor: EnemyController = get_parent()


func move_toward_point(point: Vector3, speed: float, delta: float) -> void:
	var direction := point - actor.global_position
	direction.y = 0.0
	# Limit the step to avoid oscillating across the destination.
	var step_speed := minf(maxf(speed, 0.0), direction.length() / maxf(delta, 0.001))
	direction = direction.normalized()
	actor.velocity.x = direction.x * step_speed
	actor.velocity.z = direction.z * step_speed
	if actor.is_on_floor():
		actor.velocity.y = 0.0
	else:
		actor.velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	actor.move_and_slide()


func face(point: Vector3) -> void:
	var flat_point := Vector3(point.x, actor.global_position.y, point.z)
	if actor.global_position.distance_squared_to(flat_point) > 0.001:
		actor.look_at(flat_point, Vector3.UP)
