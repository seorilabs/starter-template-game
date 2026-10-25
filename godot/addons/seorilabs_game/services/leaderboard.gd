extends RefCounted
signal changed
var port: RefCounted
var store: RefCounted
var config: Dictionary = {}
var identity := ""
var period := "alltime"
var scope := "top"
var status := "unavailable"
var rows: Array = []
var self_record: Dictionary = {}
var next_cursor := ""
var checked_at := 0
var _generation := 0
var _cache: Dictionary = {}
var _inflight: Dictionary = {}

func capabilities() -> Dictionary:
	if port == null or config.get("boardId", "").is_empty() or not config.get("enabled", false):
		return {}
	return port.capabilities()

func available() -> bool:
	var caps := capabilities()
	return caps.get("open", false) or caps.get("list", false)

func _key() -> String:
	return "%s:%s:%s:%s:%s" % [config.get("appId", ""), identity, config.get("boardId", ""), period, config.get("seasonId", "all") if period != "alltime" else "all"]

func change_identity(value: String) -> void:
	close()
	identity = value
	_cache.clear()
	_inflight.clear()
	rows = []
	self_record = {}

func close() -> void:
	_generation += 1

func fetch(more: bool = false) -> void:
	_generation += 1
	var generation := _generation
	var key := _key()
	var caps := capabilities()
	rows = rows if more else []
	if not caps.get("list", false) or not period in caps.get("periods", ["alltime"]) or identity.is_empty():
		status = "unavailable"
		changed.emit()
		return
	status = "loading"
	changed.emit()
	port.fetch({"boardId": config.boardId, "period": period, "scope": scope, "cursor": next_cursor if more else "", "limit": 50, "around": 2}, func(result: Dictionary) -> void:
		if generation != _generation or key != _key():
			return
		if result.get("ok", false):
			rows.append_array(result.get("rows", []))
			self_record = result.get("self", {})
			next_cursor = str(result.get("nextCursor", ""))
			checked_at = int(result.get("checkedAt", 0))
			status = "season_closed" if result.get("closed", false) else "empty" if result.get("boardEmpty", false) or (scope == "top" and rows.is_empty()) else "self_unranked" if self_record.is_empty() else "ready"
			_cache[key + ":" + scope] = {"rows": rows.duplicate(true), "self": self_record.duplicate(true), "checkedAt": checked_at}
		elif result.get("offline", false) and _cache.has(key + ":" + scope):
			var cached: Dictionary = _cache[key + ":" + scope]
			rows = cached.rows.duplicate(true)
			self_record = cached.self.duplicate(true)
			checked_at = cached.checkedAt
			next_cursor = ""
			status = "offline_cached"
		else:
			status = "auth_required" if result.get("authRequired", false) else "failed"
		changed.emit()
	)

func submit(score: int, run_id: String, completed: bool) -> void:
	if not capabilities().get("submit", false) or not completed or run_id.is_empty() or score < 0 or identity.is_empty():
		return
	var key := _key() + ":%d:%s" % [int(config.get("rulesVersion", 1)), run_id]
	if store.data.ui.submissions.get(key, "") == "submitted" or _inflight.has(key):
		return
	if not store.remember_ui("submissions", key, "submitting"):
		status = "failed"
		changed.emit()
		return
	status = "submitting"
	_inflight[key] = true
	changed.emit()
	var owner := identity
	var generation := _generation
	var view_key := _key()
	port.submit_score({"boardId": config.boardId, "score": score, "runId": run_id, "rulesVersion": config.get("rulesVersion", 1), "period": period, "seasonId": config.get("seasonId", "all")}, func(result: Dictionary) -> void:
		# 제출의 저장은 화면 종료와 무관하게 확정하지만 다른 사용자의 저장에 섞지 않는다.
		if owner != identity:
			return
		_inflight.erase(key)
		var accepted: bool = result.get("ok", false)
		var saved: bool = store.remember_ui("submissions", key, "submitted" if accepted else "retryable")
		if generation == _generation and view_key == _key():
			status = "submitted" if accepted and saved else "failed"
			changed.emit()
	)

func open_native(callback: Callable) -> void:
	if not capabilities().get("open", false):
		callback.call({"ok": false, "code": "unsupported"})
		return
	port.open_board(callback)
