class_name AllomancyPhysicalResponse
extends Node

enum Mode { FREE, DIRECTIONAL }
@export var mode: Mode = Mode.FREE
@export_node_path("RigidBody3D") var body_path: NodePath = NodePath("..")
@export var preferred_local_axis := Vector3.FORWARD
@export_range(0.0, 1.0, 0.01) var lateral_response := 0.15
var body: RigidBody3D

func _ready() -> void:
	body = get_node_or_null(body_path) as RigidBody3D
	if body != null: body.set_meta(&"physics_force_response", self)

func _exit_tree() -> void:
	if is_instance_valid(body) and body.get_meta(&"physics_force_response", null) == self:
		body.remove_meta(&"physics_force_response")

func filter_force(force: Vector3) -> Vector3:
	if body == null or body.freeze: return Vector3.ZERO
	var adjusted := force
	if mode == Mode.DIRECTIONAL and not preferred_local_axis.is_zero_approx():
		var axis := (body.global_basis * preferred_local_axis).normalized()
		var parallel := axis * force.dot(axis)
		adjusted = parallel + (force - parallel) * lateral_response
	return adjusted
