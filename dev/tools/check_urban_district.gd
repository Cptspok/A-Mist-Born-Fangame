extends SceneTree
## One short startup sanity check, not a gameplay test suite.
func _initialize() -> void:
	_check.call_deferred()

func _check() -> void:
	var session := root.get_node("RespawnSession")
	var original_catalog: Resource = session.intelligence_catalog
	var shell: Node = load("res://systems/session/playtest_shell.tscn").instantiate()
	root.add_child(shell)
	current_scene = shell
	shell._action("urban")
	shell._action("resume")
	await create_timer(0.4).timeout
	var world: Node3D = shell.world
	assert(world.name == "AshmarketDistrict")
	assert(world.get_node("Player") == shell.player)
	assert(session.intelligence_catalog.targets[0].unique_id == &"ashmarket_voss")
	assert(world.get_node("Gameplay/Enemies/Terrace_Archer/Sensing").detection_range == 25.0)
	assert(not world.get_node("Gameplay/CabinCheckpoint/Marker").visible)
	assert(world.get_node("Gameplay/Metalwork/IronRailing/Solid/MetalTether/CollisionShape3D").shape is BoxShape3D)
	assert(NavigationServer3D.map_get_iteration_id(world.get_world_3d().navigation_map) > 0)
	assert(world.get_node("Gameplay/Enemies").get_child_count() == 12)
	assert(shell.player.position.y > 0.5)
	print("URBAN_STARTUP_OK: shell entry, Player/HUD, district catalog, 12 enemies, tether and checkpoint overrides, navigation registered")
	shell._action("main")
	assert(session.intelligence_catalog == original_catalog)
	print("URBAN_EXIT_OK: original Court catalog restored")
	# The shell detaches and queues the level; allow its deferred deletion before exit.
	await process_frame
	await process_frame
	quit()
