class_name IronPull
extends RefCounted

func apply(player: PlayerController, tether: MetalTetherComponent, tuning: AllomancyTuning) -> Dictionary:
	return AllomancyInteraction.apply(player, tether, tuning, true)
