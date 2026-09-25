class_name AllomancyController
extends Node3D

## Spatial parent: the Targeting Area3D must inherit Player motion.

signal debug_changed(enabled: bool)
@export var tuning: AllomancyTuning
@export var debug_enabled := true
@onready var player: PlayerController = get_parent()
@onready var targeting: AllomancyTargeting = $Targeting
@onready var health: HealthComponent = $"../HealthComponent"
var last_interaction: Dictionary = {}
## Persistent, short-lived debug sample; never drives gameplay or reacquisition.
var last_captured_launch: Dictionary = {}
@onready var abilities: AbilityComponent = $"../AbilityComponent"
@onready var reserves: AllomancyComponent = $"../AllomancyComponent"
@onready var capture = $"../AllomanticOrigin/CapturePoint"
var _maintained_pull: MetalTetherComponent
## A captured throw consumes this Steel engagement until primary is released.
## This is input ownership, not a one-tick target exclusion.
var _steel_press_consumed := false
const STEEL_ABILITY = preload("res://data/abilities/allomancy/steel/steel_push_ability.tres")
const IRON_ABILITY = preload("res://data/abilities/allomancy/iron/iron_pull_ability.tres")
## Preserve existing captured player reaction; projectile speed is independent.
const CAPTURED_RECOIL_DURATION := 0.12
var steel := SteelPush.new()
var iron := IronPull.new()

func _ready() -> void:
	_register(STEEL_ABILITY, &"steel")
	_register(IRON_ABILITY, &"iron")
	abilities.deactivated.connect(_ability_ended)
	reserves.depleted.connect(_depleted)
	reserves.burn_stopped.connect(_depleted)
	reserves.access_changed.connect(_access_changed)
	targeting.configure(player, player.get_node("CameraPivot/Camera3D"), tuning)
	player.external_motion_requested.connect(_step)
	player.movement_completed.connect(_follow_capture)
	GameplayLocks.lock_changed.connect(_locked)

func _register(definition: AbilityDefinition, metal: StringName) -> void:
	abilities.register_ability(definition,
		func() -> StringName: return &"unavailable" if health.is_dead() or GameplayLocks.is_locked() or not reserves.has_access(metal) or not reserves.is_burning(metal) else &"",
		func() -> StringName: return &"empty_reserve" if reserves.reserve(metal) <= 0.0 else &"",
		func() -> bool: return true,
		func(_reason: StringName): reserves.set_engaged(metal, false))

func _depleted(metal: StringName) -> void:
	if metal != &"steel" and metal != &"iron": return
	var id: StringName = &"steel_push" if metal == &"steel" else &"iron_pull"
	abilities.deactivate(id, &"resource_unavailable")

func _access_changed(metal: StringName, available: bool) -> void:
	if not available: _depleted(metal)

## Called only by the contextual router; no independent mouse/Input polling.
func handle_focused_action(action: StringName, pressed: bool) -> void:
	var id: StringName = &"steel_push" if action == &"primary_action" else &"iron_pull"
	if action == &"primary_action" and not pressed: _steel_press_consumed = false
	if pressed: abilities.request_activation(id)
	else: abilities.deactivate(id)

func cancel_controlled_actions() -> void:
	abilities.deactivate(&"steel_push", &"context_changed")
	abilities.deactivate(&"iron_pull", &"context_changed")
	_clear_pull()
	_steel_press_consumed = false

func _clear_pull() -> void:
	_maintained_pull = null
	if is_instance_valid(capture): capture.release()

func _ability_ended(id: StringName, _reason: StringName) -> void:
	if id == &"iron_pull": _clear_pull()

func _can_control(id: StringName, metal: StringName) -> bool:
	return abilities.is_active(id) and reserves.has_access(metal) and reserves.is_burning(metal) and reserves.reserve(metal) > 0.0

func _apply_controlled(id: StringName, metal: StringName, tether: MetalTetherComponent, delta: float, pulling: bool) -> void:
	var result: Dictionary = {}
	if _can_control(id, metal) and is_instance_valid(tether) and tether.is_available():
		result = iron.apply(player, tether, tuning) if pulling else steel.apply(player, tether, tuning)
		if not result.is_empty(): last_interaction = result
	var player_force: Vector3 = result.get("player_force", Vector3.ZERO)
	var object_force: Vector3 = result.get("object_force", Vector3.ZERO)
	reserves.consume_usage(metal, delta, not player_force.is_zero_approx() or not object_force.is_zero_approx())

func _step(delta: float) -> void:
	last_interaction = {}
	if health.is_dead() or GameplayLocks.is_locked():
		_locked(true)
		return
	var pulling := _can_control(&"iron_pull", &"iron")
	var pushing := _can_control(&"steel_push", &"steel") and not _steel_press_consumed
	if not pulling: _clear_pull()
	if not capture.eligible(_maintained_pull) or not targeting.can_maintain(_maintained_pull):
		if capture.tether != null:
			abilities.deactivate(&"iron_pull", &"capture_invalid")
			pulling = false
		_clear_pull()
	if pushing and is_instance_valid(capture.tether) and capture.phase_name() == "HELD":
		# Aim owns the launch axis; actual COM only determines its starting point.
		# Projectile velocity is authored. Shared Steel math supplies recoil only.
		var launched_tether: MetalTetherComponent = capture.tether
		var launch_axis: Vector3 = capture.controlled_launch_axis()
		var metal_position := launched_tether.get_force_position()
		var throw_speed: float = capture.captured_throw_speed
		# The controlled body is frozen, so its systemic velocity is zero. Snapshot
		# Steel magnitude before release; authored follow motion never enters it.
		var launch := AllomancyInteraction.evaluate_captured_recoil(player, launched_tether, tuning, launch_axis)
		_steel_press_consumed = true
		abilities.deactivate(&"iron_pull", &"steel_release")
		if not launch.is_empty():
			var clean_velocity := PhysicalForceResponse.get_velocity(launch.owner)
			PhysicalForceResponse.apply_impulse(player, launch.player_force * CAPTURED_RECOIL_DURATION, true)
			var projectile := launch.owner as RigidBody3D
			projectile.linear_velocity = launch_axis * throw_speed
			projectile.sleeping = false
			launch.power = "Ballistic Steel release (force sample is recoil evaluation)"
			last_interaction = launch
			last_captured_launch = {"time_ms": Time.get_ticks_msec(), "origin": metal_position,
				"axis": launch_axis, "clean_velocity": clean_velocity,
				"impulse": launch_axis * throw_speed * projectile.mass,
				"velocity": PhysicsServer3D.body_get_state(launch.owner.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)}
		reserves.consume_usage(&"steel", delta, not launch.is_empty())
		reserves.consume_usage(&"iron", delta, false)
		return
	targeting.refresh(_maintained_pull)
	if pulling:
		if not is_instance_valid(_maintained_pull) and capture.eligible(targeting.selected):
			_maintained_pull = targeting.selected
		# Eligible loose Pull is authored from its FIRST targeted tick. No ordinary
		# Iron force is submitted before capture or while it owns this object.
		if is_instance_valid(_maintained_pull) and not is_instance_valid(capture.tether):
			capture.try_capture(_maintained_pull, player)
	if is_instance_valid(capture.tether):
		# APPROACH/HELD own motion completely. Ordinary Iron must not compete
		# with the planned reference or spend its vertical acceleration budget.
		reserves.consume_usage(&"iron", delta, true)
		reserves.consume_usage(&"steel", delta, false)
		return
	# Each participant uses its unchanged force law; both controls may engage.
	if not _steel_press_consumed:
		_apply_controlled(&"steel_push", &"steel", targeting.selected, delta, false)
	else:
		reserves.consume_usage(&"steel", delta, false)
	_apply_controlled(&"iron_pull", &"iron", targeting.selected, delta, true)

func _follow_capture(delta: float) -> void:
	if is_instance_valid(capture.tether) and not capture.follow(player, delta):
		abilities.deactivate(&"iron_pull", &"capture_broken")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_allomancy_debug"):
		debug_enabled = not debug_enabled
		debug_changed.emit(debug_enabled)
		get_viewport().set_input_as_handled()

func _locked(locked: bool) -> void:
	if locked:
		abilities.deactivate(&"steel_push", &"locked")
		abilities.deactivate(&"iron_pull", &"locked")
		last_interaction = {}
		targeting.clear_target()
		_clear_pull()
		_steel_press_consumed = false
