extends Node
## Native presentation and server-verified test receipts; no client callback grants currency.
signal changed
const Claims = preload("res://addons/seorilabs_platform/adapters/rewarded_claim_adapter.gd")
const Native = preload("res://game/adapters/admob_native.gd")
const Store = preload("res://addons/seorilabs_platform/core/atomic_json_store.gd")
var sdk: Node
var identity: Node
var driver: Node
var client_platform := "android"
var status := "idle"
var path_prefix := "user://starter-ad-test-"
var _owner := ""
var _claims: Node
var _data: Dictionary = {}
var _valid := true
var _busy := false

func configure(client: Node, auth: Node, options: Dictionary) -> void:
	sdk = client
	identity = auth
	client_platform = "ios" if OS.get_name() == "iOS" else "android"
	if driver == null: driver = Native.new()
	if driver.get_parent() == null: add_child(driver)
	driver.unit = str(options.get(client_platform, {}).get("rewardedUnit", ""))

func _path() -> String: return path_prefix + _owner.sha256_text() + ".json"

func _bind() -> void:
	var owner := str(sdk.current_session().get("platformUserId", "")) if sdk.is_signed_in() else ""
	if _claims != null and owner == _owner: return
	_owner = owner
	_data = {"confirmed": 0, "pending": {}}
	var saved: Dictionary = Store.read_dictionary(_path())
	_valid = saved.ok
	if saved.ok and saved.exists:
		_valid = saved.value.get("confirmed") is float or saved.value.get("confirmed") is int
		_valid = _valid and saved.value.get("pending") is Dictionary
		if _valid: _data = saved.value
	if _claims != null: _claims.queue_free()
	_claims = Claims.new()
	add_child(_claims)
	_claims.configure({"platform_client": sdk, "identity_adapter": identity, "client_platform": client_platform,
		"claim_map_path": _path() + ".claims", "ack_queue_path": _path() + ".acks"})
	status = "awaiting_server" if not _data.pending.is_empty() else "idle"

func busy() -> bool: return _busy or (driver != null and driver.busy())

func snapshot() -> Dictionary:
	_bind()
	return {"status": status, "confirmed": int(_data.confirmed), "pending": not _data.pending.is_empty(),
		"available": _valid and not _owner.is_empty() and driver.available(), "busy": busy()}

func _state(value: String) -> void:
	status = value
	changed.emit()

func watch() -> void:
	_bind()
	if busy() or not _valid or _owner.is_empty() or not driver.available() or not _data.pending.is_empty(): return
	_busy = true
	var generation: int = sdk.authentication_generation()
	_state("loading")
	var policy: Dictionary = await _claims.policy()
	if generation != sdk.authentication_generation():
		_busy = false
		return
	if not policy.get("allowed", false):
		_finish("unavailable")
		return
	var result: Dictionary = await driver.prepare()
	if result.get("ok", false): result = await driver.load_ad()
	if generation != sdk.authentication_generation():
		_busy = false
		return
	if not result.get("ok", false):
		_finish("failed")
		return
	policy = await _claims.policy()
	if generation != sdk.authentication_generation():
		_busy = false
		return
	if not policy.get("allowed", false):
		_finish("unavailable")
		return
	_data.pending = {"request_id": Crypto.new().generate_random_bytes(16).hex_encode(), "placement": "starter_rewarded_test", "reward_key": "starter_ad_test", "reward_amount": 1, "settled": false}
	if not Store.write(_path(), _data):
		_finish("failed")
		return
	var created: Dictionary = await _claims.create_admob_claim(_data.pending)
	if generation != sdk.authentication_generation():
		_busy = false
		return
	if not created.get("success", false):
		_finish("awaiting_server")
		return
	_state("presenting")
	await driver.show_ad(_claims.ssv_options(str(_data.pending.request_id)))
	if generation != sdk.authentication_generation():
		_busy = false
		return
	await _recover(generation)
	_busy = false
	changed.emit()

func refresh() -> void:
	_bind()
	if busy() or not _valid or _owner.is_empty() or _data.pending.is_empty(): return
	_busy = true
	await _recover(sdk.authentication_generation())
	_busy = false
	changed.emit()

func _recover(generation: int) -> void:
	var request: Dictionary = _data.pending.duplicate(true)
	var result: Dictionary = await _claims.recover_admob_claim(request)
	if generation != sdk.authentication_generation(): return
	if result.get("status") == "verified":
		if not _data.pending.get("settled", false):
			var next := _data.duplicate(true)
			next.pending.settled = true
			next.confirmed = int(next.confirmed) + 1
			if not Store.write(_path(), next):
				_state("failed")
				return
			_data = next
		var acknowledged: bool = await _claims.acknowledge(str(request.request_id))
		if generation != sdk.authentication_generation(): return
		if not acknowledged:
			_state("ack_pending")
			return
		var next := _data.duplicate(true)
		next.pending = {}
		if not Store.write(_path(), next):
			_state("ack_pending")
			return
		_data = next
		_state("verified")
	elif result.get("status") == "failed" and result.get("reason") == "expired":
		if _claims.discard_unsettled_claim(str(request.request_id)):
			var next := _data.duplicate(true)
			next.pending = {}
			if Store.write(_path(), next): _data = next
		_state("expired")
	else:
		_state("awaiting_server")

func _finish(value: String) -> void:
	_busy = false
	_state(value)
