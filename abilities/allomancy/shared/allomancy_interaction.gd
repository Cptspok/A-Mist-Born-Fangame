class_name AllomancyInteraction
extends RefCounted
## Both powers use the same participant velocities and the same force law.
## Returns diagnostic values; evaluating the interaction never changes velocity.
static func evaluate(player: PlayerController, tether: MetalTetherComponent,
		tuning: AllomancyTuning, pulling: bool) -> Dictionary:
	var axis := tether.get_force_position() - player.get_allomantic_origin()
	if axis.length_squared() < 0.0001: return {}
	axis = axis.normalized() * (1.0 if pulling else -1.0)
	return _evaluate_axis(player, tether, tuning, pulling, axis)

## Captured release preserves existing Steel recoil. Projectile speed belongs
## to the authored launch and does NOT use this force/terminal calculation.
static func evaluate_captured_recoil(player: PlayerController, tether: MetalTetherComponent,
		tuning: AllomancyTuning, direction: Vector3) -> Dictionary:
	if not direction.is_finite() or direction.is_zero_approx(): return {}
	return _evaluate_axis(player, tether, tuning, false, -direction.normalized())

static func _evaluate_axis(player: PlayerController, tether: MetalTetherComponent,
		tuning: AllomancyTuning, pulling: bool, axis: Vector3) -> Dictionary:
	var owner: PhysicsBody3D = tether.get_physical_owner()
	if tether.allomancy_class == AllomancyTuning.ResponseClass.ANCHORED: owner = null
	var relative := PhysicalForceResponse.get_velocity(player) - PhysicalForceResponse.get_velocity(owner)
	var speed := relative.dot(axis)
	var terminal := tuning.iron_terminal_speed if pulling else tuning.steel_terminal_speed
	var factor := clampf(1.0 - speed / maxf(terminal, 0.001), 0.0, 1.0)
	var strength := tuning.iron_force if pulling else tuning.steel_force
	var force := axis * maxf(strength, 0.0) * factor
	var coupling := tuning.response(tether.allomancy_class)
	return {"axis": axis, "speed": speed, "factor": factor, "terminal": terminal,
		"player_force": force * coupling.x, "object_force": -force * coupling.y,
		"owner": owner}

static func apply(player: PlayerController, tether: MetalTetherComponent,
		tuning: AllomancyTuning, pulling: bool) -> Dictionary:
	var result := evaluate(player, tether, tuning, pulling)
	if result.is_empty(): return {}
	result.player_force = PhysicalForceResponse.apply_force(player, result.player_force, true)
	result.object_force = PhysicalForceResponse.apply_force(result.owner, result.object_force)
	result.power = "Iron" if pulling else "Steel"
	return result
