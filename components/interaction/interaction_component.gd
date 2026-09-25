class_name InteractionComponent
extends Area3D

## Text that UI code can present when this object is available to interact with.
@export_multiline var interaction_prompt: String = "Interact"

## Allows designers or gameplay code to temporarily disable this interaction.
@export var interaction_enabled: bool = true

signal interacted(interactor: Node)

## Optional actor-specific filter shared by selection, prompt and activation.
var availability_check: Callable


func can_interact() -> bool:
	return interaction_enabled


func can_interact_with(interactor: Node) -> bool:
	return can_interact() and (not availability_check.is_valid() or availability_check.call(interactor))


func interact(interactor: Node) -> void:
	if not can_interact_with(interactor):
		return

	interacted.emit(interactor)
