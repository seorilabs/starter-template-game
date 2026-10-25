extends RefCounted
## External development boundaries only. Product SDK, account, save and UI code stay real.
const Transport = preload("res://addons/seorilabs_platform/core/http_transport.gd")
const Identity = preload("res://addons/seorilabs_platform/adapters/firebase_identity_adapter.gd")
const Cloud = preload("res://game/adapters/cloud_progress.gd")

class Service extends Transport:
	var prefix := ""
	var uid := ""
	var created := 0
	var linked := false
	var tickets := 0
	var badge := false
	var claimed := false
	var ad_verified := false
	var maintenance := false
	var seen: Array[String] = []
	var receipts: Array[String] = []
	func session() -> Dictionary:
		return {"platformToken": "synthetic-session", "refreshToken": "synthetic-refresh", "platformUserId": "puid-" + uid, "appUserId": uid, "supportCode": "STRT-TEST", "isAnonymous": false, "isLinkedAccount": linked, "expiresIn": 3600, "maintenance": {"active": maintenance}, "features": {"inbox": true, "iap": true, "ads": true}}
	func request(options: Dictionary, callback: Callable) -> void:
		var path := str(options.path)
		seen.append(path)
		var body: Dictionary = options.get("body", {})
		var result: Dictionary = {}
		match path:
			"/v1/auth/firebase-custom-token":
				created += 1
				uid = prefix + str(created)
				linked = false
				result = {"firebaseCustomToken": uid}
			"/v1/auth/session":
				uid = str(body.credential.value)
				result = session()
			"/v1/config": result = session()
			"/v1/auth/account-link-challenges", "/v1/auth/account-link-recovery-challenges": result = {"nonce": "fresh-development-nonce"}
			"/v1/auth/account-links", "/v1/auth/account-link-recoveries":
				linked = true
				if body.has("expectedAppUserId"): uid = str(body.expectedAppUserId)
				result = {"provider": body.provider, "restored": path.ends_with("recoveries"), "session": session(), "firebaseCustomToken": uid}
			"/v1/auth/account-deletions":
				receipts.append(str(body.get("receiptToken", "")))
				result = {"state": "accepted"}
			"/v1/auth/account-deletions/status": result = {"state": "completed"}
			"/v1/inbox":
				result = {"messages": [{"id": "dev-mail", "title": "Camp supplies", "body": "Test ticket from the server", "createdAt": 1, "readAt": 0, "claimedAt": 1 if claimed else 0, "expiresAt": 0, "rewards": [{"entitlementId": "starter_test_ticket_1", "quantity": 1}]}]}
			"/v1/inbox/dev-mail/read": result = {"readAt": 1}
			"/v1/inbox/dev-mail/claim":
				if not claimed: tickets += 1
				claimed = true
				result = {"id": "dev-mail", "claimedAt": 1}
			"/v1/iap/account-references": result = {"appAccountToken": "synthetic-account"}
			"/v1/iap/verify":
				if body.productId == "starter_badge": badge = true
				else: tickets += 1
				result = {"status": "verified", "completion": {"action": "finish"}}
			"/v1/iap/wallet": result = {"balances": {"starter_test_ticket_1": tickets}}
			"/v1/iap/entitlements": result = {"entitlements": ["starter_badge"] if badge else []}
			"/v1/ads/policy": result = {"appUsesAds": true, "adsEnabled": true}
			"/v1/ads/reward-claims": result = {"claimId": body.requestId, "admobSsv": {"customData": "synthetic-ssv", "userId": "puid-" + uid}}
			_:
				if path.begins_with("/v1/ads/reward-claims/"):
					result = {"state": "confirmed" if ad_verified else "accepted", "assurance": "server_verified" if ad_verified else "pending"}
				elif path != "/v1/events":
					callback.call({"ok": false, "code": "unmapped_development_boundary"})
					return
		callback.call({"ok": true, "result": result})

class Firebase extends Identity:
	func _request_json(_url: String, _method: int, _headers: PackedStringArray, body: String, _add_json_header: bool = true) -> Dictionary:
		var value: Dictionary = JSON.parse_string(body)
		return {"success": true, "data": {"localId": str(value.get("token", _state.get("uid", ""))), "idToken": str(value.get("token", _state.get("uid", ""))), "refreshToken": "synthetic-refresh", "expiresIn": "3600"}}

class NativeIdentity extends RefCounted:
	func configure(_firebase: Dictionary, _auth: Dictionary) -> void: pass
	func providers() -> Array: return ["google", "apple"]
	func app_check_token() -> Dictionary: return {"ok": true, "token": "synthetic-attestation"}
	func request(_provider: String, _nonce: String) -> Dictionary: return {"ok": true, "token": "synthetic-provider-proof", "authorization_code": "synthetic-fresh-code"}
	func close() -> void: pass

class Storage extends Cloud:
	var documents: Dictionary = {}
	var offline := false
	func _request(method: HTTPClient.Method, payload: Dictionary = {}, _revision: String = "") -> Dictionary:
		if offline: return {"ok": false, "status": 503}
		if method == HTTPClient.METHOD_GET:
			return {"ok": true, "data": {"updateTime": "dev-revision", "fields": {"payload": {"stringValue": JSON.stringify(documents[uid])}}}} if documents.has(uid) else {"ok": false, "status": 404}
		documents[uid] = payload.duplicate(true)
		return {"ok": true, "data": {"updateTime": "dev-revision"}}

class Market extends RefCounted:
	var finished := 0
	func is_market_available(_platform: String) -> bool: return true
	func request_localized_price(_platform: String, _id: String, callback: Callable) -> void: callback.call({"ok": true, "result": {"localizedPrice": "$0.99"}})
	func start_purchase(_platform: String, id: String, _references: Dictionary, callback: Callable) -> void:
		callback.call({"ok": true, "result": {"status": "purchased", "proof": {"transactionId": "synthetic-" + id}}})
	func complete_purchase(_platform: String, _completion: Dictionary, callback: Callable) -> void:
		finished += 1
		callback.call({"ok": true})
	func restore_purchases(_platform: String, callback: Callable, _manual: bool) -> void: callback.call({"ok": true, "result": {"purchases": []}})

class Ad extends Node:
	var unit := ""
	func available() -> bool: return true
	func busy() -> bool: return false
	func prepare() -> Dictionary: return {"ok": true}
	func load_ad() -> Dictionary: return {"ok": true}
	func show_ad(_ssv: Dictionary) -> Dictionary: return {"ok": true}
	func privacy_options_required() -> bool: return false
