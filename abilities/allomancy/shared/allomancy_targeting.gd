class_name AllomancyTargeting
extends Area3D

signal target_changed(tether: MetalTetherComponent)
var tuning: AllomancyTuning
var player: PlayerController
var camera: Camera3D
var selected: MetalTetherComponent
var _nearby: Array[MetalTetherComponent] = []
var _range_shape: SphereShape3D
var _exclude: Array[RID] = []

func configure(actor: PlayerController, view: Camera3D, data: AllomancyTuning) -> void:
	player = actor
	camera = view
	tuning = data
	collision_layer = 0
	collision_mask = MetalTetherComponent.COLLISION_LAYER
	monitorable = false
	_range_shape = SphereShape3D.new()
	_range_shape.radius = tuning.max_range
	var collision := CollisionShape3D.new()
	collision.shape = _range_shape
	add_child(collision)
	_exclude = [player.get_rid()]
	area_entered.connect(_entered)
	area_exited.connect(_exited)

func nearby() -> Array[MetalTetherComponent]:
	return _nearby.duplicate()

func _entered(area: Area3D) -> void:
	if area is MetalTetherComponent and area not in _nearby: _nearby.append(area)

func _exited(area: Area3D) -> void:
	_nearby.erase(area)
	if area == selected: clear_target()

func clear_target() -> void:
	if selected != null:
		selected = null
		target_changed.emit(null)

## Called once per Player physics step. New targets use overlapping candidates;
## an established manipulation may supply its separately validated target.
func refresh(maintained: MetalTetherComponent = null) -> void:
	if not is_equal_approx(_range_shape.radius, tuning.max_range):
		_range_shape.radius = tuning.max_range
	# Only the controller supplies an already acquired active manipulation.
	# Initial acquisition below keeps its existing cone, camera LOS and candidates.
	if can_maintain(maintained):
		if selected != maintained:
			selected = maintained
			target_changed.emit(selected)
		return
	var best: MetalTetherComponent
	var best_score := -INF
	for tether in _nearby:
		if not is_instance_valid(tether) or not tether.is_available(): continue
		var point := tether.target_point(camera.global_position)
		var offset := point - camera.global_position
		var distance := offset.length()
		if distance < 0.1 or distance > tuning.max_range: continue
		var alignment := (-camera.global_basis.z).dot(offset / distance)
		if alignment < cos(deg_to_rad(tuning.targeting_half_angle)): continue
		if not _visible(tether, point): continue
		var score := alignment - distance / tuning.max_range * 0.08
		if score > best_score:
			best = tether
			best_score = score
	if selected != best:
		selected = best
		target_changed.emit(selected)

func _visible(tether: MetalTetherComponent, point: Vector3) -> bool:
	var excluded := _exclude.duplicate()
	var body := tether.get_physical_owner()
	if body != null: excluded.append(body.get_rid())
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1, excluded)
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func can_maintain(tether: MetalTetherComponent) -> bool:
	if not is_instance_valid(tether) or not tether.is_inside_tree() or not tether.is_available(): return false
	var body := tether.get_physical_owner()
	if not is_instance_valid(body) or body.is_queued_for_deletion() or not body.is_inside_tree(): return false
	var origin := player.get_allomantic_origin()
	var point := tether.volume.global_position
	if origin.distance_to(point) > tuning.max_range: return false
	var excluded := _exclude.duplicate()
	excluded.append(body.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, point, 1, excluded)
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
