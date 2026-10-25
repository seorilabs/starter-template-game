extends RefCounted
signal changed
var status := "unavailable"
var code := ""
var identity := ""
var _generation := 0
var _cache: Dictionary = {}

func request(scope: String, provider: Callable) -> void:
	_generation += 1
	var generation := _generation
	identity = scope
	code = ""
	status = "checking"
	changed.emit()
	if scope.is_empty() or not provider.is_valid():
		status = "unavailable"
		changed.emit()
		return
	provider.call(func(response: Dictionary) -> void:
		if generation != _generation or identity != scope:
			return
		var raw := str(response.get("code", "")).strip_edges()
		var valid := not raw.is_empty() and raw.length() <= 128
		for c in raw:
			if c.unicode_at(0) < 32 or c.unicode_at(0) == 127:
				valid = false
		if response.get("ok", false) and response.get("identity", "") == scope and valid:
			code = raw
			_cache[scope] = raw
			status = "ready"
		elif response.get("offline", false) and _cache.has(scope):
			code = _cache[scope]
			status = "cached_offline"
		else:
			status = "failed" if response.get("retryable", true) else "unavailable"
		changed.emit()
	)

func close() -> void:
	_generation += 1
	code = ""
	status = "unavailable"

func change_identity(scope: String) -> void:
	close()
	identity = scope
	# 이전 사용자의 코드는 현재 연결에서 다시 사용하지 않는다.
	_cache.clear()

func copy_code(writer: Callable) -> bool:
	return status in ["ready", "cached_offline"] and not code.is_empty() and writer.is_valid() and bool(writer.call(code))
