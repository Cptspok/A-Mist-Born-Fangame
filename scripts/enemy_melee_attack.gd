extends Node

@export_range(0.1, 10.0, 0.1) var attack_range: float = 1.8
@export_range(0.1, 10.0, 0.1) var attack_cooldown: float = 1.5
var _remaining: float = 0.0
@onready var actor: EnemyController = get_parent()
@onready var source: DamageSourceComponent = $DamageSourceComponent


func tick(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)


func execute(target: Node3D) -> bool:
	if not actor.is_active or _remaining > 0.0 or not is_instance_valid(target):
		return false
	if actor.global_position.distance_to(target.global_position) > attack_range:
		return false
	var hurtbox := target.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox == null:
		return false
	_remaining = maxf(attack_cooldown, 0.1)
	source.apply_damage_to(hurtbox)
	return true
