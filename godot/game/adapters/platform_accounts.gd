extends Node
## Only public account facts leave this adapter. Proofs and deletion receipts stay private.
const Identity = preload("res://addons/seorilabs_platform/adapters/firebase_identity_adapter.gd")
const Native = preload("res://game/adapters/native_identity.gd")
const Progress = preload("res://game/adapters/cloud_progress.gd")
const Store = preload("res://addons/seorilabs_platform/core/atomic_json_store.gd")
const RECEIPT_PATH := "user://starter-account-deletion.json"
const LEGACY_PATH := "user://com.seorilabs.startergame.json"
const MIGRATION_PATH := "user://starter-legacy-migration.json"
var sdk: Node
var identity: Node
var cloud: Node
var native: RefCounted = Native.new()
var receipt_path := RECEIPT_PATH
var identity_path := "user://starter-firebase-identity.json"
var legacy_path := LEGACY_PATH
var migration_path := MIGRATION_PATH
var state: RefCounted
var deletion: Dictionary = {}
var _busy := false
var operation_blocker: Callable

func configure(client: Node, progress: RefCounted, options: Dictionary, boundaries: Dictionary = {}) -> void:
	sdk = client
	state = progress
	var firebase: Dictionary = options.firebase["ios" if OS.get_name() == "iOS" else "android"]
	native = boundaries.get("native", native)
	native.configure(firebase, options.auth)
	identity = boundaries.get("identity")
	if identity == null: identity = Identity.new()
	identity.configure({"firebase_api_key": firebase.apiKey, "platform_client": sdk, "state_path": str(boundaries.get("identity_path", identity_path))})
	add_child(identity)
	cloud = boundaries.get("cloud")
	if cloud == null: cloud = Progress.new()
	add_child(cloud)
	cloud.configure(identity, state, str(firebase.projectId))
	receipt_path = str(boundaries.get("receipt_path", receipt_path))
	legacy_path = str(boundaries.get("legacy_path", legacy_path))
	migration_path = str(boundaries.get("migration_path", migration_path))
	var stored: Dictionary = Store.read_dictionary(receipt_path)
	if stored.ok and stored.exists: deletion = stored.value

func providers() -> Array:
	return native.providers()

func capabilities() -> Dictionary:
	return {"create": not _busy, "logout": not _busy, "delete": not _busy, "refresh": not _busy and sdk.is_signed_in(),
		"recover": not providers().is_empty(), "link": not providers().is_empty(), "providers": providers(),
		"keep_cloud": cloud.status == "cloud_conflict" and not _busy, "keep_local": cloud.status == "cloud_conflict" and not _busy,
		"deletion_status": not deletion.is_empty()}

func snapshot() -> Dictionary:
	var session: Dictionary = sdk.current_session()
	var result: Dictionary = {"deletionStatus": str(deletion.get("state", ""))} if not deletion.is_empty() else {}
	if sdk.is_signed_in():
		result.merge({"uid": str(session.get("appUserId", "")), "platformUserId": str(session.get("platformUserId", "")),
			"supportCode": str(session.get("supportCode", "")), "linked": sdk.is_account_linked(), "saveStatus": cloud.status, "progressReady": cloud.progress_ready})
	return result

func supply(callback: Callable) -> void:
	var current: Dictionary = identity.current_identity()
	if current.is_empty():
		callback.call({"ok": true, "credential": {}})
		return
	var result: Dictionary = await _connect()
	callback.call({"ok": true, "session_ready": true} if result.ok else result)

func execute(action: String, payload: Dictionary, callback: Callable) -> void:
	if _busy or (action in ["create", "recover", "link", "logout", "delete", "refresh"] and operation_blocker.is_valid() and operation_blocker.call()):
		callback.call({"ok": false, "code": "account_busy"})
		return
	_busy = true
	var result: Dictionary
	match action:
		"create":
			result = await _logout()
			if result.ok: result = await _connect(true)
		"refresh": result = await _connect()
		"logout": result = await _logout()
		"link", "recover": result = await _link(action, payload)
		"delete": result = await _delete()
		"keep_cloud": result = await cloud.resolve_conflict(false)
		"keep_local": result = await cloud.resolve_conflict(true)
		"deletion_status": result = await _deletion_status()
		_: result = {"ok": false, "code": "account_unsupported"}
	_busy = false
	# Authentication may succeed while cloud loading fails. Show the confirmed new UID,
	# keep play disabled, and offer an explicit retry instead of showing the old account.
	result.account = snapshot()
	result.account_confirmed = true
	callback.call(result)

func _credential() -> Dictionary:
	var current: Dictionary = await identity.ensure_identity()
	if not current.get("success", false): return {"ok": false, "code": current.get("reason", "identity_failed")}
	return {"ok": true, "credential": {"kind": "firebase-id-token", "value": current.id_token}, "uid": current.uid}

func _connect(migrate_legacy: bool = false) -> Dictionary:
	var auth: Dictionary = await _credential()
	if not auth.ok: return auth
	var response: Dictionary = await _call(func(cb: Callable) -> void: sdk.sign_in(auth.credential, cb))
	if not response.get("ok", false): return response
	var restored: Dictionary = await cloud.restore(str(auth.uid))
	if restored.ok and restored.get("empty_remote", false) and (migrate_legacy or FileAccess.file_exists(migration_path)):
		_migrate_legacy(str(auth.uid))
	# Keep a valid account visible when storage is unavailable; cloud.progress_ready gates play.
	return {"ok": true, "saveReady": restored.ok}

func _migrate_legacy(account_uid: String) -> void:
	var previous: Dictionary = Store.read_dictionary(legacy_path)
	if not previous.ok or not previous.exists or not state.valid(previous.value): return
	var marker: Dictionary = Store.read_dictionary(migration_path)
	if not marker.ok or (marker.exists and marker.value.get("uid") != account_uid): return
	# The first confirmed UID owns this import, including after a crash before upload.
	if not marker.exists and not Store.write(migration_path, {"uid": account_uid}):
		cloud.progress_ready = false
		cloud.status = "migration_save_failed"
		return
	var local: Dictionary = previous.value.duplicate(true)
	if not local.has("ui"): local.ui = state.defaults().ui
	local.mail = []
	local.events = {}
	local.ui.commerce = {}
	local.ui.submissions = {}
	if FileAccess.file_exists(cloud.privacy_marker): local.settings.analytics = false
	if not state.commit(local):
		cloud.progress_ready = false
		cloud.status = state.error

func _logout() -> Dictionary:
	if cloud.has_pending(): return {"ok": false, "code": "cloud_save_pending"}
	sdk.sign_out()
	cloud.detach()
	if not identity.clear_local_state(): return {"ok": false, "code": "identity_clear_failed"}
	return {"ok": true}

func _link(action: String, payload: Dictionary) -> Dictionary:
	var provider := str(payload.get("provider", ""))
	if provider not in providers(): return {"ok": false, "code": "credential_unavailable"}
	var check: Dictionary = await native.app_check_token()
	if not check.ok: return check
	identity.set_app_check_token(str(check.token))
	if not sdk.is_signed_in():
		var connected: Dictionary = await _connect()
		if not connected.ok: return connected
	if not cloud.progress_ready or cloud.has_pending(): return {"ok": false, "code": "cloud_save_not_ready"}
	var expected_uid := str(payload.get("expectedUid", ""))
	var challenge: Dictionary = await _call(func(cb: Callable) -> void:
		if action == "recover": sdk.begin_account_link_recovery(provider, expected_uid, check.token, cb)
		else: sdk.begin_account_link(provider, check.token, cb))
	if not challenge.get("ok", false): return challenge
	var nonce := str(challenge.get("result", {}).get("nonce", ""))
	var proof: Dictionary = await native.request(provider, nonce)
	if not proof.ok: return proof
	var linked: Dictionary = await _call(func(cb: Callable) -> void:
		if action == "recover": sdk.recover_account_link(provider, proof.token, nonce, expected_uid, check.token, cb)
		else: sdk.complete_account_link(provider, proof.token, nonce, check.token, cb))
	if not linked.get("ok", false): return linked
	cloud.detach()
	var adopted: Dictionary = await identity.adopt_account_link(linked.result)
	if not adopted.get("success", false): return {"ok": false, "code": adopted.get("reason", "identity_failed")}
	return await _connect()

func _delete() -> Dictionary:
	var auth: Dictionary = await _credential()
	if not auth.ok: return auth
	var check: Dictionary = await native.app_check_token()
	if not check.ok: return check
	if deletion.get("uid", "") != auth.uid:
		deletion = {"uid": auth.uid, "receipt": Crypto.new().generate_random_bytes(32).hex_encode(), "state": "requesting"}
		if not Store.write(receipt_path, deletion): return {"ok": false, "code": "deletion_receipt_save_failed"}
	var request := func(code: String) -> Dictionary:
		return await _call(func(cb: Callable) -> void: sdk.request_account_deletion(auth.credential.value, deletion.receipt, check.token, cb, code))
	var response: Dictionary = await request.call("")
	if response.get("code") == "account_reauth_required" and "apple" in providers():
		var proof: Dictionary = await native.request("apple", Crypto.new().generate_random_bytes(32).hex_encode())
		if not proof.ok: return proof
		response = await request.call(str(proof.get("authorization_code", "")))
	if not response.get("ok", false): return response
	deletion.state = str(response.get("result", {}).get("state", "accepted"))
	if not Store.write(receipt_path, deletion): return {"ok": false, "code": "deletion_receipt_save_failed"}
	sdk.sign_out()
	cloud.detach()
	if not identity.clear_local_state(): return {"ok": false, "code": "identity_clear_failed"}
	return {"ok": true}

func _deletion_status() -> Dictionary:
	if deletion.is_empty(): return {"ok": false, "code": "deletion_receipt_missing"}
	var response: Dictionary = await _call(func(cb: Callable) -> void: sdk.account_deletion_status(str(deletion.receipt), cb))
	if response.get("ok", false):
		deletion.state = str(response.get("result", {}).get("state", "unknown"))
		if not Store.write(receipt_path, deletion): return {"ok": false, "code": "deletion_receipt_save_failed"}
	return response

func _call(start: Callable) -> Dictionary:
	var box: Array[Dictionary] = []
	start.call(func(response: Dictionary) -> void: box.append(response))
	var deadline := Time.get_ticks_msec() + 60000
	while box.is_empty() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if box.is_empty():
		sdk.sign_out()
		cloud.detach()
		return {"ok": false, "code": "platform_timeout"}
	return box[0]

func _exit_tree() -> void:
	native.close()
