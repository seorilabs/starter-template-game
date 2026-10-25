extends SceneTree
const State = preload("res://addons/seorilabs_game/flow/state.gd")
const Cloud = preload("res://game/adapters/cloud_progress.gd")
const Store = preload("res://addons/seorilabs_platform/core/atomic_json_store.gd")
var failures: Array[String] = []
var paths: Array[String] = []
class FakeIdentity:
	extends Node
	var uid := ""
	func ensure_identity() -> Dictionary: return {"success": true, "uid": uid, "id_token": "dev-boundary-proof"}
class CloudBoundary:
	extends Cloud
	var responses: Array[Dictionary] = []
	var requests: Array[Dictionary] = []
	var delay_next_patch := false
	signal release_patch
	func _request(method: HTTPClient.Method, payload: Dictionary = {}, revision: String = "") -> Dictionary:
		requests.append({"uid": uid, "method": method, "payload": payload.duplicate(true), "revision": revision})
		var result: Dictionary = responses.pop_front()
		if method == HTTPClient.METHOD_PATCH and delay_next_patch:
			delay_next_patch = false
			await release_patch
		return result
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var auth := FakeIdentity.new()
	root.add_child(auth)
	var state := State.new("user://unused-cloud-probe.json")
	var cloud := CloudBoundary.new()
	root.add_child(cloud)
	cloud.configure(auth, state, "demo-boundary")
	var suffix := Crypto.new().generate_random_bytes(8).hex_encode()
	cloud.privacy_marker = "user://cloud-privacy-probe-" + suffix
	auth.uid = "dev-a-" + suffix
	cloud.responses = [{"ok": false, "status": 404}]
	var loaded: Dictionary = await cloud.restore(auth.uid)
	paths.append(state.path); paths.append(cloud._journal_path())
	check(loaded.ok and cloud.progress_ready and state.data.coins == 0, "new account requires a confirmed missing document")
	cloud.responses = [{"ok": true, "data": {"updateTime": "revision-1"}}]
	check(state.accept_consent(true), "local save commits")
	check(cloud.requests[-1].revision == "" and cloud.requests[-1].payload.mail.is_empty(), "first write uses create precondition and excludes mailbox")
	check(not cloud.has_pending() and cloud.status == "saved", "server confirmation clears outbox")
	# A completed write whose response was lost can be recognized on restart.
	var snapshot: Dictionary = cloud._snapshot()
	check(Store.write(cloud._journal_path(), {"uid":auth.uid,"revision":"older","payload":snapshot}), "persist uncertain outcome")
	cloud.responses = [{"ok":true,"data":{"updateTime":"revision-2","fields":{"payload":{"stringValue":JSON.stringify(snapshot)}}}}]
	loaded = await cloud.restore(auth.uid)
	check(loaded.ok and not cloud.has_pending(), "same confirmed payload resolves uncertain write")
	# A different remote revision must never be overwritten by stale local progress.
	var local := snapshot.duplicate(true); local.coins = 99
	check(Store.write(cloud._journal_path(), {"uid":auth.uid,"revision":"revision-1","payload":local}), "persist local progress")
	cloud.responses = [{"ok":true,"data":{"updateTime":"revision-2","fields":{"payload":{"stringValue":JSON.stringify(snapshot)}}}}]
	loaded = await cloud.restore(auth.uid)
	check(not loaded.ok and not cloud.progress_ready and cloud.status == "cloud_conflict", "concurrent device change fails closed")
	cloud.responses = [{"ok":true,"data":{"updateTime":"revision-2","fields":{"payload":{"stringValue":JSON.stringify(snapshot)}}}},{"ok":true,"data":{"updateTime":"revision-3"}}]
	var resolved: Dictionary = await cloud.resolve_conflict(true)
	paths.append(cloud._journal_path() + ".conflict-backup")
	check(resolved.ok and state.data.coins == 99 and cloud.requests[-1].revision == "revision-2", "explicit device choice preserves backup and uses fresh precondition")
	check(FileAccess.file_exists(cloud._journal_path()+".conflict-backup"), "conflict keeps local backup")
	cloud.responses = [{"ok":false,"status":404}]
	await cloud.restore(auth.uid)
	cloud.delay_next_patch = true
	cloud.responses = [{"ok":true,"data":{"updateTime":"old-response"}}]
	check(state.skip_tutorial(), "start old UID write")
	auth.uid = "dev-b-" + suffix
	cloud.responses = [{"ok":false,"status":404}]
	await cloud.restore(auth.uid)
	paths.append(state.path);paths.append(cloud._journal_path())
	cloud.release_patch.emit()
	await process_frame
	check(cloud.uid == auth.uid and cloud._revision == "" and state.data.tutorial.status == "active", "late old UID response cannot alter new save")
	cloud.detach()
	cloud.queue_free();auth.queue_free()
	for path in paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await process_frame
	if not failures.is_empty():
		for label in failures: push_error(label)
		quit(1)
	else:
		print("Cloud ownership, conflict, lost response and account switch contracts passed")
		quit(0)
