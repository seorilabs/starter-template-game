extends RefCounted
var sdk: Node
var enabled := false
func set_enabled(value: bool) -> bool:
	enabled = value
	sdk.set_analytics_enabled(value)
	return enabled
func discard_pending() -> void:
	if not enabled: sdk.set_analytics_enabled(false)
