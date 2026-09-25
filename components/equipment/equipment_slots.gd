class_name EquipmentSlots
extends RefCounted

# Keep serialized concrete slot IDs stable.
enum Slot { MAIN_HAND, OFF_HAND, HEAD, CHEST, BELT, GLOVES, BOOTS, TRINKET_1, TRINKET_2 }
enum Category { MAIN_HAND, OFF_HAND, HEAD, CHEST, BELT, GLOVES, BOOTS, TRINKET }
const CATEGORIES := {
	Slot.MAIN_HAND: Category.MAIN_HAND, Slot.OFF_HAND: Category.OFF_HAND,
	Slot.HEAD: Category.HEAD, Slot.CHEST: Category.CHEST,
	Slot.BELT: Category.BELT, Slot.GLOVES: Category.GLOVES,
	Slot.BOOTS: Category.BOOTS,
	Slot.TRINKET_1: Category.TRINKET, Slot.TRINKET_2: Category.TRINKET,
}
# Presentation order only; compatibility never depends on screen position.
const DISPLAY_ORDER := [Slot.HEAD, Slot.CHEST, Slot.GLOVES,
	Slot.MAIN_HAND, Slot.OFF_HAND, Slot.BELT,
	Slot.BOOTS, Slot.TRINKET_1, Slot.TRINKET_2]

static func category(slot: int) -> int:
	return CATEGORIES.get(slot, -1)

static func label(slot: int) -> String:
	return Slot.keys()[slot].capitalize()
