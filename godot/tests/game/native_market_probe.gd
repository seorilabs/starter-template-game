extends SceneTree
const Market = preload("res://game/adapters/android_play_billing_market.gd")
const Ads = preload("res://game/adapters/admob_native.gd")
var failures: Array[String] = []

class Billing extends Node:
	signal connected
	signal disconnected
	signal connect_error(code: int, message: String)
	signal query_product_details_response(response: Dictionary)
	signal query_purchases_response(response: Dictionary)
	signal on_purchase_updated(response: Dictionary)
	var connection_ready :=  false
	var queries: Array[String] = []
	var launches: Array[String] = []
	func is_ready() -> bool: return connection_ready
	func start_connection() -> void: pass
	func end_connection() -> void: pass
	func set_obfuscated_account_id(_value: String) -> void: pass
	func query_purchases(_type: int, _manual: bool) -> void: pass
	func query_product_details(ids: PackedStringArray, _type: int) -> void:
		queries.append(ids[0])
		query_product_details_response.emit({"response_code": 0, "product_details": [{"product_id": ids[0], "one_time_purchase_offer_details_list": [{"formatted_price": "$0.99"}]}]})
	func purchase(id: String, _option: String, _offer: String, _personalized: bool) -> Dictionary:
		launches.append(id)
		return {"response_code": 0}

class NativeAd extends RewardedAd:
	func _init() -> void: super(1)
	func show(_listener := OnUserEarnedRewardListener.new()) -> void: pass

class TimeoutAds extends Ads:
	func _wait(_answer: Array, _duration: int) -> void:
		await get_tree().process_frame

func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)

func _run() -> void:
	var bridge := Billing.new()
	var market := Market.new(bridge)
	root.add_child(market)
	check(bridge.get_parent() == market, "native bridge is attached during construction")
	bridge.connection_ready = true
	market.request_localized_price("google_play", "ticket", func(_r: Dictionary): pass)
	market.request_localized_price("google_play", "badge", func(_r: Dictionary): pass)
	market.start_purchase("google_play", "ticket", {"googlePlayObfuscatedAccountId": "synthetic"}, func(_r: Dictionary): pass)
	check(bridge.queries == ["ticket", "badge", "ticket"] and bridge.launches == ["ticket"], "purchase refreshes the selected native ProductDetails")
	bridge.on_purchase_updated.emit({"response_code": 1})
	bridge.connection_ready = false
	var failed: Array[Dictionary] = []
	market.request_localized_price("google_play", "uncached", func(r: Dictionary): failed.append(r))
	market.start_purchase("google_play", "badge", {"googlePlayObfuscatedAccountId": "synthetic"}, func(r: Dictionary): failed.append(r))
	bridge.disconnected.emit()
	bridge.connection_ready = true
	bridge.connected.emit()
	check(failed.size() == 2 and not failed[0].ok and not failed[1].ok and bridge.launches.size() == 1, "disconnect fails the whole pending batch; reconnect cannot revive the purchase")
	bridge.connection_ready = false
	market.connection_timeout_ms = 1
	var timed_out: Array[Dictionary] = []
	market.start_purchase("google_play", "badge", {"googlePlayObfuscatedAccountId": "synthetic"}, func(r: Dictionary): timed_out.append(r))
	market._connection_deadline = Time.get_ticks_msec() - 1
	market._process(0)
	bridge.connection_ready = true
	bridge.connected.emit()
	check(timed_out.size() == 1 and not timed_out[0].ok and bridge.launches.size() == 1, "connection timeout cannot launch a late purchase")
	market.free()
	var ads := TimeoutAds.new()
	root.add_child(ads)
	var ad := NativeAd.new()
	ads._ad = ad
	var previous := AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, false)
	var answer: Dictionary = await ads.show_ad({"custom_data": "synthetic", "user_id": "synthetic"})
	check(answer.code == "ad_close_timeout" and not AudioServer.is_bus_mute(0) and ads.busy(), "ad timeout restores audio while retaining native-screen quarantine")
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
	check(not ads.busy() and not AudioServer.is_bus_mute(0), "late native close clears quarantine")
	ads.free()
	AudioServer.set_bus_mute(0, previous)
	for failure in failures: print("FAILED: " + failure)
	print("Native adapter boundary checks: " + str(failures.size()) + " failures; actual native SDK unrun")
	quit(0 if failures.is_empty() else 1)
