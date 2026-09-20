class_name InventoryComponent
extends Node

@export_range(1, 20, 1) var grid_width := 3
@export_range(1, 20, 1) var grid_height := 3
var stacks: Array[ItemStack] = []
signal contents_changed
signal item_added(definition: ItemDefinition)
signal pickup_rejected(definition: ItemDefinition)
signal throw_requested(stack: ItemStack)

func _ready() -> void:
	add_to_group("inventory_components")

func can_place(definition: ItemDefinition, position: Vector2i, ignored: ItemStack = null) -> bool:
	if definition == null or position.x < 0 or position.y < 0 or position.x + definition.grid_width > grid_width or position.y + definition.grid_height > grid_height:
		return false
	for stack in stacks:
		if stack == ignored:
			continue
		if _rects_overlap(position, definition.grid_width, definition.grid_height, stack.grid_position, stack.definition.grid_width, stack.definition.grid_height):
			return false
	return true

func try_add(definition: ItemDefinition, quantity := 1) -> bool:
	if definition == null or quantity <= 0: return false
	var clue := definition.intelligence_clue
	# Documents are read into the journal through the same pickup transaction.
	# They do not consume grid space; duplicate documents yield no extra reward.
	if clue != null:
		if clue.unique_id == &"" or clue.target == null or clue.target.unique_id == &"":
			pickup_rejected.emit(definition)
			return false
		if RespawnSession.knowledge.discover(clue): item_added.emit(definition)
		return true
	for y in grid_height:
		for x in grid_width:
			var position := Vector2i(x, y)
			if can_place(definition, position):
				stacks.append(ItemStack.new(definition, quantity, position))
				contents_changed.emit()
				item_added.emit(definition)
				return true
	pickup_rejected.emit(definition)
	return false

func try_move(stack: ItemStack, position: Vector2i) -> bool:
	if stack in stacks and can_place(stack.definition, position, stack):
		stack.grid_position = position
		contents_changed.emit()
		return true
	return false

func remove(stack: ItemStack) -> void:
	if stack in stacks:
		stacks.erase(stack)
		contents_changed.emit()

func request_throw(stack: ItemStack) -> void:
	if stack in stacks:
		throw_requested.emit(stack)

## Only owned inventory stacks can be consumed. Shared definitions are immutable.
func try_use(stack: ItemStack) -> bool:
	if stack == null or stack not in stacks or stack.quantity <= 0 or stack.definition == null:
		return false
	var consumable := stack.definition.consumable
	if consumable == null or not consumable.apply(get_parent()):
		return false
	stack.quantity -= 1
	if stack.quantity == 0:
		stacks.erase(stack)
	contents_changed.emit()
	return true

func _rects_overlap(a: Vector2i, aw: int, ah: int, b: Vector2i, bw: int, bh: int) -> bool:
	return a.x < b.x + bw and a.x + aw > b.x and a.y < b.y + bh and a.y + ah > b.y
