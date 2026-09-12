class_name CombatReactionComponent
extends Node
## Generic committed-action interruption. No power, weapon, health or UI knowledge.
signal interrupted
@export_range(0.01, 2.0, 0.01) var displacement_threshold := 0.18
@export_range(0.0, 20.0, 0.1) var minimum_external_speed := 1.2
@export_range(0.0, 3.0, 0.05) var reaction_duration := 0.5
var interruptible := false
var remaining := 0.0
var _displacement := 0.0

func begin_window() -> void:
	interruptible = true
	_displacement = 0.0

func end_window() -> void:
	interruptible = false
	_displacement = 0.0

func tick(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)

func observe_external_motion(actual_motion: Vector3, external_velocity: Vector3, delta: float) -> void:
	if not interruptible or external_velocity.length() < minimum_external_speed: return
	var moved := maxf(0.0, actual_motion.dot(external_velocity.normalized()))
	_displacement += minf(moved, external_velocity.length() * delta)
	if _displacement >= displacement_threshold:
		interrupt()

func interrupt() -> void:
	if not interruptible: return
	end_window()
	remaining = reaction_duration
	interrupted.emit()
