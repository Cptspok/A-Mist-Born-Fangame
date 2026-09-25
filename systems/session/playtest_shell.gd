extends Node
const WORLD := preload("res://world/levels/playtest_world/main.tscn")
var world: Node3D
var player: PlayerController
var page := "main"
var back_page := "main"
var destination := "hub"
@onready var menu = $Menu
@onready var feedback = $Feedback/Crosshair

func _ready() -> void:
	menu.action_requested.connect(_action)
	PlaytestSettings.changed.connect(_apply_settings)
	_show("main")

func _process(_delta: float) -> void:
	# Final arbiter: never capture while another UI still owns a gameplay lock.
	var wheel_open: bool = is_instance_valid(player) and player.get_node("ContextualInput").wheel_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if page != "game" or GameplayLocks.is_locked() or wheel_open else Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if page == "controls" and is_instance_valid(menu.controls) and menu.controls.handle_input(event): return
	if event.is_echo(): return
	if is_instance_valid(player) and player.get_node("HealthComponent").is_dead(): return
	# Fixed Escape is a menu safety path even when Pause is cleared.
	var cancel: bool = event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
	# Mouse-bound Pause opens the menu without intercepting its clickable buttons.
	var pause_context: bool = page == "game" or (page == "pause" and event is InputEventKey)
	if cancel or (pause_context and event.is_action_pressed("pause")):
		if InventoryUI.visible: return # Inventory owns Escape until it closes.
		get_viewport().set_input_as_handled()
		match page:
			"game": _show("pause")
			"pause": _resume()
			"settings", "controls": _show(back_page)
			"destinations": _show("main")
			"intro": _show("pause")
	elif event.is_action_pressed("reset_test") and is_instance_valid(world) and page == "game" and not GameplayLocks.is_locked():
		get_viewport().set_input_as_handled()
		_launch(false)

func _action(action: String) -> void:
	match action:
		"quit": get_tree().quit()
		"hub", "lab", "advanced", "urban":
			destination = action
			_launch(true)
		"restart": _launch(false)
		"resume": _resume()
		"main":
			RespawnSession.reset()
			_clear_world()
			_show("main")
		"settings", "controls":
			back_page = page
			_show(action)
		_: _show(action)

func _show(next: String) -> void:
	page = next
	get_tree().paused = true
	menu.show_page(page, back_page)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume() -> void:
	if not is_instance_valid(world):
		_show("main")
		return
	page = "game"
	menu.hide()
	get_tree().paused = InventoryUI.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if GameplayLocks.is_locked() else Input.MOUSE_MODE_CAPTURED

func _clear_world() -> void:
	InventoryUI.close()
	DialogueManager.end_dialogue()
	feedback.player = null
	player = null
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null

func _launch(intro: bool, preserve_checkpoint := false) -> void:
	if not preserve_checkpoint: RespawnSession.reset()
	_clear_world()
	get_tree().paused = true
	var level: PackedScene = load("res://world/levels/urban_district/urban_district.tscn") if destination == "urban" else WORLD
	world = level.instantiate()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	player = world.get_node("Player")
	player.get_node("DeathFlow").retry_requested.connect(_retry_after_death)
	if destination == "lab":
		player.global_transform = world.get_node("MovementLabEntry").global_transform
	elif destination == "advanced":
		player.global_transform = world.get_node("TraversalCourse/Start").global_transform
	# Reuse the existing fall reset and its single Start marker for this session.
	world.get_node("TraversalCourse/Start").global_transform = player.global_transform
	feedback.player = player
	_apply_settings()
	var controller = player.get_node("Allomancy")
	controller.debug_enabled = false
	controller.debug_changed.emit(false)
	if intro: _show("intro")
	else: _resume()

func _apply_settings() -> void:
	if is_instance_valid(player): player.mouse_sensitivity = PlaytestSettings.sensitivity

func _retry_after_death(retry_transform: Transform3D) -> void:
	_launch(false, true)
	player.global_transform = retry_transform
	world.get_node("TraversalCourse/Start").global_transform = retry_transform
