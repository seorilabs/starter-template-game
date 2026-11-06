extends Control
## 딤 + 프레임 + 제목 + 내용 슬롯 + 행동 버튼. open/close가 모션을 담당하고 closed 시그널로 결과를 알린다.
signal opened
signal closed
const Juice = preload("res://addons/seorilabs_game/ui_kit/juice.gd")
@export var dismiss_on_dim := true
var state := "closed"
var open_seconds := 0.22
var close_seconds := 0.14

func _ready() -> void:
	visible = false
	$Dim.gui_input.connect(_on_dim_input)
	var close_button: Button = $Center/Frame/Body/Header/Close
	close_button.set_meta("ui_sfx_kind", "cancel")
	close_button.pressed.connect(close)

func set_title(text: String) -> void:
	$Center/Frame/Body/Header/Title.text = text

func content() -> MarginContainer:
	return $Center/Frame/Body/Content

func add_content(node: Control) -> void:
	content().add_child(node)

func add_action(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if primary:
		button.theme_type_variation = "PrimaryButton"
		button.set_meta("ui_sfx_kind", "confirm")
	button.pressed.connect(action)
	$Center/Frame/Body/Actions.add_child(button)
	return button

func open() -> void:
	if state in ["opening", "open"]:
		return
	state = "opening"
	visible = true
	if Juice.reduced_motion:
		$Dim.modulate.a = 1.0
	else:
		$Dim.modulate.a = 0.0
		create_tween().tween_property($Dim, "modulate:a", 1.0, open_seconds * 0.8)
	await Juice.pop_in($Center/Frame, open_seconds).finished
	if state != "opening":
		return
	state = "open"
	opened.emit()

func close() -> void:
	if state in ["closing", "closed"]:
		return
	state = "closing"
	if not Juice.reduced_motion:
		create_tween().tween_property($Dim, "modulate:a", 0.0, close_seconds)
	await Juice.pop_out($Center/Frame, close_seconds).finished
	if state != "closing":
		return
	visible = false
	state = "closed"
	closed.emit()

func _on_dim_input(event: InputEvent) -> void:
	if dismiss_on_dim and event is InputEventMouseButton and event.pressed:
		close()
