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
var _held: Dictionary = {}
var steel := SteelPush.new()
var iron := IronPull.new()

func _ready() -> void:
	_register(STEEL_ABILITY, &"steel")
	_register(IRON_ABILITY, &"iron")
	reserves.depleted.connect(_depleted)
	reserves.access_changed.connect(_access_changed)
	targeting.configure(player, player.get_node("CameraPivot/Camera3D"), tuning)
	player.external_motion_requested.connect(_step)
	GameplayLocks.lock_changed.connect(_locked)

func _register(definition: AbilityDefinition, metal: StringName) -> void:
	abilities.register_ability(definition,
		func() -> StringName: return &"unavailable" if health.is_dead() or GameplayLocks.is_locked() or not reserves.has_access(metal) else &"",
		func() -> StringName: return &"empty_reserve" if reserves.reserve(metal) <= 0.0 else &"",
		func() -> bool: return true,
		func(_reason: StringName): reserves.stop_burn(metal))

func _depleted(metal: StringName) -> void:
	if metal != &"steel" and metal != &"iron": return
	var id: StringName = &"steel_push" if metal == &"steel" else &"iron_pull"
	abilities.deactivate(id, &"resource_unavailable")

func _access_changed(metal: StringName, available: bool) -> void:
	if not available: _depleted(metal)

func _sync_held(id: StringName, held: bool) -> void:
	if held and not _held.get(id, false): abilities.request_activation(id)
	if not held: abilities.deactivate(id)
	_held[id] = held

func _step(delta: float) -> void:
	last_interaction = {}
	if health.is_dead() or GameplayLocks.is_locked():
		_locked(true)
		return
	targeting.refresh()
	var pushing := Input.is_action_pressed(&"steel_push")
	var pulling := Input.is_action_pressed(&"iron_pull")
	# Preserve both-buttons-cancel, including consumption. No force law changes.
	_sync_held(&"steel_push", pushing and not pulling)
	_sync_held(&"iron_pull", pulling and not pushing)
	var tether := targeting.selected
	if is_instance_valid(tether):
		if abilities.is_active(&"steel_push"): last_interaction = steel.apply(player, tether, tuning)
		elif abilities.is_active(&"iron_pull"): last_interaction = iron.apply(player, tether, tuning)
	# apply() returns the accepted forces after participant response filtering.
	# A selected tether alone is not evidence that an effect did any work.
	var player_force: Vector3 = last_interaction.get("player_force", Vector3.ZERO)
	var object_force: Vector3 = last_interaction.get("object_force", Vector3.ZERO)
	var engaged := not player_force.is_zero_approx() or not object_force.is_zero_approx()
	reserves.consume_usage(&"steel", delta, engaged and abilities.is_active(&"steel_push"))
	reserves.consume_usage(&"iron", delta, engaged and abilities.is_active(&"iron_pull"))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_allomancy_debug"):
		debug_enabled = not debug_enabled
		debug_changed.emit(debug_enabled)
		get_viewport().set_input_as_handled()

func _locked(locked: bool) -> void:
	if locked:
		abilities.deactivate(&"steel_push", &"locked")
		abilities.deactivate(&"iron_pull", &"locked")
		_held.clear()
		last_interaction = {}
		targeting.clear_target()
