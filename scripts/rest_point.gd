extends Node3D
## Authored safe location using the ordinary interaction capability.
signal rested(interactor: Node)
@export var rest_name := "Safe resting place"
@onready var interaction: InteractionComponent = $InteractionComponent

func _ready() -> void:
	add_to_group("rest_points")
	interaction.interaction_prompt = "Rest - " + rest_name
	interaction.availability_check = _can_rest
	interaction.interacted.connect(_on_interacted)
	$Label3D.text = rest_name

func _can_rest(actor: Node) -> bool:
	var recovery := actor.get_node_or_null("PlayerRecovery")
	var health := actor.get_node_or_null("HealthComponent") as HealthComponent
	return recovery != null and health != null and not health.is_dead()

func _on_interacted(actor: Node) -> void:
	var recovery := actor.get_node_or_null("PlayerRecovery")
	if recovery != null and recovery.rest(self): rested.emit(actor)
