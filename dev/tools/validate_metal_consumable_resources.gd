extends SceneTree
## Resource-only audit. Does not instantiate the Workshop or run gameplay.
func _initialize() -> void:
	var failed := false
	for file in ["raw_steel", "basic_steel_vial", "pure_steel_vial", "basic_iron_vial", "basic_pewter_vial", "basic_mixed_vial"]:
		var item := load("res://data/items/consumables/metals/%s.tres" % file) as ItemDefinition
		if item == null or item.consumable == null:
			push_error("Invalid metal consumable: " + file)
			failed = true
	for path in ["res://dev/fixtures/inventory/workshop_item_supply.tscn", "res://dev/test_scenes/systems_workshop/systems_workshop.tscn", "res://ui/inventory/inventory_ui.gd"]:
		if load(path) == null:
			push_error("Failed resource load: " + path)
			failed = true
	print("Metal consumable resource audit: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
