extends Node3D
## Reuses interaction and resource signals; no polling or ingestion system.
var _resources: AllomancyComponent
func _ready() -> void:
	$InteractionComponent.interacted.connect(_refill)
	call_deferred("_observe")
func _observe() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null: return
	_resources = player.get_node_or_null("AllomancyComponent") as AllomancyComponent
	if _resources != null:
		_resources.reserve_changed.connect(_changed)
		_changed(&"", 0.0, 0.0)
func _refill(interactor: Node) -> void:
	var resources := interactor.get_node_or_null("AllomancyComponent") as AllomancyComponent
	if resources != null: resources.refill_all()
func _changed(_id: StringName, _current: float, _maximum: float) -> void:
	var text := "Refill metals"
	for id in _resources.metal_ids():
		text += "\n%s: %.1f / %.1f" % [_resources.metal_name(id), _resources.reserve(id), _resources.maximum_reserve(id)]
	$Label.text = text
