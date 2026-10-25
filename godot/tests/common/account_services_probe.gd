extends SceneTree
const Services = preload("res://addons/seorilabs_game/services/services.gd")

class Client extends Node:
	var sign_in_calls := 0
	var maintenance := false
	var blocked := false
	var claim_ok := true
	func claim_inbox(_id: String, callback: Callable) -> void: callback.call({"ok": claim_ok})
	func claim_inbox_batch(_ids: Array, callback: Callable) -> void: callback.call({"ok": claim_ok})
	func is_under_maintenance() -> bool: return maintenance
	func is_sdk_blocked() -> bool: return blocked
	func update_gate_state() -> Dictionary: return {"kind": "ok"}
	func sign_in(_credential: Dictionary, callback: Callable) -> void:
		sign_in_calls += 1
		callback.call({"ok": false, "code": "credential_invalid"})

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var client := Client.new()
	root.add_child(client)
	var services := Services.new()
	root.add_child(services)
	services.configure(client, func() -> Dictionary: return {})
	var responses: Array[Dictionary] = []
	services.initialize(func(response: Dictionary) -> void: responses.append(response))
	if client.sign_in_calls != 0 or responses.size() != 1 or responses[0].get("status") != "account_required":
		push_error("Signed-out startup must wait for the create-account button without sending an empty credential")
		quit(1)
		return
	for code in ["maintenance", "update_required"]:
		client.maintenance = code == "maintenance"
		client.blocked = code == "update_required"
		responses.clear()
		services.initialize(func(response: Dictionary) -> void: responses.append(response))
		if responses.size() != 1 or responses[0].get("ok", true) or responses[0].get("code") != code or client.sign_in_calls != 0:
			push_error("Signed-out startup must preserve cached maintenance and update gates")
			quit(1)
			return
	var notices: Array[bool] = []
	services.server_inventory_changed.connect(func() -> void: notices.append(true))
	for accepted in [true, false]:
		client.claim_ok = accepted
		services.claim("isolated-mail", func(_result: Dictionary) -> void: pass)
		services.claim_batch(["isolated-mail"], func(_result: Dictionary) -> void: pass)
	if notices.size() != 2:
		push_error("Inventory refresh is emitted only after confirmed mailbox claims")
		quit(1)
		return
	services.queue_free()
	client.queue_free()
	print("Account-required startup passed")
	quit(0)
