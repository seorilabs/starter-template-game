extends Control
## 보상 연출 3단계: 기대(제목 등장) → 충격(플래시·파티클·스팅·아이템 등장) → 정착(재화 칩으로 비행·카운트업).
## 입력을 가로채지 않으며 skip()이나 다음 present()로 중단된다.
signal finished
const Juice = preload("res://addons/seorilabs_game/ui_kit/juice.gd")
var phase := "idle"
var timings := {"anticipation": 0.4, "impact": 0.2, "settle": 0.5, "stagger": 0.06}
var sfx: Node
var _run := 0
var _out: Tween

func _ready() -> void:
	visible = false

## items: [{"icon": Texture2D, "amount": int, "label": String}]. target은 재화 칩 같은 정착 지점, counter는 카운트업 라벨.
## focus는 연출 중심의 화면 비율 좌표다. 주 버튼을 가리지 않는 빈 영역을 고른다.
func present(items: Array, headline := "", target: Control = null, counter: Label = null, counter_from := 0, counter_to := 0, focus := Vector2(0.5, 0.5)) -> void:
	_run += 1
	var run := _run
	$Stage.offset_top = (focus.y - 0.5) * 2.0 * size.y
	$Stage.offset_left = (focus.x - 0.5) * 2.0 * size.x
	# 직전 skip()의 퇴장 페이드가 새 연출을 지우지 않게 먼저 멈춘다.
	if _out != null and _out.is_valid():
		_out.kill()
	visible = true
	modulate.a = 1.0
	scale = Vector2.ONE
	$Stage/Column/Headline.text = headline
	$Stage/Column/Headline.visible = not headline.is_empty()
	for child in $Stage/Column/Items.get_children():
		child.queue_free()
	var cards: Array[Control] = []
	for item in items:
		var card := _card(item)
		$Stage/Column/Items.add_child(card)
		card.modulate.a = 0.0
		cards.append(card)
	# 연출 열이 화면 아래로 넘치지 않게 초점을 위로 당긴다(가로 작은 화면의 결과 화면).
	# 48px 여유: 팝업 프레임 그림의 하단 테두리(backing 12 + 테두리 띠 34) 위에 글자 외곽선이 올라타지 않는다.
	var needed: float = $Stage/Column.get_combined_minimum_size().y + 48.0
	if $Stage.offset_top > size.y - needed:
		$Stage.offset_top = maxf(size.y - needed, 0.0)
	phase = "anticipation"
	if not headline.is_empty():
		Juice.pop_in($Stage/Column/Headline, timings.anticipation, 0.6)
	await _wait(timings.anticipation)
	if run != _run:
		return
	phase = "impact"
	$Flash.modulate.a = 0.0 if Juice.reduced_motion else 0.7
	if not Juice.reduced_motion:
		create_tween().tween_property($Flash, "modulate:a", 0.0, timings.impact)
		$Stage/Burst.position = $Stage.size / 2.0
		$Stage/Sparkle.position = $Stage.size / 2.0
		$Stage/Burst.restart()
		$Stage/Sparkle.emitting = true
	if sfx != null:
		sfx.play("reward_sting")
	for i in cards.size():
		Juice.pop_in(cards[i], 0.25, 0.5)
		await _wait(timings.stagger)
		if run != _run:
			return
	await _wait(timings.impact)
	if run != _run:
		return
	phase = "settle"
	if counter != null:
		Juice.count_up(counter, counter_from, counter_to, 0.6)
	if target != null:
		for i in cards.size():
			Juice.fly_to(cards[i], target.get_global_rect().get_center(), timings.settle, i * timings.stagger)
	await _wait(timings.settle + cards.size() * timings.stagger)
	if run != _run:
		return
	_finish()

func skip() -> void:
	if phase in ["idle", "done"]:
		return
	_run += 1
	_finish()

func _finish() -> void:
	phase = "done"
	$Stage/Sparkle.emitting = false
	$Flash.modulate.a = 0.0
	_out = Juice.pop_out(self, 0.2)
	_out.finished.connect(func() -> void:
		if phase == "done":
			visible = false)
	finished.emit()

func _wait(seconds: float) -> void:
	if Juice.reduced_motion or seconds <= 0.0:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(seconds).timeout

func _card(item: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.get("icon") != null:
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
	if item.has("amount"):
		var amount := Label.new()
		amount.text = "+%d" % int(item.amount)
		amount.theme_type_variation = "NumberLabel"
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(amount)
	if not str(item.get("label", "")).is_empty():
		var label := Label.new()
		label.text = str(item.label)
		label.theme_type_variation = "DisplayLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)
	return card
