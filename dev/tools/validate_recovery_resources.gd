extends SceneTree
## Resource loading only: no actor instantiation or simulated healing/combat.
func _initialize() -> void:
	var failed := false
	for path in ["res://characters/player/player_recovery.gd", "res://world/interactables/rest_point/rest_point.gd", "res://ui/hud/health/player_health_hud.gd", "res://data/items/consumables/healing/medical_supplies.tres", "res://data/items/consumables/metals/basic_pewter_vial.tres", "res://world/interactables/rest_point/rest_point.tscn", "res://characters/player/player.tscn", "res://world/levels/mini_city/mini_city.tscn"]:
		var resource := load(path)
		if resource == null or (resource is GDScript and not resource.can_instantiate()):
			push_error("Invalid recovery resource: " + path)
			failed = true
	print("Recovery resource audit: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
