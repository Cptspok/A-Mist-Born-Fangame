class_name Projectile
extends Node3D

@export_range(0.1, 100.0, 0.1) var speed: float = 8.0
@export_range(0.1, 30.0, 0.1) var lifetime: float = 4.0
## World bodies and hurtboxes; interaction areas are excluded.
@export_flags_3d_physics var impact_mask: int = 5

var _direction := Vector3.ZERO
var _excluded: Array[RID] = []
var _age: float = 0.0
var _launched: bool = false
@onready var damage_source: DamageSourceComponent = $DamageSourceComponent


func launch(origin: Vector3, direction: Vector3, shooter: Node3D) -> void:
	damage_source.instigator = shooter
	global_position = origin
	_direction = direction.normalized()
	_excluded.clear()
	if shooter is CollisionObject3D:
		_excluded.append(shooter.get_rid())
	for node in shooter.find_children("*", "CollisionObject3D", true, false):
		_excluded.append((node as CollisionObject3D).get_rid())
	_launched = true
	if not _direction.is_zero_approx():
		look_at(origin + _direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	if not _launched or GameplayLocks.is_locked():
		return
	var travel_time := minf(delta, maxf(0.0, lifetime - _age))
	var next_position := global_position + _direction * speed * travel_time
	var query := PhysicsRayQueryParameters3D.create(global_position, next_position, impact_mask, _excluded)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		var collider := hit.collider as Node
		var hurtbox := collider as HurtboxComponent
		# A physical actor body may be slightly larger than its hurtbox.
		if hurtbox == null and collider != null:
			hurtbox = collider.get_node_or_null("HurtboxComponent") as HurtboxComponent
		if hurtbox != null:
			damage_source.apply_damage_to(hurtbox)
		_launched = false
		queue_free()
		return
	global_position = next_position
	_age += delta
	if _age >= lifetime:
		queue_free()
