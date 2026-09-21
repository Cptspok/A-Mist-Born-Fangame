class_name AmbientCreatureSpawner
extends Node3D
const CREATURE_SCENE := preload("res://scenes/ambient_creature.tscn")
@export var definition: AmbientCreatureDefinition
@export_range(1, 100) var count: int = 3
@export_range(0.0, 30.0) var spawn_radius: float = 1.0
@export var random_rotation := true
@export var spawn_on_ready := true
## Respawns the whole group after its last creature disappears.
@export var respawn_enabled := true
@export_range(0.1, 300.0) var respawn_delay: float = 20.0
## Clearance beyond the spawn area's bounding radius, in world meters.
@export_range(0.0, 100.0) var respawn_min_player_distance: float = 12.0
var _remaining: int = 0
var _waiting := false
var _respawn_timer: Timer

func _ready() -> void:
	_respawn_timer = Timer.new()
	_respawn_timer.name = "RespawnTimer"
	_respawn_timer.one_shot = true
	add_child(_respawn_timer)
	_respawn_timer.timeout.connect(_try_respawn)
	if spawn_on_ready:
		spawn()

func spawn() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if definition == null or definition.visual_scene == null or _remaining > 0 or _waiting:
		return
	for index in range(count):
		var creature := CREATURE_SCENE.instantiate() as AmbientCreature
		creature.definition = definition
		var angle := randf() * TAU
		var radius := sqrt(randf()) * spawn_radius
		creature.position = Vector3(cos(angle), 0.0, sin(angle)) * radius
		if random_rotation:
			creature.rotation.y = randf() * TAU
		_remaining += 1
		creature.tree_exited.connect(_on_creature_exited, CONNECT_ONE_SHOT)
		add_child(creature)

func _on_creature_exited() -> void:
	_remaining -= 1
	if _remaining == 0:
		# Defer so scene teardown cannot start a timer while children are exiting.
		_begin_respawn_wait.call_deferred()

func _begin_respawn_wait() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if not respawn_enabled or _remaining > 0 or _waiting:
		return
	_waiting = true
	_respawn_timer.start(maxf(0.1, respawn_delay))

func _try_respawn() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if not respawn_enabled or _remaining > 0:
		_waiting = false
		return
	if not _player_clear_of_spawn_area():
		_respawn_timer.start(1.0)
		return
	_waiting = false
	spawn()

func _player_clear_of_spawn_area() -> bool:
	# Only called once cooldown has elapsed, at most once per second while empty.
	# Resolve current players here so reload/replacement cannot leave a stale cache.
	var found_player := false
	var world_scale := global_basis.get_scale().abs()
	var area_radius := spawn_radius * maxf(world_scale.x, world_scale.z)
	var clearance := maxf(0.0, respawn_min_player_distance) + area_radius
	for node in get_tree().get_nodes_in_group(&"player"):
		var player := node as Node3D
		if player == null or player.is_queued_for_deletion():
			continue
		found_player = true
		if global_position.distance_squared_to(player.global_position) <= clearance * clearance:
			return false
	# During player removal/replacement, wait instead of spawning unseen by the gate.
	return found_player
