extends CanvasLayer

@export_range(0.5, 0.95, 0.05) var panel_screen_ratio := 0.8
@export_range(32, 128, 1) var cell_size := 72.0
@export_range(0, 16, 1) var cell_gap := 4.0
var panel: PanelContainer
var grid: InventoryGrid
var menu: PopupPanel
var tooltip: Label
var selected_stack: ItemStack
var cursor_dot: InventoryCursor
var close_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle(); get_viewport().set_input_as_handled(); return
	if not visible: return
	if event.is_action_pressed("ui_cancel"):
		close(); get_viewport().set_input_as_handled(); return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if grid.dragging != null and not panel.get_global_rect().has_point(event.position): grid.drop_outside()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and menu.visible and not menu.get_global_rect().has_point(event.position): menu.hide()

func _process(_delta: float) -> void:
	if visible: cursor_dot.global_position = get_viewport().get_mouse_position() - Vector2(7, 7)

func toggle() -> void:
	if visible: close()
	else: open()
func open() -> void:
	var inventory := get_tree().get_first_node_in_group("inventory_components") as InventoryComponent
	if inventory == null: return
	grid.configure(inventory, cell_size, cell_gap)
	var viewport_size := get_viewport().get_visible_rect().size
	panel.size = viewport_size * panel_screen_ratio
	panel.position = (viewport_size - panel.size) * 0.5
	close_button.position = Vector2(panel.size.x - 58, 14)
	show(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; get_tree().paused = true
func close() -> void:
	menu.hide(); tooltip.hide(); hide(); get_tree().paused = false

func _build_ui() -> void:
	panel = PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.size = Vector2(900,650); panel.position = -panel.size * 0.5
	var style := StyleBoxFlat.new(); style.bg_color = Color("161b24"); style.border_color = Color("8391a5"); style.set_border_width_all(2); panel.add_theme_stylebox_override("panel", style); add_child(panel)
	var title := Label.new(); title.text="Inventory"; title.position=Vector2(24,18); title.add_theme_font_size_override("font_size",28); panel.add_child(title)
	close_button = Button.new(); close_button.text="X"; close_button.position=Vector2(842,14); close_button.size=Vector2(42,42); close_button.pressed.connect(close); panel.add_child(close_button)
	grid = InventoryGrid.new(); grid.position=Vector2(40,90); grid.mouse_filter=Control.MOUSE_FILTER_STOP; grid.stack_clicked.connect(_show_menu); grid.stack_hovered.connect(_show_tooltip); panel.add_child(grid)
	menu=PopupPanel.new(); var menu_box:=VBoxContainer.new(); menu.add_child(menu_box)
	for action in ["Equip","Use","Throw","Read"]:
		var button:=Button.new(); button.text=action; button.custom_minimum_size=Vector2(120,32); button.pressed.connect(_menu_action.bind(action)); menu_box.add_child(button)
	panel.add_child(menu)
	tooltip=Label.new(); tooltip.mouse_filter=Control.MOUSE_FILTER_IGNORE; tooltip.add_theme_color_override("font_color",Color.WHITE); var tip_style:=StyleBoxFlat.new(); tip_style.bg_color=Color("111111"); tip_style.content_margin_left=8; tip_style.content_margin_right=8; tip_style.content_margin_top=6; tip_style.content_margin_bottom=6; tooltip.add_theme_stylebox_override("normal",tip_style); panel.add_child(tooltip); tooltip.hide()
	cursor_dot=InventoryCursor.new(); cursor_dot.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(cursor_dot)

func _show_menu(stack: ItemStack, position: Vector2) -> void:
	selected_stack=stack; menu.position=Vector2i(panel.get_local_mouse_position()); menu.popup()
func _menu_action(action: String) -> void:
	if action == "Throw" and selected_stack != null: grid.inventory.request_throw(selected_stack)
	else: print(action + " is not implemented yet.")
	menu.hide()
func _show_tooltip(stack: ItemStack, position: Vector2) -> void:
	if stack == null: tooltip.hide(); return
	tooltip.text=stack.definition.display_name+"\n"+stack.definition.characteristics+"\n"+stack.definition.description; tooltip.position=panel.get_local_mouse_position()+Vector2(18,18); tooltip.show()
