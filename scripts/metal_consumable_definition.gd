class_name MetalConsumableDefinition
extends "res://scripts/consumable_definition.gd"
## Quality is authoring metadata; duration is explicitly tuned per recipe.
enum PreparationQuality { RAW, BASIC, PURE }
@export var preparation_quality: PreparationQuality = PreparationQuality.BASIC
@export var metals: Array[StringName] = []
@export_range(0.01, 120.0, 0.01, "or_greater", "suffix:s") var absorption_duration := 15.0

func apply(actor: Node) -> bool:
	var allomancy := actor.get_node_or_null("AllomancyComponent") as AllomancyComponent
	return allomancy != null and allomancy.begin_absorption(metals, absorption_duration)
