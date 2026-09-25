class_name ItemStack
extends RefCounted

var definition: ItemDefinition
var quantity := 1
var grid_position := Vector2i.ZERO

func _init(item_definition: ItemDefinition, item_quantity := 1, position := Vector2i.ZERO) -> void:
	definition = item_definition
	quantity = item_quantity
	grid_position = position
