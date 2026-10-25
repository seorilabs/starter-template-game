extends SceneTree
const Ads = preload("res://game/adapters/platform_ads.gd")
var failures: Array[String] = []
class IdentityBoundary extends Node:
	func ensure_identity() -> Dictionary: return {"success": false}
class NativeBoundary extends Node:
	var unit := ""
	var loads := 0
	func available() -> bool: return true
	func busy() -> bool: return false
	func prepare() -> Dictionary: return {"ok": true}
	func load_ad() -> Dictionary:
		loads += 1
		return {"ok": true}
	func show_ad(_ssv: Dictionary) -> Dictionary: return {"ok": true, "earned": true}
class PlatformBoundary extends Node:
	var policy := false
	var remote := "accepted"
	var fail_ack := true
	var account_id := "isolated-ad-owner-a"
	var generation := 1
	var creates := 0
	var acks := 0
	func is_signed_in() -> bool: return true
	func authentication_generation() -> int: return generation
	func current_session() -> Dictionary: return {"platformUserId": account_id}
	func sign_in(_proof: Dictionary, callback: Callable) -> void: callback.call({"ok": false})
	func get_ads_policy(callback: Callable) -> void: callback.call({"ok": true, "result": {"appUsesAds": policy, "adsEnabled": true}})
	func create_reward_claim(claim: Dictionary, callback: Callable) -> void:
		creates += 1
		callback.call({"ok": true, "result": {"claimId": claim.requestId, "admobSsv": {"customData": "isolated-ad-proof", "userId": account_id}}})
	func get_reward_claim(_id: String, callback: Callable) -> void: callback.call({"ok": true, "result": {"state": remote, "assurance": "server_verified" if remote == "confirmed" else "pending"}})
	func ack_reward_claim(_id: String, callback: Callable) -> void:
		acks += 1
		callback.call({"ok": not fail_ack})
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var client := PlatformBoundary.new()
	var identity := IdentityBoundary.new()
	root.add_child(client);root.add_child(identity)
	var ads := Ads.new()
	root.add_child(ads)
	ads.path_prefix = "user://ads-contract-" + Crypto.new().generate_random_bytes(8).hex_encode() + "-"
	ads.driver = NativeBoundary.new()
	ads.configure(client, identity, {})
	await ads.watch()
	check(client.creates == 0 and ads.driver.loads == 0 and ads.status == "unavailable", "server policy blocks before native load")
	client.policy = true
	await ads.watch()
	check(ads.status == "awaiting_server" and ads.snapshot().confirmed == 0 and client.acks == 0, "native earned callback cannot confirm or grant a reward")
	client.remote = "confirmed"
	await ads.refresh()
	check(ads.snapshot().confirmed == 1 and ads.status == "ack_pending" and ads.snapshot().pending, "confirmed receipt is durable before ack")
	client.fail_ack = false
	await ads.refresh()
	await ads.refresh()
	check(ads.snapshot().confirmed == 1 and not ads.snapshot().pending and client.acks == 2, "ack retry does not count or settle twice")
	var paths: Array[String] = [ads._path()]
	client.account_id = "isolated-ad-owner-b";client.generation += 1
	check(ads.snapshot().confirmed == 0 and not ads.snapshot().pending, "another account cannot inherit a receipt")
	paths.append(ads._path())
	ads.queue_free();client.queue_free();identity.queue_free()
	await process_frame
	for path in paths:
		for suffix in ["", ".claims", ".acks"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	if not failures.is_empty():
		for failure in failures: push_error(failure)
		quit(1)
	else:
		print("Ad policy, server verification, durable ack and account isolation passed; native SDK is a boundary substitute")
		quit(0)
