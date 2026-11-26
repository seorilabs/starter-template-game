extends Control
## 컷신 재생기. 컷(그림, 자막, 줌, 이동, 효과음, 번쩍임, 흔들림, 타이틀, 카운트업)을 차례로 보여 주고 선택으로 크레딧과 끝 화면을 붙인다.
## 상태는 idle → cut → credits → end다. 시간은 _process에서만 흐르고 한 프레임을 0.1초로 자르며 앱·창 포커스를 잃으면 같은 컷에서 멈춘다.
## 입력은 탭·클릭·Space·Enter가 다음 컷, Esc·뒤로 가기가 스킵이다. lock_skip 컷에서는 둘 다 무시한다(다시 보기는 예외).
## 제품 이름, 색, 효과음, 문구, 숫자 표기, 그림 읽기는 주입하고 서체는 테마 변형(DisplayLabel, NumberLabel)을 따른다.
##
## script = {id, cuts: [{art, sub: [en, ko], dur, zoom: [시작, 끝], pan: [[x, y], [x, y]], sfx: [[t, key, db]], lock_skip,
##           flash: [t, 길이], shake: [t, 세기], vignette, title: true | [en, ko], count_up: {to}, music_db}],
##           credits: {sections: [[[en, ko], [en, ko]]], dur}}   # credits는 선택
## options = {replay: bool}
signal finished(skipped: bool)
signal cut_changed(index: int)
const Juice = preload("res://addons/seorilabs_game/ui_kit/juice.gd")
const Locale = preload("res://addons/seorilabs_game/locales/localization.gd")
const CurrencyChip = preload("res://addons/seorilabs_game/ui_kit/currency_chip.gd")
const MAX_STEP := 0.1
const OVERSCAN := 1.05
const CROSSFADE := 0.3
const SUB_DELAY := 0.35
const SUB_FADE := 0.35
const COUNT_DELAY := 0.6
const COUNT_SECONDS := 2.0
const CREDITS_SECONDS := 15.0
const OUTRO_SECONDS := 0.4
## 효과음·음악 포트: play_cue(key, db), duck_music(db, seconds), sfx_enabled(). null이면 무음으로 재생한다.
var audio: Object
## (en, ko) -> String. 비우면 기기 언어로 Locale.text를 부른다. 호스트는 자기 언어 설정을 묶어 넣는다.
var text: Callable
## int -> String. count_up 숫자 표기. 비우면 재화 칩 표기(1,234, 12.5K)를 쓴다.
var number_format: Callable
## String -> Texture2D 또는 null. 비우면 파일이 있을 때만 load한다.
var art_loader: Callable
## 타이틀 카드(cut.title)에 쓰는 제품 이름.
var title_text := ""
## 가로 전용 게임이 축소 화면에서 쓰는 UI 배율(outgame_main._ui_scale). 글자와 버튼 크기에 곱한다.
var ui_scale := 1.0
## 제품이 바꾸는 색. 어두운 컷 위에서도 읽히도록 자막은 밝은 글자에 어두운 외곽선을 둔다.
var colors := {"backdrop": Color("07050a"), "subtitle": Color("ffffff"), "outline": Color("0b0709"), "title": Color("ffd36a"),
	"title_shadow": Color(0.9, 0.22, 0.08, 0.85), "accent": Color("ffd36a"), "credits_head": Color("ffd36a"), "credits_body": Color("ede2d6")}
var skip_text := ["Skip", "건너뛰기"]
var continue_text := ["Continue", "계속하기"]
## 찾지 못한 그림 경로. 오류 대신 빈 배경과 자막으로 진행하고 여기에 남긴다.
var missing_art := PackedStringArray()
## 실제로 재생을 요청한 효과음 키. 효과음이 꺼져 있으면 쌓이지 않는다.
var cue_log := PackedStringArray()
var paused := false
var _cuts: Array = []
var _credits: Dictionary = {}
var _replay := false
var _state := "idle"
var _index := -1
var _t := 0.0
var _fade := 0.0
var _skipped := false
var _fired: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _outro: Tween
var _front: TextureRect
var _back: TextureRect

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 20261126
	_front = $Stage/Front
	_back = $Stage/Back
	if not text.is_valid():
		var locale := Locale.resolve("system", OS.get_locale())
		text = func(en: String, ko: String) -> String: return Locale.text(en, ko, locale)
	if not number_format.is_valid():
		number_format = func(value: int) -> String: return CurrencyChip.format_amount(value)
	if not art_loader.is_valid():
		art_loader = func(path: String) -> Texture2D: return load(path) as Texture2D if ResourceLoader.exists(path) else null
	$Skip.pressed.connect(request_skip)
	$End/Continue.pressed.connect(request_next)
	resized.connect(_layout)

func play(script: Dictionary, options := {}) -> void:
	if _outro != null and _outro.is_valid():
		_outro.kill()
	_cuts = script.get("cuts", []) if script.get("cuts") is Array else []
	_credits = script.get("credits", {}) if script.get("credits") is Dictionary else {}
	_replay = bool(options.get("replay", false))
	_skipped = false
	paused = false
	missing_art.clear()
	cue_log.clear()
	visible = true
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 아래 화면의 초점 버튼이 Space·Enter를 받지 않게 한다.
	if is_inside_tree():
		get_viewport().gui_release_focus()
	_front.texture = null
	_back.texture = null
	_front.modulate.a = 1.0
	$Backdrop.color = colors.backdrop
	$Credits.visible = false
	$End.visible = false
	$Captions.visible = true
	$Skip.text = _say(skip_text)
	$End/Continue.text = _say(continue_text)
	_layout()
	_duck(-9.0, 0.8)
	if not _cuts.is_empty():
		_show_cut(0)
	elif not _credits.is_empty():
		_start_credits()
	else:
		_state = "cut"
		_finish(false)

func state() -> String:
	return _state

func current_cut() -> int:
	return _index if _state == "cut" else -1

func can_skip() -> bool:
	if _state == "cut":
		return _replay or not bool(_cut().get("lock_skip", false))
	return _state == "credits"

## 탭·클릭·Space·Enter: 다음 컷. 크레딧 중이면 끝 화면, 끝 화면이면 계속하기.
func request_next() -> void:
	# 입력이 들어왔다면 창에 다시 포커스가 있으므로 멈춘 컷을 이어 간다.
	paused = false
	match _state:
		"cut":
			if can_skip():
				_advance()
		"credits":
			_go_end()
		"end":
			_finish(_skipped)

## Esc·뒤로 가기: 끝 화면에서는 계속하기와 같고, 그 밖에서는 스킵이다.
func request_back() -> void:
	if _state == "end":
		paused = false
		_finish(_skipped)
	else:
		request_skip()

## 스킵 버튼: 크레딧이 없으면 바로 끝내고, 있으면 끝 화면(계속하기)으로 간다.
func request_skip() -> void:
	paused = false
	if not can_skip():
		return
	_skipped = true
	if _credits.is_empty():
		_finish(true)
	else:
		_go_end()

func _input(event: InputEvent) -> void:
	if _state == "idle" or not event is InputEventKey:
		return
	# 재생 중에는 다른 단축키(테스트실 F9 등)도 받지 않는다.
	get_viewport().set_input_as_handled()
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE, KEY_BACK:
			request_back()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			request_next()

func _gui_input(event: InputEvent) -> void:
	if _state == "idle":
		return
	var tapped := false
	var mouse := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	if mouse != null:
		tapped = mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed
	elif touch != null and not Input.is_emulating_mouse_from_touch():
		# 터치를 마우스로 흉내 내는 기본 설정에서는 같은 탭이 마우스로도 온다. 두 번 넘기지 않는다.
		tapped = not touch.pressed
	if tapped:
		accept_event()
		request_next()

func _notification(what: int) -> void:
	# 데스크톱은 앱 포커스, 웹은 캔버스 blur·focus를 창 포커스 알림으로 보낸다. 둘 다 받는다.
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			paused = true
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			paused = false
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if _state != "idle":
				request_back()

func _process(delta: float) -> void:
	if _state == "idle" or paused or not visible:
		return
	# 웹은 탭을 숨겼다 돌아오면 긴 delta가 한 번에 온다. 그 컷부터 이어 가도록 한 프레임을 0.1초로 묶는다.
	var step := minf(delta, MAX_STEP)
	_t += step
	match _state:
		"cut":
			_update_cut(step)
		"credits":
			_update_credits()

func _cut() -> Dictionary:
	return _cuts[_index] if _index >= 0 and _index < _cuts.size() and _cuts[_index] is Dictionary else {}

func _say(value: Variant) -> String:
	if value is Array and value.size() >= 2:
		return str(text.call(str(value[0]), str(value[1])))
	if value is Array and value.size() == 1:
		return str(value[0])
	return str(value) if value is String else ""

func _vec(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

func _scale() -> float:
	var short := minf(size.x, size.y)
	return maxf(ui_scale, clampf(short / 390.0, 0.9, 1.4) if short > 0.0 else 1.0)

func _style(label: Label, base: int, color: Color, outline: int) -> void:
	var s := _scale()
	label.add_theme_font_size_override("font_size", roundi(base * s))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", colors.outline)
	label.add_theme_constant_override("outline_size", roundi(outline * s))

func _layout() -> void:
	if not is_node_ready():
		return
	var s := _scale()
	var captions: MarginContainer = $Captions
	var side := roundi(maxf(20.0 * s, size.x * 0.07))
	captions.add_theme_constant_override("margin_left", side)
	captions.add_theme_constant_override("margin_right", side)
	captions.add_theme_constant_override("margin_top", roundi(76.0 * s))
	captions.add_theme_constant_override("margin_bottom", roundi(maxf(28.0 * s, size.y * 0.06)))
	$Captions/Column.add_theme_constant_override("separation", roundi(8.0 * s))
	_style($Captions/Column/Subtitle, 19, colors.subtitle, 6)
	_style($Captions/Column/TitleCard/Title, 46, colors.title, 10)
	$Captions/Column/TitleCard/Title.add_theme_color_override("font_shadow_color", colors.title_shadow)
	$Captions/Column/TitleCard/Title.add_theme_constant_override("shadow_offset_y", roundi(5.0 * s))
	_style($Captions/Column/TitleCard/Tagline, 21, colors.subtitle, 7)
	_style($Captions/Column/Count, 32, colors.accent, 7)
	var skip: Button = $Skip
	skip.add_theme_font_size_override("font_size", roundi(16.0 * s))
	skip.offset_right = -16.0 * s
	# 터치 목표는 56px 이상이다(가로 캠프와 같은 기준).
	skip.offset_left = skip.offset_right - 124.0 * s
	skip.offset_top = 16.0 * s
	skip.offset_bottom = skip.offset_top + 56.0 * s
	# 크레딧은 스킵 버튼 아래에서만 올라가 버튼과 겹치지 않는다.
	$Credits.offset_top = skip.offset_bottom + 8.0 * s
	var proceed: Button = $End/Continue
	proceed.add_theme_font_size_override("font_size", roundi(20.0 * s))
	proceed.custom_minimum_size = Vector2(minf(260.0 * s, size.x - 48.0), 56.0 * s)

func _show_cut(index: int) -> void:
	_index = index
	_state = "cut"
	_t = 0.0
	_fired.clear()
	var cut := _cut()
	# 크로스페이드: 앞 그림을 마지막 모습 그대로 뒤로 옮기고 새 그림을 앞에 띄운다.
	_back.texture = _front.texture
	_back.scale = _front.scale
	_back.position = _front.position
	_back.pivot_offset = _front.pivot_offset
	_back.modulate.a = 1.0
	_back.visible = _back.texture != null
	_front.visible = true
	_front.scale = Vector2.ONE
	_front.position = Vector2.ZERO
	var path := str(cut.get("art", ""))
	var art: Texture2D = art_loader.call(path) if not path.is_empty() else null
	if art == null and not path.is_empty():
		missing_art.append(path)
		push_warning("cutscene art missing, showing subtitle only: " + path)
	_front.texture = art
	_fade = 0.0
	$Vignette.visible = bool(cut.get("vignette", false))
	var subtitle: Label = $Captions/Column/Subtitle
	subtitle.text = _say(cut.get("sub", ""))
	subtitle.visible = not subtitle.text.is_empty()
	subtitle.modulate.a = 1.0 if Juice.reduced_motion else 0.0
	var title_card: Control = $Captions/Column/TitleCard
	var title: Variant = cut.get("title")
	title_card.visible = title is Array or (title is bool and title)
	$Captions/Column/TitleCard/Title.text = title_text
	$Captions/Column/TitleCard/Tagline.text = _say(title) if title is Array else ""
	$Captions/Column/TitleCard/Tagline.visible = not $Captions/Column/TitleCard/Tagline.text.is_empty()
	title_card.modulate.a = 1.0 if Juice.reduced_motion else 0.0
	$Captions/Column/Count.visible = cut.get("count_up") is Dictionary
	if cut.has("music_db"):
		var db := float(cut.music_db)
		_duck(db, 4.0 if db <= -16.0 else 1.2)
	$Skip.visible = true
	cut_changed.emit(index)
	_update_cut(0.0)

func _advance() -> void:
	if _index + 1 < _cuts.size():
		_show_cut(_index + 1)
	elif not _credits.is_empty():
		_start_credits()
	else:
		_finish(_skipped)

func _update_cut(step: float) -> void:
	var cut := _cut()
	var duration := float(cut.get("dur", 3.0))
	var k := clampf(_t / duration, 0.0, 1.0) if duration > 0.0 else 1.0
	var eased := k * k * (3.0 - 2.0 * k)
	var stage_size: Vector2 = $Stage.size
	_front.pivot_offset = _front.size * 0.5
	var flash := 0.0
	if Juice.reduced_motion:
		# 움직임 줄이기: 줌·이동·흔들림·번쩍임 없이 그림과 자막만 바뀐다.
		_front.scale = Vector2.ONE
		_front.position = Vector2.ZERO
		_front.modulate.a = 1.0
		_back.visible = false
	else:
		var zoom: Array = cut.get("zoom", [OVERSCAN, OVERSCAN]) if cut.get("zoom") is Array else [OVERSCAN, OVERSCAN]
		var z := lerpf(float(zoom[0]), float(zoom[1]), eased)
		_front.scale = Vector2(z, z)
		var pan: Array = cut.get("pan", []) if cut.get("pan") is Array else []
		var offset := _vec(pan[0]).lerp(_vec(pan[1]), eased) if pan.size() >= 2 else Vector2.ZERO
		var shake := Vector2.ZERO
		if cut.get("shake") is Array and cut.shake.size() >= 2:
			var since := _t - float(cut.shake[0])
			if since >= 0.0 and since < 0.5:
				var amp := float(cut.shake[1]) * (1.0 - since / 0.5)
				shake = Vector2(_rng.randf_range(-amp, amp), _rng.randf_range(-amp, amp))
		_front.position = offset * stage_size + shake
		_fade += step
		_front.modulate.a = clampf(_fade / CROSSFADE, 0.0, 1.0) if _back.texture != null else 1.0
		_back.visible = _front.modulate.a < 1.0 and _back.texture != null
		if cut.get("flash") is Array and cut.flash.size() >= 2:
			var since := _t - float(cut.flash[0])
			if since >= 0.0 and since < float(cut.flash[1]):
				flash = 1.0 - since / float(cut.flash[1])
		$Captions/Column/Subtitle.modulate.a = clampf((_t - SUB_DELAY) / SUB_FADE, 0.0, 1.0)
		if $Captions/Column/TitleCard.visible:
			var at := float(cut.flash[0]) + 0.15 if cut.get("flash") is Array and cut.flash.size() >= 2 else SUB_DELAY
			$Captions/Column/TitleCard.modulate.a = clampf((_t - at) / 0.5, 0.0, 1.0)
	$Flash.color.a = flash * 0.95
	var count: Label = $Captions/Column/Count
	if count.visible:
		var target := int(cut.count_up.get("to", 0))
		var progress := 1.0 if Juice.reduced_motion else clampf((_t - COUNT_DELAY) / COUNT_SECONDS, 0.0, 1.0)
		var shown := target if progress >= 1.0 else int(floor(target * (1.0 - pow(1.0 - progress, 3.0))))
		count.text = str(number_format.call(shown))
	var cues: Array = cut.get("sfx", []) if cut.get("sfx") is Array else []
	for i in cues.size():
		var cue: Array = cues[i] if cues[i] is Array else []
		if cue.size() < 2 or _fired.has(i) or _t < float(cue[0]):
			continue
		_fired[i] = true
		_cue(str(cue[1]), float(cue[2]) if cue.size() > 2 else 0.0)
	$Skip.disabled = not can_skip()
	if _t >= duration:
		_advance()

func _cue(key: String, db: float) -> void:
	# 효과음을 끄면 요청하지 않는다. 자막은 효과음 설정과 무관하게 보인다.
	if audio == null or not audio.sfx_enabled():
		return
	audio.play_cue(key, db)
	cue_log.append(key)

func _duck(db: float, seconds: float) -> void:
	if audio != null:
		audio.duck_music(db, seconds)

func _start_credits() -> void:
	_state = "credits"
	_t = 0.0
	$Captions.visible = false
	$Flash.color.a = 0.0
	$Skip.visible = true
	$Skip.disabled = false
	var s := _scale()
	var roll: VBoxContainer = $Credits/Roll
	for child in roll.get_children():
		roll.remove_child(child)
		child.queue_free()
	roll.add_theme_constant_override("separation", roundi(30.0 * s))
	for section in _credits.get("sections", []):
		if not section is Array or section.is_empty():
			continue
		var block := VBoxContainer.new()
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_theme_constant_override("separation", roundi(6.0 * s))
		roll.add_child(block)
		block.add_child(_credit_label(_say(section[0]), 23, colors.credits_head, &"DisplayLabel"))
		var body := _say(section[1]) if section.size() > 1 else ""
		if not body.is_empty():
			block.add_child(_credit_label(body, 16, colors.credits_body, &""))
	$Credits.visible = true
	_update_credits()

func _credit_label(value: String, base: int, color: Color, variation: StringName) -> Label:
	var label := Label.new()
	label.text = value
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style(label, base, color, 5)
	return label

func _update_credits() -> void:
	var area: Control = $Credits
	var roll: VBoxContainer = $Credits/Roll
	var width := maxf(minf(820.0 * _scale(), area.size.x - 48.0 * _scale()), 1.0)
	roll.size = Vector2(width, 0.0)
	var height := roll.get_combined_minimum_size().y
	roll.size = Vector2(width, height)
	var duration := float(_credits.get("dur", CREDITS_SECONDS))
	var k := clampf(_t / duration, 0.0, 1.0) if duration > 0.0 else 1.0
	roll.position = Vector2((area.size.x - width) * 0.5, lerpf(area.size.y + 20.0, -height - 20.0, k))
	# 마지막 컷 그림은 크레딧이 올라가는 동안 어둡게 가라앉힌다.
	_front.modulate.a = clampf(1.0 - _t / 0.8, 0.18, 1.0)
	_back.visible = false
	if _t >= duration:
		_go_end()

func _go_end() -> void:
	_state = "end"
	_t = 0.0
	$Captions.visible = false
	$Credits.visible = false
	$Flash.color.a = 0.0
	_front.modulate.a = 0.18
	_back.visible = false
	$End.visible = true
	$Skip.visible = false
	_duck(-18.0, 1.0)

func _finish(skipped: bool) -> void:
	if _state == "idle":
		return
	_state = "idle"
	_index = -1
	$End.visible = false
	$Skip.visible = false
	# 사라지는 동안 아래 화면의 첫 탭을 가로채지 않는다.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_duck(0.0, 1.2)
	if Juice.reduced_motion:
		visible = false
	else:
		_outro = create_tween()
		_outro.tween_property(self, "modulate:a", 0.0, OUTRO_SECONDS)
		_outro.tween_callback(func() -> void:
			if _state == "idle":
				visible = false)
	finished.emit(skipped)
