class_name IntelligenceKnowledge
extends RefCounted
## Session ownership. Definitions are never mutated. Every clue ID is unique.
signal clue_discovered(clue: IntelligenceClueDefinition)
signal target_discovered(target_id: StringName)
signal target_updated(target_id: StringName)
signal cleared
enum TargetStatus { UNKNOWN, ALIVE, DEFEATED }
var _clues: Dictionary = {}
var _targets: Dictionary = {}
var _identities: Dictionary = {}
var _portraits: Dictionary = {}
## target ID -> set of revealed optional field IDs.
var _fields: Dictionary = {}
var _statuses: Dictionary = {}

func has_clue(id: StringName) -> bool:
	return _clues.has(id)

func discover(clue: IntelligenceClueDefinition) -> bool:
	if clue == null or clue.unique_id == &"" or clue.target == null or clue.target.unique_id == &"": return false
	if has_clue(clue.unique_id): return false
	_clues[clue.unique_id] = clue
	var id := clue.target.unique_id
	if clue.reveals_identity: _identities[id] = true
	if clue.reveals_portrait: _portraits[id] = true
	if not _fields.has(id): _fields[id] = {}
	for field in clue.revealed_fields:
		if field == null: continue
		if clue.target.field_by_id(field.unique_id) == null:
			push_warning("Clue %s references field %s outside its target dossier." % [clue.unique_id, field.unique_id])
			continue
		_fields[id][field.unique_id] = true
	# Clues never write status; late documents cannot resurrect a defeated target.
	_discover_target(id)
	clue_discovered.emit(clue)
	target_updated.emit(id)
	return true

func knows_identity(target_id: StringName) -> bool:
	return _identities.has(target_id)

func knows_portrait(target_id: StringName) -> bool:
	return _portraits.has(target_id)

func knows_field(target_id: StringName, field_id: StringName) -> bool:
	return field_id != &"" and _fields.has(target_id) and _fields[target_id].has(field_id)

func knows_map_location(target: CourtTargetDefinition) -> bool:
	return target != null and knows_field(target.unique_id, target.map_reveal_field_id)

func clues_for(target_id: StringName) -> Array[IntelligenceClueDefinition]:
	var result: Array[IntelligenceClueDefinition] = []
	for clue: IntelligenceClueDefinition in _clues.values():
		if clue.target.unique_id == target_id: result.append(clue)
	return result

func _discover_target(target_id: StringName) -> void:
	if _targets.has(target_id): return
	_targets[target_id] = true
	target_discovered.emit(target_id)

func is_discovered(target_id: StringName) -> bool:
	return _targets.has(target_id)

## Registration observes the live actor without revealing their identity.
## Defeat remains authoritative for this session, including checkpoint reloads.
func mark_alive(target_id: StringName) -> void:
	if target_id == &"" or _statuses.has(target_id): return
	_statuses[target_id] = TargetStatus.ALIVE
	target_updated.emit(target_id)

func mark_defeated(target_id: StringName) -> void:
	if target_id == &"" or is_defeated(target_id): return
	_statuses[target_id] = TargetStatus.DEFEATED
	_identities[target_id] = true
	_portraits[target_id] = true
	_discover_target(target_id)
	target_updated.emit(target_id)

func status_for(target_id: StringName) -> TargetStatus:
	return _statuses.get(target_id, TargetStatus.UNKNOWN)

func status_label(target_id: StringName) -> String:
	match status_for(target_id):
		TargetStatus.ALIVE: return "Alive"
		TargetStatus.DEFEATED: return "Defeated"
	return "Unknown"

func is_defeated(target_id: StringName) -> bool:
	return status_for(target_id) == TargetStatus.DEFEATED

func clear() -> void:
	_clues.clear()
	_targets.clear()
	_identities.clear()
	_portraits.clear()
	_fields.clear()
	_statuses.clear()
	cleared.emit()
