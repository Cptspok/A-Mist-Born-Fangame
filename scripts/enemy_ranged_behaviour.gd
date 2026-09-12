extends Node

@export_range(0.0, 5.0, 0.1) var alert_duration: float = 0.7
@export_range(1.0, 100.0, 0.5) var maximum_leash_distance: float = 12.0
@export_range(0.5, 30.0, 0.5) var minimum_comfortable_distance: float = 4.0
@export_range(0.5, 30.0, 0.5) var preferred_attack_distance: float = 7.0
@export_range(0.5, 30.0, 0.5) var maximum_attack_distance: float = 10.0
@export_range(0.1, 5.0, 0.1) var reposition_duration: float = 1.5
@export_range(5.0, 90.0, 5.0) var reposition_angle: float = 25.0

@onready var actor: EnemyController = get_parent()
@onready var sensing = actor.get_node("Sensing")
@onready var movement = actor.get_node("Movement")
@onready var attack = actor.get_node("RangedAttack")
var _elapsed: float = 0.0
var _reposition_point: Vector3
var _side: float = 1.0


func _ready() -> void:
	GameplayLocks.lock_changed.connect(_on_lock_changed)


func _on_lock_changed(locked: bool) -> void:
	if locked:
		actor.velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not actor.is_active or GameplayLocks.is_locked():
		return
	sensing.sample(delta)
	var was_committed: bool = attack.is_busy()
	attack.tick(delta)
	if was_committed or attack.is_busy():
		movement.move_toward_point(actor.global_position, 0.0, delta)
		return
	var target: Node3D = sensing.target
	if actor.state not in [&"Idle", &"ReturnHome"]:
		if not is_instance_valid(target) or sensing.unseen_time > sensing.lost_sight_grace or actor.global_position.distance_to(actor.spawn_position) > maximum_leash_distance:
			actor.set_state(&"ReturnHome")
	var destination := actor.global_position
	var speed: float = 0.0
	match actor.state:
		&"Idle":
			if sensing.visible_target and is_instance_valid(target):
				_elapsed = 0.0
				actor.set_state(&"Alert")
		&"Alert":
			_elapsed += delta
			if _elapsed >= alert_duration:
				actor.set_state(&"Chase")
		&"Chase":
			var distance := actor.global_position.distance_to(target.global_position)
			if distance < minimum_comfortable_distance:
				_begin_reposition(target)
			elif sensing.visible_target and distance <= minf(preferred_attack_distance, maximum_attack_distance):
				actor.set_state(&"Attack")
			else:
				destination = target.global_position
				speed = movement.chase_speed
		&"Attack":
			var distance := actor.global_position.distance_to(target.global_position)
			if not sensing.visible_target or distance > maximum_attack_distance:
				actor.set_state(&"Chase")
			elif distance < minimum_comfortable_distance:
				_begin_reposition(target)
			else:
				movement.face(target.global_position)
				if attack.execute(target):
					_begin_reposition(target)
		&"Reposition":
			_elapsed += delta
			destination = _reposition_point
			speed = movement.reposition_speed
			var offset := destination - actor.global_position
			offset.y = 0.0
			if _elapsed >= reposition_duration or offset.length() < 0.3:
				actor.set_state(&"Attack")
		&"ReturnHome":
			destination = actor.spawn_position
			speed = movement.return_speed
			var reengage_distance := maximum_leash_distance * 0.9
			if sensing.visible_target and is_instance_valid(target) and actor.global_position.distance_to(actor.spawn_position) <= reengage_distance and target.global_position.distance_to(actor.spawn_position) <= reengage_distance:
				_elapsed = 0.0
				speed = 0.0
				actor.set_state(&"Alert")
			var offset := actor.global_position - actor.spawn_position
			offset.y = 0.0
			if actor.state == &"ReturnHome" and offset.length() <= movement.home_stopping_distance:
				speed = 0.0
				actor.set_state(&"Idle")
	if is_instance_valid(target) and actor.state not in [&"Idle", &"ReturnHome"]:
		movement.face(target.global_position)
	movement.move_toward_point(destination, speed, delta)


func _begin_reposition(target: Node3D) -> void:
	var radial := actor.global_position - target.global_position
	radial.y = 0.0
	if radial.length_squared() < 0.001:
		radial = actor.global_basis.z
	_reposition_point = target.global_position + radial.normalized().rotated(Vector3.UP, deg_to_rad(reposition_angle * _side)) * preferred_attack_distance
	_reposition_point.y = actor.global_position.y
	_side *= -1.0
	_elapsed = 0.0
	actor.set_state(&"Reposition")
