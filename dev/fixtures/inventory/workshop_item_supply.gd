extends Node3D
## Unlimited Workshop stock, granted through normal inventory placement.
@export var item_definition: ItemDefinition
@export_range(1, 99, 1) var quantity_per_interaction := 3

func _ready() -> void:
	$InteractionComponent.interacted.connect(_supply)
	if item_definition != null:
		$Label.text = item_definition.display_name + "\nRepeatable supply"
		$InteractionComponent.interaction_prompt = "Take %d x %s" % [quantity_per_interaction, item_definition.display_name]

func _supply(actor: Node) -> void:
	var inventory := actor.get_node_or_null("InventoryComponent") as InventoryComponent
	if inventory != null and item_definition != null:
		inventory.try_add(item_definition, quantity_per_interaction)
