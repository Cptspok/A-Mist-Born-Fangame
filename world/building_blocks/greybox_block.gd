@tool
extends StaticBody3D
## Opt-in presentation override. Existing untargeted blocks keep their tint.
@export var surface_material: Material:
 set(value):
  surface_material = value
  if is_node_ready(): $Mesh.material_override = surface_material
## Single authored dimension drives the visible box and its collision.
@export var dimensions := Vector3(6, 1, 6):
 set(value):
  dimensions = value.max(Vector3.ONE * 0.1)
  if is_node_ready(): _sync()
@export var tint := Color(0.48, 0.52, 0.56):
 set(value):
  tint = value
  if is_node_ready(): _sync()
func _ready() -> void:
 _sync()
func _sync() -> void:
 var box := BoxMesh.new()
 box.size = dimensions
 var material := StandardMaterial3D.new()
 material.albedo_color = tint
 material.roughness = 1.0
 box.material = material
 $Mesh.mesh = box
 if surface_material != null: $Mesh.material_override = surface_material
 var shape := BoxShape3D.new()
 shape.size = dimensions
 $CollisionShape3D.shape = shape
