class_name PlayerController
extends CharacterBody3D

## Runtime effective speed; configure its base on StatComponent.
var move_speed: float = 10.0
## Locomotion target only; never a limit on externally generated velocity.
@export_range(1.0, 3.0, 0.05, "or_greater") var sprint_multiplier := 1.5
signal external_motion_requested(delta: float)
signal movement_completed(delta: float)
@export_range(0.0, 30.0, 0.1) var jump_speed := 9.9
## Horizontal convergence rate (1/second) toward ground input velocity.
## Applies equally to running and external motion; never damps airborne velocity.
@export_range(0.0, 40.0, 0.1, "or_greater") var ground_traction := 12.0
@export_range(0.0, 30.0, 0.1) var air_control_acceleration := 4.0
@export_range(0.01, 1000.0, 0.01, "or_greater") var force_response_mass := 1.0
var _external_force := Vector3.ZERO
var _ladder: ParametricLadder
enum LadderPhase { ATTACH, MOUNT_RAISE, CLIMB, EXIT_CROSS, EXIT_SETTLE }
var _ladder_phase := LadderPhase.ATTACH
var _ladder_landing := Vector3.ZERO
var _interaction_prompt: Label

@export_group("Crouch")
@export_range(0.1, 10.0, 0.1) var crouched_movement_speed := 2.5
@export_range(0.8, 1.8, 0.05) var crouched_height := 1.1
## Capsule height change in metres per second; feet stay fixed.
@export_range(0.1, 15.0, 0.1) var crouch_transition_speed := 5.0
@export_group("")
var is_crouching := false
var _standing_height: float
var _standing_center_y: float
var _origin_standing_y: float
var _capsule: CapsuleShape3D
var _clearance_sphere := SphereShape3D.new()
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var allomantic_origin: Marker3D = $AllomanticOrigin

## Radius used to find nearby interaction components.
@export_range(0.1, 10.0, 0.1, "or_greater") var interaction_radius: float = 1.75

## InputMap action used to interact with the nearest available component.
@export var interact_action: StringName = &"interact"

## Degrees of rotation per pixel of mouse movement.
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.1
@export_range(-89.0, 0.0, 1.0) var min_look_angle: float = -85.0
@export_range(0.0, 89.0, 1.0) var max_look_angle: float = 85.0
## Eye offset above the centered Player origin, not above the feet.
@export_range(0.0, 3.0, 0.05) var eye_height: float = 0.7

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var nearby_interactions: Array[InteractionComponent] = []

@onready var interaction_area: Area3D = $InteractionArea
@onready var camera_pivot: Node3D = $CameraPivot


func _ready() -> void:
	_capsule = body_shape.shape.duplicate() as CapsuleShape3D
	body_shape.shape = _capsule
	_standing_height = _capsule.height
	_standing_center_y = body_shape.position.y
	_origin_standing_y = allomantic_origin.position.y
	_clearance_sphere.radius = _capsule.radius
	var stats := $StatComponent as StatComponent
	move_speed = stats.get_value(StatIds.Stat.MOVE_SPEED)
	stats.stat_changed.connect(_on_stat_changed)
	GameplayLocks.lock_changed.connect(_on_gameplay_lock_changed)
	camera_pivot.position.y = eye_height
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var collision_shape := interaction_area.get_node("CollisionShape3D") as CollisionShape3D
	var detection_shape := collision_shape.shape as SphereShape3D
	detection_shape.radius = interaction_radius
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	_create_interaction_prompt()


## CharacterBody adapter: only this motor owns continuous-force integration.
func get_effective_mass() -> float:
	return maxf(force_response_mass, 0.001)

func apply_external_force(force: Vector3) -> void:
	if force.is_finite() and not GameplayLocks.is_locked(): _external_force += force

func apply_external_impulse(impulse: Vector3) -> void:
	if impulse.is_finite() and not GameplayLocks.is_locked():
		_ladder = null
		velocity += impulse / get_effective_mass()

func _physics_process(delta: float) -> void:
	if GameplayLocks.is_locked(): return
	if _step_ladder(delta): return
	_update_crouch(delta)
	var movement_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if $ContextualInput.wheel_open: movement_input = Vector2.ZERO
	var desired := global_basis * Vector3(movement_input.x, 0.0, movement_input.y)
	var intended_speed := crouched_movement_speed if is_crouching else move_speed * sprint_multiplier
	intended_speed *= $CombatEquipment.movement_multiplier()
	var combat_velocity: Vector3 = $CombatEquipment.movement_velocity()
	if is_on_floor():
		# One traction law for all actual horizontal motion, regardless of origin.
		# Exponential response avoids instant stops and a frame-dependent blend.
		var horizontal := Vector2(velocity.x, velocity.z)
		var ground_input_velocity := Vector2(desired.x, desired.z) * intended_speed
		ground_input_velocity += Vector2(combat_velocity.x, combat_velocity.z)
		var response := 1.0 - exp(-maxf(ground_traction, 0.0) * delta)
		horizontal = horizontal.lerp(ground_input_velocity, response)
		velocity.x = horizontal.x
		velocity.z = horizontal.y
		velocity.y = maxf(velocity.y, 0.0)
		if Input.is_action_just_pressed(&"jump") and not is_crouching and not $ContextualInput.wheel_open:
			PhysicalForceResponse.apply_impulse(self, Vector3.UP * jump_speed * $StatComponent.get_value(StatIds.Stat.JUMP_MULTIPLIER) * get_effective_mass(), true)
	else:
		_apply_air_motor(desired, intended_speed, delta)
	velocity.y -= gravity * delta
	external_motion_requested.emit(delta)
	# Applied after traction so sustained forces still produce grounded motion.
	velocity += (_external_force / get_effective_mass()) * delta
	_external_force = Vector3.ZERO
	move_and_slide()
	movement_completed.emit(delta)
	# The collision-resolved body velocity is the next frame's starting point.

func get_allomantic_origin() -> Vector3:
	return allomantic_origin.global_position

func _update_crouch(delta: float) -> void:
	var held := Input.is_action_pressed(&"crouch")
	# Keep the clearance sphere above floor contact even at the minimum height.
	var minimum_height := minf(_capsule.radius * 2.0 + 0.02, _standing_height)
	var target_height := clampf(crouched_height, minimum_height, _standing_height) if held else _standing_height
	# Check the whole remaining expansion on every tick, including mid-transition.
	if target_height > _capsule.height and not _has_standing_clearance():
		target_height = _capsule.height
	_capsule.height = move_toward(_capsule.height, target_height, crouch_transition_speed * delta)
	var height_loss := _standing_height - _capsule.height
	body_shape.position.y = _standing_center_y - height_loss * 0.5
	camera_pivot.position.y = eye_height - height_loss
	# Chest follows body height, never camera pitch or aiming direction.
	allomantic_origin.position.y = _origin_standing_y - height_loss * 0.5
	is_crouching = held or height_loss > 0.001

func _has_standing_clearance() -> bool:
	# Expanding a foot-anchored capsule adds exactly the volume swept by its
	# upper hemisphere. A full-radius sphere sweep checks that volume without
	# testing the feet against the floor. Include rigid bodies, exclude self.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _clearance_sphere
	query.transform = body_shape.global_transform
	query.transform.origin += body_shape.global_basis.y * (_capsule.height * 0.5 - _capsule.radius)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.005
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	query.motion = body_shape.global_basis.y * (_standing_height - _capsule.height)
	var sweep := space.cast_motion(query)
	if sweep[0] < 1.0: return false
	query.transform.origin += query.motion
	query.motion = Vector3.ZERO
	return space.intersect_shape(query, 1).is_empty()

## Limit the motor's proposed speed gain, not actual/external velocity.
## At excess speed, directional input can rotate or oppose momentum; it cannot
## increase its magnitude. No input leaves momentum completely untouched.
func _apply_air_motor(desired: Vector3, target_speed: float, delta: float) -> void:
	var input := Vector2(desired.x, desired.z)
	if input.is_zero_approx(): return
	var horizontal := Vector2(velocity.x, velocity.z)
	var candidate := horizontal + input * air_control_acceleration * float($CombatEquipment.movement_multiplier()) * delta
	var motor_ceiling := maxf(horizontal.length(), target_speed * input.length())
	# Keeping existing speed as the floor of this budget prevents an external
	# launch from being reduced to locomotion speed. Steering costs no extra speed.
	if candidate.length_squared() > motor_ceiling * motor_ceiling:
		candidate = candidate.normalized() * motor_ceiling
	velocity.x = candidate.x
	velocity.z = candidate.y

func _unhandled_input(event: InputEvent) -> void:
	if GameplayLocks.is_locked() or $ContextualInput.wheel_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - deg_to_rad(event.relative.y * mouse_sensitivity),
			deg_to_rad(min_look_angle), deg_to_rad(max_look_angle)
		)
	if event.is_action_pressed(interact_action):
		if is_climbing():
			_leave_ladder()
			get_viewport().set_input_as_handled()
			return
		var interaction := _get_nearest_interaction()
		if interaction != null:
			interaction.interact(self)
			get_viewport().set_input_as_handled()


func _get_nearest_interaction() -> InteractionComponent:
	var nearest: InteractionComponent
	var nearest_distance_squared := INF

	for interaction in nearby_interactions:
		if not is_instance_valid(interaction) or not interaction.can_interact_with(self):
			continue

		var distance_squared := global_position.distance_squared_to(interaction.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = interaction
			nearest_distance_squared = distance_squared

	return nearest


func _on_gameplay_lock_changed(locked: bool) -> void:
	if locked:
		if _interaction_prompt != null: _interaction_prompt.hide()
		velocity = Vector3.ZERO
		_external_force = Vector3.ZERO


func _on_interaction_area_entered(area: Area3D) -> void:
	if area is InteractionComponent and area not in nearby_interactions:
		nearby_interactions.append(area)


func _on_interaction_area_exited(area: Area3D) -> void:
	if area is InteractionComponent:
		nearby_interactions.erase(area)

func _on_stat_changed(stat: StatIds.Stat, value: float) -> void:
	if stat == StatIds.Stat.MOVE_SPEED: move_speed = value

func is_climbing() -> bool:
	return is_instance_valid(_ladder)

func begin_ladder(ladder: ParametricLadder) -> void:
	if GameplayLocks.is_locked() or not ladder.can_mount(self): return
	_ladder = ladder
	_ladder_phase = LadderPhase.MOUNT_RAISE if ladder.to_local(global_position).z < 0.0 else LadderPhase.ATTACH
	velocity = Vector3.ZERO
	_external_force = Vector3.ZERO
	$ContextualInput._cancel_context()

func _leave_ladder() -> void:
	_ladder = null
	velocity = Vector3.ZERO
	_external_force = Vector3.ZERO

## Find actual walkable support under a proposed landing using the whole capsule.
## No floor or blocked standing space means stay attached, rather than exit in air.
func _ladder_support(at: Vector3) -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.transform = body_shape.global_transform
	query.transform.origin += at - global_position
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return Vector3.INF
	var start_transform := global_transform
	start_transform.origin = at
	var contact := KinematicCollision3D.new()
	if test_move(start_transform, Vector3.DOWN * 0.65, contact) and contact.get_normal().dot(Vector3.UP) >= cos(floor_max_angle):
		return at + contact.get_travel()
	return Vector3.INF

func _step_ladder(delta: float) -> bool:
	if not is_climbing(): return false
	if $HealthComponent.is_dead():
		_leave_ladder()
		return false
	var ladder := _ladder
	if Input.is_action_just_pressed("jump") and not $ContextualInput.wheel_open:
		# F or Jump releases the grip with zero launch velocity; gravity resumes next tick.
		_leave_ladder()
		return true
	var local := ladder.to_local(global_position)
	var feet_offset := _standing_height * 0.5 - _standing_center_y
	var top := ladder.height + maxf(ladder.top_exit_height, 0.0) + feet_offset + 0.08
	# Always leave enough clearance for the capsule, including thick authored rungs.
	var face := maxf(ladder.front_offset, _capsule.radius + ladder.rung_thickness * 0.75 + 0.05)
	var axis := Input.get_axis("move_backward", "move_forward")
	if $ContextualInput.wheel_open: axis = 0.0
	var destination := Vector3(0, clampf(local.y, feet_offset, top), face)
	var speed := ladder.alignment_speed
	match _ladder_phase:
		LadderPhase.MOUNT_RAISE:
			destination = Vector3(local.x, top, local.z)
			if local.distance_to(destination) < 0.01: _ladder_phase = LadderPhase.ATTACH
		LadderPhase.ATTACH:
			if local.distance_to(destination) < 0.01: _ladder_phase = LadderPhase.CLIMB
		LadderPhase.CLIMB:
			speed = ladder.climb_speed
			destination.y = clampf(local.y + axis * speed * delta, feet_offset, top)
			if axis > 0.0 and local.y >= top - 0.01:
				var landing := ladder.to_global(Vector3(0, top, -ladder.top_exit_distance))
				_ladder_landing = _ladder_support(landing)
				if _ladder_landing.is_finite(): _ladder_phase = LadderPhase.EXIT_CROSS
			elif axis < 0.0 and local.y <= feet_offset + 0.01:
				_ladder_landing = _ladder_support(global_position + Vector3.UP * 0.02)
				if _ladder_landing.is_finite(): _ladder_phase = LadderPhase.EXIT_SETTLE
		LadderPhase.EXIT_CROSS:
			destination = Vector3(0, top, -ladder.top_exit_distance)
			if local.distance_to(destination) < 0.01:
				var support := _ladder_support(global_position)
				if support.is_finite():
					_ladder_landing = support
					_ladder_phase = LadderPhase.EXIT_SETTLE
		LadderPhase.EXIT_SETTLE:
			destination = ladder.to_local(_ladder_landing)
	var target := ladder.to_global(destination)
	velocity = (target - global_position).limit_length(speed * delta) / maxf(delta, 0.001)
	# The attached state owns locomotion, including gravity and horizontal intent.
	_external_force = Vector3.ZERO
	var saved_floor_snap := floor_snap_length
	floor_snap_length = 0.0
	move_and_slide()
	if _ladder_phase == LadderPhase.EXIT_SETTLE and global_position.distance_to(_ladder_landing) < 0.015:
		# Refresh floor contact without carrying transition velocity into locomotion.
		velocity = Vector3.DOWN * 0.1
		move_and_slide()
		if is_on_floor(): _leave_ladder()
	floor_snap_length = saved_floor_snap
	movement_completed.emit(delta)
	return true

func _create_interaction_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.name = "InteractionPromptHUD"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_interaction_prompt = Label.new()
	root.add_child(_interaction_prompt)
	_interaction_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_interaction_prompt.offset_left = -300
	_interaction_prompt.offset_right = 300
	_interaction_prompt.offset_top = -120
	_interaction_prompt.offset_bottom = -80
	_interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interaction_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	_interaction_prompt.add_theme_constant_override("shadow_offset_x", 2)
	_interaction_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_interaction_prompt.hide()

func _process(_delta: float) -> void:
	if _interaction_prompt == null: return
	_interaction_prompt.hide()
	if GameplayLocks.is_locked() or $HealthComponent.is_dead() or $ContextualInput.wheel_open: return
	var action_label := InputHint.binding(interact_action)
	if is_climbing():
		_interaction_prompt.text = "%s - Release | %s / %s - Climb" % [action_label, InputHint.binding("move_forward"), InputHint.binding("move_backward")]
	else:
		var interaction := _get_nearest_interaction()
		if interaction == null: return
		_interaction_prompt.text = action_label + " - " + interaction.interaction_prompt
	_interaction_prompt.show()
