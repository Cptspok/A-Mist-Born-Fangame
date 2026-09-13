extends Node3D
## Course-local failure plane. F6 restarts the complete fixture state.
@export var fall_height := -5.0
@export_node_path("CharacterBody3D") var player_path := NodePath("../Player")
@onready var player: CharacterBody3D = get_node(player_path)
func _physics_process(_delta: float) -> void:
 if player.global_position.y < global_position.y + fall_height:
  player.global_transform = RespawnSession.resolve($Start.global_transform)
  player.velocity = Vector3.ZERO
  player.get_node("CameraPivot").rotation = Vector3.ZERO
  player.get_node("Allomancy/Targeting").clear_target()
func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("reset_test") and not event.is_echo():
  get_viewport().set_input_as_handled()
  RespawnSession.reset()
  get_tree().reload_current_scene()
