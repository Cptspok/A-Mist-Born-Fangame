class_name EquipmentStatsBridge
extends Node

@onready var equipment: EquipmentComponent = $"../Equipment"
@onready var stats: StatComponent = $"../StatComponent"
var _sources: Array[ItemStack] = []

func _ready() -> void:
	equipment.equipment_changed.connect(_sync_equipment)
	_sync_equipment()

func _sync_equipment() -> void:
	var current: Array[ItemStack] = []
	for stack in equipment.get_equipped_items().values():
		if stack not in current: current.append(stack)
	stats.begin_update()
	for stack in _sources:
		if stack not in current: stats.remove_modifiers_from_source(stack)
	for stack in current:
		if stack in _sources: continue
		for modifier in stack.definition.stat_modifiers:
			if modifier != null:
				stats.add_modifier(modifier.stat, modifier.operation, modifier.value, stack)
	_sources = current
	stats.end_update()

func _exit_tree() -> void:
	if not is_instance_valid(stats): return
	stats.begin_update()
	for stack in _sources: stats.remove_modifiers_from_source(stack)
	stats.end_update()
