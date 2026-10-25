extends RefCounted
const SUPPORTED := ["en", "ko"]

static func resolve(selection: String, device_locale: String) -> String:
	if selection in SUPPORTED:
		return selection
	var locale := device_locale.replace("_", "-").to_lower()
	if locale in SUPPORTED:
		return locale
	var family := locale.get_slice("-", 0)
	return family if family in SUPPORTED else "en"

static func text(english: String, korean: String, locale: String) -> String:
	return korean if locale == "ko" and not korean.is_empty() else english
