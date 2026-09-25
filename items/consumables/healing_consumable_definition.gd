extends "res://items/consumables/consumable_definition.gd"
## Immutable medicine data; the actor owns the timed action.
@export_range(0.1, 1000.0, 0.1) var heal_amount := 30.0
@export_range(0.1, 30.0, 0.1, "suffix:s") var use_duration := 3.0
@export var interrupt_on_damage := true

func begin_use(actor: Node, inventory: Node, stack: RefCounted) -> bool:
	var recovery := actor.get_node_or_null("PlayerRecovery")
	return recovery != null and recovery.begin_healing(inventory, stack, heal_amount, use_duration, interrupt_on_damage)
