class_name CombatItemRuntime
extends Node3D

var definition: CombatItemDefinition
var wielder: Node3D
var aim: Camera3D
var active: bool = false


func configure(data: CombatItemDefinition, actor: Node3D, camera: Camera3D) -> void:
	definition = data
	wielder = actor
	aim = camera


func set_active(value: bool) -> void:
	active = value
	visible = value
	if not value:
		cancel_action()


func handle_action(_action: StringName, _pressed: bool) -> void:
	pass


func cancel_action() -> void:
	pass
