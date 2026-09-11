extends Node3D

@onready var controller: AllomancyController = get_parent()
var _visuals: Dictionary = {}
var _line: MeshInstance3D
var _line_mesh := ImmediateMesh.new()
var _label: Label
var _materials: Array[StandardMaterial3D] = []
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
		_label.text += "\nVelocity %s" % controller.player.velocity
		var sample := controller.last_interaction
		if not sample.is_empty():
			_label.text += "\n%s axis %s\nRelative %.2f / %.2f m/s | factor %.3f\nForce: Player %s | object %s" % [
				sample.power, sample.axis, sample.speed, sample.terminal, sample.factor,
				sample.player_force, sample.object_force]
		else:
			_label.text += "\nApplied Allomancy force: 0 (released / no target / both held)"
	_label.visible = controller.debug_enabled and not GameplayLocks.is_locked()

func _process(_delta: float) -> void:
	_refresh_label()
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
		pair[0].global_transform = tether.volume.global_transform
		pair[0].material_override = _materials[4 if selected else tether.allomancy_class]
		pair[0].show()
		pair[1].show()
		pair[1].global_position = tether.volume.global_position + Vector3.UP * 0.7
		pair[1].text = AllomancyTuning.ResponseClass.keys()[tether.allomancy_class] + (" *" if selected else "")
		pair[1].modulate = color
	_line_mesh.clear_surfaces()
	if is_instance_valid(targeting.selected):
		_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		_line_mesh.surface_add_vertex(controller.player.global_position)
		_line_mesh.surface_add_vertex(targeting.selected.target_point(controller.player.global_position))
		_line_mesh.surface_end()
