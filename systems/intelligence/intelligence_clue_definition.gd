class_name IntelligenceClueDefinition
extends Resource
@export var unique_id: StringName
@export var display_name := "Intelligence document"
@export var target: CourtTargetDefinition
## These flags are independent of optional dossier fields and runtime status.
@export var reveals_identity := false
@export var reveals_portrait := false
## Drag the field resources from the target's Dossier Fields list here.
## Only IDs belonging to the assigned target are accepted at runtime.
@export var revealed_fields: Array[CourtIntelFieldDefinition] = []
@export_multiline var clue_text := ""
@export var source_description := ""
@export var icon: Texture2D
