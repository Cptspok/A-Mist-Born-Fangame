class_name WeaponAttackDefinition
extends Resource
## Immutable attack configuration. Angles are degrees; coverage is camera-local.
@export var presentation_hook: StringName = &"slash"
@export_range(0.01, 3.0) var windup := 0.2
@export_range(0.01, 3.0) var active_duration := 0.16
@export_range(0.01, 3.0) var recovery := 0.3
@export_range(0.0, 5.0) var damage_multiplier := 1.0
@export_range(0.1, 6.0) var reach := 2.5
@export var coverage := Vector2(1.6, 1.2)
@export_range(-90.0, 90.0) var sweep_start := -35.0
@export_range(-90.0, 90.0) var sweep_end := 35.0
@export_range(0.0, 1.5) var movement_multiplier := 0.65
@export_range(0.0, 5.0) var forward_speed := 0.0
@export_range(0.0, 100.0) var impact := 2.0
@export_range(0.0, 100.0) var block_pressure := 10.0
@export var windup_pose := Vector3(-0.3, -0.5, -0.9)
@export var strike_pose := Vector3(-0.7, 0.5, 0.9)
