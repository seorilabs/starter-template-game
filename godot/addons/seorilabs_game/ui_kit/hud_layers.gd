extends Node
## HUD 레이어 스택. World(0) < Hud(10) < Popup(20) < Toast(30) < Ftue(40) < System(50).
const Juice = preload("res://addons/seorilabs_game/ui_kit/juice.gd")
const NAMES := ["World", "Hud", "Popup", "Toast", "Ftue", "System"]

func layer(name: String) -> Control:
	return get_node(name + "/Root")

## CanvasLayer는 Control 테마 상속을 끊으므로 각 층 루트에 같은 테마를 준다.
func apply_theme(theme: Theme) -> void:
	for name in NAMES:
		layer(name).theme = theme

const TOAST_SIDE_MARGIN := 16.0

## 짧은 안내를 Toast 층 위쪽 중앙에 쌓는다. 입력을 가로채지 않고 지정 시간 뒤 사라진다.
## 가장 긴 줄이 화면 폭(양옆 16px 제외)을 넘을 때만 모양을 바꾼다(_fit_toast). 화면 안에 드는 토스트는 1.1.0과 같다.
func toast(text: String, seconds := 2.0) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = "ChipPanel"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "NumberLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	_toast_stack().add_child(chip)
	# 호출한 쪽이 돌려받은 칩의 글꼴을 바꿀 수 있으므로 폭 판단은 그 뒤(프레임 끝)에 한다.
	_fit_toast.call_deferred(chip, label)
	Juice.pop_in(chip, 0.2)
	chip.create_tween().tween_interval(seconds).finished.connect(func() -> void:
		Juice.pop_out(chip, 0.14).finished.connect(chip.queue_free))
	return chip

## 토스트는 세로 스택 컨테이너가 가운데 정렬과 쌓임을 맡는다. 크기가 정해지기 전 좌표를 계산하지 않는다.
func _toast_stack() -> VBoxContainer:
	var root := layer("Toast")
	var stack := root.get_node_or_null("Stack") as VBoxContainer
	if stack == null:
		stack = VBoxContainer.new()
		stack.name = "Stack"
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_theme_constant_override("separation", 8)
		root.add_child(stack)
		stack.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		stack.offset_top = 24.0
	return stack

## 가장 긴 줄이 화면 폭을 넘으면 먼저 본문 글꼴로 바꿔 보고, 그래도 넘으면 칩 폭을 화면에 맞추고 가운데 정렬로 줄을 바꾼다.
## 칩 위 글자색과 외곽선은 NumberLabel 변형이 정하므로 변형은 그대로 두고 글꼴만 덮어쓴다.
func _fit_toast(chip: PanelContainer, label: Label) -> void:
	if not is_instance_valid(chip) or not is_instance_valid(label) or chip.is_queued_for_deletion():
		return
	var frame := chip.get_theme_stylebox("panel")
	var chrome := (frame.get_content_margin(SIDE_LEFT) + frame.get_content_margin(SIDE_RIGHT)) if frame != null else 0.0
	var room := layer("Toast").size.x - TOAST_SIDE_MARGIN * 2.0 - chrome
	if room <= 0.0 or _longest_line(label) <= room:
		return
	if label.theme_type_variation == &"NumberLabel" and not label.has_theme_font_override("font"):
		# get_theme_font("font", &"Label")은 이 Label의 변형(NumberLabel)을 그대로 따라가므로 테마 기본(본문) 글꼴을 직접 쓴다.
		label.add_theme_font_override("font", label.get_theme_default_font())
		if _longest_line(label) <= room:
			return
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = room

func _longest_line(label: Label) -> float:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var widest := 0.0
	for line in label.text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return widest
