class_name IntelligenceView
extends HBoxContainer
## Presentation reads catalog + session knowledge; selection is the only UI state.
var _catalog: IntelligenceCatalog
var _knowledge: IntelligenceKnowledge
var _targets: Array[CourtTargetDefinition] = []
var _selector: OptionButton
var _map_title: Label
var _map: Control
var _portrait: TextureRect
var _portrait_placeholder: Label
var _dossier: Label
var _notes: Label

func _ready() -> void:
	add_theme_constant_override("separation", 24)
	var left := VBoxContainer.new()
	add_child(left)
	_map_title = Label.new()
	left.add_child(_map_title)
	_map = Control.new()
	_map.custom_minimum_size = Vector2(360, 390)
	left.add_child(_map)
	var legend := Label.new()
	legend.text = "? Unknown region   /   Gold dot: known target\nSchematic district map"
	left.add_child(legend)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 440)
	add_child(right)
	_selector = OptionButton.new()
	_selector.item_selected.connect(func(_index): _render())
	right.add_child(_selector)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(120, 120)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(_portrait)
	_portrait_placeholder = Label.new()
	right.add_child(_portrait_placeholder)
	_dossier = Label.new()
	_dossier.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_dossier)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 210)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_notes = Label.new()
	_notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(_notes)

func configure(catalog: IntelligenceCatalog, knowledge: IntelligenceKnowledge) -> void:
	if _knowledge != null:
		_knowledge.target_updated.disconnect(_on_updated)
		_knowledge.cleared.disconnect(_refresh)
	_catalog = catalog
	_knowledge = knowledge
	_knowledge.target_updated.connect(_on_updated)
	_knowledge.cleared.connect(_refresh)
	_refresh()

func _on_updated(_id: StringName) -> void:
	_refresh()

func _refresh() -> void:
	var previous := _selector.selected
	_targets.clear()
	_selector.clear()
	if _catalog != null:
		for target in _catalog.targets:
			if target == null: continue
			_targets.append(target)
			_selector.add_item(target.display_name if _knowledge.knows_identity(target.unique_id) else target.unknown_display_name)
	if not _targets.is_empty(): _selector.select(clampi(previous, 0, _targets.size() - 1))
	_render()

func _render() -> void:
	for child in _map.get_children():
		_map.remove_child(child)
		child.queue_free()
	_map_title.text = "District: ???"
	if _targets.is_empty():
		_dossier.text = "No Court targets catalogued."
		_portrait.texture = null
		_portrait_placeholder.hide()
		_notes.text = ""
		return
	var target := _targets[_selector.selected]
	var identity := _knowledge.knows_identity(target.unique_id)
	var location := _knowledge.knows_map_location(target)
	_portrait.texture = target.portrait if _knowledge.knows_portrait(target.unique_id) else target.unknown_portrait
	_portrait.visible = _portrait.texture != null
	_portrait_placeholder.visible = _portrait.texture == null
	_portrait_placeholder.text = "Portrait: not assigned" if _knowledge.knows_portrait(target.unique_id) else "Portrait: unknown"
	_dossier.text = "Name: %s\nStatus: %s" % [target.display_name if identity else target.unknown_display_name, _knowledge.status_label(target.unique_id)]
	_notes.text = ""
	for field in target.ordered_fields():
		if _knowledge.knows_field(target.unique_id, field.unique_id):
			_notes.text += "%s\n%s\n\n" % [field.display_label, field.revealed_text]
	if not _knowledge.clues_for(target.unique_id).is_empty(): _notes.text += "COLLECTED DOCUMENTS\n"
	for clue in _knowledge.clues_for(target.unique_id):
		_notes.text += "%s\n%s\nSource: %s\n\n" % [clue.display_name, clue.clue_text, clue.source_description]
	for district in _catalog.maps:
		if district == null or district.district_id != target.district_id: continue
		# Map discovery is linked to an authored field, not a fixed clue category.
		_map_title.text = district.display_name if location else "District assignment: ???"
		for region in district.regions:
			if region == null: continue
			var known := region.initially_known
			var located: Array[CourtTargetDefinition] = []
			for candidate in _targets:
				if candidate.district_id == district.district_id and candidate.region_id == region.unique_id and _knowledge.knows_map_location(candidate):
					known = true
					located.append(candidate)
			var box := ColorRect.new()
			box.position = region.bounds.position * _map.custom_minimum_size
			box.size = region.bounds.size * _map.custom_minimum_size
			box.color = Color("344658") if known else Color("242832")
			_map.add_child(box)
			var label := Label.new()
			label.text = region.display_name if known else "?"
			label.position = Vector2(5, 4)
			label.size.x = maxf(1.0, box.size.x - 10.0)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_font_size_override("font_size", 13)
			box.add_child(label)
			for candidate in located:
				var marker := Label.new()
				marker.text = "●"
				marker.modulate = Color("edc46c")
				marker.position = candidate.map_position.clamp(Vector2.ZERO, Vector2.ONE) * (box.size - Vector2(16, 24))
				marker.tooltip_text = candidate.display_name if _knowledge.knows_identity(candidate.unique_id) else "???"
				box.add_child(marker)
		break
