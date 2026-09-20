extends CanvasLayer

@export_range(32, 128, 1) var cell_size := 72.0
@export_range(0, 16, 1) var cell_gap := 4.0
var tabs: TabContainer
var _tab_title: Label
var intelligence_view: IntelligenceView
var panel: PanelContainer
var grid: InventoryGrid
var slots_box: GridContainer
var slot_controls: Array[EquipmentSlotUI] = []
var stat_display: StatDebugDisplay
var tooltip: Label
var status: Label
var menu: PopupMenu
var selected_stack: ItemStack
var equipment: EquipmentComponent
var _previous_mouse_mode: Input.MouseMode

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.position = Vector2(24, 24)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var title := Label.new()
	_tab_title = title
	_update_tab_hint()
	KeybindSettings.changed.connect(_update_tab_hint)
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	tabs = TabContainer.new()
	column.add_child(tabs)
	var row := HBoxContainer.new()
	row.name = "Inventory"
	row.add_theme_constant_override("separation", 25)
	tabs.add_child(row)
	intelligence_view = IntelligenceView.new()
	intelligence_view.name = "Intelligence"
	tabs.add_child(intelligence_view)
	tabs.tab_changed.connect(_tab_changed)
	grid = InventoryGrid.new()
	grid.stack_clicked.connect(_show_menu)
	grid.stack_hovered.connect(_show_tooltip)
	var inventory_column := VBoxContainer.new()
	row.add_child(inventory_column)
	var inventory_title := Label.new()
	inventory_title.text = "INVENTORY"
	inventory_column.add_child(inventory_title)
	inventory_column.add_child(grid)
	stat_display = StatDebugDisplay.new()
	stat_display.add_theme_font_size_override("font_size", 14)
	stat_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_column.add_child(stat_display)
	var divider := VSeparator.new()
	row.add_child(divider)
	var equipment_column := VBoxContainer.new()
	row.add_child(equipment_column)
	var equipment_title := Label.new()
	equipment_title.text = "EQUIPMENT"
	equipment_column.add_child(equipment_title)
	slots_box = GridContainer.new()
	slots_box.columns = 3
	slots_box.add_theme_constant_override("h_separation", 10)
	slots_box.add_theme_constant_override("v_separation", 10)
	equipment_column.add_child(slots_box)
	status = Label.new()
	status.text = "Drag to equip, return to grid, or outside this panel to drop. Right-click for actions."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 560
	column.add_child(status)
	var legend := Label.new()
	legend.text = "Green: valid   Red: invalid   Amber / X: returns to inventory"
	column.add_child(legend)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	column.add_child(close_button)
	tooltip = Label.new()
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip.custom_minimum_size.x = 300
	inventory_column.add_child(tooltip)
	menu = PopupMenu.new()
	menu.id_pressed.connect(_menu_action)
	add_child(menu)
	get_viewport().size_changed.connect(func(): _fit_panel.call_deferred())
	hide()

func _input(event: InputEvent) -> void:
	# Do not open inventory over another SceneTree pause owner (shell menus).
	if get_tree().paused and not visible: return
	if visible and not event.is_echo():
		if event.is_action_pressed("previous_tab") or event.is_action_pressed("next_tab"):
			tabs.current_tab = posmod(tabs.current_tab + (-1 if event.is_action_pressed("previous_tab") else 1), tabs.get_tab_count())
			get_viewport().set_input_as_handled()
			return
	if visible and event is InputEventMouseButton and get_viewport().gui_is_dragging():
		_drop_drag_outside(event)
	if event.is_action_pressed("toggle_inventory"):
		if visible: close()
		else: open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _drop_drag_outside(event: InputEventMouseButton) -> void:
	if event.pressed or event.canceled or event.button_index != MOUSE_BUTTON_LEFT: return
	if panel.get_global_rect().has_point(event.position): return
	if menu.visible: return
	var data: Variant = get_viewport().gui_get_drag_data()
	if not data is Dictionary or data.get("inventory") != grid.inventory: return
	var stack: ItemStack = data.get("stack")
	var source: int = data.get("source_slot", -2)
	# Cancel native drag first, so DRAG_END clears previews before any rejection.
	get_viewport().gui_cancel_drag()
	get_viewport().set_input_as_handled()
	if source == -1:
		grid.inventory.request_throw(stack)
	elif source >= 0 and equipment.get_equipped_stack(source) == stack:
		equipment.drop_to_world(stack)

func open() -> void:
	var inventory := get_tree().get_first_node_in_group("inventory_components") as InventoryComponent
	if inventory == null: return
	equipment = inventory.get_parent().get_node("Equipment") as EquipmentComponent
	grid.configure(inventory, cell_size, cell_gap)
	stat_display.configure(inventory.get_parent().get_node("StatComponent") as StatComponent)
	var dropper := inventory.get_parent().get_node("InventoryDropper") as InventoryDropper
	if not dropper.drop_rejected.is_connected(_rejected):
		dropper.drop_rejected.connect(_rejected)
	for control in slot_controls:
		slots_box.remove_child(control)
		control.queue_free()
	slot_controls.clear()
	for slot in EquipmentSlots.DISPLAY_ORDER:
		if slot not in equipment.enabled_slots: continue
		var control := EquipmentSlotUI.new()
		control.configure(equipment, slot)
		control.preview_changed.connect(_preview)
		control.preview_cleared.connect(_clear_preview)
		slots_box.add_child(control)
		slot_controls.append(control)
	if not equipment.transaction_rejected.is_connected(_rejected):
		equipment.transaction_rejected.connect(_rejected)
	intelligence_view.configure(RespawnSession.intelligence_catalog, RespawnSession.knowledge)
	_previous_mouse_mode = Input.mouse_mode
	GameplayLocks.acquire(&"inventory")
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_fit_panel.call_deferred()

func close() -> void:
	if not visible: return
	# Cancel native drag before hiding, with no transaction.
	if get_viewport().gui_is_dragging(): get_viewport().gui_cancel_drag()
	menu.hide()
	hide()
	get_tree().paused = false
	Input.mouse_mode = _previous_mouse_mode
	GameplayLocks.release(&"inventory")

func _preview(plan: Dictionary, target: int) -> void:
	for control in slot_controls:
		var color := Color("526174")
		if control.slot == target:
			color = Color("55df88") if plan.valid else Color("ed5555")
			if plan.valid and not plan.conflicts.is_empty(): color = Color("efb34e")
		control.set_preview(color, control.slot in plan.conflicts)
	status.text = plan.reason if not plan.valid else ("Release to equip; X items return to inventory." if not plan.conflicts.is_empty() else "Release to equip.")

func _clear_preview() -> void:
	for control in slot_controls: control.refresh()
	status.text = "Drag to equip, return to grid, or outside this panel to drop. Right-click for actions."

func _rejected(reason: String) -> void:
	status.text = reason

func _show_menu(stack: ItemStack, position: Vector2) -> void:
	selected_stack = stack
	menu.clear()
	if stack.definition.consumable != null:
		menu.add_item("Use", 102)
	if stack.definition.equipment_profile != null:
		menu.add_item("Equip", 101)
		menu.set_item_disabled(menu.get_item_index(101), equipment.context_destination(stack) < 0)
	menu.add_item("Throw", 100)
	menu.position = Vector2i(position)
	menu.popup()

func _menu_action(id: int) -> void:
	if id == 100: grid.inventory.request_throw(selected_stack)
	elif id == 101: equipment.equip_from_context(selected_stack)
	elif id == 102:
		if grid.inventory.try_use(selected_stack):
			status.text = "Used %s. Close inventory to resume absorption." % selected_stack.definition.display_name
			_show_tooltip(selected_stack if selected_stack in grid.inventory.stacks else null, Vector2.ZERO)
		else:
			status.text = "Cannot use this item here."


func _show_tooltip(stack: ItemStack, _position: Vector2) -> void:
	tooltip.text = "" if stack == null else stack.definition.display_name + " (x%d)\n" % stack.quantity + stack.definition.characteristics + "\n" + stack.definition.description

func _fit_panel() -> void:
	if not visible: return
	panel.scale = Vector2.ONE
	panel.reset_size()
	var available := get_viewport().get_visible_rect().size - Vector2(48, 48)
	var extent := panel.get_combined_minimum_size()
	var ratio := minf(1.0, minf(available.x / extent.x, available.y / extent.y))
	panel.scale = Vector2.ONE * maxf(0.1, ratio)

func _tab_changed(_index: int) -> void:
	if get_viewport().gui_is_dragging(): get_viewport().gui_cancel_drag()
	if menu != null: menu.hide()
	_fit_panel.call_deferred()

func _update_tab_hint() -> void:
	_tab_title.text = "Inventory & Intelligence    [%s / %s: previous / next tab]" % [InputHint.binding("previous_tab"), InputHint.binding("next_tab")]
