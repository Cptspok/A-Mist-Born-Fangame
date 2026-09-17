class_name ConsumableDefinition
extends Resource
## Shared use data. Implementations must not store per-use runtime state here.
func apply(_actor: Node) -> bool:
	return false
