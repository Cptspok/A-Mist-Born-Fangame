class_name CourtTargetDefinition
extends Resource
## Authored data only. Discovery and defeat belong to IntelligenceKnowledge.
@export var unique_id: StringName
@export var display_name := "Court target"
@export var unknown_display_name := "???"
@export var portrait: Texture2D
@export var unknown_portrait: Texture2D
@export var dossier_fields: Array[CourtIntelFieldDefinition] = []
@export_group("Map")
@export var district_id: StringName
@export var region_id: StringName
## Optional field that reveals this map marker. Empty means no clue-based marker.
@export var map_reveal_field_id: StringName
## Normalized position within the region rectangle.
@export var map_position := Vector2(0.5, 0.5)
@export_group("Intelligence")
@export var associated_clue_ids: Array[StringName] = []

func field_by_id(id: StringName) -> CourtIntelFieldDefinition:
	if id == &"": return null
	for field in dossier_fields:
		if field != null and field.unique_id == id: return field
	return null

func ordered_fields() -> Array[CourtIntelFieldDefinition]:
	var result: Array[CourtIntelFieldDefinition] = []
	var seen: Dictionary = {}
	for field in dossier_fields:
		if field == null or field.unique_id == &"" or seen.has(field.unique_id): continue
		seen[field.unique_id] = true
		# Stable insertion preserves authored array order for equal priorities.
		var index := result.size()
		while index > 0 and result[index - 1].display_order > field.display_order: index -= 1
		result.insert(index, field)
	return result
