extends Node3D

@export var inactive_color := Color(0.8, 0.25, 0.2, 1.0)
@export var active_color := Color(0.25, 0.8, 0.3, 1.0)

var is_active := false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
@onready var interaction_component: InteractionComponent = $InteractionComponent


func _ready() -> void:
	interaction_component.interacted.connect(_on_interacted)
	_update_visual()


func _on_interacted(_interactor: Node) -> void:
	is_active = not is_active
	_update_visual()


func _update_visual() -> void:
	material.albedo_color = active_color if is_active else inactive_color
