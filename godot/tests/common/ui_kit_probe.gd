extends SceneTree
## ui_kit 계약 검사: 테마 재료, 팝업 열기·닫기, 보상 3단계, 버튼 효과음 연결, 재화 칩 표기, HUD 층, reduced_motion.
const Builder = preload("res://addons/seorilabs_game/ui_kit/theme_builder.gd")
const Juice = preload("res://addons/seorilabs_game/ui_kit/juice.gd")
const UiSfx = preload("res://addons/seorilabs_game/ui_kit/ui_sfx.gd")
const PopupBase = preload("res://addons/seorilabs_game/ui_kit/popup_base.tscn")
const RewardCeremony = preload("res://addons/seorilabs_game/ui_kit/reward_ceremony.tscn")
const CurrencyChip = preload("res://addons/seorilabs_game/ui_kit/currency_chip.tscn")
const HudLayers = preload("res://addons/seorilabs_game/ui_kit/hud_layers.tscn")
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
	await _check_popup(false)
	await _check_popup(true)
	await _check_reward(false)
	await _check_reward(true)
	_check_sfx()
	_check_chip()
	await _check_layers()
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
	low.present([{"icon": load("res://addons/seorilabs_game/skins/soft_adventure/icon_coin.svg"), "amount": 10, "label": "coins"}], "", null, null, 0, 0, Vector2(0.5, 0.86))
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
	var indexes: Array = []
	for name in layers.NAMES:
		indexes.append((layers.get_node(name) as CanvasLayer).layer)
	check(indexes == [0, 10, 20, 30, 40, 50], "layers: six canvas layers in ascending order")
	var toast = layers.toast("Saved", 0.05)
	check(toast.get_parent().get_parent() == layers.layer("Toast") and toast.mouse_filter == Control.MOUSE_FILTER_IGNORE, "layers: toast lives in Toast layer stack and ignores input")
	await process_frame
	check(absf(toast.get_global_rect().get_center().x - layers.layer("Toast").size.x / 2.0) < 2.0, "layers: toast is centered horizontally (%s)" % str(toast.get_global_rect()))
	for i in 40: await process_frame
	check(not is_instance_valid(toast) or toast.is_queued_for_deletion() or toast.modulate.a < 0.05, "layers: toast leaves after its time")
	layers.queue_free()

func _mode(reduced: bool) -> String:
	return "reduced" if reduced else "motion"
