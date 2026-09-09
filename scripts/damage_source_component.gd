class_name DamageSourceComponent
extends Area3D

signal damage_dealt(hurtbox: HurtboxComponent, amount: float)

const HURTBOX_COLLISION_LAYER := 1 << 2
const DAMAGE_SOURCE_COLLISION_LAYER := 1 << 3

@export_range(0.0, 1000000.0, 0.1, "or_greater") var damage_amount: float = 10.0
@export var enabled: bool = true


func _init() -> void:
	collision_layer = DAMAGE_SOURCE_COLLISION_LAYER
	collision_mask = HURTBOX_COLLISION_LAYER


func apply_damage_to(hurtbox: HurtboxComponent) -> float:
	if not enabled or not is_instance_valid(hurtbox):
		return 0.0

	var applied_damage := hurtbox.receive_damage(damage_amount)
	if applied_damage > 0.0:
		damage_dealt.emit(hurtbox, applied_damage)

	return applied_damage


func apply_damage_to_overlaps() -> int:
	if not enabled:
		return 0

	var damaged_hurtbox_count := 0
	for area in get_overlapping_areas():
		var hurtbox := area as HurtboxComponent
		if hurtbox != null and apply_damage_to(hurtbox) > 0.0:
			damaged_hurtbox_count += 1

	return damaged_hurtbox_count
