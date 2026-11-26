extends PanelContainer
## 재화 칩: 아이콘 + 숫자 + (+) 버튼. 값이 오르면 카운트업과 작은 튕김으로 변화를 보여 준다.
signal add_pressed
const Juice = preload("res://addons/seorilabs_game/ui_kit/juice.gd")
@export var show_add := true
var value := 0

func _ready() -> void:
	$Row/Add.visible = show_add
	$Row/Add.pressed.connect(func() -> void: add_pressed.emit())
	$Row/Value.text = format_amount(value)

func set_icon(texture: Texture2D) -> void:
	$Row/Icon.texture = texture

func set_value(next: int, animate := true) -> void:
	var previous := value
	value = next
	if animate and next != previous:
		Juice.count_up($Row/Value, previous, next, 0.6, "%s").finished.connect(func() -> void: $Row/Value.text = format_amount(next))
		if next > previous:
			Juice.press_punch(self, 1.08, 0.18)
	else:
		$Row/Value.text = format_amount(next)

## 제품이 "★ 12"처럼 조합한 표시 문자열을 그대로 쓴다. 카운트업은 하지 않는다.
func set_text(text: String) -> void:
	$Row/Value.text = text
	# 배치하는 쪽(캠프 홈)이 줄을 나눠 다시 그릴 때 원문을 쓴다.
	$Row/Value.set_meta("source_text", text)

## 보상이 날아올 목표 좌표(아이콘 중심).
func fly_target() -> Vector2:
	return $Row/Icon.get_global_rect().get_center()

## 1,234 / 12.5K / 3.2M 표기. 천 단위 구분은 locale에 따라 바꿀 수 있다.
static func format_amount(amount: int) -> String:
	if amount >= 1000000:
		return "%.1fM" % (amount / 1000000.0)
	if amount >= 100000:
		return "%.1fK" % (amount / 1000.0)
	var text := str(absi(amount))
	var out := ""
	for i in text.length():
		if i > 0 and (text.length() - i) % 3 == 0:
			out += ","
		out += text[i]
	return ("-" if amount < 0 else "") + out
