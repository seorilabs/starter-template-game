extends Control
## 테스트실: 기획자와 개발자가 디버그·playtest 빌드에서 쓰는 행동 버튼, 플레이 시점 프리셋, 연출 다시 보기, 이번 빌드에서 봐줄 점.
## class_name을 쓰지 않는다. 호스트는 OS.is_debug_build() 또는 playtest 기능 태그가 있고 파일이 있을 때만 load()로 연다. 출시 export는 dev/를 뺀다.
## 등록한 Callable은 {ok, message_pair, blocked_reason_pair}를 돌려준다. 막히면 저장을 바꾸지 않고 이유를 토스트로 알린다.
## 덮어쓰기(confirm: "double_tap", 시점 프리셋)는 첫 누름에서 "한 번 더 누르면 적용"으로 바뀌고 두 번째 누름에 적용한다.
## 결과 줄은 두 줄 고정 높이라 결과가 바뀌어도 버튼이 움직이지 않는다.
signal opened
signal closed
const Locale = preload("res://addons/seorilabs_game/locales/localization.gd")
const Juice = preload("res://addons/seorilabs_game/ui_kit/juice.gd")
const CONFIRM := ["Tap again to apply", "한 번 더 누르면 적용"]
## (en, ko) -> String. 비우면 기기 언어로 Locale.text를 부른다.
var text: Callable
## HudLayers. 막힌 이유를 toast로 알린다. 없으면 결과 줄에 쓴다.
var layers: Node
## (script, options) -> {ok, blocked_reason_pair}. 연출 다시 보기에 쓴다. 저장을 바꾸지 않는 재생이어야 한다.
var play_cutscene: Callable
## 가로 전용 게임이 축소 화면에서 쓰는 UI 배율(outgame_main._ui_scale).
var ui_scale := 1.0
var _actions: Array[Dictionary] = []
var _snapshots: Array = []
var _apply_snapshot: Callable
var _replays: Array[Dictionary] = []
var _notes: Array = []
var _armed := ""
## id → 버튼. 노드 이름 정리 규칙이나 find_child 와일드카드(*, ?)와 무관하게 정확히 찾는다.
var _buttons: Dictionary = {}
var _result: Variant = ["Action results appear here.", "행동 결과가 여기에 나와요."]

func _ready() -> void:
	visible = false
	if not text.is_valid():
		var locale := Locale.resolve("system", OS.get_locale())
		text = func(en: String, ko: String) -> String: return Locale.text(en, ko, locale)
	$Frame/Body/Header/test_room_close.pressed.connect(close)
	$Frame/Body/Header/test_room_close.set_meta("ui_sfx_kind", "cancel")
	resized.connect(_layout)

## 행동 버튼. options.confirm이 "double_tap"이면 두 번 눌러야 실행한다. options.group([en, ko])이 같은 행동끼리 묶는다.
func register_action(id: String, label_pair: Array, callable: Callable, options := {}) -> void:
	_actions = _actions.filter(func(entry: Dictionary) -> bool: return entry.id != id)
	_actions.append({"id": id, "label": label_pair, "callable": callable, "confirm": str(options.get("confirm", "none")), "group": options.get("group", ["Actions", "행동"])})
	_refresh()

## 플레이 시점 프리셋 [{id, label_pair, minutes}]. 진행을 덮어쓰므로 항상 두 번 눌러야 apply(snapshot)를 부른다.
func register_snapshots(list: Array, apply: Callable) -> void:
	_snapshots = list.duplicate(true)
	_apply_snapshot = apply
	_refresh()

## 저장을 바꾸지 않는 연출 다시 보기.
func register_replay(id: String, label_pair: Array, script: Dictionary) -> void:
	_replays = _replays.filter(func(entry: Dictionary) -> bool: return entry.id != id)
	_replays.append({"id": id, "label": label_pair, "script": script})
	_refresh()

## 이번 빌드에서 봐줄 점. 줄마다 [en, ko] 또는 문자열.
func set_notes(lines: Array) -> void:
	_notes = lines.duplicate(true)
	_refresh()

func is_open() -> bool:
	return visible

func open() -> void:
	_rebuild()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Juice.pop_in($Frame, 0.18, 0.96)
	opened.emit()

func close() -> void:
	if not visible:
		return
	_disarm()
	visible = false
	closed.emit()

func toggle() -> void:
	if visible: close()
	else: open()

## 결과 줄에 지금 보이는 문구.
func result_text() -> String:
	return $Frame/Body/Result.text

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible:
		close()

func _say(value: Variant) -> String:
	if value is Array and value.size() >= 2:
		return str(text.call(str(value[0]), str(value[1])))
	if value is Array and value.size() == 1:
		return str(value[0])
	return str(value)

func _scale() -> float:
	return maxf(ui_scale, 1.0)

func _refresh() -> void:
	if visible:
		_rebuild()

func _layout() -> void:
	if not is_node_ready():
		return
	var s := _scale()
	var frame: PanelContainer = $Frame
	var inset := 12.0 * s
	var width := minf(size.x - inset * 2.0, 760.0 * s)
	frame.offset_left = (size.x - width) * 0.5
	frame.offset_right = -frame.offset_left
	frame.offset_top = inset * 0.75
	frame.offset_bottom = -inset * 0.75
	# 그린 프레임의 테두리 띠에 글자와 버튼이 붙지 않게 스킨의 내용 여백보다 조금 더 안쪽에 둔다(모달 화면과 같은 여백).
	frame.remove_theme_stylebox_override("panel")
	var skin := frame.get_theme_stylebox("panel").duplicate() as StyleBox
	if skin != null:
		skin.content_margin_left = skin.get_content_margin(SIDE_LEFT) + 10.0 * s
		skin.content_margin_right = skin.get_content_margin(SIDE_RIGHT) + 10.0 * s
		skin.content_margin_top = skin.get_content_margin(SIDE_TOP) + 4.0 * s
		skin.content_margin_bottom = skin.get_content_margin(SIDE_BOTTOM) + 4.0 * s
		frame.add_theme_stylebox_override("panel", skin)
	$Frame/Body/Header/Title.add_theme_font_size_override("font_size", roundi(22.0 * s))
	# 터치 목표는 56px 이상이다(가로 캠프와 같은 기준).
	$Frame/Body/Header/test_room_close.custom_minimum_size = Vector2(56.0, 56.0) * s
	var result: Label = $Frame/Body/Result
	result.add_theme_font_size_override("font_size", roundi(15.0 * s))
	var font := result.get_theme_font("font")
	var line := font.get_height(roundi(15.0 * s)) + result.get_theme_constant("line_spacing")
	result.custom_minimum_size.y = ceilf(line * 2.0)
	var columns := 2 if width < 560.0 * s else 3
	for grid in $Frame/Body/Scroll/List.find_children("*", "GridContainer", true, false):
		(grid as GridContainer).columns = columns

func _rebuild() -> void:
	_buttons.clear()
	_armed = ""
	_layout()
	var s := _scale()
	var list: VBoxContainer = $Frame/Body/Scroll/List
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	list.add_theme_constant_override("separation", roundi(10.0 * s))
	$Frame/Body/Header/Title.text = _say(["Test room", "테스트실"])
	# 순서는 행동, 플레이 시점, 다시 보기, 봐줄 점이다. 가로 화면처럼 낮은 화면에서도 첫 화면에 버튼이 보인다.
	var groups: Array = []
	for entry in _actions:
		if not groups.has(entry.group): groups.append(entry.group)
	for group in groups:
		var grid := _grid(_section(group))
		for entry in _actions:
			if entry.group != group: continue
			var item: Dictionary = entry
			_button("test_action_" + str(item.id), item.label, grid, func() -> void: _run_action(item))
	if not _snapshots.is_empty():
		var grid := _grid(_section(["Play-time presets", "플레이 시점"]))
		for snapshot in _snapshots:
			var item: Dictionary = snapshot
			_button("test_snapshot_" + str(item.get("id", "")), item.get("label_pair", [str(item.get("id", ""))]), grid, func() -> void: _run_snapshot(item))
	if not _replays.is_empty():
		var grid := _grid(_section(["Replay scenes", "연출 다시 보기"]))
		for entry in _replays:
			var item: Dictionary = entry
			_button("test_replay_" + str(item.id), item.label, grid, func() -> void: _run_replay(item))
	if not _notes.is_empty():
		var notes := _section(["Check in this build", "이번 빌드에서 봐줄 점"])
		for line in _notes:
			notes.add_child(_label("• " + _say(line), 14))
	_show_result()

func _section(title: Variant) -> VBoxContainer:
	var s := _scale()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(6.0 * s))
	$Frame/Body/Scroll/List.add_child(box)
	var head := _label(_say(title), 17)
	head.theme_type_variation = &"TitleLabel"
	head.add_theme_font_size_override("font_size", roundi(17.0 * s))
	box.add_child(head)
	return box

func _grid(parent: Control) -> GridContainer:
	var s := _scale()
	var grid := GridContainer.new()
	grid.columns = 2 if $Frame.size.x < 560.0 * s or $Frame.size.x == 0.0 else 3
	grid.add_theme_constant_override("h_separation", roundi(8.0 * s))
	grid.add_theme_constant_override("v_separation", roundi(8.0 * s))
	parent.add_child(grid)
	return grid

func _label(value: String, base: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", roundi(base * _scale()))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(id: String, label_pair: Variant, parent: Control, action: Callable) -> Button:
	var s := _scale()
	var button := Button.new()
	button.name = _node_id(id)
	_buttons[id] = button
	button.text = _say(label_pair)
	button.set_meta("label_pair", label_pair)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0.0, 56.0 * s)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.add_theme_font_size_override("font_size", roundi(15.0 * s))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

## 두 번 눌러 적용: 같은 버튼을 다시 누르면 참. 다른 버튼을 누르거나 닫으면 무장이 풀린다.
func _confirmed(id: String) -> bool:
	if _armed == id:
		_disarm()
		return true
	_disarm()
	var button := _buttons.get(id) as Button
	if button == null or not is_instance_valid(button):
		return false
	_armed = id
	button.text = _say(CONFIRM)
	button.theme_type_variation = &"PrimaryButton"
	return false

func _disarm() -> void:
	if _armed.is_empty():
		return
	var button := _buttons.get(_armed) as Button
	_armed = ""
	if button != null and is_instance_valid(button):
		button.text = _say(button.get_meta("label_pair", ""))
		button.theme_type_variation = &""

func _run_action(entry: Dictionary) -> void:
	var id := "test_action_" + str(entry.id)
	if entry.confirm == "double_tap":
		if not _confirmed(id): return
	else:
		_disarm()
	_report(entry.callable.call())

func _run_snapshot(snapshot: Dictionary) -> void:
	if not _confirmed("test_snapshot_" + str(snapshot.get("id", ""))) or not _apply_snapshot.is_valid():
		return
	_report(_apply_snapshot.call(snapshot))

func _run_replay(entry: Dictionary) -> void:
	_disarm()
	var result: Variant = play_cutscene.call(entry.script, {"replay": true}) if play_cutscene.is_valid() else {"ok": false, "blocked_reason_pair": ["Scenes cannot play here", "여기서는 연출을 재생할 수 없어요"]}
	if result is Dictionary and result.get("ok", false):
		close()
	else:
		_report(result)

## 노드 이름에 쓸 수 없는 글자(. : @ / " %)는 _로 바꾼다. 버튼 이름과 두 번 누름 찾기가 같은 규칙을 쓴다.
func _node_id(id: String) -> String:
	return id.validate_node_name()

## 행동이 값을 돌려주지 않으면(null) 실행된 것으로 보고 "완료"를 적는다.
func _report(result: Variant) -> void:
	if result == null:
		result = {"ok": true}
	var outcome: Dictionary = result if result is Dictionary else {}
	if outcome.get("ok", false):
		_result = outcome.get("message_pair", ["Done", "완료"])
		_show_result()
		return
	var reason := _say(outcome.get("blocked_reason_pair", ["Not available right now", "지금은 할 수 없어요"]))
	if layers != null and layers.has_method("toast"):
		layers.toast(reason, 2.0)
	else:
		_result = reason
		_show_result()

func _show_result() -> void:
	$Frame/Body/Result.text = _say(_result)
