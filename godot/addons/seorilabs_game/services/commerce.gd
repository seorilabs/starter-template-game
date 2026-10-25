extends RefCounted
signal changed
var port: RefCounted
var store: RefCounted
var state := "idle"
var products: Array = []
var catalog_state := "unavailable"
var operation := "purchase"
var transaction := ""
var identity := "local"
var _generation := 0
var _operation_generation := 0

func change_identity(value: String) -> void:
	if value == identity:
		return
	_generation += 1
	_operation_generation += 1
	identity = value
	transaction = ""
	state = "idle"
	products = []
	catalog_state = "unavailable"

func _save_key() -> String:
	return "current:" + identity

func available() -> bool:
	return port != null and port.capabilities().get("purchase", false)

func catalog() -> void:
	_generation += 1
	var generation := _generation
	products = []
	if not available():
		catalog_state = "unavailable"
		changed.emit()
		return
	catalog_state = "loading"
	changed.emit()
	port.catalog(func(result: Dictionary) -> void:
		if generation != _generation:
			return
		products = result.get("products", []) if result.get("ok", false) else []
		catalog_state = "available" if result.get("ok", false) else "failed"
		changed.emit()
	)

func buy(product_id: String) -> void:
	if not available() or state in ["store_open", "pending", "verifying", "fulfilling"] or catalog_state != "available":
		return
	var found := false
	for product in products:
		if product.get("id", "") == product_id and not str(product.get("price", "")).is_empty() and product.get("available", false):
			found = true
	if not found:
		return
	operation = "purchase"
	_operation_generation += 1
	var generation := _operation_generation
	state = "store_open"
	changed.emit()
	port.purchase(product_id, func(result: Dictionary) -> void:
		if generation == _operation_generation:
			_receive(result)
	)

func _receive(result: Dictionary) -> void:
	var received := str(result.get("state", "failed"))
	# 구매창의 ok만으로 지급 완료로 바꾸지 않는다.
	if received == "completed" and not result.get("fulfilled", false):
		received = "verifying"
	if received not in ["cancelled", "pending", "verifying", "fulfilling", "completed", "failed", "revoked"]:
		received = "failed"
	if state == "completed" and received not in ["completed", "revoked"]:
		return
	if state == "revoked" and received != "revoked":
		return
	transaction = str(result.get("transactionId", transaction))
	state = received
	if not store.remember_ui("commerce", _save_key(), {"state": state, "transactionId": transaction}):
		state = "failed"
	changed.emit()

func reconcile() -> void:
	var saved: Dictionary = store.data.ui.commerce.get(_save_key(), {})
	transaction = str(saved.get("transactionId", transaction))
	if not available() or transaction.is_empty():
		return
	state = "verifying"
	operation = "purchase"
	_operation_generation += 1
	var generation := _operation_generation
	changed.emit()
	port.reconcile(transaction, func(result: Dictionary) -> void:
		if generation == _operation_generation:
			_receive(result)
	)

func restore() -> void:
	if port == null or not port.capabilities().get("restore", false):
		return
	if state in ["store_open", "pending", "verifying", "fulfilling", "checking"]:
		return
	operation = "restore"
	_operation_generation += 1
	var generation := _operation_generation
	state = "checking"
	changed.emit()
	port.restore(func(result: Dictionary) -> void:
		if generation != _operation_generation:
			return
		state = str(result.get("state", "failed"))
		if state not in ["none", "restored", "partial", "failed"]:
			state = "failed"
		changed.emit()
	)
