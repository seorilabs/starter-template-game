extends SceneTree
const Driver = preload("res://tests/common/e2e_driver.gd")
const State = preload("res://addons/seorilabs_game/flow/state.gd")
const Runtime = preload("res://game/adapters/platform_runtime.gd")
const SDK = preload("res://addons/seorilabs_platform/platform_client.gd")
const Boundaries = preload("res://tests/game/platform_boundaries.gd")
var d
var client: Node
var service: Node
var cloud: Node
var market: RefCounted
var runtime: RefCounted
var main: Control
var directory := ""
var cleanup: Array[String] = []

func _initialize() -> void: call_deferred("run")
func arg(key: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	return args[args.find(key) + 1] if args.has(key) else fallback
func b(name: String) -> Control: return main.find_child(name, true, false) as Control
func text_button(text: String) -> Button:
	for button in main.find_children("*", "Button", true, false):
		if button.text == text: return button
	return null
func tap(name: String) -> bool: return await d.tap(b(name))
func cleanup_owner() -> void:
	cleanup.append(main.state.path)
	cleanup.append(cloud._journal_path())
	cleanup.append(runtime.commerce._path())
	var ad_path: String = runtime.ads._path()
	for suffix in ["", ".claims", ".acks"]: cleanup.append(ad_path + suffix)

func run() -> void:
	var size := arg("--size", "568x320").split("x")
	d = Driver.new(self, Vector2i(int(size[0]), int(size[1])), arg("--out", "user://platform-journey"), OS.get_cmdline_user_args().has("--capture"))
	directory = "user://platform-journey-" + Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(directory)
	main = load("res://game/bootstrap/main.tscn").instantiate()
	main.connect_platform = false
	main.device_locale = arg("--locale", "en-US")
	main.state = State.new(directory + "/local.json")
	main.clipboard_writer = func(_value: String) -> bool: return true
	client = SDK.new()
	service = Boundaries.Service.new()
	service.prefix = "qa-" + Crypto.new().generate_random_bytes(8).hex_encode() + "-"
	client._transport = service
	client.add_child(service)
	cloud = Boundaries.Storage.new()
	cloud.privacy_marker = directory + "/privacy-off"
	market = Boundaries.Market.new()
	runtime = Runtime.new()
	var options: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/platform.json"))
	options.platform.presence_enabled = false
	runtime.attach(main, options, {"sdk": client, "market": market, "market_platform": "app_store", "ad_native": Boundaries.Ad.new(), "ads_path_prefix": directory + "/ad-", "accounts": {"identity": Boundaries.Firebase.new(), "native": Boundaries.NativeIdentity.new(), "cloud": cloud, "receipt_path": directory + "/receipt.json", "identity_path": directory + "/identity.json", "legacy_path": directory + "/legacy.json", "migration_path": directory + "/migration.json"}})
	d.begin("real-bootstrap-account-and-cloud", ["startup", "account_save", "platform_end_to_end", "ui_landscape"])
	await d.mount(main)
	d.step("signed-out startup does not create an account", main.initialized and service.created == 0 and not main.accounts.connected())
	await d.shot("signed-out-camp")
	d.step("create via primary button", await tap("start"))
	d.step("real Firebase adapter and SDK session establish a cloud-ready account", main.accounts.connected() and cloud.progress_ready and service.created == 1 and main.screen == "title")
	var original_uid := str(main.accounts.details.get("uid", ""))
	if OS.get_cmdline_user_args().has("--large-text"):
		d.step("large text through settings buttons", await tap("settings") and await tap("accessibility") and await tap("large_text") and main.state.data.settings.large_text and await tap("close"))
	d.step("open identifiers with buttons", await tap("account") and await tap("account_identifiers"))
	d.expect_equal("confirmed UID", b("identity_uid").text, "UID  " + original_uid)
	d.expect_equal("confirmed PUID", b("identity_platformUserId").text, "PUID  puid-" + original_uid)
	d.step("copy UID before support", await tap("copy_uid"))
	d.step("copy support code", await tap("copy") and main.support.code == "STRT-TEST")
	await d.shot("server-identifiers")
	d.step("return to title", await tap("close"))
	d.end()
	d.begin("actual-round-cloud-save", ["tutorial", "account_save", "platform_end_to_end"])
	d.step("start actual sample after ready", await tap("start") and main.screen == "play")
	for i in 3: d.step("collect sample star", await d.tap(text_button("★")))
	d.step("finish actual round", await d.tap(text_button(main.tr_text("Collect +10", "받기 +10"))))
	d.step("game progress reaches cloud boundary", main.state.data.coins == 10 and cloud.documents[original_uid].coins == 10 and not cloud.has_pending())
	d.step("return to camp", await tap("reward_continue") and main.screen == "home")
	await d.shot("connected-camp")
	d.end()
	d.begin("inbox-wallet-and-store", ["inbox", "commerce", "platform_end_to_end"])
	d.step("open real server inbox", await tap("inbox"))
	d.step("claim with server SDK", await d.tap(text_button(main.tr_text("Claim", "받기"))))
	d.step("server inventory signal refreshes ticket wallet without granting game coins", runtime.commerce.wallet.get("starter_test_ticket_1", 0) == 1 and main.state.data.coins == 10)
	await d.shot("server-mail-received")
	d.step("close inbox", await tap("close"))
	d.step("open store with native localized price boundary", await tap("shop"))
	await d.shot("localized-store")
	d.step("select ticket and purchase", await tap("product_starter_test_ticket_1") and await tap("buy"))
	d.step("server wallet confirms before finishing native transaction", main.commerce.state == "completed" and runtime.commerce.wallet.starter_test_ticket_1 == 2 and market.finished == 1)
	d.step("close purchase", await tap("close"))
	d.end()
	d.begin("ad-server-receipt-and-optout", ["observability", "operations", "platform_end_to_end"])
	d.step("open ad route", await tap("ads"))
	d.step("watch native boundary ad", await tap("ads_watch"))
	d.step("native completion cannot confirm receipt", runtime.ads.snapshot().confirmed == 0 and runtime.ads.snapshot().pending)
	service.ad_verified = true
	d.step("server confirmation via button", await tap("ads_refresh"))
	d.step("server confirmation counts once without ticket grant", runtime.ads.snapshot().confirmed == 1 and not runtime.ads.snapshot().pending and runtime.commerce.wallet.starter_test_ticket_1 == 2)
	await d.shot("server-ad-confirmed")
	d.step("close ads and open settings", await tap("close") and await tap("settings"))
	d.step("analytics opt-out", await tap("analytics") and not client._analytics_enabled and not cloud.documents[original_uid].settings.analytics)
	d.step("close settings", await tap("close"))
	service.maintenance = true
	client.fetch_config({}, func(_result: Dictionary): pass)
	d.step("late maintenance blocks play", await tap("play") and main.screen == "home")
	var maintenance_notice := false
	for label in main.find_children("*", "Label", true, false):
		if label.text.to_lower().contains("maintenance") or label.text.contains("점검"): maintenance_notice = true
	d.step("maintenance has its own actionable reason", maintenance_notice)
	await d.shot("maintenance-reason")
	service.maintenance = false
	client.fetch_config({}, func(_result: Dictionary): pass)
	d.step("server recovery clears the maintenance gate", runtime.sdk.is_under_maintenance() == false and main.gameplay_ready.call())
	d.end()
	d.begin("link-logout-recover-and-delete", ["account_save", "platform_end_to_end", "settings_support"])
	d.step("account management", await tap("account") and await tap("account_manage"))
	d.step("link provider through actual account adapter", await tap("link_google") and main.accounts.details.get("linked", false))
	d.step("management and logout confirmation", await tap("account_manage") and await tap("account_logout") and await tap("account_confirm"))
	d.step("signed out", not main.accounts.connected())
	d.step("recover route", await tap("account_recovery"))
	var field: LineEdit = b("recovery_uid")
	d.step("focus UID input", await d.tap(field))
	field.grab_focus()
	for character in original_uid:
		var key := InputEventKey.new()
		key.unicode = character.unicode_at(0)
		key.pressed = true
		d.viewport.push_input(key, true)
	d.step("recover linked UID", await tap("recover_google") and str(main.accounts.details.get("uid", "")) == original_uid)
	d.step("same cloud progress and optout restored", main.state.data.coins == 10 and not main.state.data.settings.analytics and cloud.progress_ready)
	cleanup_owner()
	d.step("delete via confirmation buttons", await tap("account_manage") and await tap("account_delete") and await tap("account_confirm"))
	d.step("private deletion receipt persisted before request", service.receipts.size() == 1 and service.receipts[0].length() == 64 and not main.accounts.connected())
	d.step("check deletion status with a button", await tap("account_deletion_status") and main.accounts.details.get("deletionStatus") == "completed")
	await d.shot("deletion-status")
	d.end()
	await d.unmount(main)
	for path in cleanup:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory)) if DirAccess.get_files_at(directory).is_empty() else null
	quit(d.finish({"boundary": "Only external HTTP, provider, store, native ad and cloud ports substituted; actual product scene, SDK, account adapter and save code executed. Native SDK and production service are unrun."}))
