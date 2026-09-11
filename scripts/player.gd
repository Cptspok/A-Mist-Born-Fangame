class_name PlayerController
extends CharacterBody3D

## Runtime effective speed; configure its base on StatComponent.
var move_speed: float = 10.0
## Locomotion target only; never a limit on externally generated velocity.
@export_range(1.0, 3.0, 0.05, "or_greater") var sprint_multiplier := 1.5
signal external_motion_requested(delta: float)
@export_range(0.0, 30.0, 0.1) var jump_speed := 9.9
## Horizontal convergence rate (1/second) toward ground input velocity.
## Applies equally to running and external motion; never damps airborne velocity.
@export_range(0.0, 40.0, 0.1, "or_greater") var ground_traction := 12.0
@export_range(0.0, 30.0, 0.1) var air_control_acceleration := 4.0
@export_range(0.01, 1000.0, 0.01, "or_greater") var force_response_mass := 1.0
var _external_force := Vector3.ZERO

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


## CharacterBody adapter: only this motor owns continuous-force integration.
func get_effective_mass() -> float:
	return maxf(force_response_mass, 0.001)

func apply_external_force(force: Vector3) -> void:
	if force.is_finite() and not GameplayLocks.is_locked(): _external_force += force

func apply_external_impulse(impulse: Vector3) -> void:
	if impulse.is_finite() and not GameplayLocks.is_locked():
		velocity += impulse / get_effective_mass()

func _physics_process(delta: float) -> void:
	if GameplayLocks.is_locked(): return
	var movement_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var desired := global_basis * Vector3(movement_input.x, 0.0, movement_input.y)
	var intended_speed := move_speed
	if Input.is_action_pressed(&"sprint") and not movement_input.is_zero_approx():
		intended_speed *= sprint_multiplier
	if is_on_floor():
		# One traction law for all actual horizontal motion, regardless of origin.
		# Exponential response avoids instant stops and a frame-dependent blend.
		var horizontal := Vector2(velocity.x, velocity.z)
		var ground_input_velocity := Vector2(desired.x, desired.z) * intended_speed
		var response := 1.0 - exp(-maxf(ground_traction, 0.0) * delta)
		horizontal = horizontal.lerp(ground_input_velocity, response)
		velocity.x = horizontal.x
		velocity.z = horizontal.y
		velocity.y = maxf(velocity.y, 0.0)
		if Input.is_action_just_pressed(&"jump"):
			PhysicalForceResponse.apply_impulse(self, Vector3.UP * jump_speed * get_effective_mass())
	else:
		_apply_air_motor(desired, intended_speed, delta)
	velocity.y -= gravity * delta
	external_motion_requested.emit(delta)
	# Applied after traction so sustained forces still produce grounded motion.
	velocity += (_external_force / get_effective_mass()) * delta
	_external_force = Vector3.ZERO
	move_and_slide()
	# The collision-resolved body velocity is the next frame's starting point.

## Limit the motor's proposed speed gain, not actual/external velocity.
## At excess speed, directional input can rotate or oppose momentum; it cannot
## increase its magnitude. No input leaves momentum completely untouched.
func _apply_air_motor(desired: Vector3, target_speed: float, delta: float) -> void:
	var input := Vector2(desired.x, desired.z)
	if input.is_zero_approx(): return
	var horizontal := Vector2(velocity.x, velocity.z)
	var candidate := horizontal + input * air_control_acceleration * delta
	var motor_ceiling := maxf(horizontal.length(), target_speed * input.length())
	# Keeping existing speed as the floor of this budget prevents an external
	# launch from being reduced to locomotion speed. Steering costs no extra speed.
	if candidate.length_squared() > motor_ceiling * motor_ceiling:
		candidate = candidate.normalized() * motor_ceiling
	velocity.x = candidate.x
	velocity.z = candidate.y

func _unhandled_input(event: InputEvent) -> void:
	if GameplayLocks.is_locked():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - deg_to_rad(event.relative.y * mouse_sensitivity),
			deg_to_rad(min_look_angle), deg_to_rad(max_look_angle)
		)
	if event.is_action_pressed(interact_action):
		var interaction := _get_nearest_interaction()
		if interaction != null:
			interaction.interact(self)
			get_viewport().set_input_as_handled()


func _get_nearest_interaction() -> InteractionComponent:
	var nearest: InteractionComponent
	var nearest_distance_squared := INF

	for interaction in nearby_interactions:
		if not is_instance_valid(interaction) or not interaction.can_interact():
			continue

		var distance_squared := global_position.distance_squared_to(interaction.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = interaction
			nearest_distance_squared = distance_squared

	return nearest


func _on_gameplay_lock_changed(locked: bool) -> void:
	if locked:
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
