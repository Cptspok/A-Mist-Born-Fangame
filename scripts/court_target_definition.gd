class_name CourtTargetDefinition
extends Resource
## Authored data only. Discovery and defeat belong to IntelligenceKnowledge.
@export var unique_id: StringName
@export var display_name := "Court target"
@export var unknown_display_name := "???"
@export var portrait: Texture2D
@export var unknown_portrait: Texture2D
@export_multiline var dossier_text := ""
@export_group("Map")
@export var district_id: StringName
@export var region_id: StringName
@export var location_display_name := ""
## Normalized position within the region rectangle.
@export var map_position := Vector2(0.5, 0.5)
@export_group("Intelligence")
@export var associated_clue_ids: Array[StringName] = []
