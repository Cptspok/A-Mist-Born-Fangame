class_name InputHint
extends RefCounted

## InputMap order is Primary then Secondary; empty slots add no event.
static func binding(action: StringName) -> String:
	if not InputMap.has_action(action): return "Unbound"
	var events := InputMap.action_get_events(action)
	return "Unbound" if events.is_empty() else event_name(events[0])

static func event_name(event: InputEvent) -> String:
	if event == null: return "Unbound"
	if event is InputEventKey:
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		var side := "Left " if event.location == KEY_LOCATION_LEFT else ("Right " if event.location == KEY_LOCATION_RIGHT else "")
		return side + OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			MOUSE_BUTTON_WHEEL_LEFT: return "Wheel Left"
			MOUSE_BUTTON_WHEEL_RIGHT: return "Wheel Right"
			MOUSE_BUTTON_XBUTTON1: return "Mouse4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse5"
	return event.as_text()
