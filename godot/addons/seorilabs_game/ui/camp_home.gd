extends Control
## Approved landscape composition. Text and input stay native Godot controls.
var controller: Control
var title_screen := false
var _placements: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = preload("res://addons/seorilabs_game/skins/soft_adventure/camp.svg")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	_text(controller.studio_name.to_upper(), Rect2(32, 38, 490, 30), 26, Color("fff8e5"))
	_text(controller.game_title, Rect2(32, 80, 490, 92), 36, Color("fff8e5"))
	var connected: bool = controller.accounts.connected()
	var status: String = controller.tr_text("Account connected", "계정 연결됨") if connected else controller.tr_text("Connect your account", "계정을 연결해 주세요")
	if not controller.accounts.error.is_empty(): status = controller._error_text(controller.accounts.error)
	_text(status, Rect2(32, 182, 480, 44), 22, Color("244c53"))
	# 재화는 평문 라벨이 아니라 재화 칩(아이콘·숫자·(+), 보상 비행 목표)으로 둔다.
	var chip: Control = controller._currency_chip(self)
	_placements.append({"node": chip, "rect": Rect2(32, 244, 370, 76), "font": 32, "chip": true})
	var account := _button(controller.tr_text("My account", "내 계정"), "account_hud", Rect2(772, 26, 328, 128), func() -> void: controller._open("account"), "account")
	account.tooltip_text = str(controller.accounts.details.get("uid", controller.tr_text("UID appears after connecting", "연결 후 UID 표시")))
	_button("", "settings", Rect2(1120, 26, 128, 128), func() -> void: controller._open("settings"), "settings")
	var headline: String = controller.tr_text("A new adventure begins", "새로운 모험의 시작")
	if not controller.startup_error.is_empty():
		headline = controller._error_text(controller.startup_error)
	if not controller.transient_notice.is_empty(): headline = controller.transient_notice
	_text(headline, Rect2(464, 178, 740, 112), 44, Color("244c53"))
	var action: String = controller.tr_text("Begin adventure", "모험 시작")
	if controller.services.mode == "server" and not connected:
		action = controller.tr_text("Create account", "계정 만들기")
	elif not title_screen:
		action = controller.tr_text(controller.home_text.action[0], controller.home_text.action[1])
	var play := _button(action, "start" if title_screen else "play", Rect2(426, 400, 428, 128), controller._camp_action, "", true)
	play.disabled = controller.accounts.status == "busy" or (not controller.initialized and controller.startup_error.is_empty())
	var nav := [["account", "Account", "계정"], ["shop", "Shop", "상점"], ["inbox", "Inbox", "우편함"], ["ads", "Ad\nreward", "광고\n보상"], ["operations", "Operations", "운영"], ["settings", "Settings", "설정"]]
	for i in nav.size():
		var item: Array = nav[i]
		var target := str(item[0])
		var button := _button(controller.tr_text(item[1], item[2]), target if target != "account" else "account", Rect2(32 + i * 204, 568, 188, 128), func() -> void: controller._open(target), target)
		# Stacked icons leave the full button width for translated words.
		var caption := Label.new()
		caption.text = button.text.replace("\n", " ")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_override("font", controller._font_body)
		button.add_child(caption)
		var icon := TextureRect.new()
		icon.texture = button.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		button.text = ""
		button.icon = null
		button.set_meta("caption", caption)
		button.set_meta("nav_icon", icon)
		if target == "shop":
			button.disabled = not controller.commerce.available()
		elif target in ["ads", "operations"]:
			button.disabled = not controller.feature_routes.has(target)
	resized.connect(_layout)
	_layout()

func _text(value: String, rect: Rect2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", controller._font_title if controller._font_title != null else controller._font_body)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	_placements.append({"node": label, "rect": rect, "font": font_size})

func _button(text: String, id: String, rect: Rect2, action: Callable, icon: String = "", primary: bool = false) -> Button:
	var button: Button = controller._button(text, action, self, primary)
	button.name = id
	button.custom_minimum_size = Vector2.ZERO
	button.add_theme_font_override("font", controller._font_title if controller._font_title != null else controller._font_body)
	if not icon.is_empty():
		button.icon = load("res://addons/seorilabs_game/skins/soft_adventure/icon_" + icon + ".svg")
		button.expand_icon = true
	_placements.append({"node": button, "rect": rect, "font": 38 if primary else 36, "button": true, "primary": primary})
	return button

func _layout() -> void:
	var scale_factor := minf(size.x / 1280.0, size.y / 720.0)
	var origin := (size - Vector2(1280, 720) * scale_factor) / 2.0
	for entry in _placements:
		var node: Control = entry.node
		var rect: Rect2 = entry.rect
		node.position = origin + rect.position * scale_factor
		if entry.has("chip"):
			# 칩은 내용 크기로 두고 숫자 글자만 배율에 맞춘다.
			node.size = Vector2.ZERO
			# 캠프의 모든 버튼은 56px 이상의 터치 영역을 가진다. (+)는 상점이 있을 때만 보인다.
			node.get_node("Row/Add").custom_minimum_size = Vector2(56, 56)
			node.get_node("Row/Value").add_theme_font_size_override("font_size", maxi(16, roundi(entry.font * scale_factor)) + (2 if controller.state.data.get("settings", {}).get("large_text", false) else 0))
			continue
		node.size = rect.size * scale_factor
		node.add_theme_font_size_override("font_size", maxi(16 if entry.has("button") else 11, roundi(entry.font * scale_factor)) + (2 if controller.state.data.get("settings", {}).get("large_text", false) else 0))
		if not entry.has("button"):
			continue
		if node.has_meta("caption"):
			var caption: Label = node.get_meta("caption")
			caption.position = Vector2(3, node.size.y * 0.53)
			caption.size = Vector2(node.size.x - 6, node.size.y * 0.4)
			caption.add_theme_font_size_override("font_size", maxi(14, roundi(28 * scale_factor)) + (2 if controller.state.data.get("settings", {}).get("large_text", false) else 0))
			var icon: TextureRect = node.get_meta("nav_icon")
			icon.size = Vector2(44, 44) * scale_factor
			icon.position = Vector2((node.size.x - icon.size.x) / 2, node.size.y * 0.12)
		var primary: bool = entry.primary
		node.theme_type_variation = "PrimaryButton" if primary else ""
		node.add_theme_constant_override("icon_max_width", maxi(20, roundi(44 * scale_factor)))
