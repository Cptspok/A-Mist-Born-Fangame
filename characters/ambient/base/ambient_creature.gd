class_name AmbientCreature
extends Node3D
## Reactive ambience only: no body, steering, navigation, or combat.
@export var definition: AmbientCreatureDefinition
@onready var _sensor: Area3D = $DetectionArea3D
@onready var _visual_root: Node3D = $VisualRoot
@onready var _object_check: Timer = $ObjectCheck
var _nearby_objects: Array[RigidBody3D] = []
var _geometry: Array[GeometryInstance3D] = []
var _direction := Vector3.ZERO
var _speed: float
var _distance: float = 0.0
var _fade_start: float
var _fade_time: float
var _fleeing := false

func _ready() -> void:
	set_process(false)
	if definition == null or definition.visual_scene == null:
		push_warning("AmbientCreature requires a definition with a visual_scene.")
		queue_free()
		return
	var visual := definition.visual_scene.instantiate()
	_visual_root.add_child(visual)
	# Enforce visual-only instances even if an authored visual accidentally has physics.
	_strip_collision(visual)
	_collect_geometry(visual)
	_visual_root.scale *= randf_range(1.0 - definition.size_randomization, 1.0 + definition.size_randomization)
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(definition.trigger_radius, 0.1)
	$DetectionArea3D/CollisionShape3D.shape = sphere
	_sensor.body_entered.connect(_on_body_entered)
	_sensor.body_exited.connect(_on_body_exited)
	_object_check.timeout.connect(_check_objects)

func _strip_collision(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child in node.get_children():
		_strip_collision(child)

func _collect_geometry(node: Node) -> void:
	if node is GeometryInstance3D:
		_geometry.append(node as GeometryInstance3D)
	for child in node.get_children():
		_collect_geometry(child)

func _on_body_entered(body: Node3D) -> void:
	if _fleeing:
		return
	if body.is_in_group(&"ambient_disturbance"):
		flee_from(body.global_position)
	elif body is RigidBody3D:
		var rigid := body as RigidBody3D
		if not _nearby_objects.has(rigid):
			_nearby_objects.append(rigid)
		_check_objects()
		if not _fleeing and not _nearby_objects.is_empty():
			_object_check.start()

func _on_body_exited(body: Node3D) -> void:
	if body is RigidBody3D:
		_nearby_objects.erase(body as RigidBody3D)
	if _nearby_objects.is_empty():
		_object_check.stop()

func _check_objects() -> void:
	for index in range(_nearby_objects.size() - 1, -1, -1):
		var body := _nearby_objects[index]
		if not is_instance_valid(body):
			_nearby_objects.remove_at(index)
		elif not body.freeze and body.linear_velocity.length_squared() >= pow(maxf(definition.minimum_object_speed, 0.1), 2.0):
			flee_from(body.global_position)
			return
	if _nearby_objects.is_empty():
		_object_check.stop()

func flee_from(source_position: Vector3) -> void:
	if _fleeing or definition == null:
		return
	_fleeing = true
	_direction = global_position - source_position
	_direction.y = 0.0
	if _direction.length_squared() < 0.0001:
		var yaw := randf() * TAU
		_direction = Vector3(sin(yaw), 0.0, cos(yaw))
	_direction = _direction.normalized()
	if definition.movement_profile == AmbientCreatureDefinition.MovementProfile.FLYING:
		_direction = (_direction + Vector3.UP * definition.upward_bias).normalized()
	_speed = maxf(0.1, definition.flee_speed * randf_range(1.0 - definition.speed_randomization, 1.0 + definition.speed_randomization))
	var maximum_distance := maxf(0.1, definition.flee_distance)
	_fade_start = clampf(definition.fade_start_distance, 0.0, maximum_distance - 0.01)
	_fade_time = maxf(0.001, minf(definition.fade_duration, (maximum_distance - _fade_start) / _speed))
	_visual_root.look_at(_visual_root.global_position + _direction, Vector3.UP)
	_sensor.set_deferred("monitoring", false)
	_object_check.stop()
	_nearby_objects.clear()
	set_process(true)

func _process(delta: float) -> void:
	global_position += _direction * _speed * delta
	_distance += _speed * delta
	var fade := clampf((_distance - _fade_start) / (_speed * _fade_time), 0.0, 1.0)
	for geometry in _geometry:
		geometry.transparency = fade
	if fade >= 1.0:
		queue_free()
