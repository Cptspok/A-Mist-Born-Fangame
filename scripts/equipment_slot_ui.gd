class_name EquipmentSlotUI
extends Panel

var equipment: EquipmentComponent
var slot: int
var text: Label
var cross: Label
signal preview_changed(plan: Dictionary, target: int)
signal preview_cleared

func configure(component: EquipmentComponent, slot_id: int) -> void:
	equipment = component
	slot = slot_id
	custom_minimum_size = Vector2(190, 125)
	text = Label.new()
	text.position = Vector2(10, 10)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text)
	cross = Label.new()
	cross.text = "X"
	cross.add_theme_font_size_override("font_size", 65)
	cross.add_theme_color_override("font_color", Color.RED)
	cross.position = Vector2(135, 30)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cross)
	equipment.equipment_changed.connect(refresh)
	mouse_exited.connect(func(): preview_cleared.emit())
	refresh()

func refresh() -> void:
	var stack := equipment.get_equipped_stack(slot)
	text.text = EquipmentSlots.label(slot) + "\n\n" + (stack.definition.display_name if stack != null else equipment.slot_status(slot))
	set_preview(Color("526174"), false)

func set_preview(color: Color, conflict: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("20252d")
	style.border_color = color
	style.set_border_width_all(3)
	add_theme_stylebox_override("panel", style)
	cross.visible = conflict

func _get_drag_data(_position: Vector2) -> Variant:
	var stack := equipment.get_equipped_stack(slot)
	if stack == null: return null
	var label := Label.new()
	label.text = stack.definition.display_name
	set_drag_preview(label)
	return {"stack": stack, "inventory": equipment.inventory, "offset": Vector2i.ZERO, "source_slot": slot}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or data.get("inventory") != equipment.inventory: return false
	var plan := equipment.preview(data.stack, slot)
	preview_changed.emit(plan, slot)
	return plan.valid

func _drop_data(_position: Vector2, data: Variant) -> void:
	equipment.transfer(data.stack, slot)
	preview_cleared.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END: preview_cleared.emit()
