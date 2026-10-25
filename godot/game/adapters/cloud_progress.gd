extends Node
## Progress is untrusted game data. Purchases, mailbox rewards and credentials never enter this document.
signal changed
const Store = preload("res://addons/seorilabs_platform/core/atomic_json_store.gd")
var identity: Node
var state: RefCounted
var project_id := ""
var uid := ""
var status := "signed_out"
var progress_ready := false
var _generation := 0
var _restoring := false
var _writing := false
var _revision := ""
var _journal: Dictionary = {}
var privacy_marker := "user://starter-analytics-off"

func configure(auth: Node, progress: RefCounted, project: String) -> void:
	identity = auth
	state = progress
	project_id = project
	state.connect("committed", _on_commit)

func _journal_path() -> String:
	return "user://cloud-outbox-" + uid.sha256_text() + ".json"

func _snapshot() -> Dictionary:
	var value: Dictionary = state.data.duplicate(true)
	value.mail = []
	value.events = {}
	value.ui.commerce = {}
	value.ui.submissions = {}
	return value

func has_pending() -> bool:
	return _writing or not _journal.is_empty()

func detach() -> void:
	_generation += 1
	uid = ""
	progress_ready = false
	_writing = false
	_revision = ""
	_journal = {}
	status = "signed_out"
	_restoring = true
	state.path = "user://starter-signed-out.json"
	state.data = state.defaults()
	state.data.mail = []
	_restoring = false
	changed.emit()

func restore(account_uid: String) -> Dictionary:
	_generation += 1
	var generation := _generation
	uid = account_uid
	progress_ready = false
	_writing = false
	_revision = ""
	_journal = {}
	status = "loading"
	_restoring = true
	state.path = "user://starter-progress-" + uid.sha256_text() + ".json"
	state.data = state.defaults()
	state.data.mail = []
	changed.emit()
	var response: Dictionary = await _request(HTTPClient.METHOD_GET)
	if generation != _generation: return {"ok": false, "code": "auth_state_changed"}
	if not response.ok and response.get("status", 0) != 404:
		return _restore_failed("cloud_load_failed")
	var remote: Dictionary = state.defaults()
	remote.mail = []
	if response.ok:
		var raw: Variant = response.get("data", {}).get("fields", {}).get("payload", {}).get("stringValue", "")
		var parsed: Variant = JSON.parse_string(str(raw))
		if not parsed is Dictionary or not state.valid(parsed): return _restore_failed("cloud_save_invalid")
		remote = parsed
		_revision = str(response.data.get("updateTime", ""))
		if _revision.is_empty(): return _restore_failed("cloud_save_invalid")
	var pending: Dictionary = Store.read_dictionary(_journal_path())
	if not pending.ok: return _restore_failed("cloud_outbox_invalid")
	if pending.exists:
		var item: Dictionary = pending.value
		if item.get("uid") != uid or not item.get("payload") is Dictionary or not state.valid(item.payload): return _restore_failed("cloud_outbox_invalid")
		if str(item.get("revision", "")) != _revision:
			if item.payload != remote:
				# Keep the durable local choice available to the explicit conflict UI.
				_journal = item
				return _restore_failed("cloud_conflict")
			if DirAccess.remove_absolute(ProjectSettings.globalize_path(_journal_path())) != OK: return _restore_failed("cloud_outbox_failed")
			item = {}
		if not item.is_empty():
			remote = item.payload
			_journal = item
	# A local opt-out always wins over a cloud preference.
	if FileAccess.file_exists(privacy_marker):
		remote.settings.analytics = false
	if not state.commit(remote): return _restore_failed(state.error)
	_restoring = false
	progress_ready = true
	status = "saved" if _journal.is_empty() else "pending"
	changed.emit()
	if not _journal.is_empty(): _flush()
	return {"ok": true, "empty_remote": not response.ok}

func resolve_conflict(use_device: bool) -> Dictionary:
	if status != "cloud_conflict" or _journal.is_empty() or uid.is_empty():
		return {"ok": false, "code": "cloud_conflict_unavailable"}
	var old := _journal.duplicate(true)
	var path := _journal_path()
	# Preserve both choices before replacing local progress. Never erase the only copy.
	if not Store.write(path + ".conflict-backup", old):
		return {"ok": false, "code": "cloud_outbox_failed"}
	if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
		return {"ok": false, "code": "cloud_outbox_failed"}
	var result: Dictionary = await restore(uid)
	if not result.ok:
		if not Store.write(path, old): status = "cloud_outbox_failed"
		return result
	if use_device:
		var local: Dictionary = old.payload.duplicate(true)
		if FileAccess.file_exists(privacy_marker): local.settings.analytics = false
		if not state.commit(local): return {"ok": false, "code": state.error}
	return {"ok": true}

func _restore_failed(code: String) -> Dictionary:
	_restoring = false
	status = code
	progress_ready = false
	changed.emit()
	return {"ok": false, "code": code}

func _on_commit() -> void:
	if not state.data.get("settings", {}).get("analytics", true):
		var marker := FileAccess.open(privacy_marker, FileAccess.WRITE)
		if marker != null: marker.close()
	elif not _restoring and FileAccess.file_exists(privacy_marker):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(privacy_marker))
	if _restoring or not progress_ready or uid.is_empty(): return
	_journal = {"uid": uid, "revision": _revision, "payload": _snapshot()}
	if not Store.write(_journal_path(), _journal):
		progress_ready = false
		status = "cloud_outbox_failed"
		changed.emit()
		return
	status = "pending"
	changed.emit()
	_flush()

func _flush() -> void:
	if _writing or _journal.is_empty() or not progress_ready: return
	_writing = true
	var generation := _generation
	while generation == _generation and not _journal.is_empty():
		var item := _journal.duplicate(true)
		var response: Dictionary = await _request(HTTPClient.METHOD_PATCH, item.payload, _revision)
		if generation != _generation: return
		if not response.ok:
			status = "cloud_conflict" if response.get("status", 0) in [409, 412] else "cloud_save_failed"
			progress_ready = false
			break
		_revision = str(response.data.get("updateTime", ""))
		if _revision.is_empty():
			status = "cloud_save_invalid"
			progress_ready = false
			break
		if _journal.payload == item.payload:
			if DirAccess.remove_absolute(ProjectSettings.globalize_path(_journal_path())) != OK:
				status = "cloud_outbox_failed"
				progress_ready = false
				break
			_journal = {}
		else:
			_journal.revision = _revision
			if not Store.write(_journal_path(), _journal):
				status = "cloud_outbox_failed"
				progress_ready = false
				break
		status = "saved"
	_writing = false
	changed.emit()

func _request(method: HTTPClient.Method, payload: Dictionary = {}, revision: String = "") -> Dictionary:
	var generation := _generation
	var expected_uid := uid
	var auth: Dictionary = await identity.ensure_identity()
	if generation != _generation or auth.get("uid") != expected_uid or not auth.get("success", false): return {"ok": false, "code": "auth_state_changed"}
	var http := HTTPRequest.new()
	http.timeout = 20
	http.body_size_limit = 256 * 1024
	add_child(http)
	var url := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/game_saves/%s" % [project_id.uri_encode(), expected_uid.uri_encode()]
	var body := ""
	if method == HTTPClient.METHOD_PATCH:
		url += "?currentDocument." + ("exists=false" if revision.is_empty() else "updateTime=" + revision.uri_encode())
		body = JSON.stringify({"fields": {"schemaVersion": {"integerValue": "1"}, "payload": {"stringValue": JSON.stringify(payload)}}})
	var headers := PackedStringArray(["Authorization: Bearer " + str(auth.get("id_token", "")), "Content-Type: application/json"])
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": "cloud_transport_failed"}
	var completed: Array = await http.request_completed
	http.queue_free()
	if generation != _generation: return {"ok": false, "code": "auth_state_changed"}
	var data: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	return {"ok": completed[0] == HTTPRequest.RESULT_SUCCESS and int(completed[1]) in [200, 201], "status": int(completed[1]), "data": data if data is Dictionary else {}}
