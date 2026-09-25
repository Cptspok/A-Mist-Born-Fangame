class_name EquipmentComponent
extends Node

signal equipment_changed
signal transaction_rejected(reason: String)
@export var enabled_slots: Array[EquipmentSlots.Slot] = [EquipmentSlots.Slot.MAIN_HAND, EquipmentSlots.Slot.OFF_HAND, EquipmentSlots.Slot.HEAD, EquipmentSlots.Slot.CHEST, EquipmentSlots.Slot.GLOVES, EquipmentSlots.Slot.BELT, EquipmentSlots.Slot.BOOTS, EquipmentSlots.Slot.TRINKET_1, EquipmentSlots.Slot.TRINKET_2]
@onready var inventory: InventoryComponent = $"../InventoryComponent"
var _slots: Dictionary = {}
const WORLD_DROP := -2

func get_equipped_stack(slot: int) -> ItemStack:
	return _slots.get(slot)

func get_equipped_items() -> Dictionary:
	return _slots.duplicate()

func slot_of(stack: ItemStack) -> int:
	for slot in _slots:
		if _slots[slot] == stack: return slot
	return -1

func slot_status(slot: int) -> String:
	for other in _slots:
		var profile: EquipmentProfile = _slots[other].definition.equipment_profile
		if profile.restricts_slot == slot:
			return "Unavailable" if profile.permitted_traits.is_empty() else "Restricted support slot"
	return "Empty"

func _matches(stack: ItemStack, traits: Array, families: Array) -> bool:
	if stack == null: return false
	var profile := stack.definition.equipment_profile
	if profile == null: return false
	for equipment_trait in traits:
		if equipment_trait not in profile.traits: return false
	return families.is_empty() or profile.family in families

func _invalid_slots(state: Dictionary) -> Array[int]:
	var invalid: Array[int] = []
	for slot in state:
		var stack: ItemStack = state[slot]
		var p := stack.definition.equipment_profile
		if p == null or not p.allows_slot(slot) or slot not in enabled_slots:
			invalid.append(slot)
			continue
		if p.requires_slot >= 0 and not _matches(state.get(p.requires_slot), p.required_traits, p.required_families):
			invalid.append(slot)
		if p.restricts_slot >= 0 and state.has(p.restricts_slot):
			if p.permitted_traits.is_empty() or not _matches(state[p.restricts_slot], p.permitted_traits, p.permitted_families):
				invalid.append(p.restricts_slot)
	# Weapon pairs require mutual explicit opt-in. Support items are not weapons.
	var main: ItemStack = state.get(EquipmentSlots.Slot.MAIN_HAND)
	var off: ItemStack = state.get(EquipmentSlots.Slot.OFF_HAND)
	if main != null and off != null:
		var a := main.definition.equipment_profile
		var b := off.definition.equipment_profile
		if a != null and b != null and EquipmentProfile.Trait.WEAPON in a.traits and EquipmentProfile.Trait.WEAPON in b.traits:
			if EquipmentProfile.Trait.DUAL_WIELD not in a.traits or EquipmentProfile.Trait.DUAL_WIELD not in b.traits or b.family not in a.compatible_weapon_families or a.family not in b.compatible_weapon_families:
				invalid.append(EquipmentSlots.Slot.OFF_HAND)
	return invalid

## Pure preview. No stack positions, inventory membership, or equipment are mutated.
## -1 means inventory; WORLD_DROP omits the removed item from grid placement.
## Both removal modes use the same dependency resolution and capacity validation.
func preview(stack: ItemStack, destination: int, cell := Vector2i(-1, -1)) -> Dictionary:
	var plan := {"valid": false, "reason": "", "conflicts": [], "slots": _slots.duplicate(), "positions": {}}
	if stack == null:
		plan.reason = "No item."
		return plan
	var source := slot_of(stack)
	if source < 0 and stack not in inventory.stacks:
		plan.reason = "Item is no longer owned here."
		return plan
	var state: Dictionary = plan.slots
	var returns: Array[ItemStack] = []
	if destination >= 0:
		var profile := stack.definition.equipment_profile
		if destination not in enabled_slots or profile == null or not profile.allows_slot(destination):
			plan.reason = "Item does not fit this slot."
			return plan
		if source == destination:
			plan.valid = true
			return plan
		var replaced: ItemStack = state.get(destination)
		if source >= 0: state.erase(source)
		state[destination] = stack
		if replaced != null:
			if source >= 0:
				state[source] = replaced
			else:
				returns.append(replaced)
				plan.conflicts.append(destination)
		if source >= 0:
			# Slot moves/swaps must validate exactly; never silently evict a swap partner.
			if not _invalid_slots(state).is_empty():
				plan.reason = "Both resulting slot placements must be compatible."
				return plan
		else:
			for iteration in enabled_slots.size():
				var invalid := _invalid_slots(state)
				if invalid.is_empty(): break
				if destination in invalid:
					plan.reason = "Required equipment missing or incompatible."
					return plan
				for slot in invalid:
					if state.has(slot):
						returns.append(state[slot])
						plan.conflicts.append(slot)
						state.erase(slot)
	else:
		if source < 0:
			plan.reason = "Item is not equipped."
			return plan
		state.erase(source)
		if destination != WORLD_DROP: returns.append(stack)
		for iteration in enabled_slots.size():
			var invalid := _invalid_slots(state)
			if invalid.is_empty(): break
			for slot in invalid:
				if state.has(slot):
					returns.append(state[slot])
					plan.conflicts.append(slot)
					state.erase(slot)
	if not _invalid_slots(state).is_empty():
		plan.reason = "Incompatible equipment."
		return plan
	# Use detached stacks as a scratch grid, preserving live ItemStack identity.
	var scratch := InventoryComponent.new()
	scratch.grid_width = inventory.grid_width
	scratch.grid_height = inventory.grid_height
	for owned in inventory.stacks:
		if owned != stack:
			scratch.stacks.append(ItemStack.new(owned.definition, owned.quantity, owned.grid_position))
	for returned in returns:
		var position := Vector2i(-1, -1)
		if returned == stack and destination < 0:
			if scratch.can_place(returned.definition, cell): position = cell
		else:
			for y in scratch.grid_height:
				for x in scratch.grid_width:
					if position.x < 0 and scratch.can_place(returned.definition, Vector2i(x, y)):
						position = Vector2i(x, y)
		if position.x < 0:
			scratch.free()
			plan.reason = "No valid inventory space for " + returned.definition.display_name + "."
			return plan
		plan.positions[returned] = position
		scratch.stacks.append(ItemStack.new(returned.definition, returned.quantity, position))
	scratch.free()
	plan.valid = true
	return plan

func transfer(stack: ItemStack, destination: int, cell := Vector2i(-1, -1)) -> bool:
	if destination == WORLD_DROP: return drop_to_world(stack)
	var plan := preview(stack, destination, cell)
	if not plan.valid:
		transaction_rejected.emit(plan.reason)
		return false
	if destination >= 0: inventory.stacks.erase(stack)
	_apply_plan(plan)
	# Observers always see the complete committed state.
	inventory.contents_changed.emit()
	equipment_changed.emit()
	return true

func _apply_plan(plan: Dictionary) -> void:
	_slots = plan.slots
	for returned in plan.positions:
		returned.grid_position = plan.positions[returned]
		inventory.stacks.append(returned)


func drop_to_world(stack: ItemStack) -> bool:
	var plan := preview(stack, WORLD_DROP)
	if not plan.valid:
		transaction_rejected.emit(plan.reason)
		return false
	var dropper := get_node_or_null("../InventoryDropper") as InventoryDropper
	if dropper == null:
		transaction_rejected.emit("No world dropper is available.")
		return false
	if not dropper.try_drop(stack, _commit_world_drop.bind(stack)): return false
	inventory.contents_changed.emit()
	equipment_changed.emit()
	return true

func _commit_world_drop(stack: ItemStack) -> bool:
	# Revalidate after the new WorldItem's _ready, before any live mutation.
	var plan := preview(stack, WORLD_DROP)
	if not plan.valid: return false
	_apply_plan(plan)
	return true

func get_equipped_by_category(category: EquipmentSlots.Category) -> Array[ItemStack]:
	var items: Array[ItemStack] = []
	for slot in enabled_slots:
		if EquipmentSlots.category(slot) == category and _slots.has(slot):
			items.append(_slots[slot])
	return items

func compatible_slots(stack: ItemStack) -> Array[int]:
	var result: Array[int] = []
	if stack == null or stack.definition.equipment_profile == null: return result
	for slot in enabled_slots:
		if stack.definition.equipment_profile.allows_slot(slot): result.append(slot)
	return result

## Context equip may choose an empty equivalent slot, but never an arbitrary replacement.
func context_destination(stack: ItemStack) -> int:
	var candidates := compatible_slots(stack)
	if candidates.size() == 1:
		return candidates[0] if preview(stack, candidates[0]).valid else -1
	for slot in candidates:
		if not _slots.has(slot) and preview(stack, slot).valid: return slot
	return -1

func equip_from_context(stack: ItemStack) -> bool:
	var destination := context_destination(stack)
	if destination < 0:
		transaction_rejected.emit("No unambiguous valid destination. Drag to a slot for explicit replacement.")
		return false
	return transfer(stack, destination)
