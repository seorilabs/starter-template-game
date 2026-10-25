# 공식 GodotGooglePlayBilling Android plugin을 공통 MarketPurchase seam으로 정규화한다.
# 구매 승인(acknowledge)은 여기서 수행하지 않는다. Functions가 entitlement를 원자적으로
# 기록한 뒤 Google Play Developer API로 승인한다.
extends Node

const BillingClientWrapper := preload("res://addons/GodotGooglePlayBilling/BillingClient.gd")

const GOOGLE_PLAY := "google_play"
const PRODUCT_TYPE_INAPP := 0
const BILLING_OK := 0
const BILLING_USER_CANCELLED := 1
const BILLING_ITEM_ALREADY_OWNED := 7
const PURCHASED := 1
const PENDING := 2
const MAX_PURCHASES := 100
const MAX_PRODUCT_ID_LENGTH := 256
const MAX_PURCHASE_TOKEN_LENGTH := 4096
const MAX_ACCOUNT_ID_LENGTH := 64

var _billing
var _connection_ready := false
var _connection_started := false
var _ready_waiters: Array = []
var connection_timeout_ms := 20000
var _connection_deadline := 0
var _detail_cache: Dictionary = {}
var _detail_queue: Array = []
var _detail_in_flight := false
var _detail_product_id := ""
var _purchase_callback := Callable()
var _purchase_product_id := ""
var _owned_query_callback := Callable()
var _owned_query_in_flight := false


func _init(native_bridge = null) -> void:
	_billing = native_bridge
	if _billing == null and Engine.has_singleton("GodotGooglePlayBilling"):
		_billing = BillingClientWrapper.new()
	if _billing == null:
		return
	if _billing is Node and (_billing as Node).get_parent() == null:
		add_child(_billing)
	_connect_bridge_signal("connected", _on_connected)
	_connect_bridge_signal("disconnected", _on_disconnected)
	_connect_bridge_signal("connect_error", _on_connect_error)
	_connect_bridge_signal("query_product_details_response", _on_query_product_details_response)
	_connect_bridge_signal("query_purchases_response", _on_query_purchases_response)
	_connect_bridge_signal("on_purchase_updated", _on_purchase_updated)
	_connection_ready = _bridge_is_ready()


func native_bridge():
	return _billing


func is_market_available(platform: String) -> bool:
	if platform != GOOGLE_PLAY or _billing == null:
		return false
	for method_name in [
		"start_connection",
		"is_ready",
		"query_product_details",
		"query_purchases",
		"purchase",
		"set_obfuscated_account_id",
	]:
		if not _billing.has_method(method_name):
			return false
	return _billing.has_signal("query_product_details_response") \
		and _billing.has_signal("query_purchases_response") \
		and _billing.has_signal("on_purchase_updated")


func request_localized_price(platform: String, product_id: String, callback: Callable) -> void:
	if not callback.is_valid():
		return
	if platform != GOOGLE_PLAY or not _valid_value(product_id, MAX_PRODUCT_ID_LENGTH):
		callback.call(_error("play_billing_request_invalid", "Google Play 상품 요청 값이 올바르지 않습니다."))
		return
	_ensure_product_detail(product_id, func(response: Dictionary) -> void:
		if not bool(response.get("ok", false)):
			callback.call(response)
			return
		var detail: Dictionary = response.get("result", {})
		callback.call({
			"ok": true,
			"result": {
				"productId": product_id,
				"localizedPrice": String(detail.get("localized_price", "")),
				"priceMicros": int(detail.get("price_amount_micros", 0)),
				"currencyCode": String(detail.get("price_currency_code", "")),
			},
		})
	)


func start_purchase(
	platform: String,
	product_id: String,
	account_references: Dictionary,
	callback: Callable,
) -> void:
	if not callback.is_valid():
		return
	if platform != GOOGLE_PLAY or not is_market_available(platform):
		callback.call(_error("play_billing_unavailable", "Google Play 결제를 사용할 수 없습니다."))
		return
	if _purchase_callback.is_valid() or _owned_query_callback.is_valid():
		callback.call(_error("play_billing_busy", "다른 Google Play 결제를 처리하고 있습니다."))
		return
	var account_id := String(account_references.get("googlePlayObfuscatedAccountId", "")).strip_edges()
	if not _valid_value(product_id, MAX_PRODUCT_ID_LENGTH) \
			or not _valid_value(account_id, MAX_ACCOUNT_ID_LENGTH):
		callback.call(_error("play_billing_request_invalid", "Google Play 구매 요청 값이 올바르지 않습니다."))
		return
	# 공식 plugin 3.2는 query 결과마다 native ProductDetails map을 교체한다. 가격을 상품별로
	# 조회한 뒤에는 먼저 조회한 상품이 native map에서 빠질 수 있고, Google도 오래된
	# ProductDetails 캐시로 launchBillingFlow를 시작하지 않도록 권고한다. 구매 직전 선택한
	# 상품을 다시 조회해 GDScript 캐시와 native cache를 함께 최신 상태로 맞춘다.
	_ensure_product_detail(product_id, func(response: Dictionary) -> void:
		if not bool(response.get("ok", false)):
			callback.call(response)
			return
		var detail: Dictionary = response.get("result", {})
		_billing.call("set_obfuscated_account_id", account_id)
		if _billing.has_method("set_obfuscated_profile_id"):
			_billing.call("set_obfuscated_profile_id", "")
		_purchase_product_id = product_id
		_purchase_callback = callback
		if OS.is_debug_build() and OS.get_name() == "Android":
			print("[iap] purchase launch request: option_present=%s offer_present=%s" % [
				String(detail.get("purchase_option_id", "")) != "",
				String(detail.get("offer_id", "")) != "",
			])
		var launch = _billing.call(
			"purchase",
			product_id,
			String(detail.get("purchase_option_id", "")),
			String(detail.get("offer_id", "")),
			false,
		)
		if not (launch is Dictionary):
			if OS.is_debug_build() and OS.get_name() == "Android":
				print("[iap] purchase launch: response_type=%s" % type_string(typeof(launch)))
			_finish_purchase(_error("play_billing_response_invalid", "Google Play 결제 시작 응답이 올바르지 않습니다."))
			return
		var launch_response: Dictionary = launch
		var response_code := int(launch_response.get("response_code", -999))
		if OS.is_debug_build() and OS.get_name() == "Android":
			var debug_message := String(launch_response.get("debug_message", "")) \
				.replace("\n", " ").replace("\r", " ").left(256)
			print("[iap] purchase launch: response=%d message=%s" % [response_code, debug_message])
		if response_code == BILLING_USER_CANCELLED:
			_finish_purchase({"ok": true, "result": {"status": "cancelled"}})
		elif response_code == BILLING_ITEM_ALREADY_OWNED:
			_resolve_already_owned()
		elif response_code != BILLING_OK:
			_finish_purchase(_billing_error(response_code, "Google Play 결제를 시작하지 못했습니다."))
	, true)


func restore_purchases(platform: String, callback: Callable, _manual: bool = false) -> void:
	if not callback.is_valid():
		return
	if platform != GOOGLE_PLAY or not is_market_available(platform):
		callback.call(_error("play_billing_unavailable", "Google Play 구매를 복원할 수 없습니다."))
		return
	if _purchase_callback.is_valid() or _owned_query_callback.is_valid():
		print("[iap] restore stage=market_busy purchase=%s owned=%s" % [
			_purchase_callback.is_valid(), _owned_query_callback.is_valid()])
		callback.call(_error("play_billing_busy", "다른 Google Play 결제를 처리하고 있습니다."))
		return
	print("[iap] restore stage=market_query_start")
	_start_owned_query(func(response: Dictionary) -> void:
		var raw = response.get("purchases", null)
		print("[iap] restore stage=market_query_done code=%d count=%d" % [
			int(response.get("response_code", -999)),
			(raw as Array).size() if raw is Array else -1])
		callback.call(_normalize_restored_purchases(response))
	)


func complete_purchase(_platform: String, _completion_action: Dictionary, callback: Callable) -> void:
	# Google acknowledge는 entitlement commit 이후 서버가 수행한다.
	if callback.is_valid():
		callback.call({"ok": true})


func _ensure_product_detail(product_id: String, callback: Callable, force_refresh := false) -> void:
	if not force_refresh and _detail_cache.has(product_id):
		callback.call({"ok": true, "result": (_detail_cache[product_id] as Dictionary).duplicate(true)})
		return
	_detail_queue.append({"product_id": product_id, "callback": callback})
	_pump_detail_queue()


func _pump_detail_queue() -> void:
	if _owned_query_in_flight or _detail_in_flight:
		return
	if _detail_queue.is_empty():
		_maybe_start_owned_query()
		return
	_detail_in_flight = true
	var request: Dictionary = _detail_queue[0]
	_detail_product_id = String(request.get("product_id", ""))
	_when_ready(func(response: Dictionary) -> void:
		if not bool(response.get("ok", false)):
			_finish_detail(response)
			return
		_billing.call("query_product_details", PackedStringArray([_detail_product_id]), PRODUCT_TYPE_INAPP)
	)


func _on_query_product_details_response(response: Dictionary) -> void:
	if not _detail_in_flight:
		return
	var response_code := int(response.get("response_code", -999))
	if OS.is_debug_build() and OS.get_name() == "Android":
		var debug_details = response.get("product_details", [])
		var debug_unfetched = response.get("unfetched_products", [])
		var debug_statuses: Array = []
		if debug_unfetched is Array:
			for raw_unfetched in debug_unfetched:
				if raw_unfetched is Dictionary:
					debug_statuses.append(int(raw_unfetched.get("status_code", -999)))
		print("[iap] product query: response=%d details=%d unfetched_statuses=%s" % [
			response_code,
			debug_details.size() if debug_details is Array else -1,
			debug_statuses,
		])
	if response_code != BILLING_OK:
		_finish_detail(_billing_error(response_code, "Google Play 상품 정보를 가져오지 못했습니다."))
		return
	var details = response.get("product_details", null)
	if not (details is Array) or details.size() > MAX_PURCHASES:
		_finish_detail(_error("play_billing_response_invalid", "Google Play 상품 정보 응답이 올바르지 않습니다."))
		return
	var matched: Dictionary = {}
	for raw_detail in details:
		if raw_detail is Dictionary and String(raw_detail.get("product_id", "")) == _detail_product_id:
			if not matched.is_empty():
				_finish_detail(_error("play_billing_response_invalid", "Google Play 상품 정보가 중복되었습니다."))
				return
			matched = raw_detail
	if matched.is_empty():
		_finish_detail(_error("play_billing_product_unavailable", "Google Play 상품을 찾을 수 없습니다."))
		return
	var offer := _select_base_offer(matched.get("one_time_purchase_offer_details_list", null))
	if offer.is_empty():
		_finish_detail(_error("play_billing_response_invalid", "Google Play 기본 구매 옵션을 확인하지 못했습니다."))
		return
	var localized_price := String(offer.get("formatted_price", "")).strip_edges()
	if not _valid_value(localized_price, 64):
		_finish_detail(_error("play_billing_response_invalid", "Google Play 현지가격 응답이 올바르지 않습니다."))
		return
	var normalized := {
		"localized_price": localized_price,
		"purchase_option_id": _nullable_string(offer.get("purchase_option_id", "")),
		"offer_id": "",
	}
	_detail_cache[_detail_product_id] = normalized.duplicate(true)
	_finish_detail({"ok": true, "result": normalized})


func _select_base_offer(raw_offers) -> Dictionary:
	if not (raw_offers is Array) or raw_offers.is_empty() or raw_offers.size() > MAX_PURCHASES:
		return {}
	var selected: Dictionary = {}
	for raw_offer in raw_offers:
		if not (raw_offer is Dictionary):
			return {}
		var offer_id := _nullable_string(raw_offer.get("offer_id", ""))
		if offer_id != "":
			continue
		if not selected.is_empty():
			return {}
		selected = raw_offer
	return selected.duplicate(true)


func _finish_detail(response: Dictionary) -> void:
	if _detail_queue.is_empty():
		_detail_in_flight = false
		_detail_product_id = ""
		_maybe_start_owned_query()
		return
	var request: Dictionary = _detail_queue.pop_front()
	var callback: Callable = request.get("callback", Callable())
	_detail_in_flight = false
	_detail_product_id = ""
	if callback.is_valid():
		callback.call(response.duplicate(true))
	_pump_detail_queue()


func _on_purchase_updated(response: Dictionary) -> void:
	if not _purchase_callback.is_valid():
		return
	var response_code := int(response.get("response_code", -999))
	if OS.is_debug_build() and OS.get_name() == "Android":
		var purchases = response.get("purchases", [])
		print("[iap] purchase updated: response=%d purchases=%d" % [
			response_code,
			purchases.size() if purchases is Array else -1,
		])
	if response_code == BILLING_USER_CANCELLED:
		_finish_purchase({"ok": true, "result": {"status": "cancelled"}})
		return
	if response_code == BILLING_ITEM_ALREADY_OWNED:
		_resolve_already_owned()
		return
	if response_code != BILLING_OK:
		_finish_purchase(_billing_error(response_code, "Google Play 결제를 완료하지 못했습니다."))
		return
	_finish_purchase(_normalize_purchase_update(response, _purchase_product_id))


func _resolve_already_owned() -> void:
	var callback := _take_purchase_callback()
	var product_id := _purchase_product_id
	_purchase_product_id = ""
	_start_owned_query(func(query_response: Dictionary) -> void:
		if callback.is_valid():
			callback.call(_normalize_purchase_update(query_response, product_id))
	)


func _normalize_purchase_update(response: Dictionary, product_id: String) -> Dictionary:
	var response_code := int(response.get("response_code", -999))
	if response_code != BILLING_OK:
		return _billing_error(response_code, "Google Play 구매 상태를 확인하지 못했습니다.")
	var purchases = response.get("purchases", null)
	if not (purchases is Array) or purchases.size() > MAX_PURCHASES:
		return _error("play_billing_response_invalid", "Google Play 구매 응답이 올바르지 않습니다.")
	var matched: Dictionary = {}
	for raw_purchase in purchases:
		var normalized := _normalize_purchase(raw_purchase)
		if not bool(normalized.get("ok", false)):
			return normalized
		var result: Dictionary = normalized.get("result", {})
		if String(result.get("productId", "")) != product_id:
			continue
		if not matched.is_empty():
			return _error("play_billing_response_invalid", "Google Play 비소모품 구매가 중복되었습니다.")
		matched = result
	if matched.is_empty():
		return _error("play_billing_purchase_missing", "Google Play 구매 결과를 찾을 수 없습니다.")
	return {"ok": true, "result": matched}


func _normalize_restored_purchases(response: Dictionary) -> Dictionary:
	var response_code := int(response.get("response_code", -999))
	if response_code != BILLING_OK:
		return _billing_error(response_code, "Google Play 구매 복원에 실패했습니다.")
	var raw_purchases = response.get("purchases", null)
	if not (raw_purchases is Array) or raw_purchases.size() > MAX_PURCHASES:
		return _error("play_billing_response_invalid", "Google Play 구매 복원 응답이 올바르지 않습니다.")
	var purchases: Array = []
	var seen_tokens: Dictionary = {}
	for raw_purchase in raw_purchases:
		var normalized := _normalize_purchase(raw_purchase)
		if not bool(normalized.get("ok", false)):
			# 한 건이라도 형식이 어긋나면 배치 전체가 실패한다.
			# 어느 건이 왜 걸렸는지 남기지 않으면 복원이 조용히 죽는다.
			var err = normalized.get("error", {})
			print("[iap] restore stage=normalize_failed code=%s" % [
				String(err.get("code", "?")) if err is Dictionary else "?"])
			return normalized
		var result: Dictionary = normalized.get("result", {})
		var proof: Dictionary = result.get("proof", {})
		var token := String(proof.get("purchaseToken", ""))
		if seen_tokens.has(token):
			continue
		seen_tokens[token] = true
		purchases.append({
			"productId": String(result.get("productId", "")),
			"proof": proof.duplicate(true),
		})
	print("[iap] restore stage=normalize_done in=%d out=%d" % [
		(raw_purchases as Array).size(), purchases.size()])
	return {"ok": true, "result": {"purchases": purchases}}


func _normalize_purchase(raw_purchase) -> Dictionary:
	if not (raw_purchase is Dictionary):
		return _error("play_billing_response_invalid", "Google Play 구매 항목이 올바르지 않습니다.")
	var product_ids = raw_purchase.get("product_ids", null)
	var product_id := ""
	if product_ids is Array and product_ids.size() == 1:
		product_id = String(product_ids[0]).strip_edges()
	elif product_ids is PackedStringArray and product_ids.size() == 1:
		product_id = String(product_ids[0]).strip_edges()
	else:
		return _error("play_billing_response_invalid", "Google Play 구매의 단일 상품 정보가 올바르지 않습니다.")
	var purchase_token := String(raw_purchase.get("purchase_token", "")).strip_edges()
	var purchase_state := int(raw_purchase.get("purchase_state", 0))
	if not _valid_value(product_id, MAX_PRODUCT_ID_LENGTH) \
			or not _valid_token(purchase_token) \
			or not [PURCHASED, PENDING].has(purchase_state):
		return _error("play_billing_response_invalid", "Google Play 구매 증빙이 올바르지 않습니다.")
	return {
		"ok": true,
		"result": {
			"status": "purchased" if purchase_state == PURCHASED else "pending",
			"productId": product_id,
			"proof": {"purchaseToken": purchase_token},
		},
	}


func _start_owned_query(callback: Callable) -> void:
	if not callback.is_valid():
		return
	if _owned_query_callback.is_valid():
		callback.call(_error("play_billing_busy", "Google Play 구매 상태를 이미 조회하고 있습니다."))
		return
	_owned_query_callback = callback
	_maybe_start_owned_query()


func _maybe_start_owned_query() -> void:
	if not _owned_query_callback.is_valid():
		return
	# 상세 조회가 끝나야 소유 조회를 시작한다. 여기서 조용히 돌아가면
	# 복원은 응답 없이 매달린다. 왜 미뤄졌는지 남긴다.
	if _owned_query_in_flight or _detail_in_flight or not _detail_queue.is_empty():
		print("[iap] restore stage=owned_query_deferred in_flight=%s detail=%s queued=%d" % [
			_owned_query_in_flight, _detail_in_flight, _detail_queue.size()])
		return
	_owned_query_in_flight = true
	_when_ready(func(response: Dictionary) -> void:
		if not bool(response.get("ok", false)):
			_finish_owned_query(response)
			return
		_billing.call("query_purchases", PRODUCT_TYPE_INAPP, false)
	)


func _on_query_purchases_response(response: Dictionary) -> void:
	if _owned_query_callback.is_valid() and _owned_query_in_flight:
		_finish_owned_query(response)


func _finish_owned_query(response: Dictionary) -> void:
	var callback := _owned_query_callback
	_owned_query_callback = Callable()
	_owned_query_in_flight = false
	if callback.is_valid():
		callback.call(response.duplicate(true))
	_pump_detail_queue()


func _finish_purchase(response: Dictionary) -> void:
	var callback := _take_purchase_callback()
	_purchase_product_id = ""
	if callback.is_valid():
		callback.call(response.duplicate(true))


func _take_purchase_callback() -> Callable:
	var callback := _purchase_callback
	_purchase_callback = Callable()
	return callback


func _when_ready(callback: Callable) -> void:
	if not callback.is_valid():
		return
	if _bridge_is_ready():
		_connection_ready = true
		callback.call({"ok": true})
		return
	if _billing == null:
		callback.call(_error("play_billing_unavailable", "Google Play Billing plugin이 없습니다."))
		return
	# 상위 화면의 대기가 끝난 뒤 구매가 뒤늦게 실행되지 않도록 연결 대기를 제한한다.
	if _connection_deadline == 0:
		_connection_deadline = Time.get_ticks_msec() + connection_timeout_ms
	print("[iap] restore stage=awaiting_connection waiters=%d" % (_ready_waiters.size() + 1))
	_ready_waiters.append(callback)
	_start_connection()


func _process(_delta: float) -> void:
	if _connection_deadline != 0 and Time.get_ticks_msec() >= _connection_deadline:
		_on_connect_error(-1, "connection timeout")


func _start_connection() -> void:
	if _billing == null or _connection_started or _bridge_is_ready():
		return
	_connection_started = true
	_billing.call("start_connection")


func _on_connected() -> void:
	_connection_deadline = 0
	_connection_ready = true
	_connection_started = false
	var waiters := _ready_waiters.duplicate()
	_ready_waiters.clear()
	for callback in waiters:
		if callback is Callable and callback.is_valid():
			callback.call({"ok": true})


func _on_disconnected() -> void:
	_on_connect_error(-1, "disconnected")


func _on_connect_error(response_code: int, _debug_message: String) -> void:
	_connection_ready = false
	_connection_started = false
	_connection_deadline = 0
	# Clear the entire pending batch before callbacks can re-enter. Reconnecting
	# must not revive a purchase that its caller already observed as failed.
	_ready_waiters.clear()
	var requests := _detail_queue.duplicate()
	_detail_queue.clear()
	_detail_in_flight = false
	_detail_product_id = ""
	var owned := _owned_query_callback
	_owned_query_callback = Callable()
	_owned_query_in_flight = false
	var response := _billing_error(response_code, "Google Play Billing 연결에 실패했습니다.")
	for request in requests:
		var callback: Callable = request.get("callback", Callable())
		if callback.is_valid(): callback.call(response.duplicate(true))
	if owned.is_valid(): owned.call(response.duplicate(true))
	if _purchase_callback.is_valid(): _finish_purchase(response)


func _bridge_is_ready() -> bool:
	return _billing != null and _billing.has_method("is_ready") and bool(_billing.call("is_ready"))


func _connect_bridge_signal(signal_name: StringName, callback: Callable) -> void:
	if _billing.has_signal(signal_name) and not _billing.is_connected(signal_name, callback):
		_billing.connect(signal_name, callback)


func _billing_error(response_code: int, message: String) -> Dictionary:
	var code := "play_billing_failed"
	if response_code == BILLING_USER_CANCELLED:
		code = "play_billing_cancelled"
	elif response_code == 2 or response_code == 12 or response_code == -1:
		code = "play_billing_unavailable"
	elif response_code == 4:
		code = "play_billing_product_unavailable"
	elif response_code == 5:
		code = "play_billing_developer_error"
	return _error(code, message)


func _nullable_string(value) -> String:
	return "" if value == null else String(value).strip_edges()


func _valid_token(value: String) -> bool:
	return _valid_value(value, MAX_PURCHASE_TOKEN_LENGTH) and not value.contains(" ")


func _valid_value(value: String, max_length: int) -> bool:
	var normalized := value.strip_edges()
	if normalized == "" or normalized.length() > max_length:
		return false
	for index in normalized.length():
		var code := normalized.unicode_at(index)
		if code < 32 or code == 127:
			return false
	return true


func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}


func _exit_tree() -> void:
	if _billing != null and _billing.has_method("end_connection"):
		_billing.call("end_connection")
