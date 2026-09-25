extends SceneTree
## Offline bake: godot --headless --path . --script res://dev/tools/bake_mini_city.gd
func _initialize() -> void:
	call_deferred("bake_city")

func bake_city() -> void:
	var city = load("res://world/levels/mini_city/mini_city.tscn").instantiate()
	root.add_child(city)
	city.process_mode = Node.PROCESS_MODE_DISABLED
	# Inherit established bake settings without mutating the legacy resource.
	var mesh: NavigationMesh = load("res://dev/data/navigation/testing_zone_navigation.tres").duplicate()
	mesh.clear()
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, city)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var error := ResourceSaver.save(mesh, "res://world/levels/mini_city/navigation/mini_city_navigation.tres")
	print("City bake: polygons=", mesh.get_polygon_count(), " save_error=", error)
	quit(0 if error == OK and mesh.get_polygon_count() > 0 else 1)
