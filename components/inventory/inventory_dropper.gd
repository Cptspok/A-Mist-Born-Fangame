class_name InventoryDropper
extends Node

signal drop_rejected(reason: String)
@export var world_item_scene: PackedScene
@export var drop_offset := Vector3(0, -0.45, -1.5)
@onready var inventory: InventoryComponent = $"../InventoryComponent"
var _dropping := false

func _ready() -> void:
	inventory.throw_requested.connect(_on_throw_requested)

func _on_throw_requested(stack: ItemStack) -> void:
	if stack not in inventory.stacks: return
	if try_drop(stack, _remove_inventory_stack.bind(stack)):
		inventory.contents_changed.emit()

func _remove_inventory_stack(stack: ItemStack) -> bool:
	if stack not in inventory.stacks: return false
	inventory.stacks.erase(stack)
	return true

## Shared synchronous spawn/commit boundary. Ownership callbacks must validate
## before mutating, emit no signals, and return false without changing anything.
func try_drop(stack: ItemStack, commit_ownership: Callable) -> bool:
	var scene := get_tree().current_scene
	var owner_body := get_parent() as Node3D
	if _dropping or stack == null or stack.definition == null or world_item_scene == null or not is_instance_valid(scene) or scene.is_queued_for_deletion() or owner_body == null:
		drop_rejected.emit("Cannot spawn the dropped item.")
		return false
	_dropping = true
	var instance := world_item_scene.instantiate()
	var world_item := instance as WorldItem
	if world_item == null:
		if is_instance_valid(instance): instance.free()
		_dropping = false
		drop_rejected.emit("Drop scene must contain a WorldItem root.")
		return false
	# A staged item cannot be picked up or displayed while ownership is retained.
	world_item.pickup_enabled = false
	world_item.hide()
	world_item.item_definition = stack.definition
	world_item.quantity = stack.quantity
	world_item.position = scene.to_local(owner_body.global_position + owner_body.global_basis * drop_offset) if scene is Node3D else owner_body.global_position + owner_body.global_basis * drop_offset
	scene.add_child(world_item)
	if not is_instance_valid(world_item) or not world_item.is_inside_tree() or world_item.is_queued_for_deletion():
		if is_instance_valid(world_item): world_item.free()
		_dropping = false
		drop_rejected.emit("World spawn failed; ownership was retained.")
		return false
	if not commit_ownership.call():
		world_item.free()
		_dropping = false
		drop_rejected.emit("Drop could not be committed; ownership was retained.")
		return false
	world_item.pickup_enabled = true
	world_item.show()
	_dropping = false
	return true
