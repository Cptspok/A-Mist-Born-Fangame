extends Control

## Optional HealthComponent path; otherwise use the actor in the player group.
@export var health_component_path: NodePath

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_text: Label = $HealthText


func _ready() -> void:
	var health: HealthComponent
	if not health_component_path.is_empty():
		health = get_node_or_null(health_component_path) as HealthComponent
	else:
		var player := get_tree().get_first_node_in_group("player")
		if player != null:
			health = player.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		hide()
		push_warning("PlayerHealthHUD could not find the Player HealthComponent.")
		return
	if not health.is_node_ready():
		await health.ready
	health.health_changed.connect(_update_health)
	_update_health(health.current_health, health.max_health)


func _update_health(current_health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_text.text = "%s / %s" % [String.num(current_health, 1), String.num(max_health, 1)]
