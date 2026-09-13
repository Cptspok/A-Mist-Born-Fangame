class_name MetalDefinition
extends Resource
## Shared, immutable-in-use authoring data.
enum ConsumptionPolicy { CONTINUOUS, EFFECT_GATED }
@export var consumption_policy: ConsumptionPolicy = ConsumptionPolicy.CONTINUOUS
@export var metal_id: StringName
@export var display_name: String
@export_range(0.0, 100000.0) var maximum_reserve := 1000.0
@export_range(0.0, 100000.0) var default_reserve := 1000.0
@export_range(0.0, 1000.0) var consumption_rate := 1.0
@export_multiline var description: String
