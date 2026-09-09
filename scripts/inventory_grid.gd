class_name InventoryGrid
extends Control

var inventory: InventoryComponent
var equipment: PlayerCombat
var cell_size := 72.0
var gap := 4.0
var dragging: ItemStack
var drag_offset := Vector2i.ZERO
var drag_moved := false
signal stack_clicked(stack: ItemStack, position: Vector2)
signal stack_hovered(stack: ItemStack, position: Vector2)

func configure(component: InventoryComponent, size_per_cell: float, cell_gap: float) -> void:
	if is_instance_valid(inventory) and inventory.contents_changed.is_connected(queue_redraw):
		inventory.contents_changed.disconnect(queue_redraw)
	if is_instance_valid(equipment) and equipment.equipment_changed.is_connected(queue_redraw):
		equipment.equipment_changed.disconnect(queue_redraw)
	inventory = component
	equipment = inventory.get_parent().get_node_or_null("CombatEquipment") as PlayerCombat
	if equipment != null:
		equipment.equipment_changed.connect(queue_redraw)
	cell_size = size_per_cell
	gap = cell_gap
	custom_minimum_size = Vector2(inventory.grid_width, inventory.grid_height) * (cell_size + gap)
	inventory.contents_changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if inventory == null: return
	for y in inventory.grid_height:
		for x in inventory.grid_width:
			draw_rect(Rect2(_cell_to_pixel(Vector2i(x,y)), Vector2(cell_size,cell_size)), Color("38414f"), true)
	for stack in inventory.stacks:
		if stack == dragging: continue
		_draw_stack(stack, stack.grid_position, Color.WHITE)
	if dragging != null:
		var pos := _pixel_to_cell(get_local_mouse_position()) - drag_offset
		var valid := inventory.can_place(dragging.definition, pos, dragging)
		_draw_stack(dragging, pos, Color(0.7,1,0.7,0.8) if valid else Color(1,0.5,0.5,0.8))

func _draw_stack(stack: ItemStack, pos: Vector2i, tint: Color) -> void:
	var rect := Rect2(_cell_to_pixel(pos), Vector2(stack.definition.grid_width * (cell_size + gap) - gap, stack.definition.grid_height * (cell_size + gap) - gap))
	draw_rect(rect, Color("20252d"), true)
	if stack.definition.inventory_sprite: draw_texture_rect(stack.definition.inventory_sprite, rect.grow(-6), false, tint)
	draw_string(get_theme_default_font(), rect.position + Vector2(5,18), stack.definition.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if equipment != null:
		for slot in [PlayerCombat.Slot.MAIN, PlayerCombat.Slot.SECONDARY]:
			if equipment.get_equipped_stack(slot) == stack:
				var badge := Rect2(Vector2(rect.position.x, rect.end.y - 34), Vector2(rect.size.x, 34))
				draw_rect(badge, Color("21483e"))
				draw_string(get_theme_default_font(), badge.position + Vector2(3, 13), "Equipped", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
				draw_string(get_theme_default_font(), badge.position + Vector2(3, 28), "Main" if slot == PlayerCombat.Slot.MAIN else "Secondary", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	if inventory == null: return
	if event is InputEventMouseMotion:
		if dragging != null and event.relative.length() > 0.0: drag_moved = true
		var stack := _stack_at(_pixel_to_cell(event.position))
		stack_hovered.emit(stack, get_global_mouse_position())
		if dragging != null: queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var cell := _pixel_to_cell(event.position)
			dragging = _stack_at(cell)
			if dragging != null: drag_offset = cell - dragging.grid_position
		else:
			if dragging != null and drag_moved:
				var drop := _pixel_to_cell(event.position) - drag_offset
				inventory.try_move(dragging, drop)
				dragging = null
				queue_redraw()
			else:
				var clicked := dragging if dragging != null else _stack_at(_pixel_to_cell(event.position))
				dragging = null
				if clicked != null: stack_clicked.emit(clicked, get_global_mouse_position())
			drag_moved = false

func drop_outside() -> void:
	if dragging != null:
		inventory.request_throw(dragging)
		dragging = null
		queue_redraw()

func _stack_at(cell: Vector2i) -> ItemStack:
	for stack in inventory.stacks:
		var p := stack.grid_position
		if cell.x >= p.x and cell.x < p.x + stack.definition.grid_width and cell.y >= p.y and cell.y < p.y + stack.definition.grid_height: return stack
	return null
func _cell_to_pixel(cell: Vector2i) -> Vector2: return Vector2(cell) * (cell_size + gap)
func _pixel_to_cell(pixel: Vector2) -> Vector2i: return Vector2i(floor(pixel.x / (cell_size + gap)), floor(pixel.y / (cell_size + gap)))
