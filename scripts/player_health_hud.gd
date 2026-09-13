extends Control

## Optional HealthComponent path; otherwise use the actor in the player group.
@export var health_component_path: NodePath
var _health: HealthComponent
var _pewter: Node
var _debt := 0.0

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_text: Label = $HealthText


func _ready() -> void:
	var health: HealthComponent
	if not health_component_path.is_empty():
		health = get_node_or_null(health_component_path) as HealthComponent
	else:
		var player := get_tree().get_first_node_in_group("player")
		if player != null:
			health = player.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		hide()
		push_warning("PlayerHealthHUD could not find the Player HealthComponent.")
		return
	if not health.is_node_ready():
		await health.ready
	_health = health
	_pewter = health.get_parent().get_node_or_null("PewterBurn")
	if _pewter != null:
		_debt = _pewter.debt
		_pewter.debt_changed.connect(_update_debt)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.15, 0.7, 0.3)
	health_bar.add_theme_stylebox_override("fill", fill)
	$DebtOverlay.draw.connect(_draw_debt)
	health.health_changed.connect(_update_health)
	_update_health(health.current_health, health.max_health)


func _update_health(current_health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_text.text = "%s / %s" % [String.num(current_health, 1), String.num(max_health, 1)]
	$DebtText.visible = _debt > 0.0
	$DebtText.text = "Debt %.1f%s" % [_debt, " - LETHAL" if _debt >= current_health and _debt > 0.0 else ""]
	$DebtText.modulate = Color(1, 0.25, 0.25) if _debt >= current_health else Color(0.8, 0.8, 0.8)
	$DebtOverlay.queue_redraw()

func _update_debt(amount: float) -> void:
	_debt = amount
	_update_health(_health.current_health, _health.max_health)

func _draw_debt() -> void:
	if _debt <= 0.0 or _health == null: return
	var overlay: Control = $DebtOverlay
	var hp_end := clampf(_health.current_health / _health.max_health, 0.0, 1.0) * overlay.size.x
	var covered := minf(_debt, _health.current_health) / _health.max_health * overlay.size.x
	overlay.draw_rect(Rect2(hp_end - covered, 0, covered, overlay.size.y), Color(0.6, 0.6, 0.6, 0.9))
	# Red threshold: HP must stay above total debt to survive full repayment.
	var threshold := clampf(_debt / _health.max_health, 0.0, 1.0) * (overlay.size.x - 2)
	overlay.draw_line(Vector2(threshold, 0), Vector2(threshold, overlay.size.y), Color(1, 0.1, 0.1), 2.0)
