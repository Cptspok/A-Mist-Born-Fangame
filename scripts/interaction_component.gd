class_name InteractionComponent
extends Area3D

## Text that UI code can present when this object is available to interact with.
@export_multiline var interaction_prompt: String = "Interact"

## Allows designers or gameplay code to temporarily disable this interaction.
@export var interaction_enabled: bool = true

signal interacted(interactor: Node)


func can_interact() -> bool:
	return interaction_enabled


func interact(interactor: Node) -> void:
	if not can_interact():
		return

	interacted.emit(interactor)
