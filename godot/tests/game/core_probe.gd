extends SceneTree
const Rules = preload("res://game/core/domain/round_rules.gd")
const Hit = preload("res://game/core/use_cases/record_hit.gd")
const Port = preload("res://game/core/ports/progress_port.gd")
class Progress extends Port:
 var calls := 0
 var writable := true
 func record_hit() -> bool:
  if not writable: return false
  calls += 1
  return true
func _initialize() -> void:
 var port := Progress.new()
 var hit := Hit.new()
 var ok := Rules.remaining(0) == 3 and Rules.remaining(2) == 1 and Rules.remaining(4) == 0
 ok = ok and hit.execute(port) and port.calls == 1
 port.writable = false
 ok = ok and not hit.execute(port) and port.calls == 1
 print("Game core checks passed" if ok else "Game core checks failed")
 quit(0 if ok else 1)
