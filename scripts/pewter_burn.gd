extends Node
## Pewter owns its modifiers/debt; shared Resources and health remain authoritative.
signal debt_changed(amount: float)
@export_range(0.0, 1.0, 0.05) var deferred_fraction := 0.5
@export_range(0.1, 100.0, 0.1) var debt_per_second := 5.0
@export_range(1.0, 2.0, 0.05) var jump_multiplier := 1.25
@export_range(0.0, 30.0, 0.5) var melee_impulse_bonus := 6.0
@export_range(0.0, 1.0, 0.05) var external_force_multiplier := 0.65
var debt: float = 0.0
var _enhanced := false
@onready var reserves: AllomancyComponent = $"../AllomancyComponent"
@onready var stats: StatComponent = $"../StatComponent"
@onready var health: HealthComponent = $"../HealthComponent"

func _ready() -> void:
	reserves.burn_started.connect(_burn_changed)
	reserves.burn_stopped.connect(_burn_changed)
	health.register_damage_processor(_defer_damage)
	health.died.connect(func(): set_physics_process(false))
	_burn_changed(&"pewter")

func _burn_changed(id: StringName) -> void:
	if id != &"pewter": return
	var burning := reserves.is_burning(id)
	if burning != _enhanced:
		_enhanced = burning
		stats.begin_update()
		stats.remove_modifiers_from_source(self)
		if burning:
			stats.add_modifier(StatIds.Stat.JUMP_MULTIPLIER, StatModifier.Operation.MORE_MULTIPLIER, jump_multiplier - 1.0, self)
			stats.add_modifier(StatIds.Stat.MELEE_IMPULSE, StatModifier.Operation.FLAT_ADD, melee_impulse_bonus, self)
			stats.add_modifier(StatIds.Stat.EXTERNAL_FORCE_MULTIPLIER, StatModifier.Operation.MORE_MULTIPLIER, external_force_multiplier - 1.0, self)
		stats.end_update()
	reserves.set_engaged(id, burning)
	set_physics_process(not burning and debt > 0.0 and not health.is_dead())

func _defer_damage(amount: float) -> float:
	if not reserves.is_burning(&"pewter"): return amount
	var deferred := amount * clampf(deferred_fraction, 0.0, 1.0)
	debt += deferred
	if deferred > 0.0: debt_changed.emit(debt)
	return amount - deferred

func _physics_process(delta: float) -> void:
	if health.is_dead() or reserves.is_burning(&"pewter"): return
	var payment := minf(debt, maxf(debt_per_second, 0.1) * delta)
	debt = maxf(0.0, debt - payment)
	# Normal health signals/death, but no second incoming-damage transformation.
	health.apply_damage(payment, false)
	debt_changed.emit(debt)
	if debt <= 0.0: set_physics_process(false)

func _exit_tree() -> void:
	if is_instance_valid(health): health.unregister_damage_processor(_defer_damage)
	if is_instance_valid(stats): stats.remove_modifiers_from_source(self)

## Treat injury without changing the burn state or any combat modifiers.
func recover_debt(amount: float) -> float:
	if not is_finite(amount) or amount <= 0.0 or health.is_dead(): return 0.0
	var treated := minf(amount, debt)
	debt -= treated
	if treated > 0.0: debt_changed.emit(debt)
	if debt <= 0.0: set_physics_process(false)
	return treated
