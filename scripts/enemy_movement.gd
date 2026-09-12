extends Node

@export var chase_speed: float = 3.0
@export var return_speed: float = 2.5
@export var reposition_speed: float = 2.0
@export_range(0.05, 1.0, 0.05) var home_stopping_distance: float = 0.2
@onready var actor: EnemyController = get_parent()
@onready var agent: NavigationAgent3D = get_parent().get_node("NavigationOrigin/NavigationAgent3D")
@export_range(0.1, 2.0, 0.05) var target_refresh_interval: float = 0.25
@export_range(0.05, 2.0, 0.05) var minimum_target_movement: float = 0.3
var _refresh_remaining: float = 0.0
var _last_destination: Vector3
var _has_destination: bool = false


func move_toward_point(point: Vector3, speed: float, delta: float) -> void:
	if not actor.is_active:
		actor.velocity = Vector3.ZERO
		return
	_refresh_remaining -= delta
	var direction := Vector3.ZERO
	var map := agent.get_navigation_map()
	if speed > 0.0 and NavigationServer3D.map_get_iteration_id(map) > 0:
		if not _has_destination or (_refresh_remaining <= 0.0 and (point.distance_to(_last_destination) >= minimum_target_movement or agent.is_navigation_finished())):
			_last_destination = point
			_has_destination = true
			_refresh_remaining = target_refresh_interval
			agent.target_position = NavigationServer3D.map_get_closest_point(map, point)
		var next_point := agent.get_next_path_position()
		if not agent.is_navigation_finished():
			direction = next_point - actor.global_position
			direction.y = 0.0
	else:
		_has_destination = false
	# Limit the step to avoid oscillating across the destination.
	var step_speed := minf(maxf(speed, 0.0), direction.length() / maxf(delta, 0.001))
	direction = direction.normalized()
	actor.velocity.x = direction.x * step_speed
	actor.velocity.z = direction.z * step_speed
	if direction.length_squared() > 0.001:
		face(actor.global_position + direction)
	if actor.is_on_floor():
		actor.velocity.y = 0.0
	else:
		actor.velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	actor.move_with_external_forces(delta)


func face(point: Vector3) -> void:
	var flat_point := Vector3(point.x, actor.global_position.y, point.z)
	if actor.global_position.distance_squared_to(flat_point) > 0.001:
		actor.look_at(flat_point, Vector3.UP)
