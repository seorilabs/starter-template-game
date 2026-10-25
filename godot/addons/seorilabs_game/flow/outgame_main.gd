extends Control
## 공통 흐름과 게임별 장면, 서비스 연결을 분리한 소프트 어드벤처 참조 실행체.
const State = preload("res://addons/seorilabs_game/flow/state.gd")
const Services = preload("res://addons/seorilabs_game/services/services.gd")
const Popups = preload("res://addons/seorilabs_game/flow/popup_queue.gd")
const Locale = preload("res://addons/seorilabs_game/locales/localization.gd")
const Support = preload("res://addons/seorilabs_game/services/support_identity.gd")
const Analytics = preload("res://addons/seorilabs_game/services/analytics_preference.gd")
const Ranking = preload("res://addons/seorilabs_game/services/leaderboard.gd")
const Commerce = preload("res://addons/seorilabs_game/services/commerce.gd")
@export var game_title := "Game"
@export var game_title_ko := "Game"
@export var studio_name := "Seorilabs"
@export var home_profile := "hero"
@export var lobby_art: Texture2D
@export var custom_theme: Theme
var stage_factory: Callable
var launch_game: Callable
var score_provider: Callable
var home_actions: Callable
var feature_routes: Dictionary = {}
var home_text := {"hero": ["Player", "플레이어"], "destination": ["Ready to play", "플레이 준비"], "action": ["Play", "플레이"], "account": ["Account", "계정"]}
var reward_text := ""
var state = State.new()
var services = Services.new()
var popups = Popups.new()
var support = Support.new()
var analytics = Analytics.new()
var ranking = Ranking.new()
var commerce = Commerce.new()
var identity_provider: Callable
var support_provider: Callable
var clipboard_writer: Callable
var content: VBoxContainer
var backing: Panel
var background: TextureRect
var header: Label
var screen := "title"
var initialized := false
var initializing := false
var progress := 0
var startup_error := ""
var pending := false
var navigation: Array[String] = []
var _focus_stack: Array[Dictionary] = []
var platform := OS.get_name()
var device_locale := OS.get_locale()
var config: Dictionary = {"appId": "", "privacy_url": "", "terms_url": "", "analytics_policy_allowed": false}
var _view := 0
var _font_title: Font
var _font_body: Font
var palette: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://addons/seorilabs_game/skins/soft_adventure/skin.json"))

func _variable_font(path: String, weight: int) -> Font:
	var font := FontVariation.new()
	font.base_font = load(path)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font

func configure_platform(client: Node, provider: Callable, options: Dictionary) -> void:
	if initializing or initialized:
		return
	if client.get_parent() == null:
		add_child(client)
	services.configure(client, provider)
	config.merge(options, true)

func current_identity() -> String:
	if identity_provider.is_valid():
		return str(identity_provider.call())
	if services.sdk != null:
		var session: Dictionary = services.sdk.current_session()
		var uid := str(session.get("platformUserId", ""))
		if not uid.is_empty() and not str(config.appId).is_empty():
			return str(config.appId) + ":" + uid
	return ""

func _lookup_support(callback: Callable) -> void:
	if support_provider.is_valid():
		support_provider.call(callback)
	elif services.sdk != null:
		var session: Dictionary = services.sdk.current_session()
		callback.call({"ok": true, "identity": current_identity(), "code": session.get("supportCode", "")})
	else:
		callback.call({"ok": false, "retryable": false})

func _identity_changed(_session: Dictionary = {}) -> void:
	support.change_identity(current_identity())
	ranking.change_identity(current_identity())
	commerce.change_identity(current_identity())
	if screen == "support":
		support.request(current_identity(), _lookup_support)
	elif screen == "leaderboard":
		ranking.fetch()

func _ready() -> void:
	add_child(services)
	commerce.store = state
	ranking.store = state
	_font_body = _variable_font("res://addons/seorilabs_game/fonts/NotoSansKR.ttf", 550)
	var base := ColorRect.new()
	base.color = Color(palette.background)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	background = TextureRect.new()
	background.texture = lobby_art
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.04, 0.15, 0.20, 0.75)])
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_from = Vector2(0, 0.55)
	shade_texture.fill_to = Vector2(0, 1)
	shade.texture = shade_texture
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	backing = Panel.new()
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.offset_left = 12
	backing.offset_right = -12
	backing.offset_top = 12
	backing.offset_bottom = -12
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.add_theme_stylebox_override("panel", _skin(Color(palette.panel), Color("9b9478"), 18))
	add_child(backing)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28 if side in ["left", "right"] else 12 if size.y < 500 else 26)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6 if size.y < 500 else 10)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)
	support.changed.connect(_refresh_features)
	ranking.changed.connect(_refresh_features)
	commerce.changed.connect(_refresh_features)
	services.error_observed.connect(func(code: String) -> void: startup_error = code)
	if services.sdk != null and services.sdk.has_signal("session_changed"):
		services.sdk.session_changed.connect(_identity_changed)
	if not clipboard_writer.is_valid():
		clipboard_writer = func(value: String) -> bool:
			DisplayServer.clipboard_set(value)
			return DisplayServer.clipboard_get() == value
	_initialize()

func language() -> String:
	return Locale.resolve(str(state.data.get("settings", {}).get("language", "system")), device_locale)

func tr_text(en: String, ko: String) -> String:
	return Locale.text(en, ko, language())

func _skin(color: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = color
	skin.border_color = border
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(radius)
	skin.content_margin_left = 12
	skin.content_margin_right = 12
	skin.content_margin_top = 8
	skin.content_margin_bottom = 8
	return skin

func _apply_settings() -> void:
	theme = Theme.new()
	theme.default_font = _font_body
	theme.default_font_size = 16 + (3 if state.data.settings.large_text else 0)
	_font_title = load("res://addons/seorilabs_game/fonts/Jua.ttf") if language() == "ko" else _variable_font("res://addons/seorilabs_game/fonts/Fredoka.ttf", 650)
	theme.set_color("font_color", "Label", Color(palette.text))
	for cls in ["Button", "CheckButton"]:
		theme.set_color("font_color", cls, Color(palette.text))
		theme.set_color("font_hover_color", cls, Color(palette.text))
		theme.set_color("font_pressed_color", cls, Color(palette.text))
		theme.set_color("font_focus_color", cls, Color(palette.text))
		theme.set_color("font_hover_pressed_color", cls, Color(palette.text))
		theme.set_color("font_disabled_color", cls, Color("6d7c79"))
		theme.set_stylebox("normal", cls, _skin(Color("fff8e5"), Color("94b3a6")))
		theme.set_stylebox("hover", cls, _skin(Color("e8efdb"), Color("56847c")))
		theme.set_stylebox("pressed", cls, _skin(Color("d1dfc3"), Color("3b6e71")))
		theme.set_stylebox("disabled", cls, _skin(Color("e1e4d7"), Color("c2c9b9")))
		var focus := _skin(Color.TRANSPARENT, Color("286778"))
		focus.set_border_width_all(3)
		theme.set_stylebox("focus", cls, focus)
	for pair in [["Music", "music"], ["SFX", "sfx"]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index == -1:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, pair[0])
		AudioServer.set_bus_mute(index, not state.data.settings[pair[1]])
	if custom_theme != null:
		theme = custom_theme
	analytics.policy_allowed = bool(config.get("analytics_policy_allowed", false))
	analytics.apply(state)

func _initialize() -> void:
	if initializing or initialized:
		return
	initializing = true
	progress = 0
	startup_error = ""
	_title()
	if not state.load_state():
		startup_error = state.error
		initializing = false
		_title()
		return
	progress = 1
	_apply_settings()
	_title()
	await get_tree().process_frame
	progress = 2
	_title()
	services.initialize(func(result: Dictionary) -> void:
		initializing = false
		if result.get("ok", false):
			initialized = true
			progress = 3
		else:
			startup_error = str(result.get("code", "connection_failed"))
		_identity_changed()
		if screen == "title": _title()
		else: _route(screen)
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and initialized and services.sdk != null:
		services.sdk.resume_presence()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()

func _clear(title: String) -> void:
	_view += 1
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	backing.visible = screen not in ["title", "home"]
	background.visible = home_profile == "hero" or screen != "home"
	if screen in ["title", "home"]:
		return
	header = _label(title, 25)
	header.add_theme_font_override("font", _font_title if _font_title != null else _font_body)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	content.add_child(top)
	var back := _button("‹", _back, top)
	back.name = "back"
	back.custom_minimum_size.x = 44
	back.size_flags_horizontal = Control.SIZE_FILL
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(header)
	var close := _button("×", _close, top)
	close.name = "close"
	close.custom_minimum_size.x = 44
	close.size_flags_horizontal = Control.SIZE_FILL

func _label(text: String, size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size + (3 if not state.data.is_empty() and state.data.settings.large_text else 0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, action: Callable, parent: Node = null, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 48
	button.custom_minimum_size.x = 80
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	if primary:
		button.add_theme_font_override("font", _font_title if _font_title != null else _font_body)
		button.add_theme_font_size_override("font_size", 22)
		var skin := _skin(Color(palette.primary), Color("aa8036"), 12)
		skin.shadow_color = Color("8e6425")
		skin.shadow_size = 2
		skin.shadow_offset = Vector2(0, 3)
		button.add_theme_stylebox_override("normal", skin)
	(parent if parent != null else content).add_child(button)
	return button

func _spacer() -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)

func _title() -> void:
	screen = "title"
	_clear(game_title)
	var top := HBoxContainer.new()
	content.add_child(top)
	var studio := _label(studio_name.to_upper(), 13)
	studio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	studio.add_theme_color_override("font_color", Color("fff9e5"))
	top.add_child(studio)
	var title_settings := _button(tr_text("Settings", "설정"), func() -> void: _open("settings"), top)
	title_settings.name = "settings"
	title_settings.custom_minimum_size.x = 100
	title_settings.size_flags_horizontal = Control.SIZE_FILL
	var logo := _label(game_title, 56)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_override("font", _variable_font("res://addons/seorilabs_game/fonts/Fredoka.ttf", 700))
	logo.add_theme_color_override("font_color", Color("fff1c8"))
	logo.add_theme_color_override("font_shadow_color", Color("294c62"))
	logo.add_theme_constant_override("shadow_offset_y", 4)
	content.add_child(logo)
	_spacer()
	var ready := _label(_error_text(startup_error) if not startup_error.is_empty() else tr_text("Ready for adventure", "시작할 준비가 됐어요") if initialized else tr_text("Preparing %d / 3", "준비 단계 %d / 3") % progress)
	ready.add_theme_color_override("font_color", Color("fffbe9"))
	ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(ready)
	if not initialized:
		var bar := ProgressBar.new()
		bar.max_value = 3
		bar.value = progress
		bar.show_percentage = false
		content.add_child(bar)
	if not startup_error.is_empty():
		_button(tr_text("Retry", "다시 준비"), _initialize, null, true).name = "retry"
	else:
		var start := _button(tr_text("Begin adventure", "모험 시작"), _start, null, true)
		start.name = "start"
		start.disabled = not initialized
	var version := _label("v" + str(ProjectSettings.get_setting("application/config/version", "1.0.0")), 12)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_color_override("font_color", Color("fffbe9"))
	content.add_child(version)

func _sync_metrics() -> void:
	var handed: Array = services.sync_events(state.data.events, analytics.effective)
	if not handed.is_empty():
		state.mark_events_sent(handed, int(Time.get_unix_time_from_system() * 1000))

func _start() -> void:
	if not initialized:
		return
	if state.data.consentVersion == 0 and not state.accept_consent(bool(state.data.settings.analytics)):
		_show_error(state.error)
		return
	if state.data.tutorial.status == "active":
		_route("play")
	else:
		_home()

func _open(target: String) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	_focus_stack.append({"name": str(focus.name) if focus != null else "", "text": str(focus.text) if focus is BaseButton else ""})
	navigation.append(screen)
	_route(target)

func _route(target: String) -> void:
	screen = target
	if feature_routes.has(target):
		feature_routes[target].call()
		return
	match target:
		"title": _title()
		"home": _home()
		"settings": _settings()
		"accessibility": _accessibility()
		"language": _language()
		"account": _account()
		"support":
			_draw_support()
			support.request(current_identity(), _lookup_support)
		"inbox": _inbox()
		"shop":
			_draw_shop()
			commerce.catalog()
		"offer": _draw_offer()
		"purchase": _draw_purchase()
		"result": _draw_result()
		"leaderboard":
			if ranking.capabilities().get("list", false):
				_draw_ranking()
				ranking.fetch()
			else:
				var view := _view
				var owner := current_identity()
				ranking.open_native(func(result: Dictionary) -> void:
					if screen != "leaderboard" or view != _view or owner != current_identity():
						return
					_back()
					if not result.get("ok", false): _show_error("network_error")
				)
		"play":
			if not launch_game.is_valid() and state.data.tutorial.status != "active" and not state.replay_tutorial():
				_show_error(state.error)
				return
			if not state.ensure_run(): _show_error(state.error)
			elif launch_game.is_valid(): launch_game.call(self)
			else: _show_error("game_unavailable")

func _back() -> void:
	if screen == "result":
		_finish_result()
		return
	var focus: Dictionary = _focus_stack.pop_back() if not _focus_stack.is_empty() else {}
	support.close()
	ranking.close()
	_route(navigation.pop_back() if not navigation.is_empty() else "home" if initialized else "title")
	_restore_focus.call_deferred(focus)

func _close() -> void:
	if screen == "result":
		_finish_result()
		return
	var origin := navigation[0] if not navigation.is_empty() else "home" if initialized else "title"
	var focus: Dictionary = _focus_stack[0] if not _focus_stack.is_empty() else {}
	navigation.clear()
	_focus_stack.clear()
	support.close()
	ranking.close()
	_route(origin)
	_restore_focus.call_deferred(focus)

func _restore_focus(previous: Dictionary) -> void:
	for control in content.find_children("*", "BaseButton", true, false):
		if (str(control.name) == previous.get("name", "") or str(control.text) == previous.get("text", "")) and not control.disabled:
			control.grab_focus()
			return

func _refresh_features() -> void:
	if not is_inside_tree() or content == null:
		return
	match screen:
		"support": _draw_support()
		"leaderboard": _draw_ranking()
		"shop": _draw_shop()
		"offer": _draw_offer()
		"purchase": _draw_purchase()
		"result": _draw_result()

func _home() -> void:
	_sync_metrics()
	screen = "home"
	_clear("")
	if size.y < 500:
		_compact_home()
		return
	var hud := HBoxContainer.new()
	content.add_child(hud)
	var coins := _label("● %d    ◆ 20" % state.data.coins, 20)
	coins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var resource_panel := PanelContainer.new()
	resource_panel.add_theme_stylebox_override("panel", _skin(Color("fff5d7"), Color("8ca99d")))
	resource_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(resource_panel)
	resource_panel.add_child(coins)
	var settings_button := _button("☰", func() -> void: _open("settings"), hud)
	settings_button.name = "settings"
	settings_button.tooltip_text = tr_text("Settings", "설정")
	settings_button.custom_minimum_size.x = 44
	settings_button.size_flags_horizontal = Control.SIZE_FILL
	var actions := HBoxContainer.new()
	content.add_child(actions)
	_button(tr_text("Inbox", "우편"), func() -> void: _open("inbox"), actions).name = "inbox"
	if ranking.available():
		_button(tr_text("Rank", "순위"), func() -> void: _open("leaderboard"), actions).name = "leaderboard"
	if home_profile != "hero":
		var stage: Control = stage_factory.call(home_profile) if stage_factory.is_valid() else Control.new()
		stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stage.custom_minimum_size.y = 120
		content.add_child(stage)
	else:
		_spacer()
		var hero := _label(tr_text(home_text.hero[0], home_text.hero[1]), 28)
		hero.add_theme_font_override("font", _font_title)
		hero.add_theme_color_override("font_color", Color("fff8df"))
		hero.add_theme_color_override("font_shadow_color", Color("294c62"))
		hero.add_theme_constant_override("shadow_offset_y", 2)
		hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		content.add_child(hero)
	var target := _label(tr_text(home_text.destination[0], home_text.destination[1]), 16)
	var goal := PanelContainer.new()
	goal.add_theme_stylebox_override("panel", _skin(Color("fff8e5"), Color("9baa89")))
	content.add_child(goal)
	goal.add_child(target)
	_button(tr_text(home_text.action[0], home_text.action[1]), func() -> void: _open("play"), null, true).name = "play"
	var nav := HBoxContainer.new()
	content.add_child(nav)
	if commerce.available():
		_button(tr_text("Shop", "상점"), func() -> void: _open("shop"), nav).name = "shop"
	_button(tr_text("Home", "홈"), _home, nav)
	_button(tr_text(home_text.account[0], home_text.account[1]), func() -> void: _open("account"), nav)

func _compact_home() -> void:
	background.visible = false
	var hud := HBoxContainer.new()
	content.add_child(hud)
	var coins := _label("● %d    ◆ 20" % state.data.coins, 18)
	coins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(coins)
	_button(tr_text("Inbox", "우편"), func() -> void: _open("inbox"), hud).name = "inbox"
	if ranking.available(): _button(tr_text("Rank", "순위"), func() -> void: _open("leaderboard"), hud).name = "leaderboard"
	_button(tr_text("Settings", "설정"), func() -> void: _open("settings"), hud).name = "settings"
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	content.add_child(split)
	var left: Control
	if home_profile == "hero":
		var art := TextureRect.new()
		art.texture = background.texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		left = art
	else:
		left = stage_factory.call(home_profile) if stage_factory.is_valid() else Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split.add_child(left)
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 6)
	split.add_child(actions)
	actions.add_child(_label(tr_text(home_text.destination[0], home_text.destination[1]), 18))
	_button(tr_text(home_text.action[0], home_text.action[1]), func() -> void: _open("play"), actions, true).name = "play"
	if home_actions.is_valid(): home_actions.call(actions)
	var nav := HBoxContainer.new()
	actions.add_child(nav)
	if commerce.available(): _button(tr_text("Shop", "상점"), func() -> void: _open("shop"), nav).name = "shop"
	_button(tr_text(home_text.account[0], home_text.account[1]), func() -> void: _open("account"), nav)

func _settings() -> void:
	screen = "settings"
	_clear(tr_text("Settings", "설정"))
	var box := _scroll()
	_settings_toggles(box, [["music", "Music", "음악"], ["sfx", "Sound effects", "효과음"], ["vibration", "Vibration", "진동"], ["analytics", "Allow analytics", "데이터 분석 허용"]])
	box.add_child(_label(tr_text("Gameplay statistics help improve the game. You can turn them off.", "게임 개선을 위한 플레이 통계를 보냅니다. 언제든 끌 수 있습니다."), 14))
	if analytics.reason in ["policy", "unavailable"]:
		box.add_child(_label(tr_text("Collection is currently unavailable or restricted.", "현재 수집이 제한되거나 지원되지 않습니다."), 14))
	_button(tr_text("Language", "언어"), func() -> void: _open("language"), box).name = "language"
	_button(tr_text("Account and save", "계정과 저장"), func() -> void: _open("account"), box)
	_button(tr_text("Support code", "지원코드"), func() -> void: _open("support"), box).name = "support"
	if commerce.available():
		_button(tr_text("Restore purchases", "구매 내역 복원"), func() -> void: _open("purchase"); commerce.restore(), box).name = "restore"
	_button(tr_text("Accessibility", "접근성"), func() -> void: _open("accessibility"), box).name = "accessibility"
	_button(tr_text("Replay guide", "안내 다시 보기"), func() -> void:
		if state.replay_tutorial(): _open("play")
		else: _show_error(state.error)
	, box).name = "replay"
	for item in [["terms_url", "Terms", "약관"], ["privacy_url", "Privacy", "개인정보 처리방침"]]:
		var url := str(config.get(item[0], ""))
		if not url.is_empty():
			_button(tr_text(item[1], item[2]), func() -> void: OS.shell_open(url), box)
	box.add_child(_label("v" + str(ProjectSettings.get_setting("application/config/version", "1.0.0")), 13))

func _settings_toggles(box: VBoxContainer, pairs: Array) -> void:
	for pair in pairs:
		var key: String = pair[0]
		var toggle := CheckButton.new()
		toggle.name = key
		toggle.text = tr_text(pair[1], pair[2])
		toggle.custom_minimum_size.y = 48
		toggle.mouse_filter = Control.MOUSE_FILTER_PASS
		toggle.button_pressed = bool(state.data.settings[key])
		toggle.toggled.connect(func(value: bool) -> void:
			var ok: bool = analytics.choose(state, value) if key == "analytics" else state.setting(key, value)
			if ok:
				_apply_settings()
				if key == "large_text": _route(screen)
			else:
				toggle.set_pressed_no_signal(bool(state.data.settings[key]))
				_show_error(state.error)
		)
		box.add_child(toggle)

func _accessibility() -> void:
	_clear(tr_text("Accessibility", "접근성"))
	var box := _scroll()
	_settings_toggles(box, [["large_text", "Larger text", "큰 글자"], ["reduced_motion", "Reduced motion", "움직임 줄이기"]])

func _language() -> void:
	_clear(tr_text("Language", "언어"))
	for choice in [["system", "Device language", "기기 언어 따르기"], ["en", "English", "English"], ["ko", "한국어", "한국어"]]:
		var value: String = choice[0]
		var selected: bool = state.data.settings.language == value
		var button := _button(("✓ " if selected else "") + tr_text(choice[1], choice[2]), func() -> void:
			if state.setting("language", value):
				_apply_settings()
				_language()
			else: _show_error(state.error)
		)
		button.name = value

func _account() -> void:
	_clear(tr_text("Account and save", "계정과 저장"))
	content.add_child(_label(tr_text("Guest, saved on this device" if services.mode == "local" else "Connected game account", "게스트, 이 기기에 저장" if services.mode == "local" else "연결된 게임 계정")))
	content.add_child(_label(tr_text("Progress is preserved. Linking is available only when supported by this game.", "진행은 유지됩니다. 계정 연결은 이 게임에서 지원하는 경우에만 제공됩니다.")))

func _draw_support() -> void:
	_clear(tr_text("Support code", "지원코드"))
	content.add_child(_label(tr_text("Customer support identifier", "고객지원용 식별코드"), 20))
	var value := LineEdit.new()
	value.name = "support_code"
	value.editable = false
	value.text = support.code if not support.code.is_empty() else tr_text("Checking…", "확인 중…") if support.status == "checking" else "—"
	value.add_theme_font_override("font", _variable_font("res://addons/seorilabs_game/fonts/NotoSansMono.ttf", 500))
	value.add_theme_font_size_override("font_size", 21)
	value.add_theme_color_override("font_uneditable_color", Color(palette.text))
	value.add_theme_color_override("font_color", Color(palette.text))
	value.add_theme_stylebox_override("read_only", _skin(Color("fffdf3"), Color("7e9b91")))
	value.custom_minimum_size.y = 54
	content.add_child(value)
	var description := tr_text("An identifier for customer support, not a password.", "고객지원에서 사용하는 식별코드입니다. 비밀번호가 아닙니다.")
	if support.status == "cached_offline": description = tr_text("Offline, showing your previously confirmed code.", "오프라인입니다. 이전에 확인한 현재 계정의 코드입니다.")
	elif support.status in ["failed", "unavailable"]: description = tr_text("The code cannot be checked right now. Local play remains available.", "지금 코드를 확인할 수 없습니다. 로컬 플레이는 계속할 수 있습니다.")
	content.add_child(_label(description))
	var copy := _button(tr_text("Copy code", "코드 복사"), func() -> void:
		_show_error("copied" if support.copy_code(clipboard_writer) else "copy_failed")
	, null, true)
	copy.name = "copy"
	copy.disabled = support.status not in ["ready", "cached_offline"]
	if support.status in ["failed", "unavailable"]:
		_button(tr_text("Try again", "다시 확인"), func() -> void: support.request(current_identity(), _lookup_support)).name = "support_retry"

func _draw_shop() -> void:
	_clear(tr_text("Shop", "상점"))
	var box := _scroll()
	if commerce.catalog_state != "available":
		box.add_child(_label(tr_text("Loading products…", "상품을 확인하고 있어요…") if commerce.catalog_state == "loading" else tr_text("Products are unavailable. Try again later.", "상품을 확인할 수 없습니다. 잠시 후 다시 확인해 주세요.")))
		if commerce.catalog_state == "failed": _button(tr_text("Try again", "다시 확인"), commerce.catalog, box)
	for product in commerce.products:
		var id := str(product.id)
		_product_art(product, box, 110)
		var b := _button(_product_text(product, "title") + "\n" + str(product.get("price", "")), func() -> void: config.selected_product = id; _open("offer"), box)
		b.name = "product_" + id
		b.disabled = not product.get("available", false) or str(product.get("price", "")).is_empty()

func _draw_offer() -> void:
	_clear(tr_text("Offer details", "상품 상세"))
	var box := _scroll()
	for product in commerce.products:
		if str(product.id) != str(config.get("selected_product", "")): continue
		_product_art(product, box, 150)
		box.add_child(_label(_product_text(product, "title"), 24))
		box.add_child(_label(_product_text(product, "description")))
		var buy := _button(str(product.get("price", "")), func() -> void: _open("purchase"); commerce.buy(str(product.id)), null, true)
		buy.name = "buy"
		buy.disabled = not product.get("available", false) or str(product.get("price", "")).is_empty()

func _product_text(product: Dictionary, key: String) -> String:
	return str(product.get("localized", {}).get(language(), {}).get(key, product.get(key, "")))

func _product_art(product: Dictionary, parent: Node, height: int) -> void:
	if not product.get("art") is Texture2D:
		return
	var art := TextureRect.new()
	art.texture = product.art
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size.y = height
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)

func _submit_result() -> void:
	if score_provider.is_valid():
		var result: Dictionary = score_provider.call()
		ranking.submit(int(result.get("score", 0)), str(result.get("runId", "")), bool(result.get("completed", false)))

func _draw_result() -> void:
	screen = "result"
	_clear(tr_text("Expedition complete", "원정 완료"))
	content.add_child(_label(reward_text, 28))
	if ranking.status == "submitting": content.add_child(_label(tr_text("Your score is being checked", "점수를 확인하고 있어요")))
	if ranking.status == "submitted": content.add_child(_label(tr_text("Score accepted, rankings may update shortly", "점수를 접수했어요. 순위 반영까지 잠시 걸릴 수 있어요.")))
	if ranking.status == "failed": _button(tr_text("Retry score submission", "점수 다시 보내기"), _submit_result).name = "submit_retry"
	_button(tr_text("Continue", "계속"), _finish_result, null, true).name = "reward_continue"
	if ranking.available(): _button(tr_text("View leaderboard", "순위 보기"), func() -> void: _open("leaderboard")).name = "result_leaderboard"

func _finish_result() -> void:
	popups.dismiss()
	navigation.clear()
	_focus_stack.clear()
	_home()

func _draw_purchase() -> void:
	_clear(tr_text("Purchases", "구매와 복원"))
	var names := {
		"idle": ["Confirm your purchase", "구매를 확인해 주세요"], "store_open": ["Store payment is open", "마켓 결제 확인 중"],
		"cancelled": ["Purchase cancelled", "구매를 취소했어요"], "pending": ["Waiting for approval", "결제 승인을 기다리고 있어요"],
		"verifying": ["Checking the transaction", "거래를 확인하고 있어요"], "fulfilling": ["Delivering your purchase", "상품을 지급하고 있어요"],
		"completed": ["Purchase delivered", "상품 지급 완료"], "failed": ["Check your previous transaction", "기존 거래를 확인해 주세요"],
		"revoked": ["Purchase access changed", "구매 권한이 변경됐어요"], "checking": ["Checking owned items", "보유 상품을 확인하고 있어요"],
		"none": ["No items to restore", "복원할 상품이 없어요"], "restored": ["Items restored", "보유 상품 복원 완료"], "partial": ["Some items still need checking", "일부 상품을 더 확인해야 해요"]}
	var pair: Array = names.get(commerce.state, names.failed)
	content.add_child(_label(tr_text(pair[0], pair[1]), 24))
	content.add_child(_label(tr_text("A completed payment and a delivered item are checked separately. Check the previous transaction before buying again.", "결제와 상품 지급을 각각 확인합니다. 다시 구매하기 전에 기존 거래를 확인해 주세요.")))
	if commerce.state in ["pending", "failed", "verifying", "fulfilling"]:
		_button(tr_text("Check transaction", "기존 거래 확인"), commerce.reconcile).name = "reconcile"
	_button(tr_text("Support code", "지원코드 확인"), func() -> void: _open("support")).name = "support"

func _draw_ranking() -> void:
	_clear(tr_text("Leaderboard", "리더보드"))
	var compact := size.y < 500
	var periods := HBoxContainer.new()
	content.add_child(periods)
	for item in [["alltime", "All time", "전체 기간"], ["weekly", "This week", "이번 주"]]:
		var value: String = item[0]
		if value not in ranking.capabilities().get("periods", []): continue
		_button(("✓ " if ranking.period == value else "") + tr_text(item[1], item[2]), func() -> void: ranking.period = value; ranking.fetch(), periods).name = value
	var scopes := periods if compact else HBoxContainer.new()
	if not compact: content.add_child(scopes)
	for item in [["top", "Top scores", "상위 기록"], ["around", "Around me", "내 주변"]]:
		var value: String = item[0]
		_button(tr_text(item[1], item[2]), func() -> void: ranking.scope = value; ranking.fetch(), scopes).name = value
	var box := _scroll()
	var statuses := {"loading": ["Loading scores…", "순위를 불러오고 있어요…"], "empty": ["No scores yet", "아직 등록된 기록이 없어요"], "self_unranked": ["No personal score yet", "아직 내 기록이 없어요"], "failed": ["Scores could not be loaded", "순위를 불러오지 못했어요"], "offline_cached": ["Offline, previously checked scores", "오프라인, 이전에 확인한 순위예요"], "season_closed": ["This season has ended", "이번 시즌이 종료됐어요"], "auth_required": ["Sign in to view your score", "내 기록을 보려면 로그인이 필요해요"], "submitting": ["Checking your score", "점수를 확인하고 있어요"]}
	if statuses.has(ranking.status):
		var pair: Array = statuses[ranking.status]
		box.add_child(_label(tr_text(pair[0], pair[1])))
	for row in ranking.rows:
		box.add_child(_rank_row(row))
	if not ranking.self_record.is_empty():
		var me: Dictionary = ranking.self_record
		if not compact: content.add_child(_label(tr_text("My best record", "내 최고 기록"), 13))
		content.add_child(_rank_row(me, true))
	if ranking.checked_at > 0:
		var timestamp := Time.get_datetime_string_from_unix_time(ranking.checked_at)
		content.add_child(_label(tr_text("Last checked: ", "마지막 확인: ") + (timestamp.get_slice("T", 1) if compact else timestamp.replace("T", " ")) + " UTC", 12))
	var footer := HBoxContainer.new()
	content.add_child(footer)
	if not ranking.next_cursor.is_empty(): _button(tr_text("More", "더 보기"), func() -> void: ranking.fetch(true), footer).name = "rank_more"
	_button(tr_text("Refresh", "새로고침"), func() -> void: ranking.fetch(), footer).name = "rank_refresh"

func _rank_row(row: Dictionary, self_row: bool = false) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.custom_minimum_size.y = 48
	card.add_theme_stylebox_override("panel", _skin(Color("e5ebd2") if self_row or row.get("isSelf", false) else Color(palette.panel), Color("b4c4a0") if self_row else Color("e1e3d1"), 8))
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_theme_constant_override("separation", 7)
	card.add_child(line)
	var place := _label(str(row.get("rank", "—")), 15)
	place.custom_minimum_size.x = 28
	line.add_child(place)
	var name_label := _label(str(row.get("name", "")), 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var points := _label("%s %s" % [row.get("score", ""), tr_text("pts", "점")], 15)
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	points.custom_minimum_size.x = 80
	line.add_child(points)
	return card

func _show_error(code: String) -> void:
	content.add_child(_label(_error_text(code), 14))

func _error_text(code: String) -> String:
	match code:
		"copied": return tr_text("Code copied", "코드를 복사했어요")
		"copy_failed": return tr_text("Copy failed. Select the code to copy it.", "복사하지 못했습니다. 코드를 선택해 복사해 주세요.")
		"save_failed": return tr_text("Could not save. Try again.", "저장하지 못했습니다. 다시 시도해 주세요.")
		"save_corrupt", "save_schema_invalid": return tr_text("The save could not be read. Your data was preserved.", "저장을 읽지 못했습니다. 기존 데이터는 보존했습니다.")
		"save_newer_version": return tr_text("Update the game to open this save.", "이 저장을 열려면 게임을 업데이트해 주세요.")
		"maintenance": return tr_text("Service maintenance, try again later.", "서비스 점검 중입니다. 잠시 후 다시 확인해 주세요.")
		"update_required": return tr_text("A game update is required.", "게임 업데이트가 필요합니다.")
	return tr_text("Could not complete this action. Try again.", "처리하지 못했습니다. 다시 확인해 주세요.")

func _unclaimed() -> int:
	var count := 0
	for mail in (services.mails if services.mode == "server" else state.data.mail):
		if mail.claimedAt == 0 and (mail.expiresAt == 0 or mail.expiresAt > Time.get_unix_time_from_system()):
			count += 1
	return count

func _scroll() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	return box

## notice는 목록을 다 그린 뒤 보여 준다. 서버 목록은 비동기로 다시 그려지므로 먼저 붙이면 지워진다.
func _inbox(more: bool = false, notice: String = "") -> void:
	screen = "inbox"
	_clear(tr_text("Inbox", "우편함"))
	if services.mode == "server":
		content.add_child(_label(tr_text("Loading…", "불러오는 중…")))
		services.list_mail(func(result: Dictionary) -> void:
			if not result.get("ok", false):
				_show_error(str(result.get("code", "network_error")))
				_button(tr_text("Retry", "다시 시도"), _inbox)
				_button(tr_text("Back", "뒤로"), _back)
				return
			_render_mail()
			if not notice.is_empty():
				content.add_child(_label(notice, 14))
		, more)
	else:
		_render_mail()
		if not notice.is_empty():
			content.add_child(_label(notice, 14))

func _render_mail() -> void:
	_clear(tr_text("Inbox", "우편함"))
	var mails: Array = services.mails if services.mode == "server" else state.data.mail
	var box := _scroll()
	if mails.is_empty():
		box.add_child(_label(tr_text("No messages yet", "아직 우편이 없어요")))
	for mail in mails:
		var card := VBoxContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(card)
		card.add_child(_label(str(mail.title)))
		card.add_child(_label(str(mail.body), 20))
		if services.mode == "local":
			card.add_child(_label("+%d " % mail.amount + tr_text("coins", "코인"), 20))
		else:
			for reward in mail.get("rewards", []):
				card.add_child(_label("%s ×%d" % [reward.entitlementId, reward.quantity], 20))
		card.add_child(_label(tr_text("Read", "읽음") if mail.readAt != 0 else tr_text("Unread", "읽지 않음"), 18))
		if mail.expiresAt != 0:
			card.add_child(_label(tr_text("Expires: ", "만료: ") + Time.get_datetime_string_from_unix_time(mail.expiresAt), 18))
		_button(tr_text("Mark read", "읽음 표시"), func() -> void: _read(str(mail.id)), card)
		var expired: bool = mail.expiresAt != 0 and mail.expiresAt <= Time.get_unix_time_from_system()
		var claim := _button(tr_text("Received", "수령 완료") if mail.claimedAt != 0 else (tr_text("Expired", "만료됨") if expired else tr_text("Claim", "받기")), func() -> void: _claim(str(mail.id)), card)
		claim.disabled = pending or mail.claimedAt != 0 or expired
	if services.mode == "server" and not services.cursor.is_empty():
		_button(tr_text("More messages", "더 보기"), func() -> void: _inbox(true))
	var all := _button(tr_text("Claim all available", "받을 수 있는 우편 모두 받기"), _claim_all)
	all.disabled = pending or _unclaimed() == 0
	_button(tr_text("Grant history", "지급 내역"), _history)
	_button(tr_text("Back", "뒤로"), _back)

func _read(id: String) -> void:
	if services.mode == "server":
		services.read(id, func(result: Dictionary) -> void:
			if result.get("ok", false): _inbox()
			else: _show_error(str(result.get("code", "network_error")))
		)
	elif state.read_mail(id, int(Time.get_unix_time_from_system())):
		_inbox()
	else:
		_show_error(state.error)

func _claim(id: String) -> void:
	if pending:
		return
	if services.mode == "server":
		pending = true
		_render_mail()
		var view := _view
		services.claim(id, func(result: Dictionary) -> void:
			pending = false
			if result.get("ok", false):
				state.record_remote_claim(id)
				_sync_metrics()
			# 응답 전에 화면이 바뀌었으면 사용자 위치를 바꾸지 않는다. 우편함을 다시 열어 둔 경우에만 버튼 상태를 새로 그린다.
			if view != _view:
				if screen == "inbox":
					_inbox()
				return
			if result.get("ok", false):
				_inbox()
			else:
				_render_mail()
				_show_error(str(result.get("code", "network_error")))
		)
	else:
		var result: Dictionary = state.claim_mail(id, int(Time.get_unix_time_from_system()))
		if result.ok:
			_inbox()
		else:
			_show_error(str(result.code))

func _claim_all() -> void:
	var ids: Array = []
	for mail in (services.mails if services.mode == "server" else state.data.mail):
		if mail.claimedAt == 0 and (mail.expiresAt == 0 or mail.expiresAt > Time.get_unix_time_from_system()):
			ids.append(mail.id)
	if services.mode == "local":
		for id in ids:
			var result: Dictionary = state.claim_mail(id, int(Time.get_unix_time_from_system()))
			if not result.ok:
				_show_error(str(result.code))
				return
		_inbox()
		return
	if pending or ids.is_empty():
		return
	pending = true
	_claim_batches(ids, [], _view)

## SDK는 한 번에 1~50개만 받는다. 50개씩 순서대로 요청하고 실패한 우편을 모은다.
func _claim_batches(remaining: Array, failures: Array, view: int) -> void:
	if remaining.is_empty():
		pending = false
		_sync_metrics()
		var notice: String = "" if failures.is_empty() else tr_text("Some rewards remain. Retry the unclaimed messages.", "받지 못한 우편이 있어요. 미수령 우편을 다시 받아 주세요.")
		# 화면이 바뀌었으면 사용자 위치를 바꾸지 않는다. 우편함을 다시 열어 둔 경우에만 새로 그린다.
		if view == _view or screen == "inbox":
			_inbox(false, notice)
		return
	var chunk: Array = remaining.slice(0, 50)
	services.claim_batch(chunk, func(result: Dictionary) -> void:
		if result.get("ok", false):
			for item in result.result.results:
				if item.ok:
					state.record_remote_claim(str(item.id))
				else:
					failures.append(item.id)
		else:
			failures.append_array(chunk)
		_claim_batches(remaining.slice(50), failures, view)
	)

func _history() -> void:
	screen = "history"
	_clear(tr_text("Grant history", "지급 내역"))
	var box := _scroll()
	if services.mode == "local":
		for id in state.data.grants:
			box.add_child(_label("%s  +%s" % [id, state.data.grants[id]]))
	else:
		for mail in services.mails:
			if mail.claimedAt != 0:
				box.add_child(_label(str(mail.title) + " · " + Time.get_datetime_string_from_unix_time(mail.claimedAt)))
	_button(tr_text("Back", "뒤로"), _inbox)


func _show_next_popup() -> void:
	var item: Dictionary = popups.next()
	if item.is_empty(): return
	reward_text = str(item.payload.get("text", ""))
	screen = "result"
	_submit_result()
	_draw_result()
