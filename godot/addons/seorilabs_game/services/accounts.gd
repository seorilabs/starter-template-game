extends RefCounted
## Product adapters own credentials. UI state contains public identifiers only.
signal changed
var port: Object
var status := "signed_out"
var details: Dictionary = {}
var error := ""
var operation := ""
var _generation := 0

func capabilities() -> Dictionary:
	return port.capabilities() if port != null else {}

func connected() -> bool:
	return not str(details.get("uid", "")).is_empty()

func refresh() -> void:
	if port == null:
		return
	var current: Dictionary = port.snapshot()
	if current != details:
		_generation += 1
		details = current.duplicate(true)
		status = "ready" if connected() else "signed_out"
		error = ""
		changed.emit()

func perform(action: String, payload: Dictionary = {}) -> void:
	if port == null or status == "busy" or not capabilities().get(action, false):
		return
	_generation += 1
	var generation := _generation
	operation = action
	status = "busy"
	error = ""
	changed.emit()
	port.execute(action, payload, func(result: Dictionary) -> void:
		if generation != _generation:
			return
		if result.get("ok", false):
			details = (result.get("account", port.snapshot()) as Dictionary).duplicate(true)
			status = "ready" if connected() else "signed_out"
		else:
			if result.get("account_confirmed", false):
				details = (result.get("account", {}) as Dictionary).duplicate(true)
			status = "failed"
			error = str(result.get("code", "account_failed"))
		changed.emit()
	)

func invalidate() -> void:
	_generation += 1
	details = {}
	status = "signed_out"
	error = ""
	changed.emit()
