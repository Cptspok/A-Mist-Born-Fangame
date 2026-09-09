class_name InputHint
extends RefCounted

static func binding(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	var event: InputEvent = events[0]
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
	return event.as_text()
