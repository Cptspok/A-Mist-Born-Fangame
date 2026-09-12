extends CommittedEnemyAttack
@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
@export var projectile_origin_path: NodePath = ^"../ProjectileOrigin"
@export_range(0.0, 1000.0, 1.0) var projectile_damage := 30.0
@export_range(0.1, 50.0, 0.1) var attack_range := 10.0
@onready var muzzle: Marker3D = get_node(projectile_origin_path)
@onready var sensing = actor.get_node("Sensing")

func execute(victim: Node3D) -> bool:
	if projectile_scene == null or not is_instance_valid(victim) or not sensing.visible_target: return false
	if actor.global_position.distance_to(victim.global_position) > attack_range: return false
	return begin(victim)

func resolve_strike() -> void:
	# Aim is a world-space snapshot; cover and lateral movement can defeat the shot.
	var query := PhysicsRayQueryParameters3D.create(actor.global_position, muzzle.global_position, sensing.sight_mask, [actor.get_rid()])
	if not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return
	query.from = muzzle.global_position
	query.to = aim_point
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.get("collider") != target: return
	var instance := projectile_scene.instantiate()
	var bolt := instance as Projectile
	if bolt == null:
		instance.free()
		return
	# Keep projectiles inside this gameplay world so shell retries clear them too.
	actor.get_parent().add_child(bolt)
	bolt.damage_source.damage_amount = projectile_damage
	bolt.launch(muzzle.global_position, aim_point - muzzle.global_position, actor)
