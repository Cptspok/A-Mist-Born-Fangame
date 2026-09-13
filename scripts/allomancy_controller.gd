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
@onready var abilities: AbilityComponent = $"../AbilityComponent"
@onready var reserves: AllomancyComponent = $"../AllomancyComponent"
const STEEL_ABILITY = preload("res://resources/steel_push_ability.tres")
const IRON_ABILITY = preload("res://resources/iron_pull_ability.tres")
var steel := SteelPush.new()
var iron := IronPull.new()

func _ready() -> void:
	_register(STEEL_ABILITY, &"steel")
	_register(IRON_ABILITY, &"iron")
	reserves.depleted.connect(_depleted)
	reserves.burn_stopped.connect(_depleted)
	reserves.access_changed.connect(_access_changed)
	targeting.configure(player, player.get_node("CameraPivot/Camera3D"), tuning)
	player.external_motion_requested.connect(_step)
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
	if pressed: abilities.request_activation(id)
	else: abilities.deactivate(id)

func cancel_controlled_actions() -> void:
	abilities.deactivate(&"steel_push", &"context_changed")
	abilities.deactivate(&"iron_pull", &"context_changed")

func _apply_controlled(id: StringName, metal: StringName, tether: MetalTetherComponent, delta: float, pulling: bool) -> void:
	var result: Dictionary = {}
	if abilities.is_active(id) and reserves.is_burning(metal) and is_instance_valid(tether):
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
	targeting.refresh()
	# Each participant uses its unchanged force law; both controls may engage.
	_apply_controlled(&"steel_push", &"steel", targeting.selected, delta, false)
	_apply_controlled(&"iron_pull", &"iron", targeting.selected, delta, true)

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
