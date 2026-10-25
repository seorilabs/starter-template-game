extends SceneTree
const State = preload("res://addons/seorilabs_game/flow/state.gd")
const Accounts = preload("res://game/adapters/platform_accounts.gd")
const Store = preload("res://addons/seorilabs_platform/core/atomic_json_store.gd")
class CloudBoundary:
	extends Node
	var progress_ready := true
	var status := "saved"
	var privacy_marker := ""
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var prefix := "user://legacy-probe-" + Crypto.new().generate_random_bytes(8).hex_encode()
	var port := Accounts.new()
	var state := State.new(prefix+"-current.json")
	state.load_state()
	var old: Dictionary = state.defaults()
	old.coins = 10;old.grants["tutorial-first"] = 10
	old.mail[0].title = "Local example must not become server mail"
	port.state = state
	port.legacy_path = prefix+"-legacy.json"
	port.migration_path = prefix+"-owner.json"
	var cloud := CloudBoundary.new();port.cloud = cloud;cloud.privacy_marker = prefix+"-privacy"
	var failures: Array[String] = []
	if not Store.write(port.legacy_path, old): failures.append("legacy fixture write failed")
	port._migrate_legacy("dev-first-uid")
	if state.data.coins != 10 or not state.data.mail.is_empty(): failures.append("first import must keep game progress and exclude example mail")
	var marker: Dictionary = Store.read_dictionary(port.migration_path)
	if not marker.ok or marker.value.get("uid") != "dev-first-uid": failures.append("migration target must be persisted first")
	state.data = state.defaults()
	port._migrate_legacy("dev-other-uid")
	if state.data.coins != 0: failures.append("legacy progress leaked into a second UID")
	port._migrate_legacy("dev-first-uid")
	if state.data.coins != 10: failures.append("same UID cannot resume after interrupted upload")
	for path in [state.path,port.legacy_path,port.migration_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	port.cloud = null
	cloud.free();port.free()
	for label in failures:push_error(label)
	if failures.is_empty():print("Legacy progress imports into only the first confirmed UID; local mail excluded")
	quit(0 if failures.is_empty() else 1)
