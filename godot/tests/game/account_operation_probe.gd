extends SceneTree
const State = preload("res://addons/seorilabs_game/flow/state.gd")
const Accounts = preload("res://game/adapters/platform_accounts.gd")
const SDK = preload("res://addons/seorilabs_platform/platform_client.gd")
const Boundaries = preload("res://tests/game/platform_boundaries.gd")

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "user://account-operation-" + Crypto.new().generate_random_bytes(8).hex_encode()
	var state := State.new(path + ".json")
	state.load_state()
	var service := Boundaries.Service.new()
	service.prefix = "qa-busy-" + Crypto.new().generate_random_bytes(8).hex_encode()
	service.uid = service.prefix + "-old"
	var client := SDK.new()
	client._transport = service
	client.add_child(service)
	root.add_child(client)
	client.configure({"app_id": "isolated-account-operation", "base_url": "https://unused.invalid", "presence_enabled": false})
	client.set_analytics_enabled(false)
	client._store_session(service.session())
	var accounts := Accounts.new()
	root.add_child(accounts)
	var options: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/platform.json"))
	accounts.configure(client, state, options, {"native": Boundaries.NativeIdentity.new(), "identity": Boundaries.Firebase.new(), "cloud": Boundaries.Storage.new(), "identity_path": path + ".identity", "receipt_path": path + ".receipt"})
	accounts.operation_blocker = func() -> bool: return true
	var generation: int = client.authentication_generation()
	var responses: Array[Dictionary] = []
	await accounts.execute("refresh", {}, func(result: Dictionary): responses.append(result))
	var passed: bool = responses.size() == 1 and responses[0].get("code") == "account_busy" and client.authentication_generation() == generation and service.seen.is_empty()
	accounts.queue_free()
	client.queue_free()
	await process_frame
	print("Account refresh preserves an in-flight transaction identity: " + str(passed))
	quit(0 if passed else 1)
