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
