class_name AbilityDefinition
extends Resource
## Shared authoring data. Runtime code never modifies definitions.
enum Lifecycle { INSTANT, HELD, TOGGLE }
@export var ability_id: StringName
@export var display_name: String
@export var lifecycle: Lifecycle = Lifecycle.INSTANT
@export_multiline var description: String
