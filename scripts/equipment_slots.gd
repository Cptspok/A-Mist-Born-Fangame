class_name EquipmentSlots
extends RefCounted

enum Slot { MAIN_HAND, OFF_HAND, HEAD, CHEST, BELT, GLOVES, BOOTS, TRINKET_1, TRINKET_2 }

static func label(slot: int) -> String:
	return Slot.keys()[slot].capitalize()
