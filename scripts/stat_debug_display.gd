class_name StatDebugDisplay
extends Label

var stats: StatComponent

func configure(component: StatComponent) -> void:
	if is_instance_valid(stats) and stats.values_changed.is_connected(_refresh):
		stats.values_changed.disconnect(_refresh)
	stats = component
	if stats != null: stats.values_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	text = "PLAYER STATS (effective)"
	if stats == null: return
	for stat in StatIds.Stat.values():
		text += "\n%s: %s" % [StatIds.label(stat), String.num(stats.get_value(stat), 2)]
