class_name PlayerCombat
extends Node

signal equipment_changed
## Independent hook for future abilities, never forwarded to weapon slots.
signal ability_requested(action: StringName, pressed: bool)

enum Slot { MAIN, SECONDARY }
var active_slot: int = Slot.MAIN
var _stacks: Array[ItemStack] = [null, null]
var _runtimes: Array[CombatItemRuntime] = [null, null]
@onready var inventory: InventoryComponent = $"../InventoryComponent"
@onready var camera: Camera3D = $"../CameraPivot/Camera3D"
@onready var mount: Node3D = $"../CameraPivot/Camera3D/WeaponMount"
@onready var health: HealthComponent = $"../HealthComponent"


func _ready() -> void:
	inventory.contents_changed.connect(_validate_ownership)
	GameplayLocks.lock_changed.connect(_on_lock_changed)
	health.died.connect(_cancel_actions)


func equip(stack: ItemStack, slot: int = Slot.MAIN) -> bool:
	# Inventory UI may equip while paused; gameplay input remains locked.
	if slot < 0 or slot >= _stacks.size() or stack == null or stack not in inventory.stacks or stack.definition.combat_definition == null:
		return false
	var data := stack.definition.combat_definition
	if data.runtime_scene == null:
		return false
	if _stacks[slot] == stack:
		select_slot(slot)
		return true
	var instance := data.runtime_scene.instantiate()
	var runtime := instance as CombatItemRuntime
	if runtime == null:
		instance.free()
		return false
	for i in _stacks.size():
		if _stacks[i] == stack or i == slot:
			_clear_slot(i)
	_stacks[slot] = stack
	_runtimes[slot] = runtime
	runtime.configure(data, get_parent() as Node3D, camera)
	mount.add_child(runtime)
	select_slot(slot)
	return true


func get_equipped_stack(slot: int) -> ItemStack:
	return _stacks[slot] if slot >= 0 and slot < _stacks.size() else null


func select_slot(slot: int) -> void:
	if slot < 0 or slot >= _stacks.size():
		return
	active_slot = slot
	for i in _runtimes.size():
		if is_instance_valid(_runtimes[i]):
			_runtimes[i].set_active(i == active_slot)
	equipment_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if GameplayLocks.is_locked() or health.is_dead() or get_tree().paused:
		return
	for action in [&"primary_action", &"secondary_action", &"ability_1", &"ability_2"]:
		if event.is_action_pressed(action) or event.is_action_released(action):
			var pressed := event.is_action_pressed(action)
			if action in [&"ability_1", &"ability_2"]:
				ability_requested.emit(action, pressed)
			elif is_instance_valid(_runtimes[active_slot]):
				_runtimes[active_slot].handle_action(action, pressed)
			get_viewport().set_input_as_handled()
			return
	for action in [&"weapon_slot_1", &"weapon_slot_2", &"weapon_next", &"weapon_previous"]:
		if event.is_action_pressed(action):
			match action:
				&"weapon_slot_1": select_slot(Slot.MAIN)
				&"weapon_slot_2": select_slot(Slot.SECONDARY)
				_: select_slot(1 - active_slot)
			get_viewport().set_input_as_handled()
			return


func _clear_slot(slot: int) -> void:
	if is_instance_valid(_runtimes[slot]):
		_runtimes[slot].set_active(false)
		_runtimes[slot].queue_free()
	_runtimes[slot] = null
	_stacks[slot] = null


func _validate_ownership() -> void:
	for i in _stacks.size():
		if _stacks[i] != null and _stacks[i] not in inventory.stacks:
			_clear_slot(i)
	equipment_changed.emit()


func _on_lock_changed(locked: bool) -> void:
	if locked:
		_cancel_actions()


func _cancel_actions() -> void:
	for runtime in _runtimes:
		if is_instance_valid(runtime):
			runtime.cancel_action()
