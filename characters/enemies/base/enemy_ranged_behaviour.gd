extends Node
@export_range(0.0, 5.0, 0.1) var alert_duration := 0.45
@export_range(1.0, 100.0, 0.5) var maximum_leash_distance := 22.0
@export_range(0.5, 30.0, 0.5) var minimum_comfortable_distance := 7.0
@export_range(0.5, 100.0, 0.5) var preferred_attack_distance := 15.0
@export_range(0.5, 100.0, 0.5) var maximum_attack_distance := 20.0
@export_range(0.1, 3.0, 0.1) var reposition_duration := 0.8
@export_range(0.5, 6.0, 0.25) var reposition_step := 3.0
@export_range(0.5, 10.0, 0.5) var reposition_cooldown := 4.5
@export_range(0.5, 5.0, 0.25) var escape_retry_interval := 2.5
@export_range(0.1, 2.0, 0.1) var decision_interval := 0.5
@export var hold_position := false
@export_range(1, 10) var shots_before_reposition := 2
@onready var actor: EnemyController = get_parent()
@onready var sensing = actor.get_node("Sensing")
@onready var movement = actor.get_node("Movement")
@onready var attack = actor.get_node("RangedAttack")
@onready var agent: NavigationAgent3D = actor.get_node("NavigationOrigin/NavigationAgent3D")
var _elapsed := 0.0
var _reposition_point := Vector3.ZERO
var _last_position := Vector3.ZERO
var _stalled := 0.0
var _decision_remaining := 0.0
var _move_remaining := 0.0
var _escape_remaining := 0.0
var _shots := 0
var _side := 1.0

func _ready() -> void:
	GameplayLocks.lock_changed.connect(func(locked: bool):
		if locked: actor.velocity = Vector3.ZERO)
	attack.shot_fired.connect(func(): _shots += 1)

func _physics_process(delta: float) -> void:
	if not actor.is_active or GameplayLocks.is_locked(): return
	sensing.sample(delta)
	_decision_remaining = maxf(0.0, _decision_remaining - delta)
	_move_remaining = maxf(0.0, _move_remaining - delta)
	_escape_remaining = maxf(0.0, _escape_remaining - delta)
	var was_committed: bool = attack.is_busy()
	attack.tick(delta)
	if was_committed or attack.is_busy():
		movement.move_toward_point(actor.global_position, 0.0, delta)
		return
	var target: Node3D = sensing.target
	if not sensing.is_aware() or actor.global_position.distance_to(actor.spawn_position) > maximum_leash_distance:
		if actor.state != &"Idle": actor.set_state(&"ReturnHome")
	if actor.state == &"ReturnHome":
		var inside: bool = is_instance_valid(target) and target.global_position.distance_to(actor.spawn_position) < maximum_leash_distance * 0.9 and actor.global_position.distance_to(actor.spawn_position) < maximum_leash_distance * 0.9
		if sensing.is_aware() and inside:
			actor.set_state(&"Alert")
			_elapsed = 0.0
		else:
			movement.move_toward_point(actor.spawn_position, movement.return_speed, delta)
			if _flat_distance(actor.global_position, actor.spawn_position) < movement.home_stopping_distance: actor.set_state(&"Idle")
			return
	if actor.state == &"Idle":
		if sensing.is_aware():
			actor.set_state(&"Alert")
			_elapsed = 0.0
		movement.move_toward_point(actor.global_position, 0.0, delta)
		return
	if actor.state == &"Alert":
		_elapsed += delta
		movement.move_toward_point(actor.global_position, 0.0, delta)
		if _elapsed >= alert_duration: actor.set_state(&"Attack")
		return
	if not is_instance_valid(target): return
	# Elevated support can fire across the full 3D range without chasing off its perch.
	if hold_position:
		movement.face(target.global_position)
		if sensing.visible_target and actor.global_position.distance_to(target.global_position) <= maximum_attack_distance:
			attack.execute(target)
		movement.move_toward_point(actor.global_position, 0.0, delta)
		return
	if actor.state == &"Reposition":
		_elapsed += delta
		_stalled = _stalled + delta if actor.global_position.distance_to(_last_position) < 0.01 else 0.0
		_last_position = actor.global_position
		if _elapsed >= reposition_duration or _stalled >= 0.35 or _flat_distance(actor.global_position, _reposition_point) < 0.3:
			actor.set_state(&"Attack")
		else:
			movement.move_toward_point(_reposition_point, movement.reposition_speed, delta)
			movement.face(target.global_position)
			return
	var distance := _flat_distance(actor.global_position, target.global_position)
	var too_close := distance < minimum_comfortable_distance
	if _decision_remaining <= 0.0:
		_decision_remaining = decision_interval
		if too_close and _escape_remaining <= 0.0:
			_escape_remaining = escape_retry_interval
			if _choose_reposition(target, true):
				movement.move_toward_point(_reposition_point, movement.reposition_speed, delta)
				return
		elif not too_close and distance <= preferred_attack_distance:
			if not sensing.visible_target or (_shots >= shots_before_reposition and _move_remaining <= 0.0):
				if _choose_reposition(target, false):
					movement.move_toward_point(_reposition_point, movement.reposition_speed, delta)
					return
	# Good band: prioritize firing. Cornered/failed retreat: fire anyway.
	if sensing.visible_target and distance <= minf(maximum_attack_distance, attack.attack_range) and (distance <= preferred_attack_distance or too_close):
		actor.set_state(&"Attack")
		movement.face(target.global_position)
		attack.execute(target)
		movement.move_toward_point(actor.global_position, 0.0, delta)
	elif too_close and not sensing.visible_target:
		movement.move_toward_point(actor.global_position, 0.0, delta)
	else:
		actor.set_state(&"Chase")
		movement.move_toward_point(target.global_position, movement.chase_speed, delta)

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _choose_reposition(target: Node3D, retreat: bool) -> bool:
	var map := agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0: return false
	# NavigationAgent3D is a Node; its spatial parent owns the navigation origin.
	var navigation_position := (agent.get_parent() as Node3D).global_position
	var away := actor.global_position - target.global_position
	away.y = 0.0
	if away.is_zero_approx(): away = actor.global_basis.z
	away = away.normalized()
	var lateral := away.cross(Vector3.UP) * _side
	var directions := [away, (away + lateral).normalized(), (away - lateral).normalized()] if retreat else [lateral, -lateral, (away + lateral).normalized()]
	var start := NavigationServer3D.map_get_closest_point(map, navigation_position)
	var current_distance := _flat_distance(actor.global_position, target.global_position)
	var best_score := -INF
	var best := actor.global_position
	for direction in directions:
		var wanted: Vector3 = navigation_position + direction * reposition_step
		var point := NavigationServer3D.map_get_closest_point(map, wanted)
		if _flat_distance(point, wanted) > 1.0 or _flat_distance(point, start) < 0.7: continue
		if point.distance_to(actor.spawn_position) > maximum_leash_distance * 0.9: continue
		var distance := _flat_distance(point, target.global_position)
		if distance < current_distance + (0.65 if retreat else -0.15) or distance > preferred_attack_distance + 1.0: continue
		var path := NavigationServer3D.map_get_path(map, start, point, true)
		if path.size() < 2 or path[path.size()-1].distance_to(point) > 0.2: continue
		var length := 0.0
		for i in range(1, path.size()): length += path[i-1].distance_to(path[i])
		if length > reposition_step * 1.8: continue
		# Reject detours that initially take the actor toward the player.
		if _flat_distance(path[1], target.global_position) < current_distance - 0.3: continue
		var eye: Vector3 = point + (actor.global_position - navigation_position) + Vector3.UP * sensing.sight_height
		var query := PhysicsRayQueryParameters3D.create(eye, target.global_position + Vector3.UP * sensing.sight_height, sensing.sight_mask, [actor.get_rid()])
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
		var clear: bool = hit.is_empty() or hit.get("collider") == target
		if not retreat and not clear: continue
		var score := (2.0 if clear else 0.0) + (distance - current_distance if retreat else 0.0) - length * 0.2
		if score > best_score:
			best_score = score
			best = point
	if best_score == -INF: return false
	_reposition_point = best
	_elapsed = 0.0
	_stalled = 0.0
	_last_position = actor.global_position
	_side *= -1.0
	_move_remaining = reposition_cooldown
	_shots = 0
	actor.set_state(&"Reposition")
	return true
