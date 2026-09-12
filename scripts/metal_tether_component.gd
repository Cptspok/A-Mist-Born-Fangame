class_name MetalTetherComponent
extends Area3D

const COLLISION_LAYER := 16
@export var enabled := true
@export var allomancy_class: AllomancyTuning.ResponseClass = AllomancyTuning.ResponseClass.ANCHORED
@export_node_path("PhysicsBody3D") var physical_owner_path: NodePath
@onready var volume: CollisionShape3D = $CollisionShape3D
var _physical_owner: PhysicsBody3D

func _ready() -> void:
	collision_layer = COLLISION_LAYER
	collision_mask = 0
	monitoring = false
	if not physical_owner_path.is_empty():
		_physical_owner = get_node_or_null(physical_owner_path) as PhysicsBody3D

func is_available() -> bool:
	return enabled and not is_queued_for_deletion() and volume != null and not volume.disabled and volume.shape != null

func get_physical_owner() -> PhysicsBody3D:
	return _physical_owner if is_instance_valid(_physical_owner) else null

## Isolated volume targeting, independent of render geometry.
## Closest box/sphere point; other standard shapes fall back to shape center.
func target_point(from: Vector3) -> Vector3:
	var local := volume.to_local(from)
	var shape := volume.shape
	if shape is BoxShape3D:
		var half: Vector3 = shape.size * 0.5
		return volume.to_global(local.clamp(-half, half))
	if shape is SphereShape3D:
		return volume.to_global(local.limit_length(shape.radius))
	return volume.global_position
