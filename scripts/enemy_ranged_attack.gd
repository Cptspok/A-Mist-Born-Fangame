extends CommittedEnemyAttack
signal shot_fired
@export_range(1.0, 100.0, 1.0) var projectile_speed := 24.0
@export_range(0.1, 10.0, 0.1) var projectile_lifetime := 1.25
@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
@export var projectile_origin_path: NodePath = ^"../ProjectileOrigin"
@export_range(0.0, 1000.0, 1.0) var projectile_damage := 30.0
@export_range(0.1, 50.0, 0.1) var attack_range := 20.0
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
	bolt.speed = projectile_speed
	bolt.lifetime = projectile_lifetime
	bolt.damage_source.damage_amount = projectile_damage
	bolt.launch(muzzle.global_position, aim_point - muzzle.global_position, actor)

	shot_fired.emit()

var _draw_hand: Node3D
var _hand_rest := Vector3.ZERO

func _pose() -> void:
	super._pose()
	if not is_instance_valid(_equipment): return
	if not is_instance_valid(_draw_hand):
		_draw_hand = actor.get_node("VisualRoot").find_child("RightHand", true, false) as Node3D
		if _draw_hand != null: _hand_rest = _draw_hand.position
	var raise := 0.0
	var draw := 0.0
	if phase == Phase.WINDUP:
		var progress := clampf(elapsed / windup_duration, 0.0, 1.0)
		raise = clampf(progress / 0.3, 0.0, 1.0)
		draw = clampf((progress - 0.2) / 0.5, 0.0, 1.0)
	elif phase == Phase.STRIKE:
		raise = 1.0
	elif phase == Phase.RECOVERY:
		raise = 1.0 - clampf(elapsed / recovery_duration, 0.0, 1.0)
	# Raise, visibly draw back, hold the last 30%, then snap the drawing hand free.
	_equipment.position = _rest_position + Vector3(0, 0.42 * raise, -0.18 * raise)
	_equipment.rotation = _rest_rotation + Vector3(-0.18 * raise, 0, -0.5 * raise)
	if _draw_hand != null:
		_draw_hand.position = _hand_rest + Vector3(-0.3 * raise, 0.45 * raise, 0.32 * draw)
	if reaction.remaining <= 0.0: actor.get_node("VisualRoot").rotation.x = -0.12 * draw
