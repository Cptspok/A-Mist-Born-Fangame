class_name InventoryGrid
extends Control

var inventory: InventoryComponent
var equipment: EquipmentComponent
var cell_size := 72.0
var gap := 4.0
var hover_cell := Vector2i(-1, -1)
signal stack_clicked(stack: ItemStack, position: Vector2)
signal stack_hovered(stack: ItemStack, position: Vector2)

func configure(component: InventoryComponent, size_per_cell: float, cell_gap: float) -> void:
	if inventory != null and inventory.contents_changed.is_connected(queue_redraw):
		inventory.contents_changed.disconnect(queue_redraw)
	inventory = component
	equipment = inventory.get_parent().get_node("Equipment") as EquipmentComponent
	cell_size = size_per_cell
	gap = cell_gap
	custom_minimum_size = Vector2(inventory.grid_width, inventory.grid_height) * (cell_size + gap)
	size = custom_minimum_size
	inventory.contents_changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if inventory == null: return
	for y in inventory.grid_height:
		for x in inventory.grid_width:
			draw_rect(Rect2(_cell_to_pixel(Vector2i(x,y)), Vector2(cell_size,cell_size)), Color("38414f"))
	for stack in inventory.stacks:
		var rect := Rect2(_cell_to_pixel(stack.grid_position), Vector2(stack.definition.grid_width, stack.definition.grid_height) * (cell_size + gap) - Vector2(gap, gap))
		draw_rect(rect, Color("20252d"))
		if stack.definition.inventory_sprite: draw_texture_rect(stack.definition.inventory_sprite, rect.grow(-6), false)
		draw_string(get_theme_default_font(), rect.position + Vector2(5,18), stack.definition.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var data: Variant = get_viewport().gui_get_drag_data()
	if data is Dictionary and data.get("inventory") == inventory and get_global_rect().has_point(get_global_mouse_position()):
		var stack: ItemStack = data.stack
		var valid := _valid_grid_drop(data, hover_cell)
		var rect := Rect2(_cell_to_pixel(hover_cell), Vector2(stack.definition.grid_width, stack.definition.grid_height) * (cell_size + gap) - Vector2(gap, gap))
		draw_rect(rect, Color(0.3,1,0.4,0.5) if valid else Color(1,0.2,0.2,0.5))

func _get_drag_data(at_position: Vector2) -> Variant:
	var cell := _pixel_to_cell(at_position)
	var stack := _stack_at(cell)
	if stack == null: return null
	var label := Label.new()
	label.text = stack.definition.display_name
	set_drag_preview(label)
	stack_hovered.emit(null, Vector2.ZERO)
	return {"stack": stack, "inventory": inventory, "offset": cell - stack.grid_position, "source_slot": -1}

func _valid_grid_drop(data: Dictionary, cell: Vector2i) -> bool:
	var stack: ItemStack = data.stack
	if equipment.slot_of(stack) >= 0: return equipment.preview(stack, -1, cell).valid
	return stack in inventory.stacks and inventory.can_place(stack.definition, cell, stack)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or data.get("inventory") != inventory: return false
	hover_cell = _pixel_to_cell(at_position) - data.offset
	queue_redraw()
	return _valid_grid_drop(data, hover_cell)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var cell := _pixel_to_cell(at_position) - Vector2i(data.offset)
	if equipment.slot_of(data.stack) >= 0: equipment.transfer(data.stack, -1, cell)
	else: inventory.try_move(data.stack, cell)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END: queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if inventory == null: return
	if event is InputEventMouseMotion:
		stack_hovered.emit(_stack_at(_pixel_to_cell(event.position)), get_global_mouse_position())
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var stack := _stack_at(_pixel_to_cell(event.position))
		if stack != null: stack_clicked.emit(stack, get_global_mouse_position())

func _stack_at(cell: Vector2i) -> ItemStack:
	for stack in inventory.stacks:
		var p := stack.grid_position
		if Rect2i(p, Vector2i(stack.definition.grid_width, stack.definition.grid_height)).has_point(cell): return stack
	return null
func _cell_to_pixel(cell: Vector2i) -> Vector2: return Vector2(cell) * (cell_size + gap)
func _pixel_to_cell(pixel: Vector2) -> Vector2i: return Vector2i(floor(pixel.x / (cell_size + gap)), floor(pixel.y / (cell_size + gap)))
