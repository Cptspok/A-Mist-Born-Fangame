extends Node
## Health emits failure; this component owns feedback and delegates world replacement.
signal retry_requested(retry_transform: Transform3D)
@export_range(0.2, 5.0, 0.1) var retry_delay := 1.5
@export_node_path("Node3D") var encounter_retry_path := NodePath("../../CombatRetry")
@export_range(1.0, 100.0, 1.0) var encounter_retry_radius := 24.0
var defeated := false
var _owns_lock := false
@onready var actor: PlayerController = get_parent()
@onready var health: HealthComponent = actor.get_node("HealthComponent")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	health.died.connect(_on_died)
	_restore_retry.call_deferred()

func _restore_retry() -> void:
	if get_tree().has_meta(&"player_retry_transform"):
		actor.global_transform = get_tree().get_meta(&"player_retry_transform")
		get_tree().remove_meta(&"player_retry_transform")
		var start := actor.get_parent().get_node_or_null("TraversalCourse/Start") as Node3D
		if start != null: start.global_transform = actor.global_transform

func _on_died() -> void:
	if defeated: return
	defeated = true
	InventoryUI.close()
	DialogueManager.end_dialogue()
	GameplayLocks.acquire(&"player_death")
	_owns_lock = true
	actor.velocity = Vector3.ZERO
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.025, 0.025, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var text := Label.new()
	text.text = "Defeated\nRetrying…"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 36)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(text)
	await get_tree().create_timer(retry_delay, true).timeout
	var retry := actor.global_transform
	var marker := get_node_or_null(encounter_retry_path) as Node3D
	if marker != null and actor.global_position.distance_to(marker.global_position) <= encounter_retry_radius:
		retry = marker.global_transform
	else:
		# The safe hub is the fallback for the reorganized prototype world.
		var start := actor.get_parent().get_node_or_null("CentralHub/Spawn") as Node3D
		if start != null: retry = start.global_transform
	retry = RespawnSession.resolve(retry)
	_release_lock()
	get_tree().paused = false
	if retry_requested.get_connections().is_empty():
		get_tree().set_meta(&"player_retry_transform", retry)
		get_tree().reload_current_scene()
	else:
		retry_requested.emit(retry)

func _release_lock() -> void:
	if _owns_lock:
		_owns_lock = false
		GameplayLocks.release(&"player_death")

func _exit_tree() -> void:
	_release_lock()
