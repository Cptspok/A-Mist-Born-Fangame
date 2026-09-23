extends CombatItemRuntime
## Shared melee capability. Resources are read only; all state lives here.
signal attack_presented(hook: StringName)
signal hit_confirmed(hurtbox: HurtboxComponent)
enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY, RAISING, BLOCKING, GUARD_BROKEN }
var phase := Phase.IDLE
var _elapsed := 0.0
var _index := -1
var _idle_time := 0.0
var _buffer := 0.0
var _block_held := false
var _rate := 1.0
var _attack: WeaponAttackDefinition
var _moveset: WeaponMoveset
var _data: MeleeWeaponDefinition
var _stats: StatComponent
var _excluded: Array[RID] = []
var _damaged: Array[HealthComponent] = []
var _rest_rotation: Vector3
var _rest_position: Vector3
var _feedback := 0.0
@onready var source: DamageSourceComponent = $DamageSourceComponent
@onready var presentation: Node3D = $Presentation
@onready var combat: PlayerCombat = wielder.get_node("CombatEquipment")

func _ready() -> void:
	_data = definition as MeleeWeaponDefinition
	if _data == null:
		set_physics_process(false)
		return
	_moveset = _data.moveset
	# Compatibility for older melee items without an authored sequence.
	if _moveset == null:
		_moveset = WeaponMoveset.new()
		var fallback := WeaponAttackDefinition.new()
		fallback.reach = _data.attack_reach
		fallback.coverage = Vector2(_data.hit_width, _data.hit_width)
		fallback.recovery = maxf(0.01, _data.attack_cooldown - fallback.windup - fallback.active_duration)
		_moveset.attacks.append(fallback)
	source.instigator = wielder
	_stats = wielder.get_node_or_null("StatComponent") as StatComponent
	if wielder is CollisionObject3D: _excluded.append(wielder.get_rid())
	for node in wielder.find_children("*", "CollisionObject3D", true, false):
		_excluded.append((node as CollisionObject3D).get_rid())
	_rest_rotation = presentation.rotation
	_rest_position = presentation.position
	if item_definition != null and item_definition.world_visual != null:
		presentation.add_child(item_definition.world_visual.instantiate())

func handle_action(action: StringName, pressed: bool) -> void:
	if not active or GameplayLocks.is_locked(): return
	if action == &"secondary_action":
		_block_held = pressed and _data.can_block
		if not pressed and phase in [Phase.RAISING, Phase.BLOCKING]: _set_phase(Phase.IDLE)
		if _block_held: _buffer = 0.0
	elif action == &"primary_action" and pressed:
		if phase == Phase.IDLE and not _block_held:
			_start_attack()
		elif phase in [Phase.WINDUP, Phase.ACTIVE, Phase.RECOVERY] and not _block_held:
			_buffer = _moveset.buffer_duration

func _set_phase(value: Phase) -> void:
	phase = value
	_elapsed = 0.0

func _start_attack() -> void:
	if combat.commitment_remaining > 0.0 or _moveset.attacks.is_empty(): return
	if _idle_time >= _moveset.sequence_reset: _index = -1
	_index = (_index + 1) % _moveset.attacks.size()
	_attack = _moveset.attacks[_index]
	if _attack == null: return
	_rate = maxf(0.1, _stats.get_value(StatIds.Stat.ATTACK_SPEED) if _stats != null else 1.0)
	combat.commitment_remaining = (_attack.windup + _attack.active_duration + _attack.recovery) / _rate
	source.damage_amount = (_data.damage + (_stats.get_value(StatIds.Stat.PHYSICAL_DAMAGE) if _stats != null else 0.0)) * _attack.damage_multiplier
	source.block_pressure = _attack.block_pressure
	_damaged.clear()
	_buffer = 0.0
	_idle_time = 0.0
	_set_phase(Phase.WINDUP)
	attack_presented.emit(_attack.presentation_hook)

func _physics_process(delta: float) -> void:
	if not active or GameplayLocks.is_locked(): return
	_feedback = maxf(0.0, _feedback - delta)
	_buffer = maxf(0.0, _buffer - delta)
	_elapsed += delta
	match phase:
		Phase.IDLE:
			_idle_time += delta
			if _block_held and combat.commitment_remaining <= 0.0: _set_phase(Phase.RAISING)
			elif _buffer > 0.0: _start_attack()
		Phase.WINDUP:
			if _elapsed >= maxf(0.01, _attack.windup) / _rate:
				_set_phase(Phase.ACTIVE)
				_sample_hit(0.0)
		Phase.ACTIVE:
			_sample_hit(clampf(_elapsed * _rate / maxf(0.01, _attack.active_duration), 0.0, 1.0))
			if _elapsed >= maxf(0.01, _attack.active_duration) / _rate: _set_phase(Phase.RECOVERY)
		Phase.RECOVERY:
			if _elapsed >= maxf(0.01, _attack.recovery) / _rate:
				_set_phase(Phase.IDLE)
				if _block_held: _set_phase(Phase.RAISING)
				elif _buffer > 0.0: _start_attack()
		Phase.RAISING:
			if _elapsed >= _data.block_raise_time: _set_phase(Phase.BLOCKING)
		Phase.GUARD_BROKEN:
			if _elapsed >= _data.guard_break_recovery: _set_phase(Phase.IDLE)
	_pose()

func movement_multiplier() -> float:
	if phase in [Phase.WINDUP, Phase.ACTIVE, Phase.RECOVERY]: return _attack.movement_multiplier
	if phase in [Phase.RAISING, Phase.BLOCKING, Phase.GUARD_BROKEN]: return _data.block_movement_multiplier
	return 1.0

func movement_velocity() -> Vector3:
	return -wielder.global_basis.z * _attack.forward_speed if phase == Phase.ACTIVE else Vector3.ZERO

func defend_damage(amount: float, origin: Vector3, pressure: float) -> float:
	if not active or phase != Phase.BLOCKING or GameplayLocks.is_locked(): return amount
	var toward := origin - wielder.global_position
	toward.y = 0.0
	var forward := -aim.global_basis.z
	forward.y = 0.0
	if toward.is_zero_approx() or forward.normalized().dot(toward.normalized()) < cos(deg_to_rad(_data.block_angle * 0.5)): return amount
	_feedback = 0.14
	var strength := maxf(0.01, _data.block_strength)
	if pressure > strength:
		_set_phase(Phase.GUARD_BROKEN)
		_index = -1
		combat.commitment_remaining = maxf(combat.commitment_remaining, _data.guard_break_recovery)
		PhysicalForceResponse.apply_impulse(wielder, -toward.normalized() * minf(8.0, (pressure - strength) * 0.15))
		return amount * maxf(_data.blocked_damage_multiplier, 1.0 - strength / pressure)
	return amount * _data.blocked_damage_multiplier

func _sample_hit(progress: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(0.05, _attack.coverage.x), maxf(0.05, _attack.coverage.y), maxf(0.1, _attack.reach))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = aim.global_transform
	query.transform.basis = query.transform.basis * Basis(Vector3.UP, deg_to_rad(lerpf(_attack.sweep_start, _attack.sweep_end, progress)))
	query.transform.origin -= query.transform.basis.z * _attack.reach * 0.5
	query.collision_mask = HurtboxComponent.HURTBOX_COLLISION_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = _excluded
	var space := get_world_3d().direct_space_state
	for hit in space.intersect_shape(query, 64):
		var hurtbox := hit.collider as HurtboxComponent
		if hurtbox == null: continue
		var health := hurtbox.get_health_component()
		if health == null or health.is_dead() or health in _damaged: continue
		var sight := PhysicsRayQueryParameters3D.create(aim.global_position, hurtbox.global_position, 1, _excluded)
		var obstruction := space.intersect_ray(sight)
		if not obstruction.is_empty() and obstruction.get("collider") != hurtbox.get_parent(): continue
		_damaged.append(health)
		if source.apply_damage_to(hurtbox) <= 0.0: continue
		_feedback = 0.13
		hit_confirmed.emit(hurtbox)
		_impact_flash(hurtbox.global_position + (aim.global_position - hurtbox.global_position).normalized() * (hurtbox.capsule_radius + 0.12))
		var impulse := _attack.impact + (_stats.get_value(StatIds.Stat.MELEE_IMPULSE) if _stats != null else 0.0)
		PhysicalForceResponse.apply_impulse(hurtbox.get_parent() as Node3D, -aim.global_basis.z * impulse)

func _pose() -> void:
	var offset := Vector3.ZERO
	match phase:
		Phase.WINDUP: offset = _attack.windup_pose * clampf(_elapsed * _rate / maxf(0.01, _attack.windup), 0.0, 1.0)
		Phase.ACTIVE: offset = _attack.windup_pose.lerp(_attack.strike_pose, clampf(_elapsed * _rate / maxf(0.01, _attack.active_duration), 0.0, 1.0))
		Phase.RECOVERY: offset = _attack.strike_pose * (1.0 - clampf(_elapsed * _rate / maxf(0.01, _attack.recovery), 0.0, 1.0))
		Phase.RAISING: offset = Vector3(0.1, 0.0, 1.2) * clampf(_elapsed / _data.block_raise_time, 0.0, 1.0)
		Phase.BLOCKING: offset = Vector3(0.1, 0.0, 1.2)
		Phase.GUARD_BROKEN: offset = Vector3(0.8, 0.0, -0.8)
	presentation.rotation = _rest_rotation + offset
	presentation.position = _rest_position + Vector3(0, 0, _feedback * 0.9)

func _impact_flash(at: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.8, 0.35)
	mesh.material = material
	flash.mesh = mesh
	get_tree().current_scene.add_child(flash)
	flash.global_position = at
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 0.05, 0.14)
	tween.tween_callback(flash.queue_free)

func cancel_action() -> void:
	# Shared commitment survives context/slot changes; cancellation cannot speed attacks.
	_set_phase(Phase.IDLE)
	_index = -1
	_buffer = 0.0
	_block_held = false
	_feedback = 0.0
	if is_instance_valid(presentation):
		presentation.rotation = _rest_rotation
		presentation.position = _rest_position
