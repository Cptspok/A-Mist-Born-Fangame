class_name CommittedEnemyAttack
extends Node
## Shared timing only; subclasses resolve their existing damage/projectile architecture.
enum Phase { IDLE, WINDUP, STRIKE, RECOVERY }
@export_range(0.1, 2.0, 0.05) var windup_duration := 0.65
@export_range(0.05, 1.0, 0.01) var strike_duration := 0.14
@export_range(0.1, 2.0, 0.05) var recovery_duration := 0.55
@export_range(0.1, 10.0, 0.1) var attack_cooldown := 1.5
@export var windup_rotation := Vector3(-1.3, 0, 0)
@export var equipment_name: StringName = &"Sword"
var phase := Phase.IDLE
var elapsed := 0.0
var _cooldown := 0.0
var target: Node3D
var aim_point := Vector3.ZERO
var committed_forward := Vector3.FORWARD
@onready var actor: EnemyController = get_parent()
@onready var reaction: CombatReactionComponent = actor.get_node("CombatReaction")
var _equipment: Node3D
var _rest_rotation := Vector3.ZERO
var _rest_position := Vector3.ZERO

func _ready() -> void:
	reaction.interrupted.connect(_interrupt)

func is_busy() -> bool:
	return phase != Phase.IDLE or reaction.remaining > 0.0

func is_interruptible() -> bool:
	return phase == Phase.WINDUP and reaction.interruptible

func begin(victim: Node3D) -> bool:
	if is_busy() or _cooldown > 0.0 or GameplayLocks.is_locked() or not actor.is_active or not is_instance_valid(victim): return false
	target = victim
	aim_point = victim.global_position
	var facing := Vector3(aim_point.x, actor.global_position.y, aim_point.z)
	if facing.distance_squared_to(actor.global_position) > 0.001: actor.look_at(facing, Vector3.UP)
	committed_forward = -actor.global_basis.z
	phase = Phase.WINDUP
	elapsed = 0.0
	_cooldown = attack_cooldown
	reaction.begin_window()
	return true

func tick(delta: float) -> void:
	reaction.tick(delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	if not actor.is_active:
		phase = Phase.IDLE
		reaction.end_window()
		return
	elapsed += delta
	match phase:
		Phase.WINDUP:
			if elapsed >= windup_duration:
				reaction.end_window()
				phase = Phase.STRIKE
				elapsed = 0.0
				resolve_strike()
		Phase.STRIKE:
			if elapsed >= strike_duration:
				phase = Phase.RECOVERY
				elapsed = 0.0
		Phase.RECOVERY:
			if elapsed >= recovery_duration: phase = Phase.IDLE
	_pose()

func resolve_strike() -> void:
	pass

func _interrupt() -> void:
	phase = Phase.IDLE
	elapsed = 0.0
	_pose()

func _pose() -> void:
	if not is_instance_valid(_equipment):
		_equipment = actor.get_node("VisualRoot").find_child(String(equipment_name), true, false) as Node3D
		if _equipment == null: return
		_rest_rotation = _equipment.rotation
		_rest_position = _equipment.position
	var lift := 0.0
	var recoil := 0.0
	match phase:
		Phase.WINDUP: lift = clampf(elapsed / windup_duration, 0.0, 1.0)
		Phase.STRIKE: lift = -0.8
		Phase.RECOVERY: lift = -0.8 * (1.0 - clampf(elapsed / recovery_duration, 0.0, 1.0))
	if reaction.remaining > 0.0: recoil = reaction.remaining / maxf(reaction.reaction_duration, 0.01)
	_equipment.rotation = _rest_rotation + windup_rotation * lift + Vector3(0, 0, -0.35 * recoil)
	_equipment.position = _rest_position + Vector3(0, 0.18 * lift, 0.12 * lift)
	actor.get_node("VisualRoot").rotation.x = 0.12 * lift - 0.3 * recoil
