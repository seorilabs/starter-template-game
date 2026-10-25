extends RefCounted
signal committed
## 로컬 예제의 저장과 지급은 같은 파일에서 원자적으로 확정한다.
const Store = preload("res://addons/seorilabs_platform/core/atomic_json_store.gd")
const SAVE_VERSION := 3
const TUTORIAL_VERSION := 1
var path: String
var data: Dictionary = {}
var error := ""
var analytics_allowed := false

func _init(save_path: String = "user://outgame-state.json") -> void:
	path = save_path

func load_state() -> bool:
	var result: Dictionary = Store.read_dictionary(path)
	if not result.ok:
		error = "save_corrupt"
		return false
	var candidate: Dictionary = result.value if result.exists else defaults()
	if not valid(candidate):
		error = "save_schema_invalid"
		return false
	if int(candidate.version) > SAVE_VERSION:
		error = "save_newer_version"
		return false
	data = candidate
	if FileAccess.file_exists(path + ".analytics-off"):
		data.settings.analytics = false
	if not data.has("ui"):
		var upgraded := data.duplicate(true)
		upgraded.ui = {"submissions": {}, "commerce": {}, "home": {"level": 2, "collected": false}}
		upgraded.version = SAVE_VERSION
		if not commit(upgraded):
			return false
	if int(data.tutorial.version) != TUTORIAL_VERSION:
		var migrated := data.duplicate(true)
		migrated.tutorial = {"version": TUTORIAL_VERSION, "step": 0, "status": "active", "hits": 0, "replay": false}
		migrated.version = SAVE_VERSION
		return commit(migrated)
	error = ""
	return true

func defaults() -> Dictionary:
	return {"version": SAVE_VERSION, "coins": 0, "grants": {}, "tutorial": {"version": TUTORIAL_VERSION, "step": 0, "status": "active", "hits": 0, "replay": false},
		"settings": {"music": true, "sfx": true, "vibration": true, "language": "system", "large_text": false, "reduced_motion": false, "analytics": true},
		"ui": {"submissions": {}, "commerce": {}, "home": {"level": 2, "collected": false}},
		"consentVersion": 0, "mail": [{"id": "local-welcome", "title": "Welcome gift", "body": "A local example reward. No server delivery.", "amount": 5, "readAt": 0, "claimedAt": 0, "expiresAt": 0}], "events": {}}

func whole_number(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == float(int(value)) and value >= minimum

func valid(value: Dictionary) -> bool:
	if not value.has_all(["version", "coins", "grants", "tutorial", "settings", "mail", "events", "consentVersion"]):
		return false
	if not whole_number(value.version, 1) or not whole_number(value.coins) or not whole_number(value.consentVersion):
		return false
	if not value.grants is Dictionary or not value.tutorial is Dictionary or not value.settings is Dictionary or not value.mail is Array or not value.events is Dictionary:
		return false
	var tutorial: Dictionary = value.tutorial
	if not tutorial.has_all(["version", "step", "status", "hits", "replay"]) or not whole_number(tutorial.version) or not whole_number(tutorial.step) or not whole_number(tutorial.hits) or not tutorial.replay is bool:
		return false
	if tutorial.step > 2 or tutorial.hits > 3 or tutorial.status not in ["active", "complete", "skipped"]:
		return false
	if not value.settings.has_all(["music", "sfx", "vibration", "language", "large_text", "reduced_motion", "analytics"]):
		return false
	for key in ["music", "sfx", "vibration", "large_text", "reduced_motion", "analytics"]:
		if not value.settings[key] is bool:
			return false
	if value.settings.language not in ["system", "en", "ko"]:
		return false
	if value.has("ui") and (not value.ui is Dictionary or not value.ui.get("submissions") is Dictionary or not value.ui.get("commerce") is Dictionary or not value.ui.get("home") is Dictionary):
		return false
	var ids: Dictionary = {}
	for mail in value.mail:
		if not mail is Dictionary or not mail.has_all(["id", "title", "body", "amount", "readAt", "claimedAt", "expiresAt"]):
			return false
		if not mail.id is String or mail.id.is_empty() or ids.has(mail.id) or not mail.title is String or not mail.body is String:
			return false
		ids[mail.id] = true
		for key in ["amount", "readAt", "claimedAt", "expiresAt"]:
			if not whole_number(mail[key]):
				return false
	return true

func commit(next: Dictionary) -> bool:
	if not valid(next):
		error = "save_schema_invalid"
		return false
	if not Store.write(path, next):
		error = "save_failed"
		return false
	data = next
	error = ""
	committed.emit()
	return true

func event(next: Dictionary, key: String, name: String) -> void:
	# 값·사용자 식별자·자유 입력은 수집하지 않는다. 같은 행동은 저장 키로 중복 억제한다.
	if analytics_allowed and next.settings.analytics and not next.events.has(key):
		next.events[key] = {"event_id": Crypto.new().generate_random_bytes(16).hex_encode(), "name": name, "occurred_at_micros": int(Time.get_unix_time_from_system() * 1000000), "params": {"tutorial_version": TUTORIAL_VERSION}}

func accept_consent(analytics: bool, consent_version: int = 1) -> bool:
	var next := data.duplicate(true)
	next.consentVersion = consent_version
	next.settings.analytics = analytics
	event(next, "startup-first", "game_start")
	return commit(next)

func action_completed(action: String) -> bool:
	var next := data.duplicate(true)
	var t: Dictionary = next.tutorial
	if t.status != "active":
		return false
	if t.step == 0 and action == "target_hit":
		t.hits += 1
		if t.hits >= 3:
			t.step = 1
			event(next, "tutorial-action", "tutorial_step_complete")
	elif t.step == 1 and action == "reward_collected":
		if not t.replay and not next.grants.has("tutorial-first"):
			next.coins += 10
			next.grants["tutorial-first"] = 10
		t.step = 2
		t.status = "complete"
		event(next, "tutorial-complete", "tutorial_complete")
	else:
		return false
	return commit(next)

func skip_tutorial() -> bool:
	var next := data.duplicate(true)
	next.tutorial.status = "skipped"
	event(next, "tutorial-skip", "tutorial_skip")
	return commit(next)

func replay_tutorial() -> bool:
	var next := data.duplicate(true)
	next.tutorial = {"version": TUTORIAL_VERSION, "step": 0, "status": "active", "hits": 0, "replay": true}
	next.ui.runId = ""
	return commit(next)

func ensure_run() -> bool:
	if not str(data.ui.get("runId", "")).is_empty():
		return true
	var next := data.duplicate(true)
	next.ui.runId = Crypto.new().generate_random_bytes(16).hex_encode()
	return commit(next)

func setting(key: String, value: Variant) -> bool:
	if not data.settings.has(key):
		return false
	var next := data.duplicate(true)
	next.settings[key] = value
	if key == "analytics" and value is bool and not value:
		analytics_allowed = false
		# 본 저장 실패에도 철회가 다음 실행에서 살아 있게 별도 안전 표식을 먼저 쓴다.
		if not Store.write(path + ".analytics-off", {"disabled": true}):
			error = "save_failed"
			data.settings.analytics = false
			data.events = {}
			return false
		next.events = {}
	var saved := commit(next)
	if key == "analytics" and value is bool:
		if not value:
			data.settings.analytics = false
			data.events = {}
		elif saved and FileAccess.file_exists(path + ".analytics-off"):
			if DirAccess.remove_absolute(path + ".analytics-off") != OK:
				data.settings.analytics = false
				error = "save_failed"
				return false
	return saved

func remember_ui(section: String, key: String, value: Variant) -> bool:
	if not data.ui.has(section):
		return false
	var next := data.duplicate(true)
	next.ui[section][key] = value
	return commit(next)

func read_mail(id: String, now: int) -> bool:
	var next := data.duplicate(true)
	for mail in next.mail:
		if mail.id == id:
			if mail.readAt == 0:
				mail.readAt = now
			return commit(next)
	return false

func claim_mail(id: String, now: int) -> Dictionary:
	var next := data.duplicate(true)
	for mail in next.mail:
		if mail.id != id:
			continue
		if mail.claimedAt != 0:
			return {"ok": true, "applied": false, "amount": mail.amount}
		if mail.expiresAt != 0 and mail.expiresAt <= now:
			return {"ok": false, "code": "mail_expired"}
		mail.claimedAt = now
		next.coins += mail.amount
		next.grants["mail:" + id] = mail.amount
		event(next, "mail:" + id, "inbox_claim")
		if not commit(next):
			return {"ok": false, "code": error}
		return {"ok": true, "applied": true, "amount": mail.amount}
	return {"ok": false, "code": "mail_not_found"}

func merge_remote_save(remote: Dictionary) -> Dictionary:
	# 충돌을 자동 덮어쓰기로 해결하지 않는다. 계정 adapter가 revision/선택 결과를 처리한다.
	if remote != data:
		return {"ok": false, "code": "save_conflict", "localPreserved": true}
	return {"ok": true}

func finish_remote_tutorial() -> bool:
	var next := data.duplicate(true)
	if next.tutorial.step != 1:
		return false
	next.tutorial.step = 2
	next.tutorial.status = "complete"
	next.grants["tutorial-first"] = 0
	event(next, "tutorial-complete", "tutorial_complete")
	return commit(next)

func mark_events_sent(keys: Array, sent_at: int) -> bool:
	var next := data.duplicate(true)
	for key in keys:
		if next.events.has(key):
			next.events[key].sentAt = sent_at
	return commit(next)

func record_remote_claim(id: String) -> bool:
	var next := data.duplicate(true)
	event(next, "remote-mail:" + id, "inbox_claim")
	return commit(next)
