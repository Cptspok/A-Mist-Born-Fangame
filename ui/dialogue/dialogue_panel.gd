class_name DialoguePanel
extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var speaker_label: Label = $Panel/MarginContainer/Rows/SpeakerLabel
@onready var line_label: Label = $Panel/MarginContainer/Rows/LineLabel


func _ready() -> void:
	panel.hide()


func show_line(speaker_name: String, line: String) -> void:
	speaker_label.text = speaker_name
	line_label.text = line
	panel.show()


func hide_dialogue() -> void:
	panel.hide()
