extends RefCounted
## Bootstrap owns service wiring; the common addon has no product dependencies.
const SDK = preload("res://addons/seorilabs_platform/platform_client.gd")
const Accounts = preload("res://game/adapters/platform_accounts.gd")
const AnalyticsPort = preload("res://game/adapters/platform_analytics.gd")
const CommercePort = preload("res://game/adapters/platform_commerce.gd")
const PlayMarket = preload("res://game/adapters/android_play_billing_market.gd")
const AppleMarket = preload("res://game/adapters/ios_storekit_market.gd")
const AdsPort = preload("res://game/adapters/platform_ads.gd")
var sdk: Node
var accounts: Node
var commerce: RefCounted
var ads: Node

func attach(owner: Control, options: Dictionary, boundaries: Dictionary = {}) -> void:
	sdk = boundaries.get("sdk")
	if sdk == null: sdk = SDK.new()
	owner.add_child(sdk)
	sdk.configure(options.platform)
	# Preference is applied before any session or event request can be sent.
	sdk.set_analytics_enabled(false)
	accounts = Accounts.new()
	owner.add_child(accounts)
	accounts.configure(sdk, owner.state, options, boundaries.get("accounts", {}))
	owner.accounts.port = accounts
	owner.identity_provider = func() -> String:
		return "starter-game:" + str(sdk.current_session().get("platformUserId", "")) if sdk.is_signed_in() else ""
	owner.configure_platform(sdk, accounts.supply, {"async_credentials": true, "analytics_policy_allowed": true})
	var analytics := AnalyticsPort.new()
	analytics.sdk = sdk
	owner.analytics.port = analytics
	owner.analytics.policy_allowed = true
	commerce = CommercePort.new()
	commerce.sdk = sdk
	if boundaries.has("market"):
		commerce.market = boundaries.market
		commerce.platform = str(boundaries.get("market_platform", "app_store"))
	elif OS.get_name() == "Android":
		commerce.platform = "google_play"
		commerce.market = PlayMarket.new()
		owner.add_child(commerce.market)
	elif OS.get_name() == "iOS":
		commerce.platform = "app_store"
		commerce.market = AppleMarket.new(null, CommercePort.PRODUCT_IDS)
	owner.commerce.port = commerce
	ads = AdsPort.new()
	owner.add_child(ads)
	ads.driver = boundaries.get("ad_native")
	ads.path_prefix = str(boundaries.get("ads_path_prefix", ads.path_prefix))
	ads.configure(sdk, accounts.identity, options.get("admob", {}))
	accounts.operation_blocker = func() -> bool: return commerce.has_pending() or ads.busy()
	owner.feature_routes.ads = func() -> void: _ads_screen(owner)
	ads.changed.connect(func() -> void:
		if owner.screen == "ads": _ads_screen(owner))
	owner.gameplay_ready = func() -> bool:
		return accounts.cloud.progress_ready and not sdk.is_under_maintenance() and not sdk.is_sdk_blocked() and sdk.update_gate_state().get("kind", "ok") != "required"
	owner.account_changed = func(_account: Dictionary) -> void:
		owner._apply_settings()
		_refresh_inventory(owner)
	owner.services.server_inventory_changed.connect(func() -> void: _refresh_inventory(owner))
	accounts.cloud.changed.connect(func() -> void:
		if owner.accounts.status != "busy": owner.accounts.refresh())
	owner.resource_provider = func() -> String:
		var ticket := str(commerce.wallet.get("starter_test_ticket_1", "—")) if commerce.wallet_status == "verified" else "—"
		return "★ %d    🎟 %s" % [int(owner.state.data.get("coins", 0)), ticket]
	owner.feature_routes.operations = func() -> void: _operations(owner)

func _refresh_inventory(owner: Control) -> void:
	if not sdk.is_signed_in():
		commerce.capabilities()
		return
	await commerce.refresh_wallet()
	if is_instance_valid(owner) and owner.screen in ["home", "title"]: owner._route(owner.screen)

func _ads_screen(owner: Control) -> void:
	owner._clear(owner.tr_text("Ad reward", "광고 보상"))
	var box: VBoxContainer = owner._scroll()
	var current: Dictionary = ads.snapshot()
	box.add_child(owner._label(owner.tr_text("Watch a test ad and confirm its server receipt.", "테스트 광고를 보고 서버의 시청 확인을 받아보세요."), 24))
	box.add_child(owner._label(owner.tr_text("Confirmed test views: %d", "서버 확인을 받은 테스트 시청: %d") % int(current.confirmed)))
	var messages := {
		"idle": ["Ready for a test ad.", "테스트 광고를 볼 수 있습니다."],
		"loading": ["Loading the ad…", "광고를 불러오고 있습니다…"],
		"presenting": ["Ad is open.", "광고가 열려 있습니다."],
		"awaiting_server": ["Waiting for server verification. Check again in a moment.", "서버의 시청 확인을 기다립니다. 잠시 후 다시 확인해 주세요."],
		"verified": ["The server confirmed your test view.", "서버에서 테스트 시청을 확인했습니다."],
		"ack_pending": ["Verified. Delivery confirmation is pending.", "시청은 확인됐습니다. 수령 확인을 다시 보내야 합니다."],
		"expired": ["The confirmation expired. You can try a new ad.", "확인 기한이 지났습니다. 새 광고로 다시 시도할 수 있습니다."],
		"failed": ["The ad could not finish. Please try again.", "광고를 완료하지 못했습니다. 다시 시도해 주세요."],
		"unavailable": ["Ads are unavailable under the current server policy.", "현재 서버 설정에서 광고를 제공하지 않습니다."]}
	var words: Array = messages.get(current.status, messages.idle)
	box.add_child(owner._label(owner.tr_text(words[0], words[1])))
	var watch: Button = owner._button(owner.tr_text("Watch test ad", "테스트 광고 보기"), func() -> void: ads.watch(), box, true)
	watch.name = "ads_watch"
	watch.disabled = not current.available or current.busy or current.pending
	var refresh: Button = owner._button(owner.tr_text("Check server confirmation", "서버 확인 다시 받기"), func() -> void: ads.refresh(), box)
	refresh.name = "ads_refresh"
	refresh.disabled = current.busy or not current.pending
	if ads.driver.privacy_options_required(): owner._button(owner.tr_text("Ad privacy choices", "광고 개인정보 선택"), ads.driver.privacy_options, box)
	if not current.available: box.add_child(owner._label(owner.tr_text("Connect an account in a supported mobile build.", "지원하는 모바일 빌드에서 계정을 연결해 주세요.")))

func _operations(owner: Control) -> void:
	owner._clear(owner.tr_text("Live service status", "운영 서비스 상태"))
	var box: VBoxContainer = owner._scroll()
	box.add_child(owner._label(owner.tr_text("Platform connection", "플랫폼 연결"), 22))
	box.add_child(owner._label(owner.tr_text("Account connected", "계정 연결됨") if sdk.is_signed_in() else owner.tr_text("Create or recover an account first.", "먼저 계정을 만들거나 복구해 주세요.")))
	box.add_child(owner._label(owner.tr_text("Cloud save: ", "클라우드 저장: ") + str(accounts.cloud.status)))
	box.add_child(owner._label(owner.tr_text("IAP: sandbox test purchases only", "인앱결제: 샌드박스 테스트 구매 전용")))
	box.add_child(owner._label(owner.tr_text("Test tickets: ", "테스트 티켓: ") + (str(commerce.wallet.get("starter_test_ticket_1", "—")) if commerce.wallet_status == "verified" else "—")))
	var policy: Dictionary = sdk.current_config()
	box.add_child(owner._label(owner.tr_text("Maintenance: ", "점검: ") + str(policy.get("maintenance", {}).get("active", false))))
	box.add_child(owner._label(owner.tr_text("Update: ", "업데이트: ") + str(sdk.update_gate_state().get("kind", "unknown"))))
	var refresh: Button = owner._button(owner.tr_text("Refresh server state", "서버 상태 다시 확인"), func() -> void:
		var view: int = owner._view
		sdk.fetch_config({"platform": "ios" if OS.get_name() == "iOS" else "android", "appVersion": ProjectSettings.get_setting("application/config/version", "")}, func(response: Dictionary) -> void:
			if owner._view != view: return
			if response.get("ok", false): _operations(owner)
			else: owner._show_error(str(response.get("code", "network_error"))))
	, box)
	refresh.disabled = not sdk.is_signed_in()
