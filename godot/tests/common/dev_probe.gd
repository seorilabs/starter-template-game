extends SceneTree
## 테스트실 계약 검사: 두 번 눌러 적용하는 덮어쓰기, 고정 높이 결과 줄, 막힌 행동의 토스트와 저장 무변경, 연출 다시 보기 뒤 저장 바이트 동일.
## 테스트실은 디버그·playtest 빌드에서만 런타임 load()로 연다. 출시 export에는 dev/가 없다.
#   godot --headless --path . --script res://tests/common/dev_probe.gd -- --out build/dev.json
const State = preload("res://addons/seorilabs_game/flow/state.gd")
const Juice = preload("res://addons/seorilabs_game/ui_kit/juice.gd")
const Builder = preload("res://addons/seorilabs_game/ui_kit/theme_builder.gd")
const HudLayers = preload("res://addons/seorilabs_game/ui_kit/hud_layers.tscn")
const CutscenePlayer = preload("res://addons/seorilabs_game/ui_kit/cutscene_player.tscn")
const ROOM := "res://addons/seorilabs_game/dev/test_room.tscn"
const ART := "res://addons/seorilabs_game/skins/soft_adventure/camp.svg"
var checks: Array = []
var host: Control
var layers: Node
var player: Control
var room: Control
var state
var path := ""

func check(value: bool, name: String) -> void:
	checks.append({"name": name, "passed": value})

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# headless 루트 창은 64x64라 그 밖의 탭이 컨트롤에 닿지 않는다. 검사 화면 크기로 맞춘다.
	# 소비 게임의 기준 해상도(예: 1280x720) 늘이기 변환이 탭 좌표를 옮기지 않도록 배율을 끈다.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	host = Control.new()
	host.size = Vector2(390, 844)
	root.add_child(host)
	host.theme = load(Builder.DEFAULT_SKIN.path_join("theme.tres"))
	check(ResourceLoader.exists(ROOM), "test_room.tscn exists for debug runs")
	if ResourceLoader.exists(ROOM):
		await _check_room()
	var failed := checks.filter(func(item: Dictionary) -> bool: return not item.passed)
	var result := {"kind": "dev-probe", "passed": failed.is_empty(), "checks": checks, "failures": failed}
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
		print("DEV FAILED: ", failure.name)
	print("Dev probe: %d checks, %d failed" % [checks.size(), failed.size()])
	quit(0 if failed.is_empty() else 1)

func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)

func _press(target: Control) -> bool:
	if target == null or not target.is_visible_in_tree() or (target is BaseButton and target.disabled):
		return false
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
	return true

func _node(name: String) -> Control:
	return room.find_child(name, true, false) as Control

func _toast_texts() -> Array:
	var texts: Array = []
	for label in layers.layer("Toast").find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion(): texts.append((label as Label).text)
	return texts

func _coins(amount: int, message: Array) -> Dictionary:
	var next: Dictionary = state.data.duplicate(true)
	next.coins = amount
	if not state.commit(next):
		return {"ok": false, "blocked_reason_pair": ["Could not save", "저장하지 못했어요"]}
	return {"ok": true, "message_pair": message}

func _check_room() -> void:
	path = "user://dev-probe-%d.json" % Time.get_ticks_usec()
	state = State.new(path)
	state.load_state()
	state.commit(state.data)
	layers = HudLayers.instantiate()
	host.add_child(layers)
	layers.apply_theme(host.theme)
	player = CutscenePlayer.instantiate()
	layers.layer("Ftue").add_child(player)
	room = load(ROOM).instantiate()
	room.layers = layers
	room.text = func(en: String, _ko: String) -> String: return en
	var round_running := {"value": false}
	room.play_cutscene = func(script: Dictionary, options: Dictionary) -> Dictionary:
		if round_running.value or player.state() != "idle":
			return {"ok": false, "blocked_reason_pair": ["Finish the round before replaying", "판을 끝낸 뒤 다시 보세요"]}
		player.play(script, options)
		return {"ok": true}
	layers.layer("Popup").add_child(room)
	var applied: Array = []
	var long_message := ["Applied a long result that wraps over more than two lines so the fixed result line has to clip it instead of pushing the buttons down", "두 줄을 넘는 긴 결과 문구도 결과 줄이 잘라서 보여 주고 아래 버튼을 밀어내지 않아야 합니다. 한 줄 더 들어가도록 길게 씁니다"]
	room.register_action("coins", ["Add 100 coins", "코인 100 추가"], func() -> Dictionary: return _coins(int(state.data.coins) + 100, ["Coins +100", "코인 +100"]), {"group": ["Economy", "재화"]})
	room.register_action("long", ["Long result", "긴 결과"], func() -> Dictionary: return {"ok": true, "message_pair": long_message}, {"group": ["Economy", "재화"]})
	room.register_action("reset", ["Reset coins", "코인 초기화"], func() -> Dictionary: return _coins(0, ["Coins reset", "코인 초기화됨"]), {"confirm": "double_tap", "group": ["Economy", "재화"]})
	room.register_action("blocked", ["Start a round", "판 시작"], func() -> Dictionary: return {"ok": false, "blocked_reason_pair": ["Finish the current round first", "진행 중인 판을 먼저 끝내 주세요"]}, {"group": ["Round", "판"]})
	room.register_snapshots([{"id": "m10", "label_pair": ["10 min", "10분"], "minutes": 10}, {"id": "m30", "label_pair": ["30 min", "30분"], "minutes": 30}], func(snapshot: Dictionary) -> Dictionary:
		applied.append(snapshot.id)
		return _coins(int(snapshot.minutes) * 100, ["Applied %d min" % int(snapshot.minutes), "%d분 시점 적용" % int(snapshot.minutes)]))
	room.register_replay("intro", ["Replay intro", "프롤로그 다시 보기"], {"id": "intro", "cuts": [{"art": ART, "sub": ["Once upon a time", "옛날 옛적에"], "dur": 30}]})
	room.set_notes([["Check the intro pacing", "프롤로그 속도를 봐 주세요"], "Plain note line"])
	check(not room.is_open() and not room.visible, "room starts closed")
	room.open()
	for i in 4: await process_frame
	check(room.is_open() and room.visible, "open shows the room")
	check(_node("test_action_coins") != null and _node("test_snapshot_m10") != null and _node("test_replay_intro") != null, "registered actions, presets and replays have buttons")
	var notes := ""
	for label in room.find_children("*", "Label", true, false): notes += (label as Label).text + "\n"
	check("Check the intro pacing" in notes and "Plain note line" in notes, "build notes are listed")
	var result: Label = room.get_node("Frame/Body/Result")
	var height := result.size.y
	# 결과 줄 아래 목록 영역이 밀리지 않는지 본다. 버튼 자체는 누른 버튼으로 따라가는 스크롤 때문에 움직일 수 있다(글꼴·화면에 따라 다름).
	var scroll_area: Control = room.get_node("Frame/Body/Scroll")
	var anchor_y := scroll_area.get_global_rect().position.y
	check(await _press(_node("test_action_coins")) and int(state.data.coins) == 100 and "Coins +100" in result.text, "plain action applies at once (%s)" % result.text)
	# 시점 적용은 덮어쓰기라 첫 누름에서 무장만 하고 두 번째에 적용한다. 다른 버튼을 누르면 무장이 풀린다.
	var snap: Button = _node("test_snapshot_m10")
	var label_before := snap.text
	var before := _bytes()
	check(await _press(snap) and applied.is_empty() and snap.text != label_before and _bytes() == before, "first tap arms the preset without saving (%s)" % snap.text)
	check(await _press(_node("test_snapshot_m30")) and applied.is_empty() and snap.text == label_before, "tapping another preset disarms the first")
	check(await _press(_node("test_snapshot_m30")) and applied == ["m30"] and int(state.data.coins) == 3000, "second tap applies the preset %s" % str(applied))
	check(await _press(snap) and await _press(snap) and applied == ["m30", "m10"] and int(state.data.coins) == 1000, "preset applies on a fresh double tap")
	var reset: Button = _node("test_action_reset")
	check(await _press(reset) and int(state.data.coins) == 1000, "double-tap action waits for the second tap")
	check(await _press(reset) and int(state.data.coins) == 0, "double-tap action applies on the second tap")
	check(await _press(_node("test_action_long")) and absf(result.size.y - height) < 0.5 and result.get_line_count() > 2 and result.get_visible_line_count() <= 2, "result line keeps a fixed two-line height (%.1f -> %.1f)" % [height, result.size.y])
	check(absf(scroll_area.get_global_rect().position.y - anchor_y) < 0.5, "button list does not move when the result changes")
	# 막힌 행동은 저장을 바꾸지 않고 이유를 토스트로 알린다.
	before = _bytes()
	var shown_result := result.text
	check(await _press(_node("test_action_blocked")) and _toast_texts().has("Finish the current round first"), "blocked action shows its reason as a toast %s" % str(_toast_texts()))
	# 390 폭에서 숫자 글꼴로는 넘치는 문장이 본문 글꼴 한 줄로 들어가 테스트실 제목·닫기를 덮지 않는다.
	await process_frame
	await process_frame
	var reason_label: Label = null
	for label in layers.layer("Toast").find_children("*", "Label", true, false):
		if (label as Label).text == "Finish the current round first": reason_label = label
	check(reason_label != null and reason_label.get_line_count() == 1 and reason_label.get_theme_font("font") == reason_label.get_theme_default_font(), "blocked reason fits one line in the body font at 390")
	check(_bytes() == before and result.text == shown_result, "blocked action leaves the save and result line unchanged")
	# 연출 다시 보기는 저장을 바꾸지 않는다. 제품이 막으면(판 진행 중) 재생하지 않고 이유를 알린다.
	before = _bytes()
	var data_before: Dictionary = state.data.duplicate(true)
	round_running.value = true
	check(await _press(_node("test_replay_intro")) and player.state() == "idle" and room.is_open() and _toast_texts().has("Finish the round before replaying"), "blocked replay keeps the room open and shows the reason")
	round_running.value = false
	check(await _press(_node("test_replay_intro")) and player.state() == "cut" and not room.is_open(), "replay closes the room and plays the scene")
	player.request_skip()
	for i in 3: await process_frame
	check(player.state() == "idle" and _bytes() == before and state.data == data_before, "replay leaves the save bytes identical")
	# 닫기 버튼과 Esc
	room.open()
	await process_frame
	check(await _press(_node("test_room_close")) and not room.is_open(), "close button closes the room")
	room.open()
	await process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	check(not room.is_open(), "Esc closes the room")
	# 값을 돌려주지 않는 행동은 완료로 본다. 노드 이름 정리 뒤 같아지는 id(a.b, a_b)와 와일드카드 글자도 자기 버튼을 무장한다.
	var ran := []
	room.register_action("silent", ["Silent", "조용히"], func() -> void: ran.append(true), {"group": ["Edge", "경계"]})
	room.register_action("a.b", ["Dot id", "점 id"], func() -> Dictionary: return {"ok": true, "message_pair": ["Dot applied", "점 적용"]}, {"confirm": "double_tap", "group": ["Edge", "경계"]})
	room.register_action("a_b", ["Underscore id", "밑줄 id"], func() -> Dictionary: return {"ok": true, "message_pair": ["Underscore applied", "밑줄 적용"]}, {"confirm": "double_tap", "group": ["Edge", "경계"]})
	room.register_action("w*?", ["Wildcard id", "와일드카드 id"], func() -> Dictionary: return {"ok": true, "message_pair": ["Wildcard applied", "와일드카드 적용"]}, {"confirm": "double_tap", "group": ["Edge", "경계"]})
	room.open()
	await process_frame
	var buttons: Dictionary = room._buttons
	check(await _press(buttons["test_action_silent"]) and ran == [true] and "Done" in result.text and not _toast_texts().has("Not available right now"), "action without a return value counts as done (%s)" % result.text)
	var dot: Button = buttons["test_action_a.b"]
	var under: Button = buttons["test_action_a_b"]
	check(await _press(under) and under.text == "Tap again to apply" and dot.text != "Tap again to apply", "a_b arms its own button, not a.b")
	check(await _press(under) and "Underscore applied" in result.text, "a_b applies on the second tap")
	var wild: Button = buttons["test_action_w*?"]
	check(await _press(wild) and wild.text == "Tap again to apply" and await _press(wild) and "Wildcard applied" in result.text, "ids with * and ? arm and apply")
	room.close()
	room.queue_free()
	player.queue_free()
	layers.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
