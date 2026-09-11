extends Control
var player: PlayerController

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	visible = is_instance_valid(player) and not get_tree().paused and not GameplayLocks.is_locked()
	queue_redraw()

func _draw() -> void:
	if not visible or not is_instance_valid(player): return
	var targeting: AllomancyTargeting = player.get_node("Allomancy/Targeting")
	var target := targeting.selected
	var selected := is_instance_valid(target) and target.is_available()
	var center := size * 0.5
	var color := Color(1, 0.8, 0.35) if selected else Color(0.85, 0.87, 0.9)
	draw_line(center - Vector2(5,0), center + Vector2(5,0), color, 1.5)
	draw_line(center - Vector2(0,5), center + Vector2(0,5), color, 1.5)
	if selected:
		var camera := targeting.camera
		var point := target.volume.global_position
		if not camera.is_position_behind(point):
			var screen := camera.unproject_position(point)
			draw_arc(screen, 9, 0, TAU, 24, color, 2)
			draw_line(center, screen, Color(color, 0.25), 1)
