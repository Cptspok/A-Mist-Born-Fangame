extends CanvasLayer
signal action_requested(action: String)
var backdrop: ColorRect
var center: CenterContainer
var panel: PanelContainer
var rows: VBoxContainer
var scroll: ScrollContainer
var controls: ControlsSettingsView

func _ready() -> void:
	layer = 100
	backdrop = ColorRect.new()
	backdrop.color = Color(0.035, 0.045, 0.06, 0.96)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 12)
	scroll.add_child(rows)
	get_viewport().size_changed.connect(_resize)
	_resize()

func _resize() -> void:
	var size := get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(minf(650, size.x - 32), minf(700, size.y - 32))

func show_page(page: String, back: String) -> void:
	controls = null
	show()
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	match page:
		"main":
			_title("MISTBORN PROTOTYPE")
			_label("Playtest v0.0.2")
			_buttons([["Play", "hub"], ["Settings", "settings"], ["Controls", "controls"], ["Quit", "quit"]])
		"destinations":
			_title("PLAYTEST")
			_label("Movement Lab: forgiving practice.\nAdvanced Traversal: precision and momentum.")
			_buttons([["Movement Lab", "lab"], ["Advanced Traversal", "advanced"], ["Back", "main"]])
		"pause":
			_title("PAUSED")
			_buttons([["Resume", "resume"], ["Settings", "settings"], ["Controls", "controls"], ["Restart Test", "restart"], ["Main Menu", "main"], ["Quit", "quit"]])
		"intro":
			_title("CONTROLS")
			_label(PlaytestControls.text(true))
			#_label("Visible metal offers Steel/Iron opportunities. Gold feedback shows the selected target.\nSteel pushes away; Iron pulls toward. Release to keep momentum.\nPause offers Restart Test whenever you need a fresh start.")
			_buttons([["Start", "resume"]])
		"controls":
			_title("CONTROLS")
			controls = ControlsSettingsView.new()
			rows.add_child(controls)
			_buttons([["Back", back]])
		"settings":
			_title("SETTINGS")
			_slider("Mouse sensitivity", "sensitivity", 0.01, 0.5, 0.01)
			_slider("Master volume", "master", 0, 1, 0.01)
			_slider("Music volume", "music", 0, 1, 0.01)
			_slider("SFX volume", "sfx", 0, 1, 0.01)
			_label("Focus behavior")
			var focus_mode := OptionButton.new()
			focus_mode.add_item("Toggle")
			focus_mode.add_item("Hold")
			focus_mode.selected = 1 if PlaytestSettings.focus_mode == "hold" else 0
			focus_mode.item_selected.connect(func(index: int): PlaytestSettings.update("focus_mode", "hold" if index == 1 else "toggle"))
			rows.add_child(focus_mode)
			var display := OptionButton.new()
			display.add_item("Windowed")
			display.add_item("Fullscreen")
			display.selected = 1 if PlaytestSettings.fullscreen else 0
			display.item_selected.connect(func(index: int): PlaytestSettings.update("fullscreen", index == 1))
			rows.add_child(display)
			_buttons([["Back", back]])
	for child in rows.get_children():
		if child is Button:
			child.grab_focus()
			break
	scroll.set_deferred("scroll_vertical", 0)

func _title(value: String) -> void:
	var title := _label(value)
	title.add_theme_font_size_override("font_size", 28)

func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(label)
	return label

func _buttons(entries: Array) -> void:
	for entry in entries:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 42
		button.pressed.connect(func(): action_requested.emit(entry[1]))
		rows.add_child(button)

func _slider(title: String, key: String, low: float, high: float, step: float) -> void:
	var label := _label("%s: %.2f" % [title, PlaytestSettings.get(key)])
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = PlaytestSettings.get(key)
	slider.custom_minimum_size.y = 32
	slider.value_changed.connect(func(value: float):
		PlaytestSettings.update(key, value)
		label.text = "%s: %.2f" % [title, value])
	rows.add_child(slider)
