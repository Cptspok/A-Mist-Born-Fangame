extends Control
## Replaceable gameplay feedback, independent of debug overlays and damage math.
var _incoming: StringName = &"hit"
var _remaining := 0.0
var _hit_remaining := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func show_incoming(result: StringName) -> void:
	_incoming = result
	_remaining = 0.8 if result == &"overwhelmed" else 0.6
	queue_redraw()

func show_hit() -> void:
	_hit_remaining = 0.16
	queue_redraw()

func _process(delta: float) -> void:
	visible = not GameplayLocks.is_locked()
	_remaining = maxf(0.0, _remaining - delta)
	_hit_remaining = maxf(0.0, _hit_remaining - delta)
	queue_redraw()

func _caption(text: String, at: Vector2, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var origin := at - Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x * 0.5, 0)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color.BLACK)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)

func _draw() -> void:
	var center := get_viewport_rect().size * 0.5
	var combat := get_parent().get_parent() as PlayerCombat
	if combat.health.is_dead(): return
	var status := combat.guard_status()
	if not status.is_empty(): _caption(status, center + Vector2(0, 106), Color(0.65, 0.9, 1.0))
	if _hit_remaining > 0.0:
		for x in [-1.0, 1.0]:
			for y in [-1.0, 1.0]:
				draw_line(center + Vector2(x, y) * 7, center + Vector2(x, y) * 14, Color.WHITE, 3, true)
	if _remaining <= 0.0: return
	var color := Color(1.0, 0.2, 0.18)
	var caption := "HIT"
	match _incoming:
		&"blocked":
			color = Color(0.25, 0.95, 1.0)
			caption = "BLOCKED"
		&"overwhelmed":
			color = Color(1.0, 0.5, 0.12)
			caption = "GUARD OVERWHELMED"
		&"bypassed":
			color = Color(1.0, 0.3, 0.65)
			caption = "GUARD BYPASSED"
	color.a = minf(1.0, _remaining / 0.15)
	_caption(caption, center + Vector2(0, 77), color)
	if _incoming in [&"blocked", &"overwhelmed"]:
		var shield := PackedVector2Array([Vector2(-22, -16), Vector2(22, -16), Vector2(18, 12), Vector2(0, 26), Vector2(-18, 12), Vector2(-22, -16)])
		for i in range(shield.size()): shield[i] += center + Vector2(0, 30)
		draw_polyline(shield, color, 4, true)
		if _incoming == &"overwhelmed":
			draw_polyline(PackedVector2Array([center + Vector2(4, 14), center + Vector2(-5, 28), center + Vector2(7, 34), center + Vector2(-2, 56)]), Color.BLACK, 6, true)
	else:
		draw_rect(Rect2(Vector2(5, 5), get_viewport_rect().size - Vector2(10, 10)), Color(color, color.a * 0.55), false, 8)
		if _incoming == &"bypassed":
			for x in [-1.0, 1.0]:
				draw_polyline(PackedVector2Array([center + Vector2(x * 38, 15), center + Vector2(x * 26, 30), center + Vector2(x * 38, 45)]), color, 4, true)
