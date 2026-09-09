class_name PlayerController
extends CharacterBody3D

## Horizontal movement speed in world units per second.
@export_range(0.0, 100.0, 0.1, "or_greater") var move_speed: float = 10.0

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
	GameplayLocks.lock_changed.connect(_on_gameplay_lock_changed)
	camera_pivot.position.y = eye_height
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var collision_shape := interaction_area.get_node("CollisionShape3D") as CollisionShape3D
	var detection_shape := collision_shape.shape as SphereShape3D
	detection_shape.radius = interaction_radius
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)


func _physics_process(delta: float) -> void:
	# Yield locomotion ownership to future cinematic/scripted controllers.
	if GameplayLocks.is_locked():
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var movement_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var movement_direction := global_transform.basis * Vector3(movement_input.x, 0.0, movement_input.y)
	velocity.x = movement_direction.x * move_speed
	velocity.z = movement_direction.z * move_speed

	move_and_slide()


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


func _on_interaction_area_entered(area: Area3D) -> void:
	if area is InteractionComponent and area not in nearby_interactions:
		nearby_interactions.append(area)


func _on_interaction_area_exited(area: Area3D) -> void:
	if area is InteractionComponent:
		nearby_interactions.erase(area)
