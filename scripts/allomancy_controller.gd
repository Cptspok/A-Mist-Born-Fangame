class_name AllomancyController
extends Node

signal debug_changed(enabled: bool)
@export var tuning: AllomancyTuning
@export var debug_enabled := true
@onready var player: PlayerController = get_parent()
@onready var targeting: AllomancyTargeting = $Targeting
@onready var health: HealthComponent = $"../HealthComponent"
var steel := SteelPush.new()
var iron := IronPull.new()

func _ready() -> void:
	targeting.configure(player, player.get_node("CameraPivot/Camera3D"), tuning)
	player.external_motion_requested.connect(_step)
	GameplayLocks.lock_changed.connect(_locked)

func _step(_delta: float) -> void:
	if health.is_dead() or GameplayLocks.is_locked():
		targeting.clear_target()
		return
	targeting.refresh()
	var tether := targeting.selected
	if not is_instance_valid(tether): return
	# Each power consumes the shared selected region. Both held cancel line forces.
	if Input.is_action_pressed(&"steel_push"): steel.apply(player, tether, tuning)
	if Input.is_action_pressed(&"iron_pull"): iron.apply(player, tether, tuning)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_allomancy_debug"):
		debug_enabled = not debug_enabled
		debug_changed.emit(debug_enabled)
		get_viewport().set_input_as_handled()

func _locked(locked: bool) -> void:
	if locked: targeting.clear_target()
