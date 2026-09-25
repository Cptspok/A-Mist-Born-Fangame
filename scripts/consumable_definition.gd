class_name ConsumableDefinition
extends Resource
## Immediate items retain their existing transaction; timed items override this.
func begin_use(actor: Node, inventory: Node, stack: RefCounted) -> bool:
	if not apply(actor): return false
	return inventory.consume_one(stack)

## Shared use data. Implementations must not store per-use runtime state here.
func apply(_actor: Node) -> bool:
	return false
