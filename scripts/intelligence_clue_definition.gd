class_name IntelligenceClueDefinition
extends Resource
@export var unique_id: StringName
@export var display_name := "Intelligence document"
@export var target: CourtTargetDefinition
## New categories may be authored here without changing knowledge storage.
@export_enum("identity", "location", "tactical") var reveal_type: String = "identity"
@export_multiline var clue_text := ""
@export_multiline var reveal_text := ""
@export var source_description := ""
@export var icon: Texture2D
