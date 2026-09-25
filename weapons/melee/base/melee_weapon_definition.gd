class_name MeleeWeaponDefinition
extends CombatItemDefinition

@export var moveset: WeaponMoveset
@export var can_block := false
@export_range(0.0, 180.0) var block_angle := 110.0
@export_range(0.01, 100.0) var block_strength := 20.0
@export_range(0.0, 1.0) var blocked_damage_multiplier := 0.15
@export_range(0.0, 1.0) var block_movement_multiplier := 0.45
@export_range(0.01, 1.0) var block_raise_time := 0.15
@export_range(0.01, 2.0) var guard_break_recovery := 0.65

@export_range(0.0, 1000.0, 1.0) var damage: float = 25.0
## Legacy single-strike fallback only; authored movesets own timing and coverage.
@export_range(0.1, 5.0, 0.05) var attack_cooldown: float = 0.6
@export_range(0.2, 10.0, 0.1) var attack_reach: float = 2.5
@export_range(0.1, 3.0, 0.1) var hit_width: float = 1.0
