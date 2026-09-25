class_name Npc
extends CharacterBody3D

## Name shown by dialogue presentation.
@export var display_name := "NPC"

## Ordered dialogue lines presented when this NPC is interacted with.
@export var dialogue_data: DialogueData

## Optional visual scene instantiated under VisualRoot.
@export var visual_scene: PackedScene

## Optional AnimationPlayer path and animation to play after the visual is created.
@export var animation_player_path: NodePath
@export var idle_animation: StringName

@onready var interaction_component: InteractionComponent = $InteractionComponent
@onready var visual_root: Node3D = $VisualRoot


func _ready() -> void:
	interaction_component.interacted.connect(_on_interacted)
	_instantiate_visual()
	_play_idle_animation()


func _on_interacted(_interactor: Node) -> void:
	DialogueManager.start_dialogue(display_name, dialogue_data)


func _instantiate_visual() -> void:
	if visual_scene == null:
		return

	visual_root.add_child(visual_scene.instantiate())


func _play_idle_animation() -> void:
	if animation_player_path.is_empty() or idle_animation.is_empty():
		return

	var animation_player := get_node_or_null(animation_player_path) as AnimationPlayer
	if animation_player != null and animation_player.has_animation(idle_animation):
		animation_player.play(idle_animation)
