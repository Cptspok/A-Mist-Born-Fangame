class_name StatIds
extends RefCounted

enum Stat { MAX_HEALTH, MOVE_SPEED, ARMOR, PHYSICAL_DAMAGE, ATTACK_SPEED, JUMP_MULTIPLIER, MELEE_IMPULSE, EXTERNAL_FORCE_MULTIPLIER }
const DEFAULTS := {
	Stat.MAX_HEALTH: 100.0, Stat.MOVE_SPEED: 10.0, Stat.ARMOR: 0.0,
	Stat.PHYSICAL_DAMAGE: 0.0, Stat.ATTACK_SPEED: 1.0,
	Stat.JUMP_MULTIPLIER: 1.0, Stat.MELEE_IMPULSE: 0.0, Stat.EXTERNAL_FORCE_MULTIPLIER: 1.0,
}

static func minimum(stat: Stat) -> float:
	if stat == Stat.MAX_HEALTH: return 0.1
	if stat == Stat.ATTACK_SPEED: return 0.01
	return 0.0

static func label(stat: Stat) -> String:
	return Stat.keys()[stat].capitalize()
