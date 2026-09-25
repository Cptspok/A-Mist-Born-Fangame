extends Node3D

@onready var controller: AllomancyController = get_parent()
var _visuals: Dictionary = {}
var _line: MeshInstance3D
var _line_mesh := ImmediateMesh.new()
var _label: Label
var _materials: Array[StandardMaterial3D] = []
var _capture_lines: MeshInstance3D
var _capture_mesh := ImmediateMesh.new()
const COM_COLOR := Color(1.0, 0.25, 0.8)
const REFERENCE_COLOR := Color(0.1, 0.9, 1.0)
const HOLD_COLOR := Color(0.3, 1.0, 0.25)
const STEP_COLOR := Color(1.0, 0.55, 0.1)
const COLORS := [Color("68d99b"), Color("72adf0"), Color("edab61"), Color("cd8ce8")]

func _ready() -> void:
	for color in COLORS: _materials.append(_material(color))
	_materials.append(_material(Color.YELLOW))
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.material_override = _material(Color.YELLOW)
	add_child(_line)
	_line.top_level = true
	_line.global_transform = Transform3D.IDENTITY
	_capture_lines = MeshInstance3D.new()
	_capture_lines.mesh = _capture_mesh
	var capture_material := _material(Color.WHITE)
	capture_material.vertex_color_use_as_albedo = true
	capture_material.no_depth_test = true
	_capture_lines.material_override = capture_material
	_capture_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_capture_lines)
	_capture_lines.top_level = true
	_capture_lines.global_transform = Transform3D.IDENTITY
	_capture_lines.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(330, 18)
	_label.add_theme_font_size_override("font_size", 15)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_label)
	# Parent controller configures Targeting after child _ready.
	controller.debug_changed.connect(_toggle)
	GameplayLocks.lock_changed.connect(func(_locked: bool): _refresh_label())
	controller.get_node("Targeting").target_changed.connect(_target_changed)
	_toggle(controller.debug_enabled)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

func _toggle(enabled: bool) -> void:
	set_process(enabled)
	_line.visible = enabled
	_capture_lines.visible = enabled
	for pair in _visuals.values():
		pair[0].visible = enabled
		pair[1].visible = enabled
	_refresh_label()

func _target_changed(_target: MetalTetherComponent) -> void:
	_refresh_label()

func _refresh_label() -> void:
	var target: MetalTetherComponent = controller.get_node("Targeting").selected
	_label.text = "Steel [%s]  Iron [%s]  Jump [%s]  Debug [%s]\n%s" % [
		InputHint.binding(&"steel_push"), InputHint.binding(&"iron_pull"),
		InputHint.binding(&"jump"), InputHint.binding(&"toggle_allomancy_debug"),
		("Metal: " + target.name + " / " + AllomancyTuning.ResponseClass.keys()[target.allomancy_class]) if is_instance_valid(target) else "Metal: aim at a visible tether"]
	if controller.debug_enabled and is_instance_valid(controller.player):
		if is_instance_valid(target) and target.is_available() and target.capture_enabled:
			var center_offset := target.get_force_position() - controller.player.get_allomantic_origin()
			_label.text += "\nCOM range %.2f m | height vs torso %+.2f m" % [Vector2(center_offset.x, center_offset.z).length(), center_offset.y]
		if is_instance_valid(controller.capture) and is_instance_valid(controller.capture.tether):
			_label.text += "\nCAPTURE %s: aim, Steel to throw / release Iron to drop" % controller.capture.phase_name()
		_label.text += "\nVelocity %s" % controller.player.velocity
		var sample := controller.last_interaction
		if not sample.is_empty():
			_label.text += "\n%s player-force axis %s\nRelative %.2f / %.2f m/s | factor %.3f\nForce: Player %s | object %s" % [
				sample.power, sample.axis, sample.speed, sample.terminal, sample.factor,
				sample.player_force, sample.object_force]
		elif is_instance_valid(controller.capture) and is_instance_valid(controller.capture.tether):
			_label.text += "\nLoose-metal %s owns motion" % controller.capture.phase_name()
		else:
			_label.text += "\nApplied Allomancy force: 0 (released / no target / both held)"
	_label.visible = controller.debug_enabled and not GameplayLocks.is_locked()
	if _capture_debug_enabled():
		var capture_sample: Dictionary = controller.capture.debug_snapshot()
		if not capture_sample.is_empty():
			_label.text += "\nLOOSE %s | blocked %.2fs\nPhysical COM: pink | reference: cyan | HELD: green\nApplied swept step: orange | throw ray: white" % [capture_sample.state, capture_sample.blocked]
			_label.text += "\nCOM-reference error %.3fm | swept velocity %s" % [capture_sample.com.distance_to(capture_sample.reference), capture_sample.command_velocity]
		elif is_instance_valid(target) and target.capture_enabled:
			_label.text += "\nLOOSE FREE | physical COM: pink"
		var release_sample := controller.last_captured_launch
		if _recent_launch(release_sample):
			_label.text += "\nLast captured launch: axis %s\nClean v %s | equivalent impulse %s\nImmediate solver v %s" % [release_sample.axis, release_sample.clean_velocity, release_sample.impulse, release_sample.velocity]

func _process(_delta: float) -> void:
	_refresh_label()
	_refresh_capture_visuals()
	var targeting: AllomancyTargeting = controller.get_node("Targeting")
	var nearby := targeting.nearby()
	for tether in _visuals.keys():
		if not is_instance_valid(tether) or tether not in nearby:
			for visual in _visuals[tether]: visual.queue_free()
			_visuals.erase(tether)
	for tether in nearby:
		if not is_instance_valid(tether): continue
		if not tether.is_available():
			if _visuals.has(tether):
				_visuals[tether][0].hide()
				_visuals[tether][1].hide()
			continue
		if not _visuals.has(tether):
			var wire := MeshInstance3D.new()
			wire.mesh = tether.volume.shape.get_debug_mesh()
			add_child(wire)
			wire.top_level = true
			var title := Label3D.new()
			title.font_size = 22
			title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			add_child(title)
			title.top_level = true
			_visuals[tether] = [wire, title]
		var pair: Array = _visuals[tether]
		var selected := targeting.selected == tether
		var color: Color = Color.YELLOW if selected else COLORS[tether.allomancy_class]
		pair[0].global_transform = _presentation_transform(tether, tether.volume.global_transform)
		pair[0].material_override = _materials[4 if selected else tether.allomancy_class]
		pair[0].show()
		pair[1].show()
		pair[1].global_position = pair[0].global_position + Vector3.UP * 0.7
		pair[1].text = AllomancyTuning.ResponseClass.keys()[tether.allomancy_class] + (" *" if selected else "")
		pair[1].modulate = color
	_line_mesh.clear_surfaces()
	# This line depicts FREE Allomancy only. The old origin-to-COM line was
	# misleading during capture because it is no longer the launch direction.
	if is_instance_valid(targeting.selected) and not is_instance_valid(controller.capture.tether):
		_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		var origin := controller.player.get_allomantic_origin()
		_line_mesh.surface_add_vertex(origin)
		var endpoint := Transform3D(Basis.IDENTITY, targeting.selected.get_force_position())
		_line_mesh.surface_add_vertex(_presentation_transform(targeting.selected, endpoint).origin)
		_line_mesh.surface_end()

func _capture_debug_enabled() -> bool:
	return controller.debug_enabled and is_instance_valid(controller.capture) and controller.capture.show_loose_metal_capture_debug and not GameplayLocks.is_locked()

func _recent_launch(sample: Dictionary) -> bool:
	return not sample.is_empty() and Time.get_ticks_msec() - int(sample.time_ms) < 2500

func _segment(start: Vector3, end: Vector3, color: Color) -> void:
	_capture_mesh.surface_set_color(color)
	_capture_mesh.surface_add_vertex(start)
	_capture_mesh.surface_set_color(color)
	_capture_mesh.surface_add_vertex(end)

func _marker(point: Vector3, size: float, color: Color) -> void:
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		_segment(point - axis * size, point + axis * size, color)

func _axis_ray(point: Vector3, axis: Vector3) -> void:
	var end := point + axis * 2.0
	_segment(point, end, Color.WHITE)
	var side := axis.cross(Vector3.UP).normalized()
	if side.is_zero_approx(): side = Vector3.RIGHT
	_segment(end, end - axis * 0.18 + side * 0.08, Color.WHITE)
	_segment(end, end - axis * 0.18 - side * 0.08, Color.WHITE)

func _refresh_capture_visuals() -> void:
	_capture_mesh.clear_surfaces()
	_capture_lines.visible = _capture_debug_enabled()
	if not _capture_lines.visible: return
	var sample: Dictionary = controller.capture.debug_snapshot()
	var target: MetalTetherComponent = controller.targeting.selected
	var release_sample := controller.last_captured_launch
	var free_target := is_instance_valid(target) and target.capture_enabled and target.is_available()
	if sample.is_empty() and not free_target and not _recent_launch(release_sample): return
	_capture_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# Deliberately use physical coordinates, NOT interpolated presentation poses.
	# This exposes a reference/body mismatch instead of concealing one visually.
	if not sample.is_empty():
		_marker(sample.com, 0.085, COM_COLOR)
		_marker(sample.hold, 0.14, HOLD_COLOR)
		_marker(sample.step_target, 0.045, STEP_COLOR)
		if sample.state == "APPROACH" and sample.reference_ready:
			_marker(sample.reference, 0.11, REFERENCE_COLOR)
			_segment(sample.com, sample.hold, REFERENCE_COLOR)
		if sample.state == "HELD": _axis_ray(sample.com, sample.axis)
	elif free_target:
		_marker(target.get_force_position(), 0.085, COM_COLOR)
	if _recent_launch(release_sample):
		_axis_ray(release_sample.origin, release_sample.axis)
	_capture_mesh.surface_end()

func _presentation_transform(tether: MetalTetherComponent, physical: Transform3D) -> Transform3D:
	var body := tether.get_physical_owner()
	if is_instance_valid(body) and body.has_method("get_presentation_transform"):
		return body.get_presentation_transform() * body.global_transform.affine_inverse() * physical
	return physical
