class_name WorldItem
extends StaticBody3D

@export var item_definition: ItemDefinition
@export var quantity := 1
var pickup_enabled := true
@onready var interaction_component: InteractionComponent = $InteractionComponent
@onready var fallback_mesh: MeshInstance3D = $MeshInstance3D
@onready var visual_root: Node3D = $VisualRoot

func _ready() -> void:
	interaction_component.interacted.connect(_on_interacted)
	if item_definition != null and item_definition.world_visual != null:
		visual_root.add_child(item_definition.world_visual.instantiate())
		fallback_mesh.hide()

func _on_interacted(interactor: Node) -> void:
	if not pickup_enabled: return
	var inventory := interactor.get_node_or_null("InventoryComponent") as InventoryComponent
	if inventory != null and inventory.try_add(item_definition, quantity):
		pickup_enabled = false
		queue_free()
