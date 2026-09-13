class_name AbilityComponent
extends Node
## Hooks: validators return an empty StringName on success; start returns bool;
## stop accepts a reason. Hooks own all gameplay-specific checks and effects.
signal activation_requested(id: StringName)
signal activated(id: StringName)
signal activation_failed(id: StringName, reason: StringName)
signal deactivated(id: StringName, reason: StringName)
var _owned: Dictionary = {}
var _active: Dictionary = {}
var _transitioning: Dictionary = {}

func register_ability(definition: AbilityDefinition, validate := Callable(), cost_check := Callable(), start := Callable(), stop := Callable()) -> bool:
	if definition == null or definition.ability_id == &"" or _owned.has(definition.ability_id): return false
	_owned[definition.ability_id] = {"definition": definition, "validate": validate, "cost": cost_check, "start": start, "stop": stop}
	return true

func get_definition(id: StringName) -> AbilityDefinition:
	return _owned[id].definition if _owned.has(id) else null

func ability_ids() -> Array:
	return _owned.keys()

func is_active(id: StringName) -> bool:
	return _active.has(id)

func activation_failure(id: StringName) -> StringName:
	if _transitioning.has(id): return &"transition_in_progress"
	return _validate(id)

func _validate(id: StringName) -> StringName:
	if not _owned.has(id): return &"not_owned"
	if is_active(id): return &"already_active"
	for key in ["validate", "cost"]:
		var hook: Callable = _owned[id][key]
		if hook.is_valid():
			var reason: StringName = hook.call()
			if reason != &"": return reason
	return &""

func can_activate(id: StringName) -> bool:
	return activation_failure(id) == &""

func request_activation(id: StringName) -> bool:
	if _transitioning.has(id): return false
	_transitioning[id] = true
	activation_requested.emit(id)
	if is_active(id) and get_definition(id).lifecycle == AbilityDefinition.Lifecycle.TOGGLE:
		deactivate(id)
		_transitioning.erase(id)
		return true
	var reason := _validate(id)
	if reason != &"":
		_transitioning.erase(id)
		activation_failed.emit(id, reason)
		return false
	var start: Callable = _owned[id].start
	if start.is_valid() and not start.call():
		_transitioning.erase(id)
		activation_failed.emit(id, &"execution_rejected")
		return false
	_active[id] = true
	activated.emit(id)
	if get_definition(id).lifecycle == AbilityDefinition.Lifecycle.INSTANT: deactivate(id, &"completed")
	_transitioning.erase(id)
	return true

func deactivate(id: StringName, reason: StringName = &"released") -> void:
	if not is_active(id): return
	_active.erase(id)
	var stop: Callable = _owned[id].stop
	if stop.is_valid(): stop.call(reason)
	deactivated.emit(id, reason)

func cancel_all(reason: StringName = &"cancelled") -> void:
	for id in _active.keys(): deactivate(id, reason)

func _exit_tree() -> void:
	cancel_all(&"removed")
