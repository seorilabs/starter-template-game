extends RefCounted
## 어댑터는 자동 수집, 앱 이벤트와 재전송 큐를 같은 선택으로 제어해야 한다.
var port: RefCounted
var policy_allowed := false
var effective := false
var reason := "unavailable"

func apply(store: RefCounted) -> void:
	effective = false
	var supported: bool = port != null and port.has_method("set_enabled") and port.has_method("discard_pending")
	var wanted: bool = not store.data.is_empty() and store.data.settings.analytics
	reason = "unavailable" if not supported else "policy" if not policy_allowed else "off" if not wanted else "on"
	if supported:
		if not wanted or not policy_allowed:
			port.set_enabled(false)
			port.discard_pending()
		else:
			effective = bool(port.set_enabled(true))
			if not effective:
				reason = "unavailable"
				port.set_enabled(false)
				port.discard_pending()
	store.analytics_allowed = effective

func choose(store: RefCounted, enabled: bool) -> bool:
	# 저장 전에 즉시 막는다. 저장 실패가 기존 수집을 계속 허용하지 않는다.
	if not enabled:
		effective = false
		store.analytics_allowed = false
		if port != null and port.has_method("set_enabled") and port.has_method("discard_pending"):
			port.set_enabled(false)
			port.discard_pending()
	var saved: bool = store.setting("analytics", enabled)
	apply(store)
	return saved
