class_name ControlsSettingsView
extends VBoxContainer
## Embedded in the existing menu; the shell forwards input before pause routing.
var capturing := false
var _action := ""
var _slot := 0
var _buttons: Dictionary = {}
var _status: Label
var _confirmation: ConfirmationDialog
var _pending: Callable

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var presets := HBoxContainer.new()
	add_child(presets)
	for profile in ["AZERTY", "QWERTY"]:
		var button := Button.new()
		button.text = "Apply " + profile + " Defaults"
		button.pressed.connect(func(): _confirm_preset(profile))
		presets.add_child(button)
	var reset := Button.new()
	reset.text = "Reset to Defaults"
	reset.pressed.connect(func(): _confirm_preset(KeybindSettings.preset))
	add_child(reset)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	for category in KeybindSettings.GROUPS:
		var heading := Label.new()
		heading.text = category
		heading.add_theme_font_size_override("font_size", 22)
		add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 8)
		add_child(grid)
		for text in ["Action", "Primary", "", "Secondary", ""]:
			var label := Label.new()
			label.text = text
			grid.add_child(label)
		for entry in KeybindSettings.GROUPS[category]:
			var action: String = entry[0]
			var label := Label.new()
			label.text = entry[1]
			label.custom_minimum_size.x = 145
			grid.add_child(label)
			_buttons[action] = []
			for slot in 2:
				var button := Button.new()
				button.custom_minimum_size = Vector2(120, 34)
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				button.pressed.connect(func(): _capture(action, slot))
				grid.add_child(button)
				_buttons[action].append(button)
				var clear := Button.new()
				clear.text = "X"
				clear.tooltip_text = "Clear " + entry[1] + (" Primary" if slot == 0 else " Secondary")
				clear.pressed.connect(func(): _propose(action, slot, {}))
				grid.add_child(clear)
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Confirm binding change"
	_confirmation.dialog_autowrap = true
	_confirmation.min_size = Vector2i(460, 180)
	_confirmation.confirmed.connect(func():
		var callback := _pending
		_pending = Callable()
		if callback.is_valid(): callback.call())
	_confirmation.canceled.connect(func(): _pending = Callable())
	add_child(_confirmation)
	KeybindSettings.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	for action in _buttons:
		for slot in 2:
			_buttons[action][slot].text = InputHint.event_name(KeybindSettings.to_event(KeybindSettings.slots[action][slot]))
	_status.text = "Profile: %s. Select a slot, then press a key or mouse button. X clears. Escape cancels capture. Mouse clicks and Escape remain available for menus." % KeybindSettings.preset
	if not KeybindSettings.save_error.is_empty(): _status.text += "\n" + KeybindSettings.save_error

func _capture(action: String, slot: int) -> void:
	_action = action
	_slot = slot
	capturing = true
	_status.text = "%s / %s: Press a key or mouse button... (Escape cancels)" % [KeybindSettings.display_name(action), "Primary" if slot == 0 else "Secondary"]
	_buttons[action][slot].text = "Waiting..."

func handle_input(event: InputEvent) -> bool:
	# Returning true also prevents the shell from treating a candidate as Pause.
	if _confirmation.visible: return true
	if not capturing: return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		capturing = false
		_refresh()
	else:
		var value := KeybindSettings.from_event(event)
		if not value.is_empty():
			capturing = false
			_refresh()
			_propose(_action, _slot, value)
	get_viewport().set_input_as_handled()
	return true

func _propose(action: String, slot: int, value: Dictionary) -> void:
	var reserved := KeybindSettings.reserved_name(value)
	if not reserved.is_empty():
		_status.text = "%s is reserved for %s. Choose another input; its internal binding has not changed." % [InputHint.event_name(KeybindSettings.to_event(value)), reserved]
		return
	var conflicts := KeybindSettings.conflicts(action, slot, value)
	var unbound := KeybindSettings.unbound_after(action, slot, value)
	var message := ""
	for conflict in conflicts:
		message += "%s is already bound to %s (%s).\n" % [InputHint.event_name(KeybindSettings.to_event(value)), KeybindSettings.display_name(conflict[0]), "Primary" if conflict[1] == 0 else "Secondary"]
	if not conflicts.is_empty(): message += "Replace those exact bindings? Other slots will stay unchanged.\n"
	if not unbound.is_empty(): message += "This leaves %s completely unbound. Continue?" % ", ".join(unbound)
	var apply := func(): KeybindSettings.set_binding(action, slot, value)
	if message.is_empty(): apply.call()
	else: _confirm(message, apply, "Replace" if not conflicts.is_empty() else "Clear Anyway")

func _confirm(message: String, callback: Callable, confirm_text: String) -> void:
	_pending = callback
	_confirmation.dialog_text = message
	_confirmation.ok_button_text = confirm_text
	_confirmation.popup_centered()

func _confirm_preset(profile: String) -> void:
	_confirm("Replace all custom bindings with %s defaults?" % profile, func(): KeybindSettings.apply_preset(profile), "Apply Defaults")
