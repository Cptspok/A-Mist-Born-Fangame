extends Node
## Player policy stays outside reusable HealthComponent and item definitions.
signal healing_started(duration: float)
signal healing_finished(recovered: float)
signal healing_cancelled(reason: String)
signal condition_changed(condition: StringName)
## Subscribe on the player for all rest locations; no world reset policy here.
signal rested(rest_point: Node)

@export var natural_regen_enabled := true
@export_range(0.0, 120.0, 0.5, "suffix:s") var regen_delay_after_damage := 12.0
@export_range(0.0, 20.0, 0.1) var regen_rate := 1.0
## Fraction of maximum HP. Passive recovery never treats Debt.
@export_range(0.0, 1.0, 0.05) var regen_health_ceiling := 0.65
@export_range(0.0, 1.0, 0.05) var wounded_threshold := 0.5
@export_range(0.0, 1.0, 0.05) var critical_threshold := 0.2

var condition: StringName = &"healthy"
var healing_remaining := 0.0
var feedback := ""
var _feedback_remaining := 0.0
var _since_damage := 0.0
var _inventory: InventoryComponent
var _stack: ItemStack
var _amount := 0.0
var _interrupt_on_damage := true
var _completing := false
@onready var health: HealthComponent = $"../HealthComponent"
@onready var pewter: Node = $"../PewterBurn"

func _ready() -> void:
	health.damage_received.connect(_on_damage)
	health.health_changed.connect(_update_condition)
	health.died.connect(func(): cancel_healing("Healing cancelled: defeated"))
	_update_condition(health.current_health, health.max_health)

func needs_recovery() -> bool:
	return not health.is_dead() and (pewter.debt > 0.0 or health.current_health < health.max_health)

## All active recovery sources go through this Debt-first boundary.
func apply_recovery(amount: float) -> float:
	if not is_finite(amount) or amount <= 0.0 or health.is_dead(): return 0.0
	var treated: float = pewter.recover_debt(amount)
	return treated + health.heal(amount - treated)

func is_healing() -> bool:
	return _stack != null

func begin_healing(inventory: InventoryComponent, stack: ItemStack, amount: float, duration: float, interrupt_on_damage: bool) -> bool:
	if is_healing() or _completing or not needs_recovery(): return false
	if inventory != get_parent().get_node("InventoryComponent") or stack not in inventory.stacks or stack.quantity <= 0: return false
	if not is_finite(amount) or not is_finite(duration) or amount <= 0.0 or duration <= 0.0: return false
	_inventory = inventory
	_stack = stack
	_amount = amount
	_interrupt_on_damage = interrupt_on_damage
	healing_remaining = duration
	healing_started.emit(duration)
	return true

func cancel_healing(reason: String) -> void:
	if not is_healing(): return
	_clear_action()
	_notify(reason)
	healing_cancelled.emit(reason)

func rest(rest_point: Node) -> bool:
	if health.is_dead(): return false
	cancel_healing("Healing cancelled: resting")
	apply_recovery(float(pewter.debt) + health.max_health)
	_notify("Rested: health restored, Debt cleared")
	rested.emit(rest_point)
	return true

func _physics_process(delta: float) -> void:
	_since_damage += delta
	_feedback_remaining = maxf(0.0, _feedback_remaining - delta)
	if _feedback_remaining <= 0.0: feedback = ""
	if health.is_dead(): return
	if is_healing():
		if _stack not in _inventory.stacks or _stack.quantity <= 0:
			cancel_healing("Healing cancelled: item removed")
			return
		healing_remaining = maxf(0.0, healing_remaining - delta)
		if healing_remaining <= 0.0: _complete_healing()
		return
	if natural_regen_enabled and _since_damage >= regen_delay_after_damage and pewter.debt <= 0.0:
		var missing := maxf(0.0, health.max_health * clampf(regen_health_ceiling, 0.0, 1.0) - health.current_health)
		health.heal(minf(missing, maxf(0.0, regen_rate) * delta))

func _complete_healing() -> void:
	if not needs_recovery():
		cancel_healing("No recovery needed; item retained")
		return
	var inventory := _inventory
	var stack := _stack
	var amount := _amount
	# Clear first to make callbacks/repeated requests unable to finish twice.
	_completing = true
	_clear_action()
	if not inventory.consume_one(stack):
		_completing = false
		_notify("Healing cancelled: item removed")
		healing_cancelled.emit(feedback)
		return
	var recovered := apply_recovery(amount)
	_completing = false
	_notify("Recovered %.1f (Debt first)" % recovered)
	healing_finished.emit(recovered)

func _clear_action() -> void:
	_stack = null
	_inventory = null
	healing_remaining = 0.0
	_amount = 0.0

func _on_damage(_amount_received: float) -> void:
	_since_damage = 0.0
	if _interrupt_on_damage: cancel_healing("Healing interrupted; item retained")

func _update_condition(current: float, maximum: float) -> void:
	var ratio := current / maximum
	var next: StringName = &"critical" if ratio <= critical_threshold else (&"wounded" if ratio <= wounded_threshold else &"healthy")
	if next != condition:
		condition = next
		condition_changed.emit(condition)

func _notify(message: String) -> void:
	feedback = message
	_feedback_remaining = 3.0
