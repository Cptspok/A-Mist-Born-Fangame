extends Node

@export_range(0.0, 5.0, 0.1) var alert_duration: float = 0.6
@export_range(1.0, 100.0, 0.5) var maximum_leash_distance: float = 12.0
@export_range(0.1, 10.0, 0.1) var preferred_engagement_distance: float = 1.4
@export_range(0.05, 2.0, 0.05) var engagement_hysteresis: float = 0.3
@export_range(0.1, 5.0, 0.1) var reposition_duration: float = 0.9
@export_range(5.0, 90.0, 5.0) var reposition_angle: float = 45.0
@export var persistent_close_pressure := false

@onready var actor: EnemyController = get_parent()
@onready var sensing = actor.get_node("Sensing")
@onready var movement = actor.get_node("Movement")
@onready var attack = actor.get_node("MeleeAttack")
var _elapsed: float = 0.0
var _reposition_offset: Vector3


func _ready() -> void:
	GameplayLocks.lock_changed.connect(_on_gameplay_lock_changed)


func _on_gameplay_lock_changed(locked: bool) -> void:
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
		if not is_instance_valid(target) or not sensing.is_aware() or actor.global_position.distance_to(actor.spawn_position) > maximum_leash_distance:
			actor.set_state(&"ReturnHome")
	var destination := actor.global_position
	var speed: float = 0.0
	match actor.state:
		&"Idle":
			if sensing.is_aware() and is_instance_valid(target):
				_elapsed = 0.0
				actor.set_state(&"Alert")
		&"Alert":
			_elapsed += delta
			if _elapsed >= alert_duration:
				actor.set_state(&"Chase")
		&"Chase":
			destination = target.global_position
			speed = movement.chase_speed
			if actor.global_position.distance_to(destination) <= attack.attack_range:
				speed = 0.0
				actor.set_state(&"Attack")
		&"Attack":
			# Close small gaps inside the hysteresis band while cooldown runs.
			if actor.global_position.distance_to(target.global_position) > (preferred_engagement_distance if persistent_close_pressure else attack.attack_range):
				destination = target.global_position
				speed = movement.chase_speed
			if actor.global_position.distance_to(target.global_position) > attack.attack_range + engagement_hysteresis:
				actor.set_state(&"Chase")
			elif sensing.visible_target and attack.execute(target):
				var radial := actor.global_position - target.global_position
				radial.y = 0.0
				if radial.length_squared() < 0.001:
					radial = actor.global_basis.z
				_reposition_offset = radial.normalized().rotated(Vector3.UP, deg_to_rad(reposition_angle)) * minf(preferred_engagement_distance, attack.attack_range)
				_elapsed = 0.0
				actor.set_state(&"Attack" if persistent_close_pressure else &"Reposition")
		&"Reposition":
			_elapsed += delta
			destination = target.global_position + _reposition_offset
			speed = movement.reposition_speed
			if _elapsed >= reposition_duration or actor.global_position.distance_to(destination) < 0.2:
				actor.set_state(&"Attack")
		&"ReturnHome":
			destination = actor.spawn_position
			speed = movement.return_speed
			# Re-enter inside the same leash, with a margin to avoid boundary churn.
			# The target must also be inside so an outside target cannot lure us
			# straight back across the leash after every alert.
			var reengage_distance := maximum_leash_distance * 0.9
			if sensing.is_aware() and is_instance_valid(target) and actor.global_position.distance_to(actor.spawn_position) <= reengage_distance and target.global_position.distance_to(actor.spawn_position) <= reengage_distance:
				_elapsed = 0.0
				speed = 0.0
				actor.set_state(&"Alert")
			var offset := actor.global_position - actor.spawn_position
			offset.y = 0.0
			if actor.state == &"ReturnHome" and offset.length() <= movement.home_stopping_distance:
				speed = 0.0
				actor.set_state(&"Idle")
	if actor.state not in [&"Idle", &"ReturnHome"] and is_instance_valid(target):
		movement.face(target.global_position)
	elif speed > 0.0:
		movement.face(destination)
	movement.move_toward_point(destination, speed, delta)
