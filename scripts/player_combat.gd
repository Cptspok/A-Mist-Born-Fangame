class_name PlayerCombat
extends Node

signal equipment_changed
signal ability_requested(action: StringName, pressed: bool)
var active_slot: int = -1
var _runtimes: Dictionary = {}
@onready var equipment: EquipmentComponent = $"../Equipment"
@onready var camera: Camera3D = $"../CameraPivot/Camera3D"
@onready var mount: Node3D = $"../CameraPivot/Camera3D/WeaponMount"
@onready var health: HealthComponent = $"../HealthComponent"

func _ready() -> void:
	equipment.equipment_changed.connect(_sync_equipment)
	GameplayLocks.lock_changed.connect(_on_lock_changed)
	health.died.connect(_cancel_actions)
	_sync_equipment()

func get_equipped_stack(slot: int) -> ItemStack:
	return equipment.get_equipped_stack(slot) if is_instance_valid(equipment) else null

func _sync_equipment() -> void:
	for runtime in _runtimes.values():
		runtime.set_active(false)
		runtime.queue_free()
	_runtimes.clear()
	for slot in equipment.enabled_slots:
		var stack := equipment.get_equipped_stack(slot)
		if stack == null: continue
		var data := stack.definition.combat_definition
		if data == null or data.runtime_scene == null: continue
		var instance := data.runtime_scene.instantiate()
		var runtime := instance as CombatItemRuntime
		if runtime == null:
			instance.free()
			continue
		runtime.configure(data, get_parent() as Node3D, camera)
		mount.add_child(runtime)
		_runtimes[slot] = runtime
	if not _runtimes.has(active_slot):
		active_slot = -1 if _runtimes.is_empty() else int(_runtimes.keys()[0])
	select_slot(active_slot)

func select_slot(slot: int) -> void:
	if slot != -1 and not _runtimes.has(slot): return
	active_slot = slot
	for key in _runtimes:
		_runtimes[key].set_active(key == slot)
	equipment_changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if GameplayLocks.is_locked() or health.is_dead() or get_tree().paused: return
	for action in [&"primary_action", &"secondary_action", &"ability_1", &"ability_2"]:
		if event.is_action_pressed(action) or event.is_action_released(action):
			var pressed := event.is_action_pressed(action)
			if action in [&"ability_1", &"ability_2"]:
				ability_requested.emit(action, pressed)
			elif _runtimes.has(active_slot):
				_runtimes[active_slot].handle_action(action, pressed)
			get_viewport().set_input_as_handled()
			return
	# Bindings index combat-capable items, never physical Off Hand directly.
	var available := _runtimes.keys()
	for action in [&"weapon_slot_1", &"weapon_slot_2", &"weapon_next", &"weapon_previous"]:
		if event.is_action_pressed(action) and not available.is_empty():
			var index := 0
			match action:
				&"weapon_slot_1": index = 0
				&"weapon_slot_2": index = 1
				_: index = posmod(available.find(active_slot) + (-1 if action == &"weapon_previous" else 1), available.size())
			if index < available.size(): select_slot(available[index])
			get_viewport().set_input_as_handled()
			return

func _on_lock_changed(locked: bool) -> void:
	if locked: _cancel_actions()

func _cancel_actions() -> void:
	for runtime in _runtimes.values():
		if is_instance_valid(runtime): runtime.cancel_action()
