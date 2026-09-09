extends Node

## Each system owns one named lock. Repeated acquire/release is idempotent.
signal lock_changed(locked: bool)
var _owners: Dictionary = {}


func is_locked() -> bool:
	return not _owners.is_empty()


func acquire(owner: StringName) -> void:
	var was_locked := is_locked()
	_owners[owner] = true
	if not was_locked:
		lock_changed.emit(true)


func release(owner: StringName) -> void:
	var was_locked := is_locked()
	_owners.erase(owner)
	if was_locked and not is_locked():
		lock_changed.emit(false)
