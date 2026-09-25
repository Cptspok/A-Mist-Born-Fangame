class_name StatModifier
extends Resource

enum Operation { FLAT_ADD, PERCENT_ADD, MORE_MULTIPLIER }
@export var stat: StatIds.Stat = StatIds.Stat.MAX_HEALTH
@export var operation: Operation = Operation.FLAT_ADD
## Fractions: 0.20 is +20%; -0.20 is -20%.
@export var value: float = 0.0
