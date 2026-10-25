extends RefCounted
## 실제 호스트가 있을 때만 호출한다. SDK와 호스트 접근은 core 밖에 둔다.
func available() -> bool:
 return OS.has_feature("web") and JavaScriptBridge.get_interface("SeorilabsHost") != null

func request(operation: String, payload: Dictionary) -> bool:
 if not available(): return false
 var host = JavaScriptBridge.get_interface("SeorilabsHost")
 return bool(host.request(operation, JSON.stringify(payload)))
