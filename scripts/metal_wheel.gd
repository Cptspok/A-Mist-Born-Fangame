extends Control
## View only: wedge hover is not a selected/active metal state.
var _resources: AllomancyComponent
var _router: Node
var _ids: Array = []
var _hover := -1
const INNER := 65.0
const OUTER := 215.0

func _ready() -> void:
	_resources = get_node("../../AllomancyComponent")
	_router = get_node("../../ContextualInput")
	_ids = _resources.metal_ids()
	while _ids.size() < 4: _ids.append(&"") # anonymous locked slots, no invented powers
	_router.wheel_changed.connect(func(open: bool): visible = open; queue_redraw())
	_resources.reserve_changed.connect(func(_id, _current, _maximum): if visible: queue_redraw())
	_resources.burn_started.connect(func(_id): queue_redraw())
	_resources.burn_stopped.connect(func(_id): queue_redraw())
	_resources.access_changed.connect(func(_id, _available): queue_redraw())
	hide()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var offset: Vector2 = event.position - size * 0.5
		_hover = int(fposmod(offset.angle() + PI * 0.5, TAU) / TAU * _ids.size()) if offset.length() >= INNER and offset.length() <= OUTER else -1
		queue_redraw()
	if event is InputEventMouseButton:
		accept_event()
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _hover >= 0:
			_resources.toggle_burn(_ids[_hover])

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.55))
	var center := size * 0.5
	var font := ThemeDB.fallback_font
	for i in _ids.size():
		var id: StringName = _ids[i]
		var start := -PI * 0.5 + TAU * i / _ids.size() + 0.025
		var finish := -PI * 0.5 + TAU * (i + 1) / _ids.size() - 0.025
		var points := PackedVector2Array()
		for j in range(25): points.append(center + Vector2.from_angle(lerpf(start, finish, j / 24.0)) * OUTER)
		for j in range(24, -1, -1): points.append(center + Vector2.from_angle(lerpf(start, finish, j / 24.0)) * INNER)
		var unlocked := _resources.has_access(id)
		var burning := _resources.is_burning(id)
		var color := Color(0.12, 0.42, 0.3) if burning else Color(0.2, 0.25, 0.32)
		if not unlocked: color = Color(0.3, 0.08, 0.09)
		elif i == _hover: color = color.lightened(0.15)
		draw_colored_polygon(points, color)
		var label := (_resources.metal_name(id) + (" ON" if burning else " OFF")) if unlocked else "LOCKED"
		var at := center + Vector2.from_angle((start + finish) * 0.5) * 140.0
		draw_string(font, at - Vector2(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x * 0.5, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		if unlocked:
			var reserve_text := "%.1f / %.0f" % [_resources.reserve(id), _resources.maximum_reserve(id)]
			draw_string(font, at + Vector2(-font.get_string_size(reserve_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 0.5, 24), reserve_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_string(font, center + Vector2(-42, 0), "METALS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_string(font, center + Vector2(-180, OUTER + 40), "Click to toggle burns - Release Shift to close", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

