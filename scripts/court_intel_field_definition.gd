class_name CourtIntelFieldDefinition
extends Resource
## Immutable authored content. IDs must be non-empty and unique within a target.
@export var unique_id: StringName
@export var display_label := "Information"
@export_multiline var revealed_text := ""
## Lower values appear first; equal values keep the target array's authoring order.
@export var display_order := 0
