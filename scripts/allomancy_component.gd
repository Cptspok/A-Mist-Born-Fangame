class_name AllomancyComponent
extends Node
signal reserve_changed(id: StringName, current: float, maximum: float)
signal burn_started(id: StringName)
signal burn_stopped(id: StringName)
signal depleted(id: StringName)
signal access_changed(id: StringName, available: bool)
@export var definitions: Array[Resource] = []
@export var start_at_full := true
var _states: Dictionary = {}

func _ready() -> void:
	process_physics_priority = -10 # Resolve depletion before the actor applies forces.
	for definition in definitions:
		if definition is MetalDefinition: register_metal(definition)

func register_metal(definition: MetalDefinition, available := true) -> bool:
	if definition == null or definition.metal_id == &"" or _states.has(definition.metal_id): return false
	var maximum := maxf(0.0, definition.maximum_reserve)
	_states[definition.metal_id] = {"maximum": maximum, "reserve": maximum if start_at_full else clampf(definition.default_reserve, 0.0, maximum), "rate": maxf(0.0, definition.consumption_rate), "burning": false, "automatic": true, "access": available}
	return true

func has_access(id: StringName) -> bool:
	return _states.has(id) and _states[id].access

func set_access(id: StringName, available: bool) -> void:
	if not _states.has(id) or _states[id].access == available: return
	_states[id].access = available
	if not available: stop_burn(id)
	access_changed.emit(id, available)

func reserve(id: StringName) -> float:
	return _states[id].reserve if _states.has(id) else 0.0

func maximum_reserve(id: StringName) -> float:
	return _states[id].maximum if _states.has(id) else 0.0

func can_afford(id: StringName, amount: float) -> bool:
	return is_finite(amount) and amount >= 0.0 and has_access(id) and reserve(id) >= amount

func add_reserve(id: StringName, amount: float) -> void:
	if not _states.has(id) or not is_finite(amount) or amount <= 0.0: return
	_set_reserve(id, reserve(id) + amount)

func consume(id: StringName, amount: float) -> bool:
	if not can_afford(id, amount): return false
	_set_reserve(id, reserve(id) - amount)
	return true

func _set_reserve(id: StringName, value: float) -> void:
	var previous := reserve(id)
	var current := clampf(value, 0.0, maximum_reserve(id))
	if previous == current: return
	_states[id].reserve = current
	if current == 0.0:
		stop_burn(id)
		depleted.emit(id)
	reserve_changed.emit(id, current, maximum_reserve(id))

func begin_burn(id: StringName, automatic_consumption := true) -> bool:
	if not has_access(id) or reserve(id) <= 0.0: return false
	_states[id].automatic = automatic_consumption
	if not is_burning(id):
		_states[id].burning = true
		burn_started.emit(id)
	return true

func stop_burn(id: StringName) -> void:
	if not is_burning(id): return
	_states[id].burning = false
	burn_stopped.emit(id)

func is_burning(id: StringName) -> bool:
	return _states.has(id) and _states[id].burning

func refill_all() -> void:
	for id in _states: add_reserve(id, maximum_reserve(id))

## Concrete effects report actual usage for this step. No target knowledge here.
## Manual consumption bypasses the continuous loop, avoiding stale/double charges.
func consume_usage(id: StringName, delta: float, engaged: bool) -> void:
	if not engaged:
		stop_burn(id)
		return
	if not is_finite(delta) or delta <= 0.0 or not begin_burn(id, false): return
	_set_reserve(id, reserve(id) - float(_states[id].rate) * delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	for id in _states.keys():
		if is_burning(id) and _states[id].automatic: _set_reserve(id, reserve(id) - float(_states[id].rate) * delta)

func _physics_process(delta: float) -> void:
	advance(delta)
