extends CommittedEnemyAttack
@export_range(0.1, 10.0, 0.1) var attack_range := 1.8
@export_range(5.0, 90.0, 1.0) var strike_half_angle := 50.0
@onready var source: DamageSourceComponent = $DamageSourceComponent

func execute(victim: Node3D) -> bool:
	if not is_instance_valid(victim) or actor.global_position.distance_to(victim.global_position) > attack_range: return false
	return begin(victim)

func resolve_strike() -> void:
	if not is_instance_valid(target): return
	var offset := target.global_position - actor.global_position
	if offset.length() > attack_range: return
	var flat := Vector3(offset.x, 0, offset.z)
	if not flat.is_zero_approx() and committed_forward.dot(flat.normalized()) < cos(deg_to_rad(strike_half_angle)): return
	var query := PhysicsRayQueryParameters3D.create(actor.global_position, target.global_position, 1, [actor.get_rid()])
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.get("collider") != target: return
	var hurtbox := target.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox != null:
		source.instigator = actor
		source.apply_damage_to(hurtbox)
