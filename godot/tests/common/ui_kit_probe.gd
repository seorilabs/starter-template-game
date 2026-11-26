extends SceneTree
## ui_kit 계약 검사: 테마 재료, 팝업 열기·닫기, 보상 3단계, 버튼 효과음 연결, 재화 칩 표기, HUD 층, 컷신 재생기, reduced_motion.
const Builder = preload("res://addons/seorilabs_game/ui_kit/theme_builder.gd")
const Juice = preload("res://addons/seorilabs_game/ui_kit/juice.gd")
const UiSfx = preload("res://addons/seorilabs_game/ui_kit/ui_sfx.gd")
const PopupBase = preload("res://addons/seorilabs_game/ui_kit/popup_base.tscn")
const RewardCeremony = preload("res://addons/seorilabs_game/ui_kit/reward_ceremony.tscn")
const CurrencyChip = preload("res://addons/seorilabs_game/ui_kit/currency_chip.tscn")
const HudLayers = preload("res://addons/seorilabs_game/ui_kit/hud_layers.tscn")
const CUTSCENE := "res://addons/seorilabs_game/ui_kit/cutscene_player.tscn"
const ART := "res://addons/seorilabs_game/skins/soft_adventure/camp.svg"
var checks: Array = []
var host: Control

func check(value: bool, name: String) -> void:
	checks.append({"name": name, "passed": value})

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	host = Control.new()
	host.size = Vector2(390, 844)
	root.add_child(host)
	host.theme = load(Builder.DEFAULT_SKIN.path_join("theme.tres"))
	_check_theme()
	_check_focus()
	_check_tooltip()
	await _check_ambient(false)
	await _check_ambient(true)
	await _check_popup(false)
	await _check_popup(true)
	await _check_reward(false)
	await _check_reward(true)
	_check_sfx()
	_check_chip()
	await _check_layers()
	await _check_cutscene(false)
	await _check_cutscene(true)
	Juice.reduced_motion = false
	var failed := checks.filter(func(item: Dictionary) -> bool: return not item.passed)
	var result := {"kind": "ui-kit-probe", "passed": failed.is_empty(), "checks": checks, "failures": failed}
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
		print("UI KIT FAILED: ", failure.name)
	print("UI kit probe: %d checks, %d failed" % [checks.size(), failed.size()])
	quit(0 if failed.is_empty() else 1)

func _check_theme() -> void:
	var theme: Theme = host.theme
	check(theme != null, "theme.tres loads")
	if theme == null: return
	var display := theme.get_font("font", "PrimaryButton")
	check(theme.default_font != null and display != null and display != theme.default_font, "theme separates display and body fonts")
	check(theme.get_font("font", "NumberLabel") != null, "theme has number font role")
	check(theme.get_stylebox("normal", "Button") is StyleBoxTexture and theme.get_stylebox("normal", "PrimaryButton") is StyleBoxTexture, "buttons use painted StyleBoxTexture skins")
	check(theme.get_stylebox("panel", "PanelContainer") is StyleBoxTexture and theme.get_stylebox("panel", "PopupFrame") is StyleBoxTexture and theme.get_stylebox("panel", "ChipPanel") is StyleBoxTexture, "panels use painted skins")
	check(theme.get_stylebox("focus", "Button") is StyleBoxFlat, "focus stays an overlay")
	var skin := Builder.load_skin()
	check(skin.get("contract") == "1.1.0" and skin.has("textures") and skin.has("fonts") and skin.has("motion"), "skin.json v2 records contract, textures, fonts, motion")
	var built := Builder.build(Builder.DEFAULT_SKIN, "ko")
	check(built.get_font("font", "TitleLabel") != theme.get_font("font", "TitleLabel"), "korean display font differs from english build")

func _check_ambient(reduced: bool) -> void:
	# 상시 모션: 주 버튼 숨쉬기와 하이라이트 스윕. reduced_motion이면 배율이 1에 머물고 띠를 만들지 않는다.
	Juice.reduced_motion = reduced
	var button := Button.new()
	button.size = Vector2(160, 56)
	host.add_child(button)
	Juice.idle_pulse(button, 1.05, 0.4)
	Juice.shine(button, 0.6)
	var moved := false
	for i in 30:
		await process_frame
		if not button.scale.is_equal_approx(Vector2.ONE): moved = true
	check(moved != reduced, "ambient %s: idle pulse %s" % [_mode(reduced), "moves" if not reduced else "stays still"])
	check((button.get_node_or_null("Shine") != null) != reduced, "ambient %s: shine band %s" % [_mode(reduced), "exists" if not reduced else "absent"])
	button.queue_free()
	await process_frame

func _check_tooltip() -> void:
	var theme: Theme = Builder.build(Builder.DEFAULT_SKIN, "en")
	var color := theme.get_color("font_color", "TooltipLabel")
	check(theme.get_stylebox("panel", "TooltipPanel") is StyleBoxTexture and color.get_luminance() > 0.8, "tooltip: painted panel with light text")

func _check_focus() -> void:
	# 초점 테두리 색은 skin.json의 focus(없으면 #286778)다. 어두운 스킨은 밝은 초점 색을 지정한다.
	var theme: Theme = Builder.build(Builder.DEFAULT_SKIN, "en")
	var focus: StyleBox = theme.get_stylebox("focus", "Button")
	check(focus is StyleBoxFlat and (focus as StyleBoxFlat).border_color.is_equal_approx(Color("286778")), "focus: default skin keeps the soft-adventure focus color")

func _check_popup(reduced: bool) -> void:
	Juice.reduced_motion = reduced
	var popup: Control = PopupBase.instantiate()
	host.add_child(popup)
	popup.set_title("Title")
	var log: Array = []
	popup.opened.connect(func() -> void: log.append("opened"))
	popup.closed.connect(func() -> void: log.append("closed"))
	popup.open()
	check(popup.visible and popup.state == "opening", "popup %s: open shows dim and frame" % _mode(reduced))
	var frames := 0
	for i in 120:
		if log.has("opened"): break
		await process_frame
		frames += 1
	check(log == ["opened"] and popup.state == "open", "popup %s: opened signal once" % _mode(reduced))
	if reduced:
		check(frames <= 2, "popup reduced: opens within two frames (%d)" % frames)
	else:
		check(frames >= 3, "popup motion: enter animates over several frames (%d)" % frames)
	popup.open()
	check(log.count("opened") == 1, "popup %s: reopen while open is ignored" % _mode(reduced))
	popup.close()
	for i in 120:
		if log.has("closed"): break
		await process_frame
	check(log == ["opened", "closed"] and not popup.visible and popup.state == "closed", "popup %s: closed signal and hidden" % _mode(reduced))
	popup.queue_free()
	await process_frame

func _check_reward(reduced: bool) -> void:
	Juice.reduced_motion = reduced
	var ceremony: Control = RewardCeremony.instantiate()
	host.add_child(ceremony)
	var phases: Array = []
	var count := {"finished": 0}
	ceremony.finished.connect(func() -> void: count.finished += 1)
	ceremony.present([{"amount": 10, "label": "coins"}], "Reward")
	for i in 300:
		if phases.is_empty() or phases.back() != ceremony.phase: phases.append(ceremony.phase)
		if ceremony.phase == "done": break
		await process_frame
	check(phases == ["anticipation", "impact", "settle", "done"], "reward %s: phases in order %s" % [_mode(reduced), str(phases)])
	check(count.finished == 1, "reward %s: finished once" % _mode(reduced))
	check(ceremony.get_node("Stage/Burst") is CPUParticles2D, "reward: impact uses particles")
	# 중단 뒤 다시 present하면 퇴장 페이드가 새 연출을 지우지 않는다.
	ceremony.present([{"amount": 5}], "Again")
	await process_frame
	ceremony.skip()
	check(ceremony.phase == "done" and count.finished == 2, "reward %s: skip finishes once" % _mode(reduced))
	ceremony.present([{"amount": 7}], "Third")
	for i in (1 if reduced else 20): await process_frame
	check(ceremony.visible and ceremony.modulate.a > 0.99 and ceremony.phase != "done", "reward %s: present after skip stays visible" % _mode(reduced))
	ceremony.skip()
	ceremony.queue_free()
	await process_frame
	# 가로 568x320처럼 낮은 화면에서 초점이 아래쪽(0.86)이어도 연출 열이 화면 밖으로 나가지 않는다.
	var low: Control = RewardCeremony.instantiate()
	host.add_child(low)
	low.set_anchors_preset(Control.PRESET_TOP_LEFT)
	low.size = Vector2(568, 320)
	# 실제 결과 화면처럼 아이콘(64px)이 있는 카드가 기준이다.
	low.present([{"icon": load("res://addons/seorilabs_game/skins/soft_adventure/icon_coin.png"), "amount": 10, "label": "coins"}], "", null, null, 0, 0, Vector2(0.5, 0.86))
	await process_frame
	await process_frame
	var column: Control = low.get_node("Stage/Column")
	var bounds: Rect2 = low.get_global_rect()
	check(column.get_global_rect().end.y <= bounds.end.y + 0.5 and column.get_global_rect().position.y >= bounds.position.y - 0.5, "reward %s: low focus keeps the column on a 320px screen (column end %d)" % [_mode(reduced), int(column.get_global_rect().end.y)])
	low.skip()
	low.queue_free()
	await process_frame

func _check_sfx() -> void:
	var panel := Control.new()
	host.add_child(panel)
	for i in 3:
		panel.add_child(Button.new())
	var sfx = UiSfx.attach(panel)
	check(UiSfx.attach(panel) == sfx, "sfx: attach is idempotent")
	var late := Button.new()
	panel.add_child(late)
	var silent := Button.new()
	silent.set_meta("ui_sfx_silent", true)
	panel.add_child(silent)
	check(sfx.attached == 4, "sfx: every button is hooked, including late ones (%d)" % sfx.attached)
	for button in panel.get_children():
		if button is Button: button.button_down.emit()
	check(int(sfx.plays.get("tap", 0)) == 4, "sfx: tap plays per button down (%d)" % int(sfx.plays.get("tap", 0)))
	late.set_meta("ui_sfx_kind", "confirm")
	late.button_down.emit()
	check(int(sfx.plays.get("confirm", 0)) == 1, "sfx: button kind meta selects sound")
	check(UiSfx.KINDS.all(func(kind: String) -> bool: return sfx.streams.get(kind) != null), "sfx: all five streams load")
	panel.queue_free()

func _check_chip() -> void:
	var chip = CurrencyChip.instantiate()
	host.add_child(chip)
	chip.set_value(1234, false)
	check(chip.get_node("Row/Value").text == "1,234", "chip: thousands separator")
	check(chip.format_amount(123456) == "123.5K" and chip.format_amount(2500000) == "2.5M" and chip.format_amount(-42) == "-42", "chip: compact large amounts")
	check(chip.get_node("Row/Add") is Button and chip.get_node("Row/Icon") is TextureRect, "chip: icon + number + add button")
	chip.queue_free()

func _check_layers() -> void:
	var layers = HudLayers.instantiate()
	host.add_child(layers)
	# CanvasLayer는 테마 상속을 끊으므로 실제 화면처럼 층마다 스킨 테마를 준다.
	layers.apply_theme(host.theme)
	var indexes: Array = []
	for name in layers.NAMES:
		indexes.append((layers.get_node(name) as CanvasLayer).layer)
	check(indexes == [0, 10, 20, 30, 40, 50], "layers: six canvas layers in ascending order")
	var toast = layers.toast("Saved", 0.05)
	check(toast.get_parent().get_parent() == layers.layer("Toast") and toast.mouse_filter == Control.MOUSE_FILTER_IGNORE, "layers: toast lives in Toast layer stack and ignores input")
	await process_frame
	check(absf(toast.get_global_rect().get_center().x - layers.layer("Toast").size.x / 2.0) < 2.0, "layers: toast is centered horizontally (%s)" % str(toast.get_global_rect()))
	# 화면 폭보다 긴 문장은 칩이 화면 안(양옆 16px)에 머물고 줄을 바꾼다.
	var long_toast = layers.toast("Finish the current round first, then try this action again from the test room. ".repeat(4).strip_edges(), 30.0)
	await process_frame
	await process_frame
	var bounds: Rect2 = long_toast.get_global_rect()
	var width: float = layers.layer("Toast").size.x
	check(bounds.position.x >= 15.0 and bounds.end.x <= width - 15.0 and (long_toast.get_child(0) as Label).get_line_count() > 1, "layers: long toast wraps inside the screen (%s in %s)" % [str(bounds), str(width)])
	var long_label := long_toast.get_child(0) as Label
	var chip_text_color := long_label.get_theme_color("font_color", &"NumberLabel")
	check(long_label.theme_type_variation == &"NumberLabel" and long_label.get_theme_font("font") == long_label.get_theme_default_font() and long_label.get_theme_font("font") != (host.theme as Theme).get_font("font", "NumberLabel") and long_label.get_theme_color("font_color") == chip_text_color and long_label.get_theme_constant("outline_size") == long_label.get_theme_constant("outline_size", &"NumberLabel"), "layers: long toast switches only the font and keeps the chip text color and outline")
	# 화면 안에 드는 여러 줄 토스트는 1.1.0 모양(왼쪽 정렬, 폭 고정 없음, 숫자 글꼴) 그대로다.
	var lines_toast = layers.toast("Could not save.\nTap again to retry.", 30.0)
	await process_frame
	await process_frame
	var lines_label := lines_toast.get_child(0) as Label
	check(lines_label.custom_minimum_size.x == 0.0 and lines_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and lines_label.theme_type_variation == &"NumberLabel", "layers: fitting multi-line toast keeps the 1.1.0 look")
	long_toast.queue_free()
	lines_toast.queue_free()
	for i in 40: await process_frame
	check(not is_instance_valid(toast) or toast.is_queued_for_deletion() or toast.modulate.a < 0.05, "layers: toast leaves after its time")
	layers.queue_free()

func _mode(reduced: bool) -> String:
	return "reduced" if reduced else "motion"

## 효과음 포트 대역. sfx_enabled가 거짓이면 재생기는 효과음을 요청하지 않는다.
class FakeAudio extends RefCounted:
	var enabled := true
	var cues: Array = []
	var ducks: Array = []
	func play_cue(key: String, db: float) -> void: cues.append([key, db])
	func duck_music(db: float, seconds: float) -> void: ducks.append([db, seconds])
	func sfx_enabled() -> bool: return enabled

func _press(target: Control) -> void:
	var at := target.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event)
		await process_frame

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	await process_frame

## 시간은 _process에서만 흐른다. 프레임 시간에 흔들리지 않게 자동 처리를 끄고 같은 간격으로 직접 넘긴다.
func _advance(player: Control, seconds: float, step := 0.1) -> void:
	var left := seconds
	while left > 0.0001:
		player._process(minf(step, left))
		left -= step

func _check_cutscene(reduced: bool) -> void:
	var mode := "cutscene " + _mode(reduced)
	Juice.reduced_motion = reduced
	check(ResourceLoader.exists(CUTSCENE), mode + ": cutscene_player.tscn exists")
	if not ResourceLoader.exists(CUTSCENE): return
	# headless 루트 창은 64x64라 그 밖의 탭이 컨트롤에 닿지 않는다. 검사 화면 크기로 맞춘다.
	# 소비 게임의 기준 해상도(예: 1280x720) 늘이기 변환이 탭 좌표를 옮기지 않도록 배율을 끈다.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	var player: Control = load(CUTSCENE).instantiate()
	host.add_child(player)
	await process_frame
	player.set_process(false)
	# 기기 언어와 무관하게 영어 문구로 확인한다.
	player.text = func(en: String, _ko: String) -> String: return en
	var log := {"finished": [], "cuts": []}
	player.finished.connect(func(skipped: bool) -> void: log.finished.append(skipped))
	player.cut_changed.connect(func(index: int) -> void: log.cuts.append(index))
	var audio := FakeAudio.new()
	player.audio = audio
	check(player.state() == "idle" and not player.visible, mode + ": starts idle and hidden")
	# 다음 컷: 탭과 Space. 컷 끝에서 크레딧이 없으면 바로 끝난다.
	player.play({"id": "next", "cuts": [
		{"art": ART, "sub": ["First line", "첫 줄"], "dur": 30, "zoom": [1.0, 1.2], "flash": [0.0, 1.0], "shake": [0.0, 8.0], "sfx": [[0.0, "tap", -3.0]]},
		{"art": ART, "sub": ["Second line", "둘째 줄"], "dur": 30}]})
	check(player.state() == "cut" and player.current_cut() == 0 and log.cuts == [0] and player.visible, mode + ": play shows the first cut")
	await process_frame
	_advance(player, 0.8)
	var front: Control = player.get_node("Stage/Front")
	var flash: ColorRect = player.get_node("Flash")
	if reduced:
		check(front.scale.is_equal_approx(Vector2.ONE) and flash.color.a < 0.01, mode + ": no zoom, shake or flash (scale %s, flash %.2f)" % [str(front.scale), flash.color.a])
	else:
		check(front.scale.x > 1.0 and flash.color.a > 0.05, mode + ": zoom and flash run (scale %s, flash %.2f)" % [str(front.scale), flash.color.a])
	var subtitle: Label = player.get_node("Captions/Column/Subtitle")
	check(subtitle.text == "First line" and subtitle.is_visible_in_tree() and subtitle.modulate.a > 0.99, mode + ": subtitle visible (%s)" % subtitle.text)
	check(audio.cues == [["tap", -3.0]] and player.cue_log == PackedStringArray(["tap"]), mode + ": sfx cue requested once %s" % str(audio.cues))
	await _press(player)
	check(player.current_cut() == 1 and log.cuts == [0, 1], mode + ": tap goes to the next cut %s" % str(log.cuts))
	await _key(KEY_SPACE)
	check(player.state() == "idle" and log.finished == [false], mode + ": Space on the last cut finishes %s" % str(log.finished))
	# 잠긴 컷: 스킵·탭·Esc를 무시하고 시간이 다 되면 넘어간다. 다시 보기는 잠금을 풀어 준다.
	log.finished.clear(); log.cuts.clear()
	audio.enabled = false
	player.play({"id": "lock", "cuts": [{"art": ART, "sub": ["Locked", "잠김"], "dur": 0.35, "lock_skip": true, "sfx": [[0.0, "tap", 0.0]]}, {"art": ART, "dur": 30}]})
	var skip: Button = player.get_node("Skip")
	check(not player.can_skip() and skip.disabled, mode + ": locked cut cannot be skipped")
	player.request_skip()
	await _press(player)
	await _key(KEY_ESCAPE)
	await _key(KEY_ENTER)
	check(player.current_cut() == 0 and player.state() == "cut" and log.finished.is_empty(), mode + ": skip, tap, Esc and Enter are ignored on a locked cut")
	check(player.cue_log.is_empty() and player.get_node("Captions/Column/Subtitle").text == "Locked", mode + ": subtitle shows while sfx are off")
	_advance(player, 0.4)
	check(player.current_cut() == 1 and player.can_skip() and not skip.disabled, mode + ": locked cut advances by time")
	await _key(KEY_ESCAPE)
	check(log.finished == [true] and player.state() == "idle", mode + ": Esc skips an unlocked cut %s" % str(log.finished))
	player.play({"id": "lock", "cuts": [{"art": ART, "dur": 30, "lock_skip": true}]}, {"replay": true})
	check(player.can_skip(), mode + ": replay unlocks locked cuts")
	player.request_skip()
	audio.enabled = true
	# 크레딧, 카운트업 표기 주입, 그림 누락. 오류 줄을 남기지 않고 빈 배경과 자막으로 진행한다.
	log.finished.clear()
	player.number_format = func(value: int) -> String: return "N%d" % value
	var missing := "res://addons/seorilabs_game/ui_kit/missing-cut.png"
	player.play({"id": "end", "cuts": [{"art": missing, "sub": ["Paid in full", "모두 치렀다"], "dur": 30, "count_up": {"to": 12345}}],
		"credits": {"sections": [[["Made by", "만든 곳"], ["Example studio", "예제 스튜디오"]]], "dur": 30}})
	check(player.state() == "cut" and player.missing_art == PackedStringArray([missing]) and (player.get_node("Stage/Front") as TextureRect).texture == null, mode + ": missing art continues on a blank stage %s" % str(player.missing_art))
	var count: Label = player.get_node("Captions/Column/Count")
	_advance(player, 3.0)
	check(count.is_visible_in_tree() and count.text == "N12345", mode + ": count-up ends with the injected format (%s)" % count.text)
	player.request_next()
	check(player.state() == "credits" and player.get_node("Credits").visible, mode + ": last cut opens credits")
	var roll_text := ""
	for label in player.get_node("Credits/Roll").find_children("*", "Label", true, false):
		roll_text += (label as Label).text + "\n"
	check("Made by" in roll_text and "Example studio" in roll_text, mode + ": credits list sections")
	check(player.can_skip(), mode + ": credits can be skipped")
	player.request_skip()
	var proceed: Button = player.get_node("End/Continue")
	check(player.state() == "end" and proceed.is_visible_in_tree() and not skip.visible, mode + ": skip from credits opens the end screen")
	await process_frame
	await _press(proceed)
	check(log.finished == [true] and player.state() == "idle", mode + ": continue finishes after skipped credits %s" % str(log.finished))
	# 끝 화면에서 뒤로 가기·Esc는 계속하기와 같다. 아무 반응이 없으면 안 된다.
	log.finished.clear()
	player.play({"id": "back", "cuts": [{"art": ART, "dur": 30}], "credits": {"sections": [[["Made by", "만든 곳"], ["Example studio", "예제 스튜디오"]]], "dur": 30}})
	player.request_skip()
	check(player.state() == "end", mode + ": skip with credits reaches the end screen before back")
	player.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(log.finished == [true] and player.state() == "idle", mode + ": back on the end screen continues %s" % str(log.finished))
	# 길이 0인 컷만 있으면 play() 안에서 바로 끝난다. finished 는 그 안에서 한 번 나온다.
	log.finished.clear()
	player.play({"id": "flash", "cuts": [{"art": ART, "dur": 0}]})
	check(log.finished == [false] and player.state() == "idle", mode + ": zero-length cut finishes inside play %s" % str(log.finished))
	# 포커스를 잃으면 같은 컷에서 멈추고, 돌아오면 이어 간다. 한 프레임 시간은 0.1초로 자른다.
	log.cuts.clear()
	player.play({"id": "focus", "cuts": [{"art": ART, "dur": 0.35}, {"art": ART, "dur": 30}]})
	player._process(5.0)
	check(player.current_cut() == 0, mode + ": one long frame advances at most 0.1s")
	player.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_advance(player, 2.0)
	check(player.paused and player.current_cut() == 0, mode + ": focus loss pauses on the same cut")
	player.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not player.paused and player.current_cut() == 0, mode + ": focus return resumes the same cut")
	player.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_advance(player, 1.0)
	player.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(player.current_cut() == 0, mode + ": window blur also pauses")
	_advance(player, 0.3)
	check(player.current_cut() == 1 and log.cuts == [0, 1], mode + ": resumed cut finishes its remaining time %s" % str(log.cuts))
	player.request_skip()
	check(audio.ducks.size() >= 2 and audio.ducks.back() == [0.0, 1.2], mode + ": music ducks while playing and returns at the end")
	player.queue_free()
	await process_frame
