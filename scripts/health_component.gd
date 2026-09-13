class_name HealthComponent
extends Node

signal health_changed(current_health: float, max_health: float)
signal died

@export_range(0.1, 1000000.0, 0.1, "or_greater") var max_health: float = 100.0
@export var start_at_max_health: bool = true
## Optional stat provider; enemies retain their local maximum.
@export var stat_component_path: NodePath

var current_health: float:
	get:
		return _current_health

var _current_health: float = 0.0
var _is_dead: bool = false
var _damage_processors: Array[Callable] = []


func _ready() -> void:
	if not stat_component_path.is_empty():
		var stats := get_node(stat_component_path) as StatComponent
		max_health = stats.get_value(StatIds.Stat.MAX_HEALTH)
		stats.stat_changed.connect(_on_stat_changed)
	_current_health = max_health if start_at_max_health else 0.0
	_is_dead = is_zero_approx(_current_health)


## Processors transform incoming damage, never healing. Return immediate damage.
func register_damage_processor(processor: Callable) -> void:
	if processor.is_valid() and processor not in _damage_processors: _damage_processors.append(processor)

func unregister_damage_processor(processor: Callable) -> void:
	_damage_processors.erase(processor)

## Already-processed obligations can bypass processors to avoid deferring twice.
func apply_damage(amount: float, process_incoming := true) -> float:
	if not is_finite(amount) or amount <= 0.0 or _is_dead:
		return 0.0
	if process_incoming:
		for processor in _damage_processors.duplicate():
			if processor.is_valid(): amount = maxf(0.0, float(processor.call(amount)))
		if amount <= 0.0: return 0.0

	var previous_health := _current_health
	_current_health = maxf(_current_health - amount, 0.0)
	var applied_damage := previous_health - _current_health
	health_changed.emit(_current_health, max_health)

	if is_zero_approx(_current_health):
		_is_dead = true
		died.emit()

	return applied_damage


func heal(amount: float) -> float:
	if amount <= 0.0 or _is_dead:
		return 0.0

	var previous_health := _current_health
	_current_health = minf(_current_health + amount, max_health)
	var applied_healing := _current_health - previous_health

	if applied_healing > 0.0:
		health_changed.emit(_current_health, max_health)

	return applied_healing


func restore_to_max() -> float:
	if _is_dead:
		return 0.0

	return heal(max_health - _current_health)


func is_dead() -> bool:
	return _is_dead

func _on_stat_changed(stat: StatIds.Stat, value: float) -> void:
	if stat == StatIds.Stat.MAX_HEALTH: set_max_health(value)

## Preserve absolute HP on increases; clamp on decreases. Never revive or heal.
func set_max_health(value: float) -> void:
	if not is_finite(value): return
	value = maxf(0.1, value)
	if is_equal_approx(max_health, value): return
	max_health = value
	_current_health = minf(_current_health, max_health)
	health_changed.emit(_current_health, max_health)
