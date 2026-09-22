extends CommittedEnemyAttack
@export_range(0.1, 10.0, 0.1) var attack_range := 1.8
@export_range(5.0, 90.0, 1.0) var strike_half_angle := 50.0
@onready var source: DamageSourceComponent = $DamageSourceComponent
## Opt-in volume keeps legacy enemies unchanged. Configuration is never mutated.
@export var use_hit_volume := false
@export var hit_volume_size := Vector3(0.65, 0.8, 1.5)
@export var hit_volume_offset := Vector3(0, 0, -0.9)
@export var horizontal_sweep := false
var _hit_victims: Array[int] = []
var _volume: BoxShape3D

func tick(delta: float) -> void:
	super.tick(delta)
	if use_hit_volume and phase == Phase.STRIKE:
		_sample_volume()

func _sample_volume() -> void:
	if _volume == null:
		_volume = BoxShape3D.new()
		_volume.size = hit_volume_size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _volume
	query.transform = Transform3D(actor.global_basis, actor.to_global(hit_volume_offset))
	query.collision_mask = DamageSourceComponent.HURTBOX_COLLISION_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in actor.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var hurtbox := hit.collider as HurtboxComponent
		if hurtbox == null or not hurtbox.get_parent().is_in_group("player"): continue
		if hurtbox.get_instance_id() in _hit_victims: continue
		var ray := PhysicsRayQueryParameters3D.create(actor.global_position, hurtbox.global_position, 1, [actor.get_rid()])
		var obstruction := actor.get_world_3d().direct_space_state.intersect_ray(ray)
		if not obstruction.is_empty() and obstruction.get("collider") != hurtbox.get_parent(): continue
		_hit_victims.append(hurtbox.get_instance_id())
		source.instigator = actor
		source.apply_damage_to(hurtbox)

func _pose() -> void:
	super._pose()
	if not horizontal_sweep or not is_instance_valid(_equipment): return
	var sweep := 1.1
	match phase:
		Phase.IDLE: sweep = 0.0
		Phase.WINDUP: sweep = lerpf(0.0, 1.1, clampf(elapsed / windup_duration, 0.0, 1.0))
		Phase.STRIKE: sweep = lerpf(1.1, -1.1, clampf(elapsed / strike_duration, 0.0, 1.0))
		Phase.RECOVERY: sweep = lerpf(-1.1, 0.0, clampf(elapsed / recovery_duration, 0.0, 1.0))
	# Prototype horizontal weapon arc; the broad volume is active for the whole strike.
	_equipment.rotation = _rest_rotation + Vector3(0, sweep, -1.35 if phase != Phase.IDLE else 0.0)
	_equipment.position = _rest_position + Vector3(sin(sweep) * 0.6, 0.1, -cos(sweep) * 0.7)

func execute(victim: Node3D) -> bool:
	if not is_instance_valid(victim) or actor.global_position.distance_to(victim.global_position) > attack_range: return false
	return begin(victim)

func resolve_strike() -> void:
	if use_hit_volume:
		_hit_victims.clear()
		_sample_volume()
		return
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
