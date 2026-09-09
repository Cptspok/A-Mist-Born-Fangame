extends Node

const DIALOGUE_PANEL_SCENE: PackedScene = preload("res://scenes/dialogue_panel.tscn")

## InputMap action used to advance the active dialogue.
@export var advance_action: StringName = &"advance_dialogue"

var active_dialogue: DialogueData
var active_speaker_name := ""
var line_index := 0

@onready var dialogue_panel: DialoguePanel = DIALOGUE_PANEL_SCENE.instantiate()


func _ready() -> void:
	add_child(dialogue_panel)


func start_dialogue(speaker_name: String, dialogue: DialogueData) -> void:
	if dialogue == null or dialogue.lines.is_empty():
		return

	active_speaker_name = speaker_name
	GameplayLocks.acquire(&"dialogue")
	active_dialogue = dialogue
	line_index = 0
	_show_current_line()


func _unhandled_input(event: InputEvent) -> void:
	if active_dialogue != null and event.is_action_pressed(advance_action):
		advance_dialogue()
		get_viewport().set_input_as_handled()


func advance_dialogue() -> void:
	if active_dialogue == null:
		return
	line_index += 1
	if line_index >= active_dialogue.lines.size():
		end_dialogue()
		return

	_show_current_line()


func end_dialogue() -> void:
	active_dialogue = null
	active_speaker_name = ""
	line_index = 0
	dialogue_panel.hide_dialogue()
	GameplayLocks.release(&"dialogue")


func _show_current_line() -> void:
	dialogue_panel.show_line(active_speaker_name, active_dialogue.lines[line_index])
