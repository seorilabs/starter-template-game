extends RefCounted
const PRIORITY := {"consent": 0, "update_required": 1, "maintenance": 2, "reward": 3, "notice": 4}
var items: Array[Dictionary] = []
var current: Dictionary = {}
func enqueue(kind: String, payload: Dictionary = {}) -> void:
	if current.get("kind", "") == kind:
		return
	for item in items:
		if item.kind == kind:
			return
	items.append({"kind": kind, "payload": payload})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return PRIORITY.get(a.kind, 99) < PRIORITY.get(b.kind, 99))
func next() -> Dictionary:
	if not current.is_empty() or items.is_empty():
		return current
	current = items.pop_front()
	return current
func dismiss() -> void:
	current = {}
