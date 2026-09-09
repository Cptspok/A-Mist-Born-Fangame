class_name HealthComponent
extends Node

signal health_changed(current_health: float, max_health: float)
signal died

@export_range(0.1, 1000000.0, 0.1, "or_greater") var max_health: float = 100.0
@export var start_at_max_health: bool = true

var current_health: float:
	get:
		return _current_health

var _current_health: float = 0.0
var _is_dead: bool = false


func _ready() -> void:
	_current_health = max_health if start_at_max_health else 0.0
	_is_dead = is_zero_approx(_current_health)


func apply_damage(amount: float) -> float:
	if amount <= 0.0 or _is_dead:
		return 0.0

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
