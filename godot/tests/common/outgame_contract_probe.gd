extends SceneTree

# 예제 화면에 버튼이 없어 E2E 여정으로 닿을 수 없는 계약을 확인한다(결제 상태·복원·저장 충돌·팝업 순서·잘못된 설정 값).
# 게임이 결제·복원 화면을 붙이면 그 흐름은 E2E 여정으로 옮긴다.
#   godot --headless --path . --script tests/common/outgame_contract_probe.gd
# 실패하면 exit 1.

const State := preload("res://addons/seorilabs_game/flow/state.gd")
const Services := preload("res://addons/seorilabs_game/services/services.gd")
const Popups := preload("res://addons/seorilabs_game/flow/popup_queue.gd")


class FakeSDK extends Node:
	var calls: Array = []

	func verify_purchase(_proof: Dictionary, callback: Callable) -> void:
		calls.append("verify_purchase")
		callback.call({"ok": false, "pending": true})

	func list_entitlements(callback: Callable) -> void:
		calls.append("list_entitlements")
		callback.call({"ok": true, "result": {"entitlements": []}})


var failures: Array[String] = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


# 람다는 바깥 지역 변수에 다시 대입할 수 없으므로 같은 사전을 비우고 채운다.
func _keep(target: Dictionary, result: Dictionary) -> void:
	target.clear()
	target.merge(result)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dir := "user://outgame-contract-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	var popups = Popups.new()
	for kind in ["notice", "reward", "maintenance", "consent", "consent"]:
		popups.enqueue(kind)
	check(popups.next().kind == "consent" and popups.items.size() == 3, "popup priority or duplicate")
	popups.dismiss()
	check(popups.next().kind == "maintenance", "popup sequencing")

	var services = Services.new()
	root.add_child(services)
	check(services.commerce_state({"cancelled": true}) == "cancelled", "purchase cancel state")
	check(services.commerce_state({"pending": true}) == "pending", "purchase pending state")
	check(services.commerce_state({"ok": false}) == "failed", "purchase failure state")
	var response: Dictionary = {}
	services.purchase({}, func(result: Dictionary) -> void: _keep(response, result))
	check(response.get("code", "") == "commerce_unsupported", "local purchase must be unsupported")
	services.mode = "server"
	services.claim("local-welcome", func(result: Dictionary) -> void: _keep(response, result))
	check(response.get("code", "") == "service_unconnected", "server claim without SDK must not grant locally")
	var sdk := FakeSDK.new()
	root.add_child(sdk)
	services.configure(sdk, func() -> Dictionary: return {})
	services.purchase({}, func(result: Dictionary) -> void: _keep(response, result))
	check(services.commerce_state(response) == "pending" and sdk.calls.back() == "verify_purchase", "purchase provider state lost")
	services.restore(func(result: Dictionary) -> void: _keep(response, result))
	check(response.get("ok", false) and sdk.calls.back() == "list_entitlements", "restore not connected to the SDK")

	var state = State.new(dir + "/state.json")
	check(state.load_state(), "fresh load")
	var conflict: Dictionary = state.data.duplicate(true)
	conflict.coins += 1
	var merged: Dictionary = state.merge_remote_save(conflict)
	check(not merged.ok and merged.get("localPreserved", false) and state.data.coins == 0, "save conflict overwrote local progress")
	check(not state.setting("music", "invalid") and state.data.settings.music == true, "invalid setting value persisted")
	check(not state.action_completed("unrelated"), "an unrelated action advanced the guide")

	if failures.is_empty():
		print("Outgame contract probe passed: popups, commerce states, restore, conflict, invalid setting")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
