class_name WeaponMoveset
extends Resource
@export var attacks: Array[WeaponAttackDefinition] = []
@export_range(0.05, 2.0) var buffer_duration := 0.45
@export_range(0.05, 3.0) var sequence_reset := 0.8
