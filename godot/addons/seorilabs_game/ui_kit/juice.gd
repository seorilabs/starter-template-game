extends RefCounted
## UI 모션 레시피. 수치 기본값은 game-ui-commercial의 motion-sfx-table을 따르고 reduced_motion이면 즉시 끝낸다.
static var reduced_motion := false

static func _instant(node: Node) -> Tween:
	var tween := node.create_tween()
	tween.tween_interval(0.0)
	return tween

static func center_pivot(node: Control) -> void:
	node.pivot_offset = node.size / 2.0

static func press_punch(node: Control, amount := 0.94, seconds := 0.1) -> Tween:
	center_pivot(node)
	if reduced_motion:
		node.scale = Vector2.ONE
		return _instant(node)
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * amount, seconds * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, "scale", Vector2.ONE, seconds * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tween

static func pop_in(node: Control, seconds := 0.22, from := 0.9) -> Tween:
	center_pivot(node)
	node.visible = true
	if reduced_motion:
		node.scale = Vector2.ONE
		node.modulate.a = 1.0
		return _instant(node)
	node.scale = Vector2.ONE * from
	node.modulate.a = 0.0
	var tween := node.create_tween().set_parallel(true)
	tween.tween_property(node, "scale", Vector2.ONE, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "modulate:a", 1.0, seconds * 0.7)
	return tween

static func pop_out(node: Control, seconds := 0.14, to := 0.92) -> Tween:
	center_pivot(node)
	if reduced_motion:
		node.modulate.a = 0.0
		return _instant(node)
	var tween := node.create_tween().set_parallel(true)
	tween.tween_property(node, "scale", Vector2.ONE * to, seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, "modulate:a", 0.0, seconds)
	return tween

## 보상 아이콘이 재화 칩으로 날아간다. 끝나면 기본으로 노드를 지운다.
static func fly_to(node: Control, target: Vector2, seconds := 0.45, delay := 0.0, free := true) -> Tween:
	center_pivot(node)
	if reduced_motion:
		if free: node.queue_free()
		else: node.visible = false
		return _instant(node)
	node.top_level = true
	var tween := node.create_tween().set_parallel(true)
	tween.tween_property(node, "global_position", target - node.size * 0.2, seconds).set_delay(delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, "scale", Vector2.ONE * 0.4, seconds).set_delay(delay).set_ease(Tween.EASE_IN)
	if free:
		tween.chain().tween_callback(node.queue_free)
	else:
		tween.chain().tween_callback(func() -> void: node.visible = false)
	return tween

static func count_up(label: Label, from: int, to: int, seconds := 0.6, format := "%d") -> Tween:
	if reduced_motion:
		label.text = format % to
		return _instant(label)
	label.text = format % from
	var tween := label.create_tween()
	tween.tween_method(func(value: float) -> void: label.text = format % roundi(value), float(from), float(to), seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return tween

## "+10" 같은 변화량이 떠올랐다 사라진다. 입력을 가로채지 않는다.
static func float_delta(parent: Control, text: String, at: Vector2, seconds := 0.8, color := Color("fff7df")) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "NumberLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate = color
	parent.add_child(label)
	label.position = at
	if reduced_motion:
		label.create_tween().tween_interval(seconds).finished.connect(label.queue_free)
		return label
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", at.y - 40.0, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, seconds * 0.5).set_delay(seconds * 0.5)
	tween.chain().tween_callback(label.queue_free)
	return label

static func shake(node: Control, amplitude := 6.0, seconds := 0.3) -> Tween:
	if reduced_motion:
		return _instant(node)
	var origin := node.position
	var tween := node.create_tween()
	for i in 6:
		var offset := amplitude * (1.0 - float(i) / 6.0) * (1 if i % 2 == 0 else -1)
		tween.tween_property(node, "position:x", origin.x + offset, seconds / 7.0)
	tween.tween_property(node, "position:x", origin.x, seconds / 7.0)
	return tween

## 상시 모션: 주 버튼이 숨 쉬듯 1.0~scale 사이를 오간다. 노드에 묶인 Tween이라 노드가 사라지면 함께 끝난다.
static func idle_pulse(node: Control, amount := 1.03, period := 1.6) -> Tween:
	center_pivot(node)
	# 레이아웃 전(size 0)에 불려도 크기가 정해지면 축을 가운데로 다시 잡는다.
	if not node.resized.is_connected(center_pivot.bind(node)):
		node.resized.connect(center_pivot.bind(node))
	if reduced_motion:
		node.scale = Vector2.ONE
		return _instant(node)
	var tween := node.create_tween().set_loops()
	tween.tween_property(node, "scale", Vector2.ONE * amount, period * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "scale", Vector2.ONE, period * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	return tween

## 상시 모션: 칩·배지가 아주 작게 숨 쉰다. 컨테이너 안에서도 안전하게 scale만 쓴다(position은 컨테이너가 되돌린다).
static func float_loop(node: Control, amount := 1.02, period := 2.4) -> Tween:
	return idle_pulse(node, amount, period)

## 상시 모션: 밝은 띠가 주기적으로 버튼을 가로질러 지나간다(상용 게임의 주 버튼 하이라이트 스윕).
static func shine(node: Control, period := 3.0, width := 0.18) -> Tween:
	if reduced_motion:
		return _instant(node)
	var band := ColorRect.new()
	band.name = "Shine"
	band.color = Color(1, 1, 1, 0.28)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.clip_contents = false
	node.clip_contents = true
	node.add_child(band)
	if node.size == Vector2.ZERO:
		await node.get_tree().process_frame
	band.size = Vector2(node.size.x * width, node.size.y * 2.0)
	band.rotation_degrees = 18.0
	band.position = Vector2(-band.size.x * 2.0, -node.size.y * 0.5)
	var tween := band.create_tween().set_loops()
	tween.tween_property(band, "position:x", node.size.x + band.size.x, period * 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: band.position.x = -band.size.x * 2.0)
	tween.tween_interval(period * 0.65)
	return tween
