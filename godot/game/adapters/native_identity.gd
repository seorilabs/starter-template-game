extends RefCounted
## Actual provider credentials stay inside adapters. A timed-out native request is
## quarantined until its callback arrives, so it cannot satisfy a later account operation.
const TIMEOUT_MS := 60000
var _plugin: Object
var _platform := OS.get_name()
var _configured := false
var _google_client_id := ""
var _ios_enabled := false
var _sign_in: Dictionary = {"active": false, "result": {}}
var _app_check: Dictionary = {"active": false, "result": {}}

func configure(firebase: Dictionary, auth: Dictionary) -> void:
	_google_client_id = str(auth.get("googleWebClientId", ""))
	_ios_enabled = bool(auth.get("appleEnabled", false))
	if not Engine.has_singleton("SeoriAccountLink") or _platform not in ["Android", "iOS"]:
		return
	_plugin = Engine.get_singleton("SeoriAccountLink")
	var method := "configureFirebase" if _platform == "Android" else "configure_firebase"
	if not _plugin.has_method(method): return
	_configured = bool(_plugin.call(method, str(firebase.get("apiKey", "")), str(firebase.get("appId", "")), str(firebase.get("projectId", "")), str(firebase.get("projectNumber", ""))))
	if not _configured: return
	if _platform == "Android":
		_plugin.connect("google_id_token", _on_google_token)
		_plugin.connect("google_id_failed", _on_sign_in_failed)
	else:
		_plugin.connect("apple_id_token", _on_apple_token)
		_plugin.connect("apple_id_failed", _on_sign_in_failed)
	_plugin.connect("app_check_token", _on_app_check_token)
	_plugin.connect("app_check_failed", _on_app_check_failed)

func providers() -> Array:
	if not _configured: return []
	if _platform == "Android" and _google_client_id.ends_with(".apps.googleusercontent.com"): return ["google"]
	if _platform == "iOS" and _ios_enabled: return ["apple"]
	return []

func request(provider: String, nonce: String) -> Dictionary:
	if provider not in providers() or _sign_in.active or nonce.is_empty():
		return {"ok": false, "code": "credential_unavailable"}
	_sign_in = {"active": true, "result": {}}
	if provider == "google":
		_plugin.call("signIn", _google_client_id, nonce)
	elif not bool(_plugin.call("sign_in", nonce.sha256_text())):
		_sign_in.active = false
		return {"ok": false, "code": "credential_unavailable"}
	return await _wait(_sign_in, "credential_timeout")

func app_check_token() -> Dictionary:
	if not _configured or _app_check.active:
		return {"ok": false, "code": "app_check_unavailable"}
	_app_check = {"active": true, "result": {}}
	var method := "appCheckToken" if _platform == "Android" else "app_check_token"
	if _plugin.call(method) == false:
		_app_check.active = false
		return {"ok": false, "code": "app_check_unavailable"}
	return await _wait(_app_check, "app_check_timeout")

func _wait(flight: Dictionary, timeout_code: String) -> Dictionary:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while flight.result.is_empty() and Time.get_ticks_msec() < deadline:
		await Engine.get_main_loop().process_frame
	# Keep active=true after timeout until the native callback is consumed.
	return flight.result.duplicate(true) if not flight.result.is_empty() else {"ok": false, "code": timeout_code}

func _complete(flight: Dictionary, result: Dictionary) -> void:
	if not flight.active: return
	flight.result = result
	flight.active = false

func _on_google_token(token: String) -> void:
	_complete(_sign_in, {"ok": true, "token": token})

func _on_apple_token(token: String, code: String) -> void:
	_complete(_sign_in, {"ok": true, "token": token, "authorization_code": code})

func _on_sign_in_failed(code: String, _message: String) -> void:
	_complete(_sign_in, {"ok": false, "code": "credential_" + code})

func _on_app_check_token(token: String) -> void:
	_complete(_app_check, {"ok": true, "token": token})

func _on_app_check_failed(code: String) -> void:
	_complete(_app_check, {"ok": false, "code": "app_check_" + code})

func close() -> void:
	if _plugin == null: return
	for pair in [["google_id_token", _on_google_token], ["apple_id_token", _on_apple_token], ["google_id_failed", _on_sign_in_failed], ["apple_id_failed", _on_sign_in_failed], ["app_check_token", _on_app_check_token], ["app_check_failed", _on_app_check_failed]]:
		if _plugin.has_signal(pair[0]) and _plugin.is_connected(pair[0], pair[1]): _plugin.disconnect(pair[0], pair[1])
	_plugin = null
