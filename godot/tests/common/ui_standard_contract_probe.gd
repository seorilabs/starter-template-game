extends SceneTree
## 공통 UI 컨트롤러의 실제 상태와 저장 경계를 검사한다. 마켓과 기기는 호출하지 않는다.
const State = preload("res://addons/seorilabs_game/flow/state.gd")
const Analytics = preload("res://addons/seorilabs_game/services/analytics_preference.gd")
const Support = preload("res://addons/seorilabs_game/services/support_identity.gd")
const Ranking = preload("res://addons/seorilabs_game/services/leaderboard.gd")
const Commerce = preload("res://addons/seorilabs_game/services/commerce.gd")
const Locale = preload("res://addons/seorilabs_game/locales/localization.gd")

class RefuseSave extends State:
	var refuse := false
	func commit(next: Dictionary) -> bool:
		if refuse:
			error = "save_failed"
			return false
		return super.commit(next)

class AnalyticsPort extends RefCounted:
	var enabled := false
	var pending: Array = ["before-opt-out"]
	var calls: Array = []
	var allow_enable := true
	func set_enabled(value: bool) -> bool:
		calls.append(value)
		enabled = value and allow_enable
		return enabled
	func discard_pending() -> void:
		calls.append("discard")
		pending.clear()

class SupportPort extends RefCounted:
	var callbacks: Array = []
	func request(callback: Callable) -> void:
		callbacks.append(callback)
	func reply(index: int, response: Dictionary) -> void:
		callbacks[index].call(response)

class RankingPort extends RefCounted:
	var caps := {"open": true, "list": true, "submit": true, "periods": ["alltime", "weekly"]}
	var fetches: Array = []
	var fetch_callbacks: Array = []
	var submissions: Array = []
	var submit_callbacks: Array = []
	var opens := 0
	func capabilities() -> Dictionary:
		return caps
	func fetch(query: Dictionary, callback: Callable) -> void:
		fetches.append(query.duplicate(true))
		fetch_callbacks.append(callback)
	func submit_score(value: Dictionary, callback: Callable) -> void:
		submissions.append(value.duplicate(true))
		submit_callbacks.append(callback)
	func open_board(callback: Callable) -> void:
		opens += 1
		callback.call({"ok": true})

class CommercePort extends RefCounted:
	var catalog_callbacks: Array = []
	var purchases: Array = []
	var purchase_callbacks: Array = []
	var restore_callbacks: Array = []
	var reconciles: Array = []
	var reconcile_callbacks: Array = []
	func capabilities() -> Dictionary:
		return {"purchase": true, "restore": true}
	func catalog(callback: Callable) -> void:
		catalog_callbacks.append(callback)
	func purchase(id: String, callback: Callable) -> void:
		purchases.append(id)
		purchase_callbacks.append(callback)
	func reconcile(id: String, callback: Callable) -> void:
		reconciles.append(id)
		reconcile_callbacks.append(callback)
	func restore(callback: Callable) -> void:
		restore_callbacks.append(callback)

var checks: Array = []
var save_dir := ""

func check(value: bool, name: String) -> void:
	checks.append({"name": name, "passed": value})

func _initialize() -> void:
	call_deferred("_run")

func fresh(name: String):
	var state = State.new(save_dir + "/" + name + ".json")
	check(state.load_state(), name + ": state loads")
	return state

func _run() -> void:
	save_dir = "user://e2e-ui-contract-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(save_dir)
	_check_analytics()
	_check_support()
	_check_locale()
	_check_ranking()
	_check_commerce()
	var failed := checks.filter(func(item: Dictionary) -> bool: return not item.passed)
	var result := {"kind": "ui-standard-contract-probe", "passed": failed.is_empty(), "checks": checks, "failures": failed}
	var args := OS.get_cmdline_user_args()
	if args.has("--out") and args.find("--out") + 1 < args.size():
		var file := FileAccess.open(args[args.find("--out") + 1], FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result, "  ") + "\n")
			file.close()
		else:
			check(false, "probe report writable")
			failed = checks.filter(func(item: Dictionary) -> bool: return not item.passed)
	for failure in failed:
		print("UI CONTRACT FAILED: ", failure.name)
	print("UI standard contract probe: %d checks, %d failed" % [checks.size(), failed.size()])
	# 이 실행에서만 만든 격리 저장을 지운다. 사용자 기본 저장은 건드리지 않는다.
	for name in DirAccess.get_files_at(save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir))
	quit(0 if failed.is_empty() else 1)

func _check_analytics() -> void:
	var store = fresh("analytics")
	var port := AnalyticsPort.new()
	var preference = Analytics.new()
	preference.port = port
	preference.policy_allowed = true
	preference.apply(store)
	check(store.data.settings.analytics and preference.effective and store.analytics_allowed and port.enabled, "analytics defaults on only when supported and policy permits")
	var next: Dictionary = store.data.duplicate(true)
	store.event(next, "before", "example_event")
	check(store.commit(next) and store.data.events.has("before"), "analytics permitted event stored")
	check(preference.choose(store, false), "analytics opt-out saves")
	check(not preference.effective and not store.analytics_allowed and not port.enabled and port.pending.is_empty() and store.data.events.is_empty(), "analytics opt-out disables provider and purges both queues")
	var restarted = State.new(store.path)
	check(restarted.load_state() and not restarted.data.settings.analytics, "analytics opt-out survives restart")
	preference.apply(restarted)
	check(not preference.effective, "analytics off applied before further events")
	check(preference.choose(restarted, true) and preference.effective and port.pending.is_empty() and restarted.data.events.is_empty(), "analytics re-enable does not backfill discarded events")
	preference.policy_allowed = false
	preference.apply(restarted)
	next = restarted.data.duplicate(true)
	restarted.event(next, "blocked", "example_event")
	check(not preference.effective and preference.reason == "policy" and not port.enabled and not next.events.has("blocked"), "analytics policy blocks collection and event creation")
	preference.policy_allowed = true
	port.allow_enable = false
	preference.apply(restarted)
	check(not preference.effective and not restarted.analytics_allowed and preference.reason == "unavailable", "analytics provider refusal is not success")
	var failed = RefuseSave.new(save_dir + "/failed-save.json")
	check(failed.load_state() and failed.commit(failed.data.duplicate(true)), "analytics failure fixture starts with persisted on")
	failed.refuse = true
	port.allow_enable = true
	preference.apply(failed)
	check(not preference.choose(failed, false) and not failed.data.settings.analytics and not preference.effective and not port.enabled, "analytics failed main save remains off")
	var after_failure = State.new(failed.path)
	check(after_failure.load_state() and not after_failure.data.settings.analytics, "analytics failed main save safety marker survives restart")
	check(not preference.choose(failed, true) and not failed.data.settings.analytics and not preference.effective, "analytics failed enable save remains off")
	var no_provider = Analytics.new()
	no_provider.policy_allowed = true
	no_provider.apply(store)
	check(not no_provider.effective and no_provider.reason == "unavailable", "analytics missing provider stays unavailable")

func _check_support() -> void:
	var support = Support.new()
	var provider := SupportPort.new()
	var copied: Array = []
	var writer := func(value: String) -> bool: copied.append(value); return true
	support.request("app:alice", provider.request)
	check(support.status == "checking" and not support.copy_code(writer) and copied.is_empty(), "support checking cannot copy")
	provider.reply(0, {"ok": true, "identity": "app:bob", "code": "OTHER-CODE"})
	check(support.status == "failed" and support.code.is_empty(), "support rejects response for other identity")
	support.request("app:alice", provider.request)
	provider.reply(1, {"ok": true, "identity": "app:alice", "code": "  SK-7H2K9X4Q  "})
	check(support.status == "ready" and support.code == "SK-7H2K9X4Q" and support.copy_code(writer) and copied == ["SK-7H2K9X4Q"], "support ready normalizes only whitespace and copies exact code")
	check(not support.copy_code(func(_value: String) -> bool: return false), "support clipboard failure is not success")
	support.request("app:alice", provider.request)
	provider.reply(2, {"ok": false, "offline": true})
	check(support.status == "cached_offline" and support.code == "SK-7H2K9X4Q", "support offline cache belongs to current identity")
	support.request("app:alice", provider.request)
	support.close()
	provider.reply(3, {"ok": true, "identity": "app:alice", "code": "LATE-CODE"})
	check(support.status == "unavailable" and support.code.is_empty(), "support closed view ignores late response")
	support.request("app:alice", provider.request)
	support.change_identity("app:bob")
	provider.reply(4, {"ok": true, "identity": "app:alice", "code": "LATE-ALICE"})
	check(support.code.is_empty(), "support account change ignores old response")
	support.request("app:bob", provider.request)
	provider.reply(5, {"ok": false, "offline": true})
	check(support.status == "failed" and support.code.is_empty(), "support account change cannot reuse previous cache")
	for invalid in ["", " \n ", "BAD\tCODE", "X".repeat(129)]:
		support.request("app:bob", provider.request)
		provider.reply(provider.callbacks.size() - 1, {"ok": true, "identity": "app:bob", "code": invalid})
		check(support.status == "failed" and support.code.is_empty(), "support rejects invalid code length %d" % invalid.length())
	support.request("", Callable())
	check(support.status == "unavailable" and not support.copy_code(writer), "support missing identity or provider remains visible unavailable state")
	provider.callbacks.clear()

func _check_locale() -> void:
	check(Locale.resolve("ko", "en-US") == "ko", "locale manual selection takes precedence")
	check(Locale.resolve("system", "ko_KR") == "ko", "locale system underscores use supported language family")
	check(Locale.resolve("system", "en-GB") == "en", "locale supported region falls back to family")
	check(Locale.resolve("system", "pt-BR") == "en", "locale unsupported device language falls back to English")
	check(Locale.resolve("system", "") == "en", "locale missing device locale has safe fallback")
	check(Locale.text("Restore", "", "ko") == "Restore", "locale missing translation shows English rather than empty text")
	var store = fresh("locale")
	check(store.setting("language", "ko"), "locale selection saved locally")
	var restored = State.new(store.path)
	check(restored.load_state() and restored.data.settings.language == "ko", "locale selection survives restart without a network service")

func ranking_fixture(name: String):
	var ranking = Ranking.new()
	ranking.store = fresh(name)
	ranking.port = RankingPort.new()
	ranking.config = {"enabled": true, "appId": "fixture-app", "boardId": "score", "rulesVersion": 1, "seasonId": "week-a"}
	ranking.identity = "alice"
	return ranking

func _check_ranking() -> void:
	var ranking = ranking_fixture("ranking-list")
	var port = ranking.port
	ranking.config.enabled = false
	ranking.fetch()
	check(not ranking.available() and port.fetches.is_empty() and ranking.status == "unavailable", "ranking disabled configuration never queries provider")
	ranking.config.enabled = true
	ranking.fetch()
	check(ranking.status == "loading" and port.fetches[0].limit == 50 and port.fetches[0].around == 2, "ranking bounded query requests top fifty and two neighbours")
	var tied := [{"rank": 1, "name": "A", "score": 100}, {"rank": 2, "name": "B", "score": 90}, {"rank": 2, "name": "C", "score": 90}, {"rank": 4, "name": "D", "score": 80}]
	port.fetch_callbacks[0].call({"ok": true, "rows": tied, "self": tied[2], "nextCursor": "page-two", "checkedAt": 100})
	check(ranking.status == "ready" and ranking.rows.map(func(row): return row.rank) == [1, 2, 2, 4], "ranking preserves provider shared ranks for tied scores")
	ranking.fetch(true)
	check(port.fetches[1].cursor == "page-two", "ranking pagination uses provider cursor")
	port.fetch_callbacks[1].call({"ok": true, "rows": [{"rank": 5, "name": "E", "score": 70}], "self": tied[2], "nextCursor": "", "checkedAt": 101})
	check(ranking.rows.size() == 5 and ranking.next_cursor.is_empty(), "ranking pagination appends without reranking prior page")
	ranking.fetch()
	port.fetch_callbacks[2].call({"ok": false, "offline": true})
	check(ranking.status == "offline_cached" and ranking.rows.size() == 5 and ranking.checked_at == 101, "ranking offline cache exposes previous check time")
	ranking.fetch()
	ranking.change_identity("bob")
	port.fetch_callbacks[3].call({"ok": true, "rows": tied, "self": tied[2]})
	check(ranking.rows.is_empty() and ranking.self_record.is_empty(), "ranking user change ignores late old user list")
	ranking.fetch()
	port.fetch_callbacks[4].call({"ok": false, "offline": true})
	check(ranking.status == "failed" and ranking.rows.is_empty(), "ranking new identity cannot see old offline cache")
	ranking.period = "weekly"
	ranking.fetch()
	ranking.config.seasonId = "week-b"
	port.fetch_callbacks[5].call({"ok": true, "rows": tied, "self": tied[2]})
	check(ranking.rows.is_empty(), "ranking changed season rejects pending old season list")
	ranking.fetch()
	port.fetch_callbacks[6].call({"ok": false, "offline": true})
	check(ranking.status == "failed" and ranking.rows.is_empty(), "ranking season cache does not cross period boundary")
	ranking.scope = "around"
	ranking.fetch()
	check(port.fetches[7].scope == "around" and port.fetches[7].cursor == "", "ranking around-me query starts independently of top cursor")
	port.fetch_callbacks[7].call({"ok": true, "rows": [], "self": {}, "closed": true})
	check(ranking.status == "season_closed", "ranking closed season remains distinct from empty")
	port.caps.list = false
	ranking.fetch()
	check(ranking.status == "unavailable" and port.fetches.size() == 8, "ranking native-only provider does not fake list capability")
	var native_result: Dictionary = {}
	ranking.open_native(func(value: Dictionary) -> void: native_result.merge(value, true))
	check(port.opens == 1 and native_result.get("ok", false), "ranking native open delegates to provider")
	_check_ranking_submission()
	port.fetch_callbacks.clear()
	port.submit_callbacks.clear()

func _check_ranking_submission() -> void:
	var ranking = ranking_fixture("ranking-submit")
	var port = ranking.port
	ranking.submit(10, "unfinished", false)
	ranking.submit(-1, "invalid", true)
	check(port.submissions.is_empty(), "ranking rejects unfinished or negative score")
	ranking.submit(100, "run-a", true)
	ranking.submit(100, "run-a", true)
	check(port.submissions.size() == 1 and ranking.status == "submitting", "ranking duplicate tap while submitting sends one request")
	port.submit_callbacks[0].call({"ok": false})
	ranking.submit(100, "run-a", true)
	check(port.submissions.size() == 2 and port.submissions[0] == port.submissions[1], "ranking failed run retries identical identity and run payload")
	port.submit_callbacks[1].call({"ok": true})
	ranking.submit(100, "run-a", true)
	check(port.submissions.size() == 2 and ranking.status == "submitted", "ranking accepted run is not resubmitted")
	var restarted = Ranking.new()
	restarted.store = State.new(ranking.store.path)
	check(restarted.store.load_state(), "ranking restart fixture loads persisted submissions")
	restarted.port = port
	restarted.config = ranking.config.duplicate(true)
	restarted.identity = "alice"
	restarted.submit(100, "run-a", true)
	check(port.submissions.size() == 2, "ranking confirmed run remains deduplicated after restart")
	ranking.submit(110, "interrupted", true)
	var uncertain = Ranking.new()
	uncertain.store = State.new(ranking.store.path)
	check(uncertain.store.load_state(), "ranking uncertain restart loads")
	uncertain.port = port
	uncertain.config = ranking.config.duplicate(true)
	uncertain.identity = "alice"
	uncertain.submit(110, "interrupted", true)
	check(port.submissions.size() == 4 and port.submissions[2] == port.submissions[3], "ranking interrupted submission can retry same run after restart")
	var seasonal = ranking_fixture("ranking-season-submit")
	seasonal.period = "weekly"
	seasonal.submit(90, "last-run", true)
	seasonal.config.seasonId = "week-b"
	seasonal.fetch()
	seasonal.port.submit_callbacks[0].call({"ok": true})
	check(seasonal.status == "loading", "ranking old season submit result cannot overwrite current season view")
	var switched = ranking_fixture("ranking-user-submit")
	switched.submit(30, "alice-run", true)
	switched.change_identity("bob")
	switched.port.submit_callbacks[0].call({"ok": true})
	check(not switched.store.data.ui.submissions.values().has("submitted"), "ranking old account callback does not update current account store")
	port.submit_callbacks.clear()
	seasonal.port.fetch_callbacks.clear()
	seasonal.port.submit_callbacks.clear()
	switched.port.submit_callbacks.clear()

func _check_commerce() -> void:
	var store = fresh("commerce")
	var commerce = Commerce.new()
	var port := CommercePort.new()
	commerce.store = store
	commerce.port = port
	commerce.buy("coins")
	check(port.purchases.is_empty(), "commerce cannot buy before catalog availability")
	commerce.catalog()
	commerce.catalog()
	port.catalog_callbacks[0].call({"ok": true, "products": [{"id": "old", "price": "$1", "available": true}]})
	check(commerce.products.is_empty() and commerce.catalog_state == "loading", "commerce stale catalog response is ignored")
	port.catalog_callbacks[1].call({"ok": true, "products": [{"id": "coins", "price": "", "available": true}, {"id": "missing", "price": "$1", "available": false}]})
	commerce.buy("coins")
	commerce.buy("missing")
	check(port.purchases.is_empty(), "commerce missing price and unavailable product cannot purchase")
	commerce.catalog()
	port.catalog_callbacks[2].call({"ok": true, "products": [{"id": "coins", "price": "US$2.99", "available": true}]})
	commerce.buy("coins")
	commerce.buy("coins")
	check(port.purchases == ["coins"] and commerce.state == "store_open", "commerce duplicate purchase tap starts one store request")
	port.purchase_callbacks[0].call({"ok": true})
	check(commerce.state != "completed" and store.data.coins == 0, "commerce ok-only store result is not a fulfilled grant")
	commerce.buy("coins")
	port.purchase_callbacks[1].call({"state": "pending", "transactionId": "transaction-one"})
	commerce.buy("coins")
	check(commerce.state == "pending" and port.purchases.size() == 2 and store.data.coins == 0, "commerce pending blocks repurchase and grants nothing")
	commerce.restore()
	check(port.restore_callbacks.is_empty() and commerce.state == "pending", "commerce pending transaction cannot be replaced by restore")
	var restarted = Commerce.new()
	restarted.store = State.new(store.path)
	check(restarted.store.load_state(), "commerce persisted transaction reloads")
	restarted.port = port
	restarted.reconcile()
	check(port.reconciles == ["transaction-one"] and restarted.state == "verifying", "commerce restart checks previous transaction")
	port.reconcile_callbacks[0].call({"state": "completed", "fulfilled": false, "transactionId": "transaction-one"})
	check(restarted.state == "verifying" and store.data.coins == 0, "commerce unfulfilled completed response waits for verification")
	port.reconcile_callbacks[0].call({"state": "completed", "fulfilled": true, "transactionId": "transaction-one"})
	check(restarted.state == "completed", "commerce completed requires explicit fulfillment")
	for restore_state in ["none", "restored", "partial", "failed", "unexpected"]:
		restarted.restore()
		port.restore_callbacks.back().call({"state": restore_state})
		check(restarted.operation == "restore" and restarted.state == ("failed" if restore_state == "unexpected" else restore_state), "commerce restore distinguishes " + restore_state)
	check(store.data.coins == 0 and restarted.store.data.coins == 0, "commerce controller never invents local currency grants")
	port.catalog_callbacks.clear()
	port.purchase_callbacks.clear()
	port.reconcile_callbacks.clear()
	port.restore_callbacks.clear()
	_check_commerce_late_response()

func _check_commerce_late_response() -> void:
	var commerce = Commerce.new()
	var port := CommercePort.new()
	commerce.store = fresh("commerce-late")
	commerce.port = port
	commerce.catalog()
	port.catalog_callbacks[0].call({"ok": true, "products": [{"id": "coins", "price": "US$2.99", "available": true}]})
	commerce.buy("coins")
	port.purchase_callbacks[0].call({"state": "failed", "transactionId": "old-transaction"})
	commerce.buy("coins")
	check(port.purchases.size() == 2 and commerce.state == "store_open", "commerce new purchase may start after explicit prior failure")
	port.purchase_callbacks[0].call({"state": "completed", "fulfilled": true, "transactionId": "old-transaction"})
	check(commerce.state == "store_open", "commerce late prior transaction cannot complete current purchase")
	port.purchase_callbacks[1].call({"state": "pending", "transactionId": "new-transaction"})
	check(commerce.state == "pending" and commerce.transaction == "new-transaction", "commerce current transaction still handles its response")
	port.catalog_callbacks.clear()
	port.purchase_callbacks.clear()
