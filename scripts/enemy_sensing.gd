extends Node

@export_range(0.1, 100.0, 0.1) var detection_range: float = 8.0
@export_range(0.05, 5.0, 0.05) var detection_interval: float = 0.25
@export_range(0.0, 20.0, 0.1) var lost_sight_grace: float = 2.0
@export_flags_3d_physics var sight_mask: int = 1
@export var sight_height: float = 0.5

@export_range(0.0, 60.0, 0.5) var ally_alert_radius := 18.0
@export_range(0.5, 20.0, 0.5) var awareness_duration := 6.0
@export_range(0.2, 5.0, 0.1) var alert_interval := 1.0
var _awareness_remaining := 0.0
var _broadcast_remaining := 0.0

var target: Node3D
var visible_target: bool = false
var unseen_time: float = 0.0
var _remaining: float = 0.0
@onready var actor: EnemyController = get_parent()


func _ready() -> void:
	add_to_group("enemy_sensors")
	actor.get_node("HurtboxComponent").attacked_by.connect(_attacked_by)
	actor.state_changed.connect(_state_changed)

func is_aware() -> bool:
	return _awareness_remaining > 0.0 and is_instance_valid(target) and not target.get_node("HealthComponent").is_dead()

func _attacked_by(instigator: Node3D) -> void:
	if instigator.is_in_group("player"):
		identify_hostile(instigator, true)

func _state_changed(state: StringName) -> void:
	if state == &"Alert" and visible_target and is_instance_valid(target): identify_hostile(target)

func identify_hostile(hostile: Node3D, urgent: bool = false) -> void:
	if not is_instance_valid(hostile) or not hostile.is_in_group("player"): return
	receive_alert(hostile)
	if (not urgent and _broadcast_remaining > 0.0) or actor.encounter_id == &"" or ally_alert_radius <= 0.0: return
	_broadcast_remaining = alert_interval
	for sensor in get_tree().get_nodes_in_group("enemy_sensors"):
		if sensor == self or not sensor.actor.is_active: continue
		if sensor.actor.encounter_id != actor.encounter_id: continue
		if actor.global_position.distance_to(sensor.actor.global_position) <= ally_alert_radius:
			sensor.receive_alert(hostile)

func receive_alert(hostile: Node3D) -> void:
	# Received knowledge does not propagate again or pretend to grant LOS.
	if not actor.is_active: return
	target = hostile
	_awareness_remaining = awareness_duration

func sample(delta: float) -> void:
	_awareness_remaining = maxf(0.0, _awareness_remaining - delta)
	_broadcast_remaining = maxf(0.0, _broadcast_remaining - delta)
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
		identify_hostile(target)
