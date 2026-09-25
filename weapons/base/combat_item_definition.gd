class_name CombatItemDefinition
extends Resource

## Runtime scene implementing CombatItemRuntime; no inventory identity here.
@export var runtime_scene: PackedScene
## Leave unsupported action labels empty.
@export var primary_action_label: String = ""
@export var secondary_action_label: String = ""
