extends Node

@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
@export_range(0.1, 10.0, 0.1) var attack_cooldown: float = 2.0
@export var projectile_origin_path: NodePath = ^"../ProjectileOrigin"
var _remaining: float = 0.0
@onready var actor: EnemyController = get_parent()
@onready var muzzle: Marker3D = get_node(projectile_origin_path)
@onready var sensing = actor.get_node("Sensing")


func tick(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)


func execute(target: Node3D) -> bool:
	if GameplayLocks.is_locked() or not actor.is_active or _remaining > 0.0 or not is_instance_valid(target) or not sensing.visible_target:
		return false
	if projectile_scene == null:
		return false
	var hurtbox := target.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox == null or hurtbox.get_health_component() == null or hurtbox.get_health_component().is_dead():
		return false
	var aim_point := hurtbox.global_position
	# One launch-time clearance check, only when the cooldown permits a shot.
	# Also prevents a muzzle placed through a nearby wall from firing beyond it.
	_remaining = attack_cooldown
	var query := PhysicsRayQueryParameters3D.create(actor.global_position, muzzle.global_position, sensing.sight_mask, [actor.get_rid()])
	if not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return false
	query.from = muzzle.global_position
	query.to = aim_point
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.get("collider") != target:
		return false
	var instance := projectile_scene.instantiate()
	var bolt := instance as Projectile
	if bolt == null:
		instance.free()
		push_warning("Ranged attack requires a Projectile scene.")
		return false
	get_tree().current_scene.add_child(bolt)
	bolt.launch(muzzle.global_position, aim_point - muzzle.global_position, actor)
	return true
