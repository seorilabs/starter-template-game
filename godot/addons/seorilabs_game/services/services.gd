extends Node
## 실제 공통 SDK만 받는다. 서버 오류를 로컬 지급으로 바꾸지 않는다.
signal error_observed(code: String)
var sdk: Node
var credential_provider: Callable
var mode := "local"
var mails: Array = []
var cursor := ""

func configure(client: Node, provider: Callable) -> void:
	sdk = client
	credential_provider = provider
	mode = "server"

func initialize(callback: Callable) -> void:
	if mode == "local":
		callback.call({"ok": true, "status": "local"})
		return
	if sdk == null or not credential_provider.is_valid():
		callback.call({"ok": false, "code": "service_unconnected"})
		return
	var credential: Dictionary = credential_provider.call()
	sdk.sign_in(credential, func(response: Dictionary) -> void:
		if not response.get("ok", false):
			callback.call(response)
			return
		var config: Dictionary = sdk.current_config()
		if sdk.is_under_maintenance():
			callback.call({"ok": false, "code": "maintenance"})
		elif str(sdk.update_gate_state().get("kind", "ok")) == "required" or sdk.is_sdk_blocked():
			callback.call({"ok": false, "code": "update_required"})
		else:
			list_mail(func(mail_response: Dictionary) -> void:
				if mail_response.get("ok", false):
					callback.call({"ok": true, "status": "server", "config": config})
				else:
					callback.call(mail_response)
			)
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
	sdk.claim_inbox(id, callback)

func claim_batch(ids: Array, callback: Callable) -> void:
	if mode != "server" or sdk == null:
		callback.call({"ok": false, "code": "service_unconnected"})
		return
	sdk.claim_inbox_batch(ids, callback)

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
