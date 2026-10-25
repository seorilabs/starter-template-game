extends Node
const Rules = preload("res://game/core/domain/round_rules.gd")
const RecordHit = preload("res://game/core/use_cases/record_hit.gd")
const Progress = preload("res://game/adapters/local_progress.gd")
var host: Control
var progress_port
var record_hit = RecordHit.new()

func begin(owner: Control) -> void:
	host = owner
	progress_port = Progress.new(host.state)
	render()

func render() -> void:
	host.screen = "play"
	host._clear(host.tr_text("Gather three stars", "별 세 개를 모아요"))
	var tutorial: Dictionary = host.state.data.tutorial
	host.content.add_child(host._label(host.tr_text("Tap the star", "별을 눌러 보세요") if tutorial.step == 0 else host.tr_text("Collect your first reward", "첫 보상을 받아요")))
	host.content.add_child(host._label("● " .repeat(mini(int(tutorial.hits), Rules.TARGETS)) + "○ " .repeat(Rules.remaining(int(tutorial.hits))), 24 if host.size.y < 500 else 44))
	host._spacer()
	if tutorial.step == 0:
		var target: Button = host._button("★", _hit)
		target.custom_minimum_size.y = 60 if host.size.y < 500 else 150
		target.add_theme_font_size_override("font_size", 72)
	else:
		host._button(host.tr_text("Collect", "받기") + (" +10" if host.services.mode == "local" and not tutorial.replay and not host.state.data.grants.has("tutorial-first") else " · " + host.tr_text("practice", "연습") if tutorial.replay else ""), _collect)
	host._spacer()
	host._button(host.tr_text("Skip guide", "안내 건너뛰기"), func() -> void:
		if host.state.skip_tutorial():
			host._home()
		else:
			host._show_error(host.state.error)
	)

func _hit() -> void:
	if record_hit.execute(progress_port):
		host._sync_metrics()
		if host.state.data.settings.vibration:
			Input.vibrate_handheld(25)
		render()
	else:
		host._show_error(host.state.error)

func _collect() -> void:
	if host.services.mode == "server" and not host.state.data.tutorial.replay:
		if host.pending:
			return
		host.pending = true
		host.services.claim(str(host.config.get("tutorial_mail_id", "tutorial-first")), func(result: Dictionary) -> void:
			host.pending = false
			if not result.get("ok", false):
				host._show_error(str(result.get("code", "network_error")))
				return
			if not host.state.finish_remote_tutorial():
				host._show_error(host.state.error)
				return
			host.popups.enqueue("reward", {"text": host.tr_text("Server reward received", "서버 보상 수령 완료")})
			host._show_next_popup()
		)
		return
	var before: int = host.state.data.coins
	if not host.state.action_completed("reward_collected"):
		host._show_error(host.state.error)
		return
	host.popups.enqueue("reward", {"text": host.tr_text("Practice complete", "연습 완료") if host.state.data.tutorial.replay else "+%d coins" % (host.state.data.coins - before)})
	host._show_next_popup()

