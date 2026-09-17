class_name ItemDefinition
extends Resource
const ConsumableDefinition = preload("res://scripts/consumable_definition.gd")

@export var item_id := ""
@export var display_name := "Item"
@export_multiline var description := ""
@export_multiline var characteristics := ""
@export var item_type := "Misc"
@export var inventory_sprite: Texture2D
@export_range(1, 10, 1) var grid_width := 1
@export_range(1, 10, 1) var grid_height := 1
@export var world_visual: PackedScene
@export var combat_definition: CombatItemDefinition
@export var consumable: ConsumableDefinition

@export var equipment_profile: EquipmentProfile

@export var stat_modifiers: Array[StatModifier] = []
