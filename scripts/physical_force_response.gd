class_name PhysicalForceResponse
extends RefCounted
## Adapter boundary. Forces are submitted once per physics tick, without delta.
## Character motor integrates F/m * dt; Godot integrates RigidBody forces.
## An unsupported/null owner represents an immovable participant.

static func get_velocity(body: Node3D) -> Vector3:
	if body is RigidBody3D:
		return Vector3.ZERO if body.freeze else body.linear_velocity
	if body is CharacterBody3D: return body.velocity
	return Vector3.ZERO

static func get_effective_mass(body: Node3D) -> float:
	if body is RigidBody3D: return maxf(body.mass, 0.001)
	if is_instance_valid(body) and body.has_method("get_effective_mass"):
		return body.get_effective_mass()
	return INF

static func get_world_position(body: Node3D) -> Vector3:
	return body.global_position if is_instance_valid(body) else Vector3.ZERO

static func apply_force(body: Node3D, force: Vector3) -> Vector3:
	if not force.is_finite() or not is_instance_valid(body): return Vector3.ZERO
	if body is RigidBody3D:
		if body.freeze: return Vector3.ZERO
		var response = body.get_meta(&"physics_force_response", null)
		if is_instance_valid(response): force = response.filter_force(force)
		if not force.is_zero_approx(): body.sleeping = false
		body.apply_central_force(force)
		return force
	if body.has_method("apply_external_force"):
		body.apply_external_force(force)
		return force
	return Vector3.ZERO

static func apply_impulse(body: Node3D, impulse: Vector3) -> void:
	if not impulse.is_finite() or not is_instance_valid(body): return
	if body is RigidBody3D:
		if body.freeze: return
		var response = body.get_meta(&"physics_force_response", null)
		if is_instance_valid(response): impulse = response.filter_force(impulse)
		if not impulse.is_zero_approx(): body.sleeping = false
		body.apply_central_impulse(impulse)
	elif body.has_method("apply_external_impulse"):
		body.apply_external_impulse(impulse)
