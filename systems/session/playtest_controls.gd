class_name PlaytestControls
extends RefCounted
const GROUPS := {
	"MOVEMENT": [["move_forward", "Forward"], ["move_backward", "Backward"], ["move_left", "Left"], ["move_right", "Right"], ["crouch", "Crouch (hold)"], ["jump", "Jump"], ["interact", "Interact"]],
	"ALLOMANCY": [["metal_wheel", "Metal wheel (hold; click to toggle burns)"], ["allomancy_focus", "Focus"], ["primary_action", "Focused Steelpush (Steel burning)"], ["secondary_action", "Focused Ironpull (Iron burning)"]],
	"COMBAT": [["primary_action", "Primary Action"], ["secondary_action", "Secondary Action"], ["weapon_slot_1", "Weapon Slot 1"], ["weapon_slot_2", "Weapon Slot 2"], ["weapon_next", "Weapon Next"], ["weapon_previous", "Weapon Previous"], ["ability_1", "Ability 1 (reserved)"], ["ability_2", "Ability 2 (reserved)"]],
	"GAMEPLAY": [["toggle_inventory", "Inventory"], ["previous_tab", "Previous Tab"], ["next_tab", "Next Tab"], ["pause", "Pause"]],
	"DEVELOPER": [["toggle_allomancy_debug", "Allomancy Debug"], ["reset_test", "Reset Test"]]
}

static func text(intro := false) -> String:
	var result := ""
	for heading in GROUPS:
		if intro and heading in ["COMBAT", "DEVELOPER"]: continue
		result += heading + "\n"
		for entry in GROUPS[heading]:
			if InputMap.has_action(entry[0]):
				var label: String = entry[1]
				if entry[0] == "allomancy_focus": label += " (%s)" % PlaytestSettings.focus_mode
				result += "%s — %s\n" % [label, InputHint.binding(entry[0])]
		result += "\n"
	return result
