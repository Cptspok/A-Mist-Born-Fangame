extends Node
## Runtime session only. Survives world replacement, never writes a save file.
signal checkpoint_changed(id: StringName)
var checkpoint_id: StringName = &""
var _transform := Transform3D.IDENTITY

func activate(id: StringName, destination: Transform3D) -> void:
	if id == &"" or id == checkpoint_id: return
	checkpoint_id = id
	_transform = destination
	checkpoint_changed.emit(id)

func resolve(fallback: Transform3D) -> Transform3D:
	return _transform if checkpoint_id != &"" else fallback

func reset() -> void:
	checkpoint_id = &""
	_transform = Transform3D.IDENTITY
	checkpoint_changed.emit(checkpoint_id)
