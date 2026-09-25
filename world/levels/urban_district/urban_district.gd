extends Node3D
## Scope authored Court data to this level, including shell retries and F6.
const CATALOG = preload("res://data/intelligence/urban_district/catalog.tres")
var previous_catalog: IntelligenceCatalog

func _enter_tree() -> void:
	previous_catalog = RespawnSession.intelligence_catalog
	RespawnSession.intelligence_catalog = CATALOG

func _ready() -> void:
	if get_tree().current_scene == self:
		$StandaloneFeedback/Crosshair.player = $Player
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		$StandaloneFeedback.hide()

func _exit_tree() -> void:
	RespawnSession.intelligence_catalog = previous_catalog
