class_name EnemyRewardDefinition
extends Resource
## Each entry drops one item; repeated item entries allow multiple consumables.
@export var items: Array[ItemDefinition] = []
@export var intelligence_clues: Array[IntelligenceClueDefinition] = []
