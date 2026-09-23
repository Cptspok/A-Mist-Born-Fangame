class_name ItemMaterialDefinition
extends Resource
@export var category: StringName = &"wood"
## Fraction reserved for future mixed-material force scaling; zero is undetectable.
@export_range(0.0, 1.0) var metallic_content := 0.0
@export_range(0.01, 100.0) var mass_kg := 1.0
