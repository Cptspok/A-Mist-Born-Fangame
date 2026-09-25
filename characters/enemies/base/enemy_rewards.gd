extends RefCounted
const PICKUP = preload("res://world/world_items/world_item.tscn")

static func drop(actor: Node3D, rewards: EnemyRewardDefinition) -> void:
	if rewards == null or not actor.is_inside_tree(): return
	var items: Array[ItemDefinition] = rewards.items.duplicate()
	var seen: Dictionary = {}
	for clue in rewards.intelligence_clues:
		if clue == null or clue.unique_id == &"" or clue.target == null or clue.target.unique_id == &"": continue
		if seen.has(clue.unique_id) or RespawnSession.knowledge.has_clue(clue.unique_id): continue
		seen[clue.unique_id] = true
		# Construct a new document definition; never modify an authored resource.
		var document := ItemDefinition.new()
		document.item_id = "intelligence/" + String(clue.unique_id)
		document.display_name = clue.display_name
		document.item_type = "Intelligence"
		document.description = clue.clue_text
		document.inventory_sprite = clue.icon
		document.intelligence_clue = clue
		items.append(document)
	for index in items.size():
		if items[index] == null: continue
		var pickup := PICKUP.instantiate() as WorldItem
		pickup.item_definition = items[index]
		actor.get_parent().add_child(pickup)
		# Keep drops at the corpse's floor height, including rooftop carriers.
		var angle := TAU * float(index) / maxf(items.size(), 1.0)
		pickup.global_position = actor.global_position + Vector3(cos(angle) * 0.65, -0.35, sin(angle) * 0.65)
		pickup.get_node("InteractionComponent").interaction_prompt = "Pick up " + items[index].display_name
