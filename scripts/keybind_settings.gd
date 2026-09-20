extends Node
## Curated player profile. Gameplay reads InputMap, never this file.
signal changed
const PATH := "user://keybinds.cfg"
const GROUPS := {
	"Movement": [["move_forward", "Move Forward", KEY_Z], ["move_backward", "Move Backward", KEY_S], ["move_left", "Move Left", KEY_Q], ["move_right", "Move Right", KEY_D], ["jump", "Jump", KEY_SPACE], ["crouch", "Crouch", KEY_CTRL]],
	"Interaction / UI": [["interact", "Interact", KEY_F], ["toggle_inventory", "Inventory", KEY_I], ["previous_tab", "Previous Tab", KEY_A], ["next_tab", "Next Tab", KEY_E], ["pause", "Pause", KEY_ESCAPE]],
	"Combat": [["primary_action", "Primary Action", -MOUSE_BUTTON_LEFT], ["secondary_action", "Secondary Action", -MOUSE_BUTTON_RIGHT]],
	"Allomancy": [["metal_wheel", "Metal Wheel", KEY_SHIFT], ["allomancy_focus", "Allomancy Focus", KEY_C]]
}
# These still have live consumers. Never erase or silently overlap their events.
# ui_* and advance_dialogue are context-specific fixed navigation. ability_1/2
# are reserved hooks with no connected ability, and are intentionally unchanged.
const RESERVED := {"weapon_slot_1": "Weapon Slot 1", "weapon_slot_2": "Weapon Slot 2", "weapon_next": "Next Weapon", "weapon_previous": "Previous Weapon", "reset_test": "Reset Test", "toggle_allomancy_debug": "Allomancy Debug"}
var preset := "AZERTY"
var slots: Dictionary = {}
var save_error := ""

func _ready() -> void:
	_defaults("AZERTY")
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		var saved_preset: String = str(config.get_value("profile", "preset", "AZERTY"))
		_defaults(saved_preset if saved_preset in ["AZERTY", "QWERTY"] else "AZERTY")
		for action in slots:
			var saved: Variant = config.get_value("bindings", action, slots[action])
			if not saved is Array or saved.size() != 2: continue
			if not _valid(saved[0]) or not _valid(saved[1]): continue
			slots[action] = saved
	_apply()

func _defaults(profile: String) -> void:
	preset = profile
	slots.clear()
	for entries in GROUPS.values():
		for entry in entries:
			var code: int = entry[2]
			if profile == "QWERTY":
				match entry[0]:
					"move_forward": code = KEY_W
					"move_left": code = KEY_A
					"previous_tab": code = KEY_Q
			var value: Dictionary = {"kind": "mouse", "code": -code} if code < 0 else {"kind": "key", "code": code, "location": KEY_LOCATION_LEFT if code in [KEY_SHIFT, KEY_CTRL] else KEY_LOCATION_UNSPECIFIED}
			slots[entry[0]] = [value, {}]

func apply_preset(profile: String) -> void:
	_defaults(profile if profile in ["AZERTY", "QWERTY"] else "AZERTY")
	_commit()

func display_name(action: String) -> String:
	for entries in GROUPS.values():
		for entry in entries:
			if entry[0] == action: return entry[1]
	return "Action"

func _valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if not value.get("code") is int: return false
	if value.get("kind") == "mouse": return value.code >= MOUSE_BUTTON_LEFT and value.code <= MOUSE_BUTTON_XBUTTON2
	if value.get("kind") == "key":
		return value.code > 0 and value.get("location", 0) in [KEY_LOCATION_UNSPECIFIED, KEY_LOCATION_LEFT, KEY_LOCATION_RIGHT]
	return false

func from_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode != 0:
		# Layout-aware single keys; modifier keys themselves are supported.
		return {"kind": "key", "code": int(event.keycode), "location": int(event.location)}
	if event is InputEventMouseButton and event.pressed:
		var value := {"kind": "mouse", "code": int(event.button_index)}
		if _valid(value): return value
	return {}

func to_event(value: Dictionary) -> InputEvent:
	if value.is_empty(): return null
	if value.kind == "key":
		var event := InputEventKey.new()
		event.keycode = value.code
		event.location = value.get("location", KEY_LOCATION_UNSPECIFIED)
		return event
	if value.kind == "mouse":
		var event := InputEventMouseButton.new()
		event.button_index = value.code
		return event
	return null

func overlaps(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty(): return false
	if a.kind != b.kind or a.code != b.code: return false
	return a.kind == "mouse" or a.get("location", 0) == 0 or b.get("location", 0) == 0 or a.location == b.location

func conflicts(action: String, slot: int, value: Dictionary) -> Array:
	var found: Array = []
	for other in slots:
		for index in 2:
			if other == action and index == slot: continue
			if overlaps(value, slots[other][index]): found.append([other, index])
	return found

func reserved_name(value: Dictionary) -> String:
	if value.is_empty(): return ""
	for action in RESERVED:
		for event in InputMap.action_get_events(action):
			var existing: Dictionary = {}
			if event is InputEventKey:
				existing = {"kind": "key", "code": int(event.keycode if event.keycode != 0 else DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)), "location": int(event.location)}
			elif event is InputEventMouseButton:
				existing = {"kind": "mouse", "code": int(event.button_index)}
			if overlaps(value, existing): return RESERVED[action]
	return ""

func unbound_after(action: String, slot: int, value: Dictionary) -> Array[String]:
	var proposed: Dictionary = slots.duplicate(true)
	for conflict in conflicts(action, slot, value): proposed[conflict[0]][conflict[1]] = {}
	proposed[action][slot] = value
	var result: Array[String] = []
	for id in proposed:
		if proposed[id][0].is_empty() and proposed[id][1].is_empty() and not (slots[id][0].is_empty() and slots[id][1].is_empty()): result.append(display_name(id))
	return result

## UI has already confirmed conflicts and any newly unbound actions.
func set_binding(action: String, slot: int, value: Dictionary) -> void:
	if not slots.has(action) or slot not in [0, 1] or not _valid(value) or not reserved_name(value).is_empty(): return
	for conflict in conflicts(action, slot, value): slots[conflict[0]][conflict[1]] = {}
	slots[action][slot] = value.duplicate()
	_commit()

func _apply() -> void:
	for action in slots:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
		InputMap.action_erase_events(action)
		for value in slots[action]:
			var event := to_event(value)
			if event != null and not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)

func _commit() -> void:
	_apply()
	var config := ConfigFile.new()
	config.set_value("profile", "version", 1)
	config.set_value("profile", "preset", preset)
	for action in slots: config.set_value("bindings", action, slots[action])
	var error := config.save(PATH)
	save_error = "" if error == OK else "Applied for this session, but saving failed (%s)." % error
	if error != OK: push_warning(save_error)
	get_tree().call_group("input_binding_hints", "refresh_bindings")
	changed.emit()
