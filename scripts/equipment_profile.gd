class_name EquipmentProfile
extends Resource

enum Trait { WEAPON, TWO_HANDED, BOW, QUIVER, DUAL_WIELD, MAGIC_SUPPORT }
@export var allowed_slots: Array[EquipmentSlots.Slot] = []
@export var traits: Array[Trait] = []
## Explicit family IDs, not item names. Both weapons must opt in for dual wield.
@export var family: StringName
@export var compatible_weapon_families: Array[StringName] = []
## Restrict another occupied slot to these traits; an empty array blocks it entirely.
@export var restricts_slot: int = -1
@export var permitted_traits: Array[Trait] = []
@export var permitted_families: Array[StringName] = []
## Dependency is one-way: a support item can require a bow without the reverse.
@export var requires_slot: int = -1
@export var required_traits: Array[Trait] = []
@export var required_families: Array[StringName] = []
