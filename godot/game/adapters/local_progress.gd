extends "res://game/core/ports/progress_port.gd"
var store: RefCounted
func _init(value: RefCounted) -> void:
	store = value
func record_hit() -> bool:
	return store.action_completed("target_hit")
