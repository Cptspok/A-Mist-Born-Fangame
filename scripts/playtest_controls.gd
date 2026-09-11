class_name PlaytestControls
extends RefCounted
const GROUPS := {
	"MOVEMENT": [["move_forward", "Forward"], ["move_backward", "Backward"], ["move_left", "Left"], ["move_right", "Right"], ["sprint", "Sprint"], ["jump", "Jump"], ["interact", "Interact"]],
	"ALLOMANCY": [["steel_push", "Steelpush"], ["iron_pull", "Ironpull"]],
	"COMBAT": [["primary_action", "Primary Action"], ["secondary_action", "Secondary Action"], ["weapon_slot_1", "Weapon Slot 1"], ["weapon_slot_2", "Weapon Slot 2"], ["weapon_next", "Weapon Next"], ["weapon_previous", "Weapon Previous"], ["ability_1", "Ability 1"], ["ability_2", "Ability 2"]],
	"GAMEPLAY": [["toggle_inventory", "Inventory"], ["pause", "Pause"]],
	"DEVELOPER": [["toggle_allomancy_debug", "Allomancy Debug"], ["reset_test", "Reset Test"]]
}

static func text(intro := false) -> String:
	var result := ""
	for heading in GROUPS:
		if intro and heading in ["COMBAT", "DEVELOPER"]: continue
		result += heading + "\n"
		for entry in GROUPS[heading]:
			if InputMap.has_action(entry[0]):
				result += "%s — %s\n" % [entry[1], InputHint.binding(entry[0])]
		result += "\n"
	return result
