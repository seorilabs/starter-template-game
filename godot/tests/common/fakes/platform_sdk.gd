extends RefCounted

class FakeSDK extends Node:
	var calls: Array = []
	var maintenance := false
	var required_update := false
	var hold_sign_in := false
	var claim_code := ""
	var failed_mail_ids: Array = []
	var hold_claim := false
	var defer_list := false
	var messages: Array = []
	var tracked_ids: Array = []
	var batch_sizes: Array = []
	var _held: Callable
	var _held_claim: Callable

	func sign_in(_credential: Dictionary, callback: Callable) -> void:
		calls.append("sign_in")
		if hold_sign_in:
			_held = callback
			return
		callback.call({"ok": true})

	func release_sign_in(response: Dictionary) -> void:
		var callback := _held
		_held = Callable()
		callback.call(response)

	func current_config() -> Dictionary:
		return {}

	func is_under_maintenance() -> bool:
		return maintenance

	func update_gate_state() -> Dictionary:
		return {"kind": "required" if required_update else "ok"}

	func is_sdk_blocked() -> bool:
		return false

	func is_account_linked() -> bool:
		return false

	func resume_presence() -> void:
		calls.append("resume_presence")

	func list_inbox(_cursor: String, callback: Callable) -> void:
		calls.append("list_inbox")
		var response := {"ok": true, "result": {"messages": messages.duplicate(true), "nextCursor": ""}}
		# 실제 SDK는 HTTP 응답 뒤에 콜백한다. 화면을 그린 다음 프레임에 목록이 다시 그려지는 경우를 재현한다.
		if defer_list:
			callback.call_deferred(response)
		else:
			callback.call(response)

	func read_inbox(id: String, callback: Callable) -> void:
		calls.append("read_inbox")
		for message in messages:
			if message.id == id and message.readAt == 0:
				message.readAt = int(Time.get_unix_time_from_system())
		callback.call({"ok": true})

	func claim_inbox(id: String, callback: Callable) -> void:
		calls.append("claim_inbox")
		if hold_claim:
			_held_claim = func() -> void:
				_mark_claimed([id])
				callback.call({"ok": true})
			return
		if not claim_code.is_empty():
			callback.call({"ok": false, "code": claim_code})
			return
		_mark_claimed([id])
		callback.call({"ok": true})

	func release_claim() -> void:
		var release := _held_claim
		_held_claim = Callable()
		release.call()

	func claim_inbox_batch(ids: Array, callback: Callable) -> void:
		calls.append("claim_inbox_batch")
		batch_sizes.append(ids.size())
		if ids.is_empty() or ids.size() > 50:
			callback.call({"ok": false, "code": "request_invalid"})
			return
		var results: Array = []
		for id in ids:
			results.append({"id": id, "ok": claim_code.is_empty() and id not in failed_mail_ids})
		if claim_code.is_empty():
			_mark_claimed(ids.filter(func(id): return id not in failed_mail_ids))
		callback.call({"ok": true, "result": {"results": results}})

	func _mark_claimed(ids: Array) -> void:
		for message in messages:
			if ids.has(message.id):
				message.claimedAt = int(Time.get_unix_time_from_system())

	func verify_purchase(_proof: Dictionary, callback: Callable) -> void:
		calls.append("verify_purchase")
		callback.call({"ok": false, "pending": true})

	func list_entitlements(callback: Callable) -> void:
		calls.append("list_entitlements")
		callback.call({"ok": true, "result": {"entitlements": []}})

	func track_event(event: Dictionary) -> void:
		calls.append("track_event")
		tracked_ids.append(event.get("event_id", ""))

	func flush_events() -> void:
		calls.append("flush_events")
