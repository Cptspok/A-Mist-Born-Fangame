@tool
class_name ParametricLadder
extends Node3D
## Origin at the bottom. Local +Z is the climbing face; -Z is the top landing.
## Keep upright, rotate around Y, and resize with these fields instead of scale.
@export_range(1.0, 40.0, 0.1) var height := 4.0:
	set(value):
		height = clampf(value, 1.0, 40.0)
		_queue_rebuild()
@export_range(0.5, 3.0, 0.05) var width := 0.8:
	set(value):
		width = clampf(value, 0.5, 3.0)
		_queue_rebuild()
@export_range(0.15, 0.6, 0.01) var rung_spacing := 0.3:
	set(value):
		rung_spacing = clampf(value, 0.15, 0.6)
		_queue_rebuild()
@export_range(0.03, 0.15, 0.01) var rung_thickness := 0.07:
	set(value):
		rung_thickness = clampf(value, 0.03, 0.15)
		_queue_rebuild()
@export_range(0.2, 8.0, 0.1) var climb_speed := 3.0
## Clearance between ladder plane and the player's centered capsule.
@export_range(0.45, 1.0, 0.05) var front_offset := 0.55:
	set(value):
		front_offset = clampf(value, 0.45, 1.0)
		_queue_rebuild()
@export_range(0.5, 1.5, 0.05) var top_exit_distance := 0.8:
	set(value):
		top_exit_distance = clampf(value, 0.5, 1.5)
		_queue_rebuild()
## Speed used to attach and cross onto a landing.
@export_range(0.5, 8.0, 0.1) var alignment_speed := 4.0
## Landing height relative to the ladder top.
@export_range(-0.5, 1.0, 0.05) var top_exit_height := 0.0:
	set(value):
		top_exit_height = clampf(value, -0.5, 1.0)
		_queue_rebuild()
var _rebuild_pending := false

func _ready() -> void:
	_queue_rebuild()

func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_pending: return
	_rebuild_pending = true
	_rebuild.call_deferred()

func _rebuild() -> void:
	_rebuild_pending = false
	var old := get_node_or_null("Generated")
	if old != null:
		remove_child(old)
		old.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.25, 0.17)
	for side in [-1.0, 1.0]:
		_add_box(generated, Vector3(rung_thickness * 1.5, height, rung_thickness * 1.5), Vector3(side * width * 0.5, height * 0.5, 0), material)
	var count := maxi(1, int(floor(height / rung_spacing)))
	for index in count:
		_add_box(generated, Vector3(width, rung_thickness, rung_thickness), Vector3(0, (index + 0.5) * height / count, 0), material)
	# One representative solid panel covers both rails and rungs.
	var body := StaticBody3D.new()
	body.name = "LadderCollision"
	body.position.y = height * 0.5
	generated.add_child(body)
	var solid_shape := BoxShape3D.new()
	solid_shape.size = Vector3(width + rung_thickness * 1.5, height, rung_thickness * 1.5)
	var solid_collision := CollisionShape3D.new()
	solid_collision.shape = solid_shape
	body.add_child(solid_collision)
	var interaction := InteractionComponent.new()
	interaction.name = "ClimbInteraction"
	interaction.collision_layer = 2
	interaction.collision_mask = 0
	interaction.monitoring = false
	interaction.interaction_prompt = "Climb"
	interaction.availability_check = can_mount
	interaction.position = Vector3(0, (height + maxf(top_exit_height, 0.0)) * 0.5 + 0.5, 0)
	generated.add_child(interaction)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width + 0.4, height + maxf(top_exit_height, 0.0) + 2.0, maxf(front_offset, top_exit_distance) * 2.0 + 0.5)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	interaction.add_child(collision)
	if not Engine.is_editor_hint(): interaction.interacted.connect(_interact)

func _add_box(parent: Node3D, dimensions: Vector3, at: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)

func can_mount(interactor: Node) -> bool:
	if not interactor is PlayerController: return false
	if interactor.is_climbing() or interactor.is_crouching or interactor.get_node("HealthComponent").is_dead(): return false
	var local := to_local(interactor.global_position)
	if absf(local.x) > width * 0.5 + 0.5 or absf(local.z) > maxf(front_offset, top_exit_distance) + 0.6: return false
	if local.y < 0.0 or local.y > height + 1.5 + top_exit_height: return false
	# The back face is only usable at the top landing.
	return local.z >= -0.15 or local.y >= height + top_exit_height + 0.6

func _interact(interactor: Node) -> void:
	if can_mount(interactor): interactor.begin_ladder(self)
