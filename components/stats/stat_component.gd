class_name StatComponent
extends Node

signal stat_changed(stat: StatIds.Stat, effective_value: float)
signal values_changed
@export var initial_base_values: Dictionary[StatIds.Stat, float] = {
	StatIds.Stat.MAX_HEALTH: 100.0, StatIds.Stat.MOVE_SPEED: 10.0,
	StatIds.Stat.ARMOR: 0.0, StatIds.Stat.PHYSICAL_DAMAGE: 0.0,
	StatIds.Stat.ATTACK_SPEED: 1.0,
}
var _base: Dictionary = {}
var _effective: Dictionary = {}
var _modifiers: Dictionary = {}
var _next_handle := 1
var _batch_depth := 0
var _dirty: Dictionary = {}

func _ready() -> void:
	for stat in StatIds.Stat.values():
		var value: float = initial_base_values.get(stat, StatIds.DEFAULTS[stat])
		_base[stat] = value if is_finite(value) else StatIds.DEFAULTS[stat]
		_effective[stat] = maxf(_base[stat], StatIds.minimum(stat))

func get_base_value(stat: StatIds.Stat) -> float:
	return _base.get(stat, initial_base_values.get(stat, StatIds.DEFAULTS[stat]))

func get_value(stat: StatIds.Stat) -> float:
	return _effective.get(stat, maxf(get_base_value(stat), StatIds.minimum(stat)))

func set_base_value(stat: StatIds.Stat, value: float) -> void:
	if not is_finite(value) or get_base_value(stat) == value: return
	_base[stat] = value
	_mark_dirty(stat)

## Returns a unique handle; source can be a retained runtime object or stable key.
## Contributions are numeric snapshots, never mutable shared definition Resources.
func add_modifier(stat: StatIds.Stat, operation: StatModifier.Operation, value: float, source: Variant) -> int:
	if source == null or not is_finite(value) or operation not in StatModifier.Operation.values():
		return -1
	var handle := _next_handle
	_next_handle += 1
	_modifiers[handle] = {"stat": stat, "operation": operation, "value": value, "source": source}
	_mark_dirty(stat)
	return handle

func remove_modifier(handle: int) -> void:
	if not _modifiers.has(handle): return
	var stat: StatIds.Stat = _modifiers[handle].stat
	_modifiers.erase(handle)
	_mark_dirty(stat)

func remove_modifiers_from_source(source: Variant) -> void:
	begin_update()
	for handle in _modifiers.keys():
		if _modifiers[handle].source == source: remove_modifier(handle)
	end_update()

## Batch a gameplay transaction so consumers never see intermediate removals.
func begin_update() -> void:
	_batch_depth += 1

func end_update() -> void:
	assert(_batch_depth > 0, "Unbalanced stat update")
	_batch_depth -= 1
	if _batch_depth == 0: _flush()

func _mark_dirty(stat: StatIds.Stat) -> void:
	_dirty[stat] = true
	if _batch_depth == 0: _flush()

func _calculate(stat: StatIds.Stat) -> float:
	var flat := 0.0
	var percent := 0.0
	var more := 1.0
	for entry in _modifiers.values():
		if entry.stat != stat: continue
		match entry.operation:
			StatModifier.Operation.FLAT_ADD: flat += entry.value
			StatModifier.Operation.PERCENT_ADD: percent += entry.value
			StatModifier.Operation.MORE_MULTIPLIER: more *= 1.0 + entry.value
	var result := (get_base_value(stat) + flat) * (1.0 + percent) * more
	if not is_finite(result):
		push_warning("Stat arithmetic overflow; retaining last finite value.")
		return get_value(stat)
	return maxf(StatIds.minimum(stat), result)

func _flush() -> void:
	var changed: Dictionary = {}
	var dirty := _dirty.keys()
	_dirty.clear()
	for stat in dirty:
		var value := _calculate(stat)
		if not is_equal_approx(value, get_value(stat)):
			_effective[stat] = value
			changed[stat] = value
	# All affected values are cached before any consumer is notified.
	for stat in changed:
		stat_changed.emit(stat, changed[stat])
	if not changed.is_empty(): values_changed.emit()
