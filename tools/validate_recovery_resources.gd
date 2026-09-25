extends SceneTree
## Resource loading only: no actor instantiation or simulated healing/combat.
func _initialize() -> void:
	var failed := false
	for path in ["res://scripts/player_recovery.gd", "res://scripts/rest_point.gd", "res://scripts/player_health_hud.gd", "res://resources/healing/medical_supplies.tres", "res://resources/metal_consumables/basic_pewter_vial.tres", "res://scenes/rest_point.tscn", "res://scenes/player.tscn", "res://scenes/mini_city.tscn"]:
		var resource := load(path)
		if resource == null or (resource is GDScript and not resource.can_instantiate()):
			push_error("Invalid recovery resource: " + path)
			failed = true
	print("Recovery resource audit: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
