extends Control
## Replaceable presentation: state and costs belong to AllomancyComponent.
var _resources: AllomancyComponent
@export var resource_component_path: NodePath
@onready var steel_bar: ProgressBar = $Rows/Steel/Bar
@onready var iron_bar: ProgressBar = $Rows/Iron/Bar
@onready var steel_text: Label = $Rows/Steel/Text
@onready var iron_text: Label = $Rows/Iron/Text

func _ready() -> void:
	var resources: AllomancyComponent
	if not resource_component_path.is_empty():
		resources = get_node_or_null(resource_component_path) as AllomancyComponent
	else:
		var player := get_tree().get_first_node_in_group("player")
		if player != null: resources = player.get_node_or_null("AllomancyComponent") as AllomancyComponent
	if resources == null:
		hide()
		return
	if not resources.is_node_ready(): await resources.ready
	_resources = resources
	resources.reserve_changed.connect(_update)
	resources.burn_started.connect(_burn_changed)
	resources.burn_stopped.connect(_burn_changed)
	var router = get_tree().get_first_node_in_group("player").get_node("ContextualInput")
	router.focus_changed.connect(func(focused: bool): $Focus.text = "FOCUSED: Push / Pull" if focused else "Equipment")
	_update(&"steel", resources.reserve(&"steel"), resources.maximum_reserve(&"steel"))
	_update(&"iron", resources.reserve(&"iron"), resources.maximum_reserve(&"iron"))

func _update(id: StringName, current: float, maximum: float) -> void:
	if id != &"steel" and id != &"iron": return
	var bar := steel_bar if id == &"steel" else iron_bar
	var label := steel_text if id == &"steel" else iron_text
	bar.max_value = maxf(maximum, 0.001)
	bar.value = current
	label.text = "%s %s  %.1f / %.0f" % ["Steel" if id == &"steel" else "Iron", "ON" if _resources.is_burning(id) else "OFF", current, maximum]

func _burn_changed(id: StringName) -> void:
	_update(id, _resources.reserve(id), _resources.maximum_reserve(id))
