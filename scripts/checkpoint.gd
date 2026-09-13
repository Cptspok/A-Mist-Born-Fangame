extends Area3D
@export var checkpoint_id: StringName
func _ready() -> void:
	body_entered.connect(_entered)
	RespawnSession.checkpoint_changed.connect(_update_label)
	_update_label(RespawnSession.checkpoint_id)
func _entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		RespawnSession.activate(checkpoint_id, $Respawn.global_transform)
func _update_label(active_id: StringName) -> void:
	$Label.text = "Checkpoint active" if active_id == checkpoint_id else "Checkpoint"
