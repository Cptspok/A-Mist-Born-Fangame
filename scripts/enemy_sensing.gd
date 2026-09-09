extends Node

@export_range(0.1, 100.0, 0.1) var detection_range: float = 8.0
@export_range(0.05, 5.0, 0.05) var detection_interval: float = 0.25
@export_range(0.0, 20.0, 0.1) var lost_sight_grace: float = 2.0
@export_flags_3d_physics var sight_mask: int = 1
@export var sight_height: float = 0.5

var target: Node3D
var visible_target: bool = false
var unseen_time: float = 0.0
var _remaining: float = 0.0
@onready var actor: EnemyController = get_parent()


func sample(delta: float) -> void:
	unseen_time += delta
	_remaining -= delta
	if _remaining > 0.0:
		return
	_remaining = maxf(detection_interval, 0.05)
	target = get_tree().get_first_node_in_group("player") as Node3D
	visible_target = false
	if not is_instance_valid(target):
		return
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	if health == null or health.is_dead():
		target = null
		return
	if actor.global_position.distance_squared_to(target.global_position) > detection_range * detection_range:
		return
	var offset := Vector3.UP * sight_height
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + offset, target.global_position + offset, sight_mask, [actor.get_rid()])
	query.collide_with_areas = false
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	visible_target = hit.is_empty() or hit.get("collider") == target
	if visible_target:
		unseen_time = 0.0
