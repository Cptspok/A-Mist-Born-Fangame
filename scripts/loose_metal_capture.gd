extends Marker3D
## One swept movement owner during manipulation; dynamic physics outside it.
enum Phase { FREE, APPROACH, HELD }
@export var show_loose_metal_capture_debug := true
@export_range(1.5, 3.5, 0.1) var held_distance := 2.2
@export_range(-0.8, 0.3, 0.05) var held_vertical_offset := -0.3
@export_range(2.0, 40.0, 0.5) var pull_travel_speed := 18.0
@export_range(4.0, 24.0, 0.5) var follow_responsiveness := 16.0
@export_range(30.0, 150.0, 1.0) var captured_throw_speed := 90.0
const MINIMUM_PITCH := -35.0
const MAXIMUM_PITCH := 55.0
const MAXIMUM_MASS := 2.0
const MAXIMUM_RADIUS := 0.65
var phase := Phase.FREE
var tether: MetalTetherComponent
var _body: RigidBody3D
var _player: PlayerController
var _saved_freeze_mode := RigidBody3D.FREEZE_MODE_STATIC
var _saved_can_sleep := true
var _reference := Vector3.ZERO
var _goal := Vector3.ZERO
var _step_velocity := Vector3.ZERO
var _step_target := Vector3.ZERO
var _separation_limit := 5.0
var _blocked_time := 0.0

func eligible(candidate: MetalTetherComponent) -> bool:
	if not is_instance_valid(candidate) or not candidate.is_available() or not candidate.capture_enabled: return false
	if candidate.allomancy_class != AllomancyTuning.ResponseClass.LIGHT: return false
	var body := candidate.get_physical_owner() as RigidBody3D
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion(): return false
	if (body.freeze and body != _body) or body.custom_integrator or body.mass > MAXIMUM_MASS: return false
	if not body.has_method("set_manipulation_active"): return false
	var ancestor: Node = body
	while ancestor != null:
		if ancestor is CharacterBody3D or ancestor.get_node_or_null("HealthComponent") != null: return false
		ancestor = ancestor.get_parent()
	var radius := _body_radius(body)
	return radius > 0.0 and radius <= MAXIMUM_RADIUS

func _body_radius(body: RigidBody3D) -> float:
	var radius := 0.0
	for child in body.get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.disabled or collision.shape == null: continue
		var bounds: AABB = collision.shape.get_debug_mesh().get_aabb()
		for index in range(8):
			radius = maxf(radius, body.global_position.distance_to(collision.to_global(bounds.get_endpoint(index))))
	return radius

func _aim_basis() -> Basis:
	var pitch := clampf(_player.camera_pivot.rotation.x, deg_to_rad(MINIMUM_PITCH), deg_to_rad(MAXIMUM_PITCH))
	return _player.global_basis * Basis(Vector3.RIGHT, pitch)

func controlled_launch_axis() -> Vector3:
	return -_aim_basis().z.normalized()

func _hold_position() -> Vector3:
	var camera := _player.get_node("CameraPivot/Camera3D") as Camera3D
	return camera.global_position + _aim_basis() * Vector3(0.0, held_vertical_offset, -held_distance)

func try_capture(candidate: MetalTetherComponent, player: PlayerController) -> bool:
	if phase != Phase.FREE or not eligible(candidate): return false
	# Targeting already enforces acquisition range/visibility. Eligible loose
	# Pull takes ownership immediately; no close-range or height gate remains.
	tether = candidate
	_body = candidate.get_physical_owner() as RigidBody3D
	_player = player
	_goal = _hold_position()
	_reference = candidate.get_force_position()
	_step_target = _reference
	_step_velocity = Vector3.ZERO
	_separation_limit = maxf(5.0, _reference.distance_to(player.get_allomantic_origin()) + 1.0)
	_blocked_time = 0.0
	_saved_freeze_mode = _body.freeze_mode
	_saved_can_sleep = _body.can_sleep
	_body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_body.freeze = true
	_body.can_sleep = false
	_body.set_manipulation_active(true, player)
	_body.tree_exiting.connect(release, CONNECT_ONE_SHOT)
	phase = Phase.APPROACH
	return true

func follow(player: PlayerController, dt: float) -> bool:
	if phase == Phase.FREE: return false
	if not eligible(tether) or not is_instance_valid(_body) or tether.get_physical_owner() != _body:
		release()
		return false
	var center := tether.get_force_position()
	if center.distance_to(player.get_allomantic_origin()) > _separation_limit or _blocked_time > 0.5:
		release()
		return false
	_goal = _hold_position()
	var smoothing := 1.0 - exp(-follow_responsiveness * dt)
	if phase == Phase.APPROACH:
		# Every displacement is collinear with current COM -> current capture
		# point. No spline, incoming tangent, gravity or force affects the path.
		_reference = center.move_toward(_goal, pull_travel_speed * dt)
	else:
		_reference = center.lerp(_goal, smoothing)
	# This is the ONLY physical movement during control. Actual swept movement,
	# not a test followed by a second, competing dynamic integration pass.
	var hit := _body.move_and_collide(_reference - center, false, 0.001)
	var after := tether.get_force_position()
	_step_velocity = (after - center) / dt
	_step_target = after
	var blocked := hit != null and hit.get_remainder().length() > 0.001
	_blocked_time = _blocked_time + dt if blocked else 0.0
	if phase == Phase.APPROACH and not blocked and after.distance_to(_goal) < 0.001:
		phase = Phase.HELD
	return true

func release() -> void:
	if is_instance_valid(_body):
		if _body.tree_exiting.is_connected(release): _body.tree_exiting.disconnect(release)
		_body.set_manipulation_active(false)
		_body.freeze = false
		_body.freeze_mode = _saved_freeze_mode
		# Captured movement is exclusively authored/kinematic. Its velocity is
		# controller motion, not world momentum. Never resurrect incoming motion
		# or infer hidden "free" histories for an authored Pull/hold.
		_body.linear_velocity = Vector3.ZERO
		_body.angular_velocity = Vector3.ZERO
		_body.can_sleep = _saved_can_sleep
		_body.sleeping = false
	tether = null
	_body = null
	_player = null
	phase = Phase.FREE

func phase_name() -> String:
	return Phase.keys()[phase]

func debug_snapshot() -> Dictionary:
	if not is_instance_valid(tether): return {}
	return {"state": phase_name(), "com": tether.get_force_position(),
		"reference": _reference, "reference_ready": true, "hold": _goal,
		"axis": controlled_launch_axis(), "blocked": _blocked_time,
		"step_target": _step_target, "command_velocity": _step_velocity}

func _exit_tree() -> void:
	release()
