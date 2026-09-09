class_name EnemyController
extends CharacterBody3D

@export_group("Identity")
@export var display_name: String = "Enemy"

@export_group("Visuals")
@export var visual_scene: PackedScene
@export var animation_player_path: NodePath
@export var idle_animation: StringName

@export_group("Body")
@export_range(0.05, 10.0, 0.05, "or_greater") var collision_radius: float = 0.4
@export_range(0.1, 20.0, 0.1, "or_greater") var collision_height: float = 1.8

var is_active: bool:
	get:
		return _is_active

var _is_active: bool = true

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual_root: Node3D = $VisualRoot
@onready var health_component: HealthComponent = $HealthComponent


func _ready() -> void:
	_configure_collision()
	_instantiate_visual()
	_play_idle_animation()
	health_component.died.connect(_on_died)


func _configure_collision() -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return

	capsule = capsule.duplicate() as CapsuleShape3D
	capsule.radius = collision_radius
	capsule.height = maxf(collision_height, collision_radius * 2.0)
	collision_shape.shape = capsule


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


func _on_died() -> void:
	_is_active = false
