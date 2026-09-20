class_name EnemyController
extends CharacterBody3D

@export_group("Identity")
@export var encounter_id: StringName = &""
@export var display_name: String = "Enemy"
@export var court_target: CourtTargetDefinition
@export var rewards: EnemyRewardDefinition
var _rewards_issued := false

@export_group("Visuals")
@export var visual_scene: PackedScene
@export var animation_player_path: NodePath
@export var idle_animation: StringName

@export_group("Body")
@export_range(0.05, 10.0, 0.05, "or_greater") var collision_radius: float = 0.4
@export_range(0.1, 20.0, 0.1, "or_greater") var collision_height: float = 1.8

var is_active: bool:
	get:
		return _is_active

var _is_active: bool = true
signal state_changed(state: StringName)
var state: StringName = &"Idle"
var spawn_position: Vector3

@export_group("External forces")
@export_range(0.01, 1000.0, 0.01, "or_greater") var force_response_mass := 2.0
@export_range(0.0, 50.0, 0.1) var external_ground_drag := 4.0
var _external_force := Vector3.ZERO
var _external_velocity := Vector3.ZERO

func get_effective_mass() -> float:
	return maxf(force_response_mass, 0.001)

func apply_external_force(force: Vector3) -> void:
	if is_active and not GameplayLocks.is_locked() and force.is_finite():
		_external_force += force

func apply_external_impulse(impulse: Vector3) -> void:
	if is_active and not GameplayLocks.is_locked() and impulse.is_finite():
		_external_velocity += impulse / get_effective_mass()

## The motor supplies intent; external momentum is integrated independently.
func move_with_external_forces(delta: float) -> void:
	_external_velocity += _external_force / get_effective_mass() * delta
	_external_force = Vector3.ZERO
	velocity += _external_velocity
	var before_motion := global_position
	move_and_slide()
	var reaction := get_node_or_null("CombatReaction") as CombatReactionComponent
	if reaction != null:
		reaction.observe_external_motion(global_position - before_motion, _external_velocity, delta)
	# Remove momentum into contact surfaces so walls/floors cannot store it.
	for index in get_slide_collision_count():
		var normal := get_slide_collision(index).get_normal()
		if _external_velocity.dot(normal) < 0.0:
			_external_velocity = _external_velocity.slide(normal)
	if is_on_floor():
		_external_velocity = _external_velocity.move_toward(Vector3.ZERO, external_ground_drag * delta)
	# Vertical momentum is already carried by the motor's velocity/gravity.
	_external_velocity.y = 0.0

func _clear_external_forces(locked: bool = true) -> void:
	if locked:
		_external_force = Vector3.ZERO
		_external_velocity = Vector3.ZERO

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual_root: Node3D = $VisualRoot
@onready var health_component: HealthComponent = $HealthComponent


func _ready() -> void:
	GameplayLocks.lock_changed.connect(_clear_external_forces)
	if court_target != null:
		if not health_component.is_dead(): RespawnSession.knowledge.mark_alive(court_target.unique_id)
		display_name = court_target.display_name
		var nameplate := get_node_or_null("Nameplate") as Label3D
		if nameplate != null: nameplate.text = display_name
	spawn_position = global_position
	_configure_collision()
	_instantiate_visual()
	_play_idle_animation()
	health_component.died.connect(_on_died)
	if health_component.is_dead():
		_on_died()


func set_state(value: StringName) -> void:
	if state == &"Dead" or state == value:
		return
	state = value
	state_changed.emit(state)


func _configure_collision() -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return

	capsule = capsule.duplicate() as CapsuleShape3D
	capsule.radius = collision_radius
	capsule.height = maxf(collision_height, collision_radius * 2.0)
	collision_shape.shape = capsule


func _instantiate_visual() -> void:
	if visual_scene == null:
		return

	visual_root.add_child(visual_scene.instantiate())


func _play_idle_animation() -> void:
	if animation_player_path.is_empty() or idle_animation.is_empty():
		return

	var animation_player := get_node_or_null(animation_player_path) as AnimationPlayer
	if animation_player != null and animation_player.has_animation(idle_animation):
		animation_player.play(idle_animation)


func _on_died() -> void:
	if not _rewards_issued:
		_rewards_issued = true
		if court_target != null: RespawnSession.knowledge.mark_defeated(court_target.unique_id)
		_drop_rewards.call_deferred()
	_is_active = false
	_clear_external_forces()
	for tether in visual_root.find_children("*", "Area3D", true, false):
		if tether is MetalTetherComponent:
			tether.enabled = false
	velocity = Vector3.ZERO
	set_state(&"Dead")

func _drop_rewards() -> void:
	preload("res://scripts/enemy_rewards.gd").drop(self, rewards)
