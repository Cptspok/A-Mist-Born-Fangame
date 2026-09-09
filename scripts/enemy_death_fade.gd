extends Node

@export_range(0.0, 10.0, 0.1) var fade_delay: float = 0.5
@export_range(0.1, 10.0, 0.1) var fade_duration: float = 3.0
@onready var actor: EnemyController = get_parent()
var _started: bool = false


func _ready() -> void:
	actor.state_changed.connect(_on_state_changed)


func _on_state_changed(state: StringName) -> void:
	if state != &"Dead" or _started:
		return
	_started = true
	var tween := create_tween()
	tween.tween_interval(fade_delay)
	tween.tween_method(_fade, 0.0, 1.0, maxf(fade_duration, 0.1))
	tween.tween_callback(actor.queue_free)


func _fade(amount: float) -> void:
	for node in actor.visual_root.find_children("*", "GeometryInstance3D", true, false):
		# Per-instance transparency leaves shared imported materials untouched.
		(node as GeometryInstance3D).transparency = amount
