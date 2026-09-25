class_name HurtboxComponent
extends Area3D

signal attacked_by(instigator: Node3D)

signal hit_received(amount: float, current_health: float, max_health: float)

const HURTBOX_COLLISION_LAYER := 1 << 2

@export_group("Health")
@export var health_component_path: NodePath = ^"../HealthComponent"

@export_group("Shape")
@export_range(0.05, 10.0, 0.05, "or_greater") var capsule_radius: float = 0.4
@export_range(0.1, 20.0, 0.1, "or_greater") var capsule_height: float = 1.8

var _health_component: HealthComponent

@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _init() -> void:
	collision_layer = HURTBOX_COLLISION_LAYER
	collision_mask = 0
	monitoring = false


func _ready() -> void:
	_resolve_health_component()
	_configure_collision_shape()

	if _health_component == null:
		push_error("HurtboxComponent could not find a HealthComponent at %s." % health_component_path)


func receive_damage(amount: float, instigator: Node3D = null, source: DamageSourceComponent = null) -> float:
	if not is_instance_valid(_health_component):
		_resolve_health_component()

	if _health_component == null:
		return 0.0
	# Invalid/dead hits must not react against the guard before Health rejects them.
	if not is_finite(amount) or amount <= 0.0 or _health_component.is_dead(): return 0.0

	if amount > 0.0 and not _health_component.is_dead() and is_instance_valid(instigator):
		attacked_by.emit(instigator)
	var defense := get_parent().get_node_or_null("CombatEquipment")
	if source != null and defense != null and defense.has_method("defend_damage"):
		# Melee sources sit on the attacker; projectiles supply their contact position.
		amount = defense.defend_damage(amount, source.global_position, source.block_pressure)
	elif defense != null and defense.has_method("present_incoming"):
		defense.present_incoming(&"hit")
	var applied_damage := _health_component.apply_damage(amount)
	if applied_damage > 0.0:
		hit_received.emit(
			applied_damage,
			_health_component.current_health,
			_health_component.max_health
		)

	return applied_damage


func get_health_component() -> HealthComponent:
	return _health_component


func _resolve_health_component() -> void:
	_health_component = get_node_or_null(health_component_path) as HealthComponent


func _configure_collision_shape() -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return

	capsule = capsule.duplicate() as CapsuleShape3D
	capsule.radius = capsule_radius
	capsule.height = maxf(capsule_height, capsule_radius * 2.0)
	collision_shape.shape = capsule
