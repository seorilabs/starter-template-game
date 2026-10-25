extends SceneTree
const Commerce = preload("res://game/adapters/platform_commerce.gd")
var failures: Array[String] = []
class PlatformBoundary extends Node:
	var account_id := ""
	var generation := 1
	var wallet_ok := false
	var active: Array = []
	var defer_verify := false
	var verify_callback: Callable
	func current_session() -> Dictionary: return {"platformUserId": account_id}
	func authentication_generation() -> int: return generation
	func is_signed_in() -> bool: return true
	func is_anonymous() -> bool: return false
	func account_references(callback: Callable) -> void: callback.call({"ok":true,"result":{"appAccountToken":"isolated-account-reference"}})
	func verify_purchase(_proof: Dictionary, callback: Callable) -> void:
		if defer_verify: verify_callback = callback
		else: callback.call({"ok":true,"result":{"status":"verified","completion":{"action":"finish"}}})
	func get_wallet(callback: Callable) -> void: callback.call({"ok":wallet_ok,"result":{"balances":{"starter_test_ticket_1":1}}})
	func list_entitlements(callback: Callable) -> void: callback.call({"ok":true,"result":{"entitlements":active.duplicate()}})
class MarketBoundary extends RefCounted:
	var finishes := 0
	var purchases := 0
	func is_market_available(_platform: String) -> bool: return true
	func request_localized_price(_platform: String, _id: String, callback: Callable) -> void: callback.call({"ok":true,"result":{"localizedPrice":"$0.99"}})
	func start_purchase(_platform: String, _id: String, _references: Dictionary, callback: Callable) -> void:
		purchases += 1
		callback.call({"ok":true,"result":{"status":"purchased","proof":{"transactionId":"isolated-purchase-"+str(purchases)}}})
	func complete_purchase(_platform: String, _completion: Dictionary, callback: Callable) -> void:
		finishes += 1
		callback.call({"ok":true})
	func restore_purchases(_platform: String, callback: Callable, _refresh: bool) -> void: callback.call({"ok":true,"result":{"purchases":[]}})
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var client := PlatformBoundary.new()
	root.add_child(client)
	client.account_id = "commerce-contract-" + Crypto.new().generate_random_bytes(8).hex_encode()
	var market := MarketBoundary.new()
	var port := Commerce.new()
	port.sdk = client;port.market = market;port.platform = "app_store"
	var replies: Array[Dictionary] = []
	port.purchase("starter_test_ticket_1",func(result: Dictionary) -> void: replies.append(result))
	check(replies.size()==1 and replies[0].state=="fulfilling" and market.finishes==0, "store and verify callbacks cannot finish before the server wallet")
	var paths: Array[String] = [port._path()]
	client.wallet_ok = true
	port.restore(func(result: Dictionary) -> void: replies.append(result))
	check(replies[-1].state=="restored" and market.finishes==1 and not port.has_pending() and port.wallet.starter_test_ticket_1==1, "restore retries the durable proof and finishes once after server state")
	port.purchase("starter_badge",func(result: Dictionary) -> void: replies.append(result))
	check(replies[-1].state=="fulfilling" and market.finishes==1, "badge delivery requires its active server entitlement")
	client.active = ["starter_badge"]
	port.restore(func(result: Dictionary) -> void: replies.append(result))
	check(replies[-1].state=="restored" and market.finishes==2, "verified permanent entitlement completes delivery")
	port.catalog(func(result: Dictionary) -> void: replies.append(result))
	check(replies[-1].products[0].title=="Test Ticket (1)" and not replies[-1].products[1].available and replies[-1].products[1].localized.ko.title.contains("보유"), "catalog names are localized and an owned permanent product cannot be bought again")
	client.defer_verify = true
	port.purchase("starter_test_ticket_1",func(result: Dictionary) -> void: replies.append(result))
	check(client.verify_callback.is_valid(), "hold an old-account verification response")
	client.generation += 1;client.account_id += "-new"
	client.verify_callback.call({"ok":true,"result":{"status":"verified","completion":{"action":"finish"}}})
	await process_frame
	port.capabilities()
	paths.append(port._path())
	check(market.finishes==2 and port.wallet.is_empty() and port.entitlements.is_empty(), "late old-account verification cannot finish or populate the new account")
	port.purchase("starter_test_ticket_1",func(result: Dictionary) -> void: replies.append(result))
	client.queue_free()
	await process_frame
	await process_frame
	check(replies[-1].state=="failed" and market.finishes==2, "removing the service owner cancels pending verification safely")
	await process_frame
	for path in paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not failures.is_empty():
		for failure in failures: push_error(failure)
		quit(1)
	else:
		print("Commerce server delivery, restore, permanent ownership and account generation passed; market SDK is a boundary substitute")
		quit(0)
