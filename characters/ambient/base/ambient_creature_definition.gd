class_name AmbientCreatureDefinition
extends Resource
## Visuals face local -Z, with their feet at y=0. Use visual-only scenes.
enum MovementProfile { GROUND, FLYING }

@export var unique_id: StringName
@export var visual_scene: PackedScene
@export var movement_profile: MovementProfile = MovementProfile.GROUND
@export_group("Reaction")
@export_range(0.1, 30.0) var trigger_radius: float = 4.5
@export_range(0.1, 30.0) var flee_speed: float = 4.0
## Maximum travel, including fade. Fade duration is shortened if needed to fit.
@export_range(0.1, 50.0) var flee_distance: float = 7.0
@export_range(0.0, 50.0) var fade_start_distance: float = 2.0
@export_range(0.01, 10.0) var fade_duration: float = 0.8
@export_range(0.1, 30.0) var minimum_object_speed: float = 2.5
@export_group("Variation")
## Fractional variation around the base value.
@export_range(0.0, 0.9) var speed_randomization: float = 0.15
@export_range(0.0, 0.9) var size_randomization: float = 0.1
@export_group("Flying")
@export_range(0.0, 5.0) var upward_bias: float = 0.65
