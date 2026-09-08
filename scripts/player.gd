class_name PlayerController
extends CharacterBody3D

## Horizontal movement speed in world units per second.
@export_range(0.0, 100.0, 0.1, "or_greater") var move_speed: float = 10.0

## Radius used to find nearby interaction components.
@export_range(0.1, 10.0, 0.1, "or_greater") var interaction_radius: float = 1.75

## InputMap action used to interact with the nearest available component.
@export var interact_action: StringName = &"interact"

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var nearby_interactions: Array[InteractionComponent] = []

@onready var interaction_area: Area3D = $InteractionArea


func _ready() -> void:
	var collision_shape := interaction_area.get_node("CollisionShape3D") as CollisionShape3D
	var detection_shape := collision_shape.shape as SphereShape3D
	detection_shape.radius = interaction_radius
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var movement_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	velocity.x = movement_input.x * move_speed
	velocity.z = movement_input.y * move_speed

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
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


func _on_interaction_area_entered(area: Area3D) -> void:
	if area is InteractionComponent and area not in nearby_interactions:
		nearby_interactions.append(area)


func _on_interaction_area_exited(area: Area3D) -> void:
	if area is InteractionComponent:
		nearby_interactions.erase(area)
