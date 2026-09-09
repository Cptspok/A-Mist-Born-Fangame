class_name MeleeWeaponDefinition
extends CombatItemDefinition

@export_range(0.0, 1000.0, 1.0) var damage: float = 25.0
@export_range(0.1, 5.0, 0.05) var attack_cooldown: float = 0.6
@export_range(0.2, 10.0, 0.1) var attack_reach: float = 2.5
@export_range(0.1, 3.0, 0.1) var hit_width: float = 1.0
