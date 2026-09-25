extends Node
## Sole primary/secondary input dispatcher. Runtime Focus is independent of input mode.
signal focus_changed(focused: bool)
signal wheel_changed(open: bool)
## Settings override this input adapter; gameplay still consumes focused only.
@export_enum("Hold", "Toggle") var focus_input_mode := 1
@export_range(0.05, 0.5) var wheel_time_scale := 0.15
var focused := false
var wheel_open := false
var _previous_time_scale := 1.0
var _suppressed: Dictionary = {}
var _routed: Dictionary = {}
var _blocked := false
@onready var equipment = $"../CombatEquipment"
@onready var allomancy = $"../Allomancy"
@onready var health = $"../HealthComponent"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlaytestSettings.changed.connect(_apply_focus_preference)
	_apply_focus_preference()
	GameplayLocks.lock_changed.connect(_lock_changed)
	get_window().focus_exited.connect(func(): _lock_changed(true))

func _apply_focus_preference() -> void:
	var mode := 0 if PlaytestSettings.focus_mode == "hold" else 1
	if focus_input_mode == mode: return
	# Do not transfer an in-progress hold/click into the new interpretation.
	set_focus(false)
	_cancel_context()
	focus_input_mode = mode

func _cancel_context() -> void:
	equipment._cancel_actions()
	allomancy.cancel_controlled_actions()
	_routed.clear()
	for action in [&"primary_action", &"secondary_action"]:
		if Input.is_action_pressed(action): _suppressed[action] = true

func set_focus(value: bool) -> void:
	if focused == value: return
	_cancel_context()
	focused = value
	focus_changed.emit(focused)

func set_wheel_open(value: bool) -> void:
	if wheel_open == value: return
	_cancel_context()
	wheel_open = value
	if wheel_open:
		_previous_time_scale = Engine.time_scale
		Engine.time_scale = _previous_time_scale * wheel_time_scale
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Engine.time_scale = _previous_time_scale
		if not get_tree().paused and not GameplayLocks.is_locked(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	wheel_changed.emit(wheel_open)

func _lock_changed(locked: bool) -> void:
	if locked:
		set_wheel_open(false)
		set_focus(false)
		_cancel_context()

func _process(_delta: float) -> void:
	var blocked: bool = get_tree().paused or GameplayLocks.is_locked() or health.is_dead()
	if blocked and not _blocked: _lock_changed(true)
	_blocked = blocked
	# Releases can be consumed by GUI/menu layers; never leave stale routed holds.
	for action in [&"primary_action", &"secondary_action"]:
		if not Input.is_action_pressed(action):
			_suppressed.erase(action)
			_release(action)
	if wheel_open and not Input.is_action_pressed(&"metal_wheel"): set_wheel_open(false)
	if focus_input_mode == 0 and focused and not Input.is_action_pressed(&"allomancy_focus"): set_focus(false)

func _input(event: InputEvent) -> void:
	if event.is_echo(): return
	if event.is_action_released(&"metal_wheel"):
		set_wheel_open(false)
		return
	if get_tree().paused or GameplayLocks.is_locked() or health.is_dead(): return
	if event.is_action_pressed(&"metal_wheel"):
		set_wheel_open(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"allomancy_focus"):
		set_focus(not focused if focus_input_mode == 1 else true)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"allomancy_focus") and focus_input_mode == 0:
		set_focus(false)
		get_viewport().set_input_as_handled()

func _release(action: StringName) -> void:
	if not _routed.has(action): return
	var was_focused: bool = _routed[action]
	_routed.erase(action)
	if was_focused: allomancy.handle_focused_action(action, false)
	else: equipment.handle_contextual_action(action, false)

func _unhandled_input(event: InputEvent) -> void:
	for action in [&"primary_action", &"secondary_action"]:
		if not event.is_action_pressed(action) and not event.is_action_released(action): continue
		get_viewport().set_input_as_handled()
		if get_tree().paused or GameplayLocks.is_locked() or health.is_dead() or wheel_open or get_parent().is_climbing(): return
		if _suppressed.has(action):
			if event.is_action_released(action): _suppressed.erase(action)
			return
		if event.is_echo(): return
		if event.is_action_released(action):
			_release(action)
		else:
			_routed[action] = focused
			if focused: allomancy.handle_focused_action(action, true)
			else: equipment.handle_contextual_action(action, true)
		return

func _exit_tree() -> void:
	if wheel_open: Engine.time_scale = _previous_time_scale
