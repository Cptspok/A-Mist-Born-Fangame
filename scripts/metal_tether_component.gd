class_name MetalTetherComponent
extends Area3D

const COLLISION_LAYER := 16
@export var enabled := true
## Explicit loose-prop opt-in; LIGHT and a live, unfrozen RigidBody are also required.
@export var capture_enabled := false
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
	return enabled and not is_queued_for_deletion() and is_instance_valid(volume) and not volume.disabled and volume.shape != null

func get_physical_owner() -> PhysicsBody3D:
	return _physical_owner if is_instance_valid(_physical_owner) else null

## Loose capture-enabled props use their actual physical center, including
## offset collision shapes/custom COM. Other tethers retain their authored point.
func get_force_position() -> Vector3:
	var body := get_physical_owner() as RigidBody3D
	if capture_enabled and body != null and allomancy_class == AllomancyTuning.ResponseClass.LIGHT:
		if body.center_of_mass_mode == RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM:
			return body.to_global(body.center_of_mass)
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state != null: return body.to_global(state.center_of_mass_local)
	return volume.global_position

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
