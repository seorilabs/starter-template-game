extends Node
## 실제 공통 SDK만 받는다. 서버 오류를 로컬 지급으로 바꾸지 않는다.
signal error_observed(code: String)
signal server_inventory_changed
var sdk: Node
var credential_provider: Callable
var async_credentials := false
var _authentication_generation := 0
var mode := "local"
var mails: Array = []
var cursor := ""

func configure(client: Node, provider: Callable, asynchronous: bool = false) -> void:
	sdk = client
	credential_provider = provider
	async_credentials = asynchronous
	mode = "server"

func initialize(callback: Callable) -> void:
	if mode == "local":
		callback.call({"ok": true, "status": "local"})
		return
	if sdk == null or not credential_provider.is_valid():
		callback.call({"ok": false, "code": "service_unconnected"})
		return
	_authentication_generation += 1
	var generation := _authentication_generation
	if async_credentials:
		credential_provider.call(func(result: Dictionary) -> void:
			if generation != _authentication_generation:
				return
			if not result.get("ok", false):
				callback.call(result)
				return
			if result.get("session_ready", false):
				_initialize_session(callback, generation)
				return
			_initialize_credential(result.get("credential", {}), callback, generation)
		)
	else:
		_initialize_credential(credential_provider.call(), callback, generation)

func _initialize_credential(credential: Dictionary, callback: Callable, generation: int) -> void:
	# An empty credential is a signed-out user, not a failed sign-in or a request to create an account.
	if credential.is_empty():
		mails.clear()
		cursor = ""
		if sdk.is_under_maintenance():
			callback.call({"ok": false, "code": "maintenance"})
		elif sdk.is_sdk_blocked() or sdk.update_gate_state().get("kind", "ok") == "required":
			callback.call({"ok": false, "code": "update_required"})
		else:
			callback.call({"ok": true, "status": "account_required"})
		return
	sdk.sign_in(credential, func(response: Dictionary) -> void:
		if generation != _authentication_generation:
			return
		if not response.get("ok", false):
			callback.call(response)
			return
		_initialize_session(callback, generation)
	)

func _initialize_session(callback: Callable, generation: int) -> void:
	var config: Dictionary = sdk.current_config()
	if sdk.is_under_maintenance():
		callback.call({"ok": false, "code": "maintenance"})
	elif str(sdk.update_gate_state().get("kind", "ok")) == "required" or sdk.is_sdk_blocked():
		callback.call({"ok": false, "code": "update_required"})
	else:
		list_mail(func(response: Dictionary) -> void:
			if generation != _authentication_generation: return
			callback.call({"ok": true, "status": "server", "config": config} if response.get("ok", false) else response)
		)

func list_mail(callback: Callable, more: bool = false) -> void:
	if mode != "server" or sdk == null:
		callback.call({"ok": false, "code": "service_unconnected"})
		return
	sdk.list_inbox(cursor if more else "", func(response: Dictionary) -> void:
		if response.get("ok", false):
			var result: Dictionary = response.result
			if not more:
				mails.clear()
			mails.append_array(result.get("messages", []))
			cursor = str(result.get("nextCursor", ""))
		else:
			error_observed.emit(str(response.get("code", "network_error")))
		callback.call(response)
	)

func claim(id: String, callback: Callable) -> void:
	if mode != "server" or sdk == null:
		callback.call({"ok": false, "code": "service_unconnected"})
		return
	sdk.claim_inbox(id, func(response: Dictionary) -> void:
		if response.get("ok", false): server_inventory_changed.emit()
		callback.call(response))

func claim_batch(ids: Array, callback: Callable) -> void:
	if mode != "server" or sdk == null:
		callback.call({"ok": false, "code": "service_unconnected"})
		return
	sdk.claim_inbox_batch(ids, func(response: Dictionary) -> void:
		if response.get("ok", false): server_inventory_changed.emit()
		callback.call(response))

func read(id: String, callback: Callable) -> void:
	if mode != "server" or sdk == null:
		callback.call({"ok": false, "code": "service_unconnected"})
		return
	sdk.read_inbox(id, callback)

func purchase(proof: Dictionary, callback: Callable) -> void:
	if mode != "server" or sdk == null:
		callback.call({"ok": false, "code": "commerce_unsupported"})
		return
	sdk.verify_purchase(proof, callback)

func restore(callback: Callable) -> void:
	if mode != "server" or sdk == null:
		callback.call({"ok": false, "code": "commerce_unsupported"})
		return
	sdk.list_entitlements(callback)

func commerce_state(response: Dictionary) -> String:
	if response.get("cancelled", false):
		return "cancelled"
	if response.get("pending", false) or str(response.get("result", {}).get("state", "")) == "pending":
		return "pending"
	return "completed" if response.get("ok", false) else "failed"

## 아직 넘기지 않은 이벤트만 SDK에 한 번 넘기고 그 키를 돌려준다. 이후 전송·재시도는 SDK(세션 안 outbox)가 맡는다.
## 플랫폼 /events는 서버 dedup이 없고 쿼리에서 eventId로 중복을 제거한다.
func sync_events(events: Dictionary, consent: bool) -> Array:
	var handed: Array = []
	if mode != "server" or sdk == null or not consent:
		return handed
	for key in events:
		var event: Dictionary = events[key]
		if event.has("sentAt"):
			continue
		sdk.track_event(event)
		handed.append(key)
	sdk.flush_events()
	return handed

func begin_account_link(provider: String, app_check_token: String, callback: Callable) -> void:
	if mode != "server" or sdk == null:
		callback.call({"ok": false, "code": "account_link_unsupported"})
		return
	sdk.begin_account_link(provider, app_check_token, callback)

func complete_account_link(provider: String, id_token: String, nonce: String,
	app_check_token: String, callback: Callable) -> void:
	if mode != "server" or sdk == null:
		callback.call({"ok": false, "code": "account_link_unsupported"})
		return
	sdk.complete_account_link(provider, id_token, nonce, app_check_token, callback)
