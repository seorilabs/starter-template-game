# StoreKit 2 native plugin을 공통 MarketPurchase seam으로 정규화한다.
# 구매와 복원 단계에서는 거래를 finish하지 않는다. 서버가 entitlement를 커밋한 뒤
# complete_purchase가 서버가 지정한 거래 하나만 기기에서 finish한다.
# finish가 실패하거나 늦으면 거래는 미완료로 남고, 다음 시작이나 복귀 때 복원이 다시 검증한다.
extends RefCounted

const APP_STORE := "app_store"
const STATE_REFUNDED := 1
const STATE_PENDING := 2
const STATE_DEFERRED := 3
const STATE_PURCHASED := 4
const STATE_RESTORED := 5
const STATE_CANCELLED := 7
const MAX_RESTORED_PURCHASES := 100
const FINISH_TIMEOUT_SEC := 10.0

## PurchaseFlow watchdog(90초)보다 짧아야 지급 결과를 완료 오류와 함께 돌려줄 수 있다.
var finish_timeout_sec := FINISH_TIMEOUT_SEC
var _store_kit
var _product_ids := PackedStringArray()
var _localized_price_queue: Array = []
var _localized_price_queue_running := false
var _iap_environment := ""
var _environment_waiters: Array[Callable] = []
## transaction_id → {"token": int, "callbacks": Array[Callable]}
var _finish_waiters: Dictionary = {}
var _finish_token := 0


func _init(native_bridge = null, product_ids: Array = []) -> void:
	_store_kit = native_bridge
	if _store_kit == null and ClassDB.class_exists("GodotStoreKit2"):
		_store_kit = ClassDB.instantiate("GodotStoreKit2")
	# 모든 finish 응답이 같은 signal로 온다. 응답의 transaction_id로 요청을 찾는다.
	if _store_kit != null and _store_kit.has_signal("transaction_finished"):
		_store_kit.connect("transaction_finished", _on_transaction_finished)
	for raw_product_id in product_ids:
		var product_id := String(raw_product_id).strip_edges()
		if _valid_value(product_id, 256) and not _product_ids.has(product_id):
			_product_ids.append(product_id)
	_product_ids.sort()


func native_bridge():
	return _store_kit


func iap_environment() -> String:
	return _iap_environment


# 구매 전 계정 참조와 복원 목록도 같은 원장으로 보내야 한다.
# 앱의 설치 환경은 실행 중 고정하고, 실패한 조회는 다음 사용자 동작에서 재시도한다.
func ensure_iap_environment(callback: Callable) -> void:
	if not callback.is_valid():
		return
	if ["production", "sandbox"].has(_iap_environment):
		callback.call({"ok": true})
		return
	if _store_kit == null or not _store_kit.has_method("request_iap_environment"):
		callback.call(_error("storekit_environment_unavailable", "StoreKit 결제 환경을 확인할 수 없습니다."))
		return
	_environment_waiters.append(callback)
	if _environment_waiters.size() == 1:
		_load_iap_environment()


func _load_iap_environment() -> void:
	var response = await _store_kit.request_iap_environment()
	var environment = response.get("environment", "") if response is Dictionary else ""
	var result := _error("storekit_environment_unavailable", "StoreKit 결제 환경을 확인할 수 없습니다.")
	if response is Dictionary and bool(response.get("ok", false)) \
		and environment is String and ["production", "sandbox"].has(environment):
		_iap_environment = environment
		result = {"ok": true}
	var waiters := _environment_waiters.duplicate()
	_environment_waiters.clear()
	for waiter in waiters:
		waiter.call(result.duplicate(true))


func is_market_available(platform: String) -> bool:
	return platform == APP_STORE and _store_kit != null \
		and _store_kit.has_method("purchase_product") \
		and _store_kit.has_method("current_entitlements") \
		and _store_kit.has_method("request_iap_environment")


func is_refund_available(platform: String) -> bool:
	return is_market_available(platform) and _store_kit.has_method("request_refund")


# App Store storefront/locale가 반영된 StoreKit 표시 가격만 반환한다.
func request_localized_price(platform: String, product_id: String, callback: Callable) -> void:
	if not callback.is_valid():
		return
	if platform != APP_STORE or _store_kit == null or not _store_kit.has_method("request_product_info"):
		callback.call(_error("storekit_unavailable", "StoreKit 상품 정보를 사용할 수 없습니다."))
		return
	if not _valid_value(product_id, 256):
		callback.call(_error("storekit_request_invalid", "StoreKit 상품 식별자가 올바르지 않습니다."))
		return
	_localized_price_queue.append({"product_id": product_id, "callback": callback})
	if not _localized_price_queue_running:
		_drain_localized_price_queue()


# native plugin은 모든 상품 조회에 같은 product_info_received signal을 반환한다.
# 동시에 await하면 첫 응답이 여러 요청을 깨울 수 있으므로 한 번에 하나만 bridge에 보낸다.
func _drain_localized_price_queue() -> void:
	_localized_price_queue_running = true
	while not _localized_price_queue.is_empty():
		var request: Dictionary = _localized_price_queue.pop_front()
		var product_id := String(request.get("product_id", ""))
		var callback: Callable = request.get("callback", Callable())
		var info = await _store_kit.request_product_info(product_id)
		if callback.is_valid():
			callback.call(_normalize_localized_price_response(product_id, info))
	_localized_price_queue_running = false


func _normalize_localized_price_response(product_id: String, info) -> Dictionary:
	if not (info is Dictionary):
		return _error("storekit_response_invalid", "StoreKit 상품 정보 응답이 올바르지 않습니다.")
	if String(info.get("error", "")) != "":
		return _error("storekit_product_info_failed", "StoreKit 상품 정보를 가져오지 못했습니다.")
	var received_product_id := String(info.get("product_id", "")).strip_edges()
	var localized_price := String(info.get("localized_price", "")).strip_edges()
	if received_product_id != product_id or not _valid_value(localized_price, 64):
		return _error("storekit_response_invalid", "StoreKit 현지가격 응답이 올바르지 않습니다.")
	return {
		"ok": true,
		"result": {
			"productId": received_product_id,
			"localizedPrice": localized_price,
			# 네이티브가 제공하면 실제 결제 금액·통화를 분석에 쓴다(없으면 0/빈 문자열).
			"priceMicros": int(round(float(info.get("price", 0.0)) * 1_000_000.0)) if (info.get("price", null) is float or info.get("price", null) is int) else int(info.get("price_micros", 0)),
			"currencyCode": String(info.get("currency_code", "")).strip_edges(),
		},
	}


func start_purchase(
	platform: String,
	product_id: String,
	account_references: Dictionary,
	callback: Callable,
) -> void:
	if not callback.is_valid():
		return
	if not is_market_available(platform):
		callback.call(_error("storekit_unavailable", "StoreKit을 사용할 수 없습니다."))
		return
	var app_account_token := String(account_references.get("appStoreAppAccountToken", "")).strip_edges()
	if not _valid_value(product_id, 256) or not _valid_uuid(app_account_token):
		callback.call(_error("storekit_request_invalid", "StoreKit 구매 요청 값이 올바르지 않습니다."))
		return
	ensure_iap_environment(func(response: Dictionary) -> void:
		if not bool(response.get("ok", false)):
			callback.call(response)
			return
		_purchase_async(product_id, app_account_token, callback)
	)


func _purchase_async(product_id: String, app_account_token: String, callback: Callable) -> void:
	var transaction = await _store_kit.purchase_product(product_id, app_account_token, 1)
	if not (transaction is Dictionary):
		callback.call(_error("storekit_response_invalid", "StoreKit 구매 응답이 올바르지 않습니다."))
		return
	var error_message := String(transaction.get("error", ""))
	if error_message != "":
		callback.call(_error("storekit_failed", "StoreKit 구매를 완료하지 못했습니다."))
		return
	var state := int(transaction.get("transaction_state", -1))
	if state == STATE_CANCELLED:
		callback.call({"ok": true, "result": {"status": "cancelled"}})
		return
	if state == STATE_PENDING or state == STATE_DEFERRED:
		callback.call({"ok": true, "result": {"status": "pending"}})
		return
	if state != STATE_PURCHASED and state != STATE_RESTORED:
		callback.call(_error("storekit_failed", "StoreKit 거래가 구매 완료 상태가 아닙니다."))
		return
	if transaction.get("environment", "") != _iap_environment:
		callback.call(_error("environment_mismatch", "StoreKit 거래와 앱의 결제 환경이 다릅니다."))
		return
	var received_product_id := String(transaction.get("product_id", "")).strip_edges()
	var transaction_id := String(transaction.get("transaction_id", "")).strip_edges()
	if received_product_id != product_id or not _valid_transaction_id(transaction_id):
		callback.call(_error("storekit_response_invalid", "StoreKit 거래 식별자가 올바르지 않습니다."))
		return
	callback.call({
		"ok": true,
		"result": {
			"status": "purchased",
			"proof": {"transactionId": transaction_id},
		},
	})


func request_refund(platform: String, product_id: String, callback: Callable) -> void:
	if not callback.is_valid():
		return
	if not is_refund_available(platform):
		callback.call(_error("storekit_unavailable", "StoreKit 환불 요청을 사용할 수 없습니다."))
		return
	if not _valid_value(product_id, 256):
		callback.call(_error("storekit_request_invalid", "StoreKit 상품 식별자가 올바르지 않습니다."))
		return
	_request_refund_async(product_id, callback)


func _request_refund_async(product_id: String, callback: Callable) -> void:
	var response = await _store_kit.request_refund(product_id)
	if not (response is Dictionary):
		callback.call(_error("storekit_response_invalid", "StoreKit 환불 요청 응답이 올바르지 않습니다."))
		return
	if not bool(response.get("ok", false)):
		callback.call(_error("storekit_refund_failed", "StoreKit 환불 요청을 완료하지 못했습니다."))
		return
	var received_product_id := String(response.get("product_id", "")).strip_edges()
	var status := String(response.get("status", "")).strip_edges()
	if received_product_id != product_id or not ["submitted", "cancelled"].has(status):
		callback.call(_error("storekit_response_invalid", "StoreKit 환불 요청 상태가 올바르지 않습니다."))
		return
	callback.call({"ok": true, "result": {"status": status}})


# StoreKit은 거래 정보를 자동으로 갱신한다. 시작·재개·사용자 복원 모두 현재 거래를
# 읽고 서버에서 다시 검증한다. 인증 화면을 띄우는 AppStore.sync()는 일반 복원의
# 선행 조건으로 삼지 않는다. Sandbox reset 재시도에서는 별도 사용자 동작으로 호출한다.
# 등록 상품별 latest 거래에는 환불돼 currentEntitlements에서 사라진 기록도 포함된다.
func restore_purchases(platform: String, callback: Callable, _manual: bool = false) -> void:
	if not callback.is_valid():
		return
	if not is_market_available(platform):
		callback.call(_error("storekit_unavailable", "StoreKit을 사용할 수 없습니다."))
		return
	ensure_iap_environment(func(response: Dictionary) -> void:
		if not bool(response.get("ok", false)):
			callback.call(response)
			return
		_restore_async(callback)
	)


func _restore_async(callback: Callable) -> void:
	var response = await _store_kit.current_entitlements(_product_ids)
	if not (response is Dictionary) or not bool(response.get("ok", false)):
		callback.call(_error("storekit_failed", "StoreKit 거래 복구에 실패했습니다."))
		return
	var transactions = response.get("transactions", null)
	if not (transactions is Array) or transactions.size() > MAX_RESTORED_PURCHASES:
		callback.call(_error("storekit_response_invalid", "StoreKit 복원 응답이 올바르지 않습니다."))
		return
	var purchases: Array = []
	var seen: Dictionary = {}
	for raw_transaction in transactions:
		if not (raw_transaction is Dictionary):
			callback.call(_error("storekit_response_invalid", "StoreKit 복원 거래가 올바르지 않습니다."))
			return
		var transaction: Dictionary = raw_transaction
		var product_id := String(transaction.get("product_id", "")).strip_edges()
		var transaction_id := String(transaction.get("transaction_id", "")).strip_edges()
		var state := int(transaction.get("transaction_state", -1))
		if not [STATE_REFUNDED, STATE_PURCHASED, STATE_RESTORED].has(state):
			continue
		if transaction.get("environment", "") != _iap_environment:
			callback.call(_error("environment_mismatch", "StoreKit 복원 거래와 앱의 결제 환경이 다릅니다."))
			return
		if not _valid_value(product_id, 256) or not _valid_transaction_id(transaction_id):
			callback.call(_error("storekit_response_invalid", "StoreKit 복원 거래 식별자가 올바르지 않습니다."))
			return
		var dedupe_key := "%s:%s" % [product_id, transaction_id]
		if seen.has(dedupe_key):
			continue
		seen[dedupe_key] = true
		purchases.append({
			"productId": product_id,
			"proof": {"transactionId": transaction_id},
		})
	callback.call({"ok": true, "result": {"purchases": purchases}})


func complete_purchase(platform: String, completion_action: Dictionary, callback: Callable) -> void:
	if not callback.is_valid():
		return
	var action := String(completion_action.get("action", ""))
	if platform != APP_STORE or _store_kit == null:
		callback.call(_error("storekit_unavailable", "StoreKit 을 사용할 수 없습니다."))
		return
	if action == "app_store_sync_after_sandbox_reset":
		if not _store_kit.has_method("sync"):
			callback.call(_error("storekit_sync_unavailable", "StoreKit 구매 내역 동기화를 사용할 수 없습니다."))
			return
		_sync_after_sandbox_reset(callback)
		return
	if action == "app_store_finish_transaction" or action == "none":
		# PurchaseFlow는 서버가 지급을 커밋한 verified 응답 뒤에만 여기로 온다.
		# none은 서버가 App Store Server API로 이미 완료했을 수 있어 기기에서는 not_found가 정상이다.
		var transaction_id := String(completion_action.get("orderId", "")).strip_edges()
		if transaction_id.is_empty() or not _store_kit.has_method("finish_transaction") \
			or not _store_kit.has_signal("transaction_finished"):
			callback.call(_error("storekit_finish_unavailable", "StoreKit 거래 완료(finish)를 사용할 수 없습니다."))
			return
		if not _valid_transaction_id(transaction_id):
			callback.call(_error("storekit_request_invalid", "StoreKit 완료 거래 식별자가 올바르지 않습니다."))
			return
		_finish_transaction(transaction_id, callback)
		return
	callback.call(_error("storekit_completion_unsupported", "지원하지 않는 완료 동작입니다."))


# 같은 거래의 동시 요청은 네이티브 호출 한 번으로 합친다. 시간 초과는 실패로 알리지만
# 네이티브 요청은 취소하지 않는다(서버 커밋 뒤라 늦게 끝나도 안전). 늦은 응답은 버린다.
func _finish_transaction(transaction_id: String, callback: Callable) -> void:
	if _finish_waiters.has(transaction_id):
		(_finish_waiters[transaction_id].callbacks as Array).append(callback)
		return
	_finish_token += 1
	var token := _finish_token
	_finish_waiters[transaction_id] = {"token": token, "callbacks": [callback]}
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.create_timer(finish_timeout_sec).timeout.connect(func() -> void:
			_resolve_finish(transaction_id, token, _error("storekit_finish_timeout", "StoreKit 거래 완료 응답이 없습니다."))
		)
	_store_kit.call("finish_transaction", transaction_id)


func _on_transaction_finished(response) -> void:
	if not (response is Dictionary):
		return
	var transaction_id := String(response.get("transaction_id", "")).strip_edges()
	if not _finish_waiters.has(transaction_id):
		return
	_resolve_finish(transaction_id, int(_finish_waiters[transaction_id].token), _normalize_finish_response(transaction_id, response))


func _resolve_finish(transaction_id: String, token: int, result: Dictionary) -> void:
	var entry = _finish_waiters.get(transaction_id, null)
	if entry == null or int(entry.token) != token:
		return
	_finish_waiters.erase(transaction_id)
	for waiter in entry.callbacks:
		if (waiter as Callable).is_valid():
			waiter.call(result.duplicate(true))


# ok=true는 finished(지금 완료)와 not_found(미완료 목록에 없음, 이미 완료)를 구분해 돌려준다.
func _normalize_finish_response(transaction_id: String, response: Dictionary) -> Dictionary:
	if not bool(response.get("ok", false)):
		var failed := _error("storekit_finish_failed", "StoreKit 거래를 완료하지 못했습니다.")
		failed.error["reason"] = String(response.get("error", "")).left(64)
		return failed
	var status := String(response.get("status", ""))
	if not ["finished", "not_found"].has(status):
		return _error("storekit_response_invalid", "StoreKit 거래 완료 응답이 올바르지 않습니다.")
	return {"ok": true, "result": {"transactionId": transaction_id, "status": status}}


func _sync_after_sandbox_reset(callback: Callable) -> void:
	var error_message = await _store_kit.sync()
	if not (error_message is String):
		callback.call(_error("storekit_response_invalid", "StoreKit 동기화 응답이 올바르지 않습니다."))
		return
	if String(error_message) != "":
		callback.call(_error("storekit_sync_failed", "StoreKit 구매 내역 동기화에 실패했습니다."))
		return
	callback.call({"ok": true})


func _valid_uuid(value: String) -> bool:
	var regex := RegEx.new()
	return regex.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$") == OK \
		and regex.search(value) != null


func _valid_transaction_id(value: String) -> bool:
	if not _valid_value(value, 128):
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		if code < 48 or code > 57:
			return false
	return true


func _valid_value(value: String, max_length: int) -> bool:
	return value != "" and value.length() <= max_length and not _has_control(value)


func _has_control(value: String) -> bool:
	for index in value.length():
		var code := value.unicode_at(index)
		if code < 32 or code == 127:
			return true
	return false


func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}
