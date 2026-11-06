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

## 짧은 안내를 Toast 층 위쪽 중앙에 쌓는다. 입력을 가로채지 않고 지정 시간 뒤 사라진다.
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
