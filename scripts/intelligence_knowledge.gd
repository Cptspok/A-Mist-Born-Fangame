class_name IntelligenceKnowledge
extends RefCounted
## Session ownership. Definitions are never mutated. Every clue ID is unique.
signal clue_discovered(clue: IntelligenceClueDefinition)
signal target_discovered(target_id: StringName)
signal target_updated(target_id: StringName)
signal cleared
var _clues: Dictionary = {}
var _targets: Dictionary = {}
var _defeated: Dictionary = {}

func has_clue(id: StringName) -> bool:
	return _clues.has(id)

func discover(clue: IntelligenceClueDefinition) -> bool:
	if clue == null or clue.unique_id == &"" or clue.target == null or clue.target.unique_id == &"": return false
	if has_clue(clue.unique_id): return false
	_clues[clue.unique_id] = clue
	var id := clue.target.unique_id
	if not _targets.has(id):
		_targets[id] = true
		target_discovered.emit(id)
	clue_discovered.emit(clue)
	target_updated.emit(id)
	return true

func knows(target_id: StringName, category: String) -> bool:
	return not clues_for(target_id, category).is_empty()

func clues_for(target_id: StringName, category := "") -> Array[IntelligenceClueDefinition]:
	var result: Array[IntelligenceClueDefinition] = []
	for clue: IntelligenceClueDefinition in _clues.values():
		if clue.target.unique_id == target_id and (category.is_empty() or clue.reveal_type == category): result.append(clue)
	return result

func is_discovered(target_id: StringName) -> bool:
	return _targets.has(target_id)

func mark_defeated(target_id: StringName) -> void:
	if target_id == &"" or _defeated.has(target_id): return
	_defeated[target_id] = true
	target_updated.emit(target_id)

func is_defeated(target_id: StringName) -> bool:
	return _defeated.has(target_id)

func clear() -> void:
	_clues.clear()
	_targets.clear()
	_defeated.clear()
	cleared.emit()
