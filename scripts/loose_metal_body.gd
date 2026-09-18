extends RigidBody3D
## Presentation only. Capture owns swept motion; FREE uses native integration.
var manipulation_active := false
var _previous := Transform3D.IDENTITY
var _current := Transform3D.IDENTITY
var _visuals: Array[Dictionary] = []
var _presentation_frame: Node3D
var _frame_previous := Vector3.ZERO
var _frame_current := Vector3.ZERO
var _frame_weight := 0.0

func set_manipulation_active(active: bool, frame: Node3D = null) -> void:
	manipulation_active = active
	if is_instance_valid(frame):
		_presentation_frame = frame
		_frame_previous = frame.global_position
		_frame_current = frame.global_position
	sleeping = false

func _ready() -> void:
	_previous = global_transform
	_current = global_transform
	# Draw-only proxies: moving a Mesh that parents a tether would also move
	# targeting/physics. Keep the original hierarchy and interpolate only rendering.
	for node in find_children("*", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		var proxy := MeshInstance3D.new()
		proxy.mesh = source.mesh
		proxy.material_override = source.material_override
		proxy.material_overlay = source.material_overlay
		proxy.cast_shadow = source.cast_shadow
		proxy.layers = source.layers
		for surface in range(source.get_surface_override_material_count()):
			proxy.set_surface_override_material(surface, source.get_surface_override_material(surface))
		add_child(proxy)
		proxy.top_level = true
		proxy.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var offset := global_transform.affine_inverse() * source.global_transform
		proxy.global_transform = global_transform * offset
		_visuals.append({"source": source, "proxy": proxy, "offset": offset})
		source.layers = 0

func _physics_process(_delta: float) -> void:
	_previous = _current
	_current = global_transform
	if _previous.origin.distance_squared_to(_current.origin) > 100.0:
		_previous = _current
	if is_instance_valid(_presentation_frame):
		_frame_previous = _frame_current
		_frame_current = _presentation_frame.global_position

func _process(delta: float) -> void:
	_frame_weight = move_toward(_frame_weight, 1.0 if manipulation_active else 0.0, delta * 10.0)
	var rendered := get_presentation_transform()
	for pair in _visuals:
		if not is_instance_valid(pair.source): continue
		pair.proxy.visible = pair.source.is_visible_in_tree()
		pair.proxy.global_transform = rendered * pair.offset

func get_presentation_transform() -> Transform3D:
	var fraction := Engine.get_physics_interpolation_fraction()
	var rendered := _previous.interpolate_with(_current, fraction)
	# The FPS camera translates on physics ticks. Interpolate relative translation
	# while held, so a stepped camera and smooth world mesh do not beat against
	# each other. Never compensate camera rotation: visible turn lag stays real.
	if is_instance_valid(_presentation_frame):
		rendered.origin += (_presentation_frame.global_position - _frame_previous.lerp(_frame_current, fraction)) * _frame_weight
	return rendered
