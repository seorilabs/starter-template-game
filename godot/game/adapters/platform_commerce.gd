extends RefCounted
## A store callback is evidence to verify, never a currency grant.
const Store = preload("res://addons/seorilabs_platform/core/atomic_json_store.gd")
const PRODUCT_IDS := ["starter_test_ticket_1", "starter_badge"]
var sdk: Node
var market: Object
var platform := ""
var wallet: Dictionary = {}
var wallet_status := "unknown"
var entitlements: Array = []
var entitlement_status := "unknown"
var _busy := false
var _pending: Dictionary = {}
var _valid_store := true
var _owner := ""
var _wallet_generation := 0

func _path() -> String:
	return "user://starter-purchases-" + _owner.sha256_text() + ".json"

func _bind() -> void:
	var owner := str(sdk.current_session().get("platformUserId", ""))
	if owner == _owner: return
	_owner = owner
	wallet = {}
	wallet_status = "unknown"
	entitlements = []
	entitlement_status = "unknown"
	_pending = {}
	var saved: Dictionary = Store.read_dictionary(_path())
	_valid_store = saved.ok
	if saved.ok and saved.exists: _pending = saved.value

func capabilities() -> Dictionary:
	_bind()
	var available: bool = market != null and market.is_market_available(platform) and sdk.is_signed_in() and not sdk.is_anonymous()
	return {"purchase": available and _valid_store, "restore": available and _valid_store}

func catalog(callback: Callable) -> void:
	_bind()
	var generation: int = sdk.authentication_generation()
	var products: Array = []
	for product_id in PRODUCT_IDS:
		var result: Dictionary = await _call(func(cb: Callable) -> void: market.request_localized_price(platform, product_id, cb))
		if not _current(generation): return
		var en := "Test Ticket (1)" if product_id == PRODUCT_IDS[0] else "Starter Badge"
		var ko := "테스트 티켓 1장" if product_id == PRODUCT_IDS[0] else "스타터 배지"
		products.append({"id": product_id, "title": en, "localized": {"ko": {"title": ko}}, "price": str(result.get("result", {}).get("localizedPrice", "")), "available": result.get("ok", false)})
	await refresh_wallet()
	if not _current(generation): return
	for product in products:
		if product.id == "starter_badge" and entitlement_status == "verified" and "starter_badge" in entitlements:
			product.available = false
			product.title += " (Owned)"
			product.localized.ko.title += " (보유 중)"
	callback.call({"ok": true, "products": products})

func purchase(product_id: String, callback: Callable) -> void:
	_bind()
	if _busy or not capabilities().purchase or product_id not in PRODUCT_IDS:
		callback.call({"state": "failed"})
		return
	_busy = true
	var generation: int = sdk.authentication_generation()
	var references: Dictionary = await _call(func(cb: Callable) -> void: sdk.account_references(cb))
	if not references.get("ok", false) or generation != sdk.authentication_generation():
		_busy = false
		callback.call({"state": "failed"})
		return
	var response: Dictionary = await _call(func(cb: Callable) -> void: market.start_purchase(platform, product_id, references.result, cb), 180000)
	if not _current(generation):
		_busy = false
		return
	var result: Dictionary = response.get("result", {})
	if not response.get("ok", false): callback.call({"state": "failed"})
	elif result.get("status") in ["cancelled", "pending"]: callback.call({"state": result.status})
	else: callback.call(await _verify(product_id, result.get("proof", {}), generation))
	_busy = false

func _verify(product_id: String, proof: Dictionary, generation: int) -> Dictionary:
	var token := str(proof.get("purchaseToken", proof.get("transactionId", "")))
	if token.is_empty() or product_id not in PRODUCT_IDS: return {"state": "failed"}
	# Only the opaque hash may enter shared UI saves. Raw proof stays in this private file.
	var key := (platform + ":" + product_id + ":" + token).sha256_text()
	_pending[key] = {"owner": _owner, "product": product_id, "proof": proof.duplicate(true)}
	if not Store.write(_path(), _pending): return {"state": "failed", "transactionId": key}
	var response: Dictionary = await _call(func(cb: Callable) -> void: sdk.verify_purchase({"platform": platform, "product_id": product_id, "token": token}, cb))
	if not _current(generation): return {"state": "failed"}
	if not response.get("ok", false): return {"state": "failed", "transactionId": key}
	var result: Dictionary = response.get("result", {})
	if result.get("status") == "pending": return {"state": "pending", "transactionId": key}
	if result.get("status") == "revoked":
		_pending.erase(key)
		Store.write(_path(), _pending)
		await refresh_wallet()
		return {"state": "revoked", "transactionId": key}
	if result.get("status") != "verified": return {"state": "failed", "transactionId": key}
	if not await refresh_wallet(): return {"state": "fulfilling", "transactionId": key}
	if product_id == "starter_badge" and product_id not in entitlements: return {"state": "fulfilling", "transactionId": key}
	var completion: Dictionary = result.get("completion", {})
	if platform == "app_store":
		var done: Dictionary = await _call(func(cb: Callable) -> void: market.complete_purchase(platform, completion, cb))
		if not _current(generation): return {"state": "failed"}
		if not done.get("ok", false): return {"state": "fulfilling", "transactionId": key}
	elif completion.get("action") != "none":
		return {"state": "fulfilling", "transactionId": key}
	_pending.erase(key)
	if not Store.write(_path(), _pending): return {"state": "fulfilling", "transactionId": key}
	return {"state": "completed", "fulfilled": true, "transactionId": key}

func reconcile(key: String, callback: Callable) -> void:
	_bind()
	if _busy or not _pending.has(key) or not _valid_store:
		callback.call({"state": "failed", "transactionId": key})
		return
	_busy = true
	var item: Dictionary = _pending[key]
	callback.call(await _verify(str(item.product), item.proof, sdk.authentication_generation()))
	_busy = false

func restore(callback: Callable) -> void:
	_bind()
	if _busy or not capabilities().restore:
		callback.call({"state": "failed"})
		return
	_busy = true
	var generation: int = sdk.authentication_generation()
	var response: Dictionary = await _call(func(cb: Callable) -> void: market.restore_purchases(platform, cb, true))
	if not _current(generation):
		_busy = false
		return
	if not response.get("ok", false):
		_busy = false
		callback.call({"state": "failed"})
		return
	var items: Array = response.get("result", {}).get("purchases", []).duplicate(true)
	for item in _pending.values():
		if item.get("owner") == _owner: items.append({"productId": item.product, "proof": item.proof})
	var restored := 0
	var failed := 0
	var seen: Dictionary = {}
	for item in items:
		if not _current(generation):
			_busy = false
			return
		var product_id := str(item.get("productId", ""))
		if product_id not in PRODUCT_IDS: continue
		var proof: Dictionary = item.get("proof", {})
		var key := JSON.stringify(proof).sha256_text()
		if seen.has(key): continue
		seen[key] = true
		var result: Dictionary = await _verify(product_id, proof, generation)
		if result.get("state") == "completed": restored += 1
		else: failed += 1
	await refresh_wallet()
	_busy = false
	callback.call({"state": "partial" if failed and restored else "failed" if failed else "restored" if restored else "none"})

func refresh_wallet() -> bool:
	_bind()
	_wallet_generation += 1
	var request_generation := _wallet_generation
	wallet_status = "loading"
	entitlement_status = "loading"
	var generation: int = sdk.authentication_generation()
	var response: Dictionary = await _call(func(cb: Callable) -> void: sdk.get_wallet(cb))
	if not _current(generation) or request_generation != _wallet_generation: return false
	if not response.get("ok", false):
		wallet_status = "unavailable"
		return false
	var balances: Variant = response.get("result", {}).get("balances")
	if not balances is Dictionary or not balances.has("starter_test_ticket_1"):
		wallet_status = "unavailable"
		return false
	wallet = balances
	wallet_status = "verified"
	var access: Dictionary = await _call(func(cb: Callable) -> void: sdk.list_entitlements(cb))
	if not _current(generation) or request_generation != _wallet_generation: return false
	var active: Variant = access.get("result", {}).get("entitlements")
	if not access.get("ok", false) or not active is Array:
		entitlement_status = "unavailable"
		return false
	entitlements = active
	entitlement_status = "verified"
	return true

func has_pending() -> bool:
	return _busy or not _pending.is_empty()

func _current(generation: int) -> bool:
	return is_instance_valid(sdk) and generation == sdk.authentication_generation()

func _call(start: Callable, timeout_ms: int = 60000) -> Dictionary:
	if not is_instance_valid(sdk): return {"ok": false, "code": "auth_state_changed"}
	var box: Array[Dictionary] = []
	start.call(func(response: Dictionary) -> void: box.append(response))
	var deadline := Time.get_ticks_msec() + timeout_ms
	while box.is_empty() and is_instance_valid(sdk) and Time.get_ticks_msec() < deadline: await Engine.get_main_loop().process_frame
	return box[0] if not box.is_empty() else {"ok": false, "code": "store_timeout"}
