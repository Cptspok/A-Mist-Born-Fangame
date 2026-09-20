class_name IntelligenceRegionDefinition
extends Resource
@export var unique_id: StringName
@export var display_name := "Region"
## Normalized map coordinates, not world coordinates.
@export var bounds := Rect2(0.1, 0.1, 0.3, 0.3)
@export var initially_known := false
