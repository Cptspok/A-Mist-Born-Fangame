class_name PlayerController
extends CharacterBody3D

## Runtime effective speed; configure its base on StatComponent.
var move_speed: float = 10.0
signal external_motion_requested(delta: float)
@export_range(0.0, 30.0, 0.1) var jump_speed := 7.0
## Ground friction for carried momentum only; air has no automatic drag.
@export_range(0.0, 30.0, 0.1) var ground_momentum_drag := 2.0
@export_range(0.0, 30.0, 0.1) var air_control_acceleration := 4.0
var _drive := Vector3.ZERO
var _momentum := Vector3.ZERO
var _external_acceleration := Vector3.ZERO
var _was_grounded := true

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


## External systems add acceleration; the controller integrates it exactly once.
func add_external_acceleration(acceleration: Vector3) -> void:
	if acceleration.is_finite(): _external_acceleration += acceleration

func _physics_process(delta: float) -> void:
	if GameplayLocks.is_locked(): return
	var grounded := is_on_floor()
	var movement_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var desired := global_basis * Vector3(movement_input.x, 0.0, movement_input.y)
	if grounded:
		if not _was_grounded and not desired.is_zero_approx():
			# Reclassify carried running speed on landing instead of adding it twice.
			var axis := desired.normalized()
			_momentum -= axis * clampf(_momentum.dot(axis), 0.0, move_speed * desired.length())
		_drive = desired * move_speed
		_momentum.x = move_toward(_momentum.x, 0.0, ground_momentum_drag * delta)
		_momentum.z = move_toward(_momentum.z, 0.0, ground_momentum_drag * delta)
		_momentum.y = maxf(_momentum.y, 0.0)
		if Input.is_action_just_pressed(&"jump"):
			_momentum += _drive
			_drive = Vector3.ZERO
			_momentum.y += jump_speed
	else:
		# Carry the final grounded drive into flight once, including running off edges.
		_momentum += _drive
		_drive = Vector3.ZERO
		_momentum += desired * air_control_acceleration * delta
	_was_grounded = grounded
	_momentum.y -= gravity * delta
	external_motion_requested.emit(delta)
	_momentum += _external_acceleration * delta
	_external_acceleration = Vector3.ZERO
	velocity = _drive + _momentum
	move_and_slide()
	# Collision response clips both channels so blocked drive cannot become recoil.
	for index in get_slide_collision_count():
		var normal := get_slide_collision(index).get_normal()
		if _drive.dot(normal) < 0.0: _drive = _drive.slide(normal)
	_momentum = velocity - _drive

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
		_drive = Vector3.ZERO
		_momentum = Vector3.ZERO
		_external_acceleration = Vector3.ZERO


func _on_interaction_area_entered(area: Area3D) -> void:
	if area is InteractionComponent and area not in nearby_interactions:
		nearby_interactions.append(area)


func _on_interaction_area_exited(area: Area3D) -> void:
	if area is InteractionComponent:
		nearby_interactions.erase(area)

func _on_stat_changed(stat: StatIds.Stat, value: float) -> void:
	if stat == StatIds.Stat.MOVE_SPEED: move_speed = value
