extends Node3D

@export var swing_duration: float = 0.25
var _tween: Tween
var _rest: Vector3


func _ready() -> void:
	_rest = rotation


func swing() -> void:
	reset_pose()
	_tween = create_tween()
	_tween.tween_property(self, "rotation", _rest + Vector3(-0.6, -0.4, 1.0), swing_duration * 0.4)
	_tween.tween_property(self, "rotation", _rest, swing_duration * 0.6)


func reset_pose() -> void:
	if _tween != null:
		_tween.kill()
	rotation = _rest
