class_name SteelPush
extends RefCounted

func apply(player: PlayerController, tether: MetalTetherComponent, tuning: AllomancyTuning) -> void:
	var direction := player.global_position - tether.target_point(player.global_position)
	if direction.length_squared() < 0.01: return
	direction = direction.normalized()
	var response := tuning.response(tether.allomancy_class)
	player.add_external_acceleration(direction * tuning.steel_acceleration * response.x)
	tether.apply_object_acceleration(-direction * tuning.steel_acceleration * response.y)
