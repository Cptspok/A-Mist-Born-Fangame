class_name AllomancyTuning
extends Resource

enum ResponseClass { LIGHT, MEDIUM, HEAVY, ANCHORED }
## Vector2(player force coupling, object force coupling); mass stays on bodies.
@export var light_response := Vector2(0.03, 2.0)
@export var medium_response := Vector2(0.35, 1.0)
@export var heavy_response := Vector2(0.85, 0.25)
@export var anchored_response := Vector2(1.0, 0.0)
@export_range(0.0, 200.0, 0.5, "or_greater") var steel_force := 30.0
@export_range(0.0, 200.0, 0.5, "or_greater") var iron_force := 30.0
@export_range(0.1, 200.0, 0.1, "or_greater") var steel_terminal_speed := 24.0
@export_range(0.1, 200.0, 0.1, "or_greater") var iron_terminal_speed := 24.0
@export_range(1.0, 200.0, 1.0, "or_greater") var max_range := 30.0
@export_range(1.0, 85.0, 1.0) var targeting_half_angle := 45.0

func response(kind: ResponseClass) -> Vector2:
	match kind:
		ResponseClass.LIGHT: return light_response
		ResponseClass.MEDIUM: return medium_response
		ResponseClass.HEAVY: return heavy_response
		_: return Vector2(anchored_response.x, 0.0)
