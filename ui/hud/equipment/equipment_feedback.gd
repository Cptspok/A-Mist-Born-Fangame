extends Control

@export_range(1.0, 10.0, 0.5) var notification_duration: float = 4.0
@onready var active_text: Label = $ActiveWeapon
@onready var toast: Label = $PickupToast
@onready var timer: Timer = $ToastTimer
var _equipment: PlayerCombat
var _pickup: ItemDefinition


func _ready() -> void:
	add_to_group("input_binding_hints")
	toast.hide()
	timer.timeout.connect(toast.hide)
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		hide()
		return
	_equipment = player.get_node_or_null("CombatEquipment") as PlayerCombat
	var inventory := player.get_node_or_null("InventoryComponent") as InventoryComponent
	if _equipment == null or inventory == null:
		hide()
		return
	_equipment.equipment_changed.connect(refresh_bindings)
	inventory.item_added.connect(_on_item_added)
	refresh_bindings()


## Call after InputMap rebinding (or call this on group input_binding_hints).
func refresh_bindings() -> void:
	if not is_instance_valid(_equipment):
		return
	var stack := _equipment.get_equipped_stack(_equipment.active_slot)
	active_text.text = "Unarmed"
	if stack != null:
		active_text.text = stack.definition.display_name
		var data := stack.definition.combat_definition
		if data != null:
			if not data.primary_action_label.is_empty():
				active_text.text += "\n%s — %s" % [InputHint.binding(&"primary_action"), data.primary_action_label]
			if not data.secondary_action_label.is_empty():
				active_text.text += "\n%s — %s" % [InputHint.binding(&"secondary_action"), data.secondary_action_label]
	if toast.visible and _pickup != null:
		_update_toast()


func _on_item_added(definition: ItemDefinition) -> void:
	_pickup = definition
	_update_toast()
	toast.show()
	timer.start(notification_duration)


func _update_toast() -> void:
	toast.text = "%s added to inventory" % _pickup.display_name
	if _pickup.equipment_profile != null:
		toast.text += "\nOpen Inventory [%s] to equip" % InputHint.binding(&"toggle_inventory")
