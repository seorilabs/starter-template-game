extends SceneTree
const Accounts = preload("res://addons/seorilabs_game/services/accounts.gd")

class Port extends RefCounted:
	var current := {"uid": "first"}
	var callbacks: Array[Callable] = []
	func capabilities() -> Dictionary: return {"create": true, "recover": true, "logout": true}
	func snapshot() -> Dictionary: return current.duplicate(true)
	func execute(_action: String, _payload: Dictionary, callback: Callable) -> void: callbacks.append(callback)

func _initialize() -> void:
	var port := Port.new()
	var accounts := Accounts.new()
	accounts.port = port
	accounts.refresh()
	accounts.perform("recover", {"expectedUid": "second"})
	accounts.perform("create")
	if port.callbacks.size() != 1 or accounts.status != "busy":
		_fail("A second tap must not open a concurrent account operation")
		return
	accounts.invalidate()
	port.callbacks[0].call({"ok": true, "account": {"uid": "second"}})
	if accounts.connected():
		_fail("An old recovery callback must not sign in after logout")
		return
	accounts.perform("create")
	port.current = {"uid": "third", "platformUserId": "puid-third", "supportCode": "SK-EXAMPLE"}
	port.callbacks[1].call({"ok": true, "account": port.current})
	if accounts.details.get("uid") != "third" or accounts.status != "ready":
		_fail("A confirmed account must expose its public identifiers")
		return
	accounts.perform("recover")
	port.callbacks[2].call({"ok": false, "code": "provider_cancelled"})
	if accounts.details.get("uid") != "third" or accounts.status != "failed" or accounts.error != "provider_cancelled":
		_fail("Cancelled recovery must preserve the current account")
		return
	print("Account concurrency, cancellation and stale callback contracts passed")
	port.callbacks.clear()
	accounts.port = null
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
