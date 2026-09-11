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
var steel := SteelPush.new()
var iron := IronPull.new()

func _ready() -> void:
	targeting.configure(player, player.get_node("CameraPivot/Camera3D"), tuning)
	player.external_motion_requested.connect(_step)
	GameplayLocks.lock_changed.connect(_locked)

func _step(_delta: float) -> void:
	last_interaction = {}
	if health.is_dead() or GameplayLocks.is_locked():
		targeting.clear_target()
		return
	targeting.refresh()
	var tether := targeting.selected
	if not is_instance_valid(tether): return
	# Opposite velocity-dependent laws would otherwise create unintended braking.
	# Preserve the existing both-buttons-cancel convention explicitly.
	var pushing := Input.is_action_pressed(&"steel_push")
	var pulling := Input.is_action_pressed(&"iron_pull")
	if pushing == pulling: return
	if pushing: last_interaction = steel.apply(player, tether, tuning)
	else: last_interaction = iron.apply(player, tether, tuning)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_allomancy_debug"):
		debug_enabled = not debug_enabled
		debug_changed.emit(debug_enabled)
		get_viewport().set_input_as_handled()

func _locked(locked: bool) -> void:
	if locked:
		last_interaction = {}
		targeting.clear_target()
