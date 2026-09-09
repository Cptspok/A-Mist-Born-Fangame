extends CombatItemRuntime

var _cooldown: float = 0.0
var _excluded: Array[RID] = []
@onready var source: DamageSourceComponent = $DamageSourceComponent
@onready var presentation: Node3D = $Presentation


func _ready() -> void:
	if wielder is CollisionObject3D:
		_excluded.append(wielder.get_rid())
	for node in wielder.find_children("*", "CollisionObject3D", true, false):
		_excluded.append((node as CollisionObject3D).get_rid())


func _physics_process(delta: float) -> void:
	if not GameplayLocks.is_locked():
		_cooldown = maxf(0.0, _cooldown - delta)


func handle_action(action: StringName, pressed: bool) -> void:
	if action != &"primary_action" or not pressed or not active or GameplayLocks.is_locked() or _cooldown > 0.0:
		return
	var data := definition as MeleeWeaponDefinition
	if data == null:
		return
	_cooldown = data.attack_cooldown
	source.damage_amount = data.damage
	presentation.call("swing")
	var shape := BoxShape3D.new()
	shape.size = Vector3(data.hit_width, data.hit_width, data.attack_reach)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = aim.global_transform
	query.transform.origin -= aim.global_basis.z * data.attack_reach * 0.5
	query.collision_mask = HurtboxComponent.HURTBOX_COLLISION_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = _excluded
	var damaged: Array[HealthComponent] = []
	var space := get_world_3d().direct_space_state
	for hit in space.intersect_shape(query, 32):
		var hurtbox := hit.collider as HurtboxComponent
		if hurtbox == null:
			continue
		var health := hurtbox.get_health_component()
		if health == null or health.is_dead() or health in damaged:
			continue
		var sight := PhysicsRayQueryParameters3D.create(aim.global_position, hurtbox.global_position, 1, _excluded)
		var obstruction := space.intersect_ray(sight)
		if not obstruction.is_empty() and obstruction.get("collider") != hurtbox.get_parent():
			continue
		damaged.append(health)
		source.apply_damage_to(hurtbox)


func cancel_action() -> void:
	if is_instance_valid(presentation):
		presentation.call("reset_pose")
