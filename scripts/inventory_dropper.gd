class_name InventoryDropper
extends Node

@export var world_item_scene: PackedScene
@export var drop_offset := Vector3(0, -0.45, -1.5)
@onready var inventory: InventoryComponent = $"../InventoryComponent"

func _ready() -> void:
	inventory.throw_requested.connect(_on_throw_requested)

func _on_throw_requested(stack: ItemStack) -> void:
	if world_item_scene == null or get_tree().current_scene == null:
		return
	var world_item := world_item_scene.instantiate() as WorldItem
	if world_item == null:
		return
	world_item.item_definition = stack.definition
	world_item.quantity = stack.quantity
	get_tree().current_scene.add_child(world_item)
	var owner_body := get_parent() as Node3D
	world_item.global_position = owner_body.global_position + owner_body.global_transform.basis * drop_offset
	inventory.remove(stack)
