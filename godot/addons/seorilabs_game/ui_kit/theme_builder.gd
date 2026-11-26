extends RefCounted
## skin.json v2로 Theme를 조립한다. 제품은 skin.json과 svg, 서체만 바꾸고 조립 규칙은 공통이다.
const DEFAULT_SKIN := "res://addons/seorilabs_game/skins/soft_adventure"
const VARIATIONS := {"PrimaryButton": "Button", "ChipPanel": "PanelContainer", "PopupFrame": "PanelContainer", "RowPanel": "PanelContainer", "DisplayLabel": "Label", "TitleLabel": "Label", "NumberLabel": "Label", "CaptionLabel": "Label"}

static func load_skin(dir: String = DEFAULT_SKIN) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("skin.json")))
	return parsed if parsed is Dictionary else {}

static func variable_font(path: String, weight: int) -> Font:
	var font := FontVariation.new()
	font.base_font = load(path)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font

## 한국어는 Jua처럼 굵기 축이 없는 서체를 그대로 쓰고, 영어는 가변 서체의 굵기를 고른다.
static func display_font(skin: Dictionary, language: String) -> Font:
	var fonts: Dictionary = skin.get("fonts", {})
	if language == "ko":
		return load(str(fonts.get("display_ko", fonts.get("display_en"))))
	return variable_font(str(fonts.get("display_en")), 650)

## 9분할 값은 최종 파일 픽셀 기준이다(skin.json margins: 좌, 상, 우, 하).
static func texture_box(dir: String, spec: Dictionary, state: String = "normal") -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(dir.path_join(str(spec.get(state, spec.get("normal", "")))))
	var margins: Array = spec.get("margins", [16, 16, 16, 16])
	box.texture_margin_left = float(margins[0])
	box.texture_margin_top = float(margins[1])
	box.texture_margin_right = float(margins[2])
	box.texture_margin_bottom = float(margins[3])
	var content: Array = spec.get("content", margins)
	box.content_margin_left = float(content[0])
	box.content_margin_top = float(content[1])
	box.content_margin_right = float(content[2])
	box.content_margin_bottom = float(content[3])
	# 늘어나는 구역에 결(나뭇결, 바느질)이 있는 그린 스킨은 tile로 반복해 줄무늬가 생기지 않게 한다.
	# tile_fit은 반복 횟수를 정수로 맞춰 마지막 타일이 잘리지 않게 한다(타일 끝 → 모서리 조각이 원래 이웃 픽셀로 이어진다).
	var axis: Array = spec.get("axis", ["stretch", "stretch"])
	box.axis_stretch_horizontal = _axis_mode(str(axis[0]))
	box.axis_stretch_vertical = _axis_mode(str(axis[1]))
	return box

static func _axis_mode(name: String) -> StyleBoxTexture.AxisStretchMode:
	match name:
		"tile": return StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		"tile_fit": return StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH

static func focus_overlay(color: Color) -> StyleBoxFlat:
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = color
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(14)
	return focus

static func build(dir: String = DEFAULT_SKIN, language: String = "en") -> Theme:
	var skin := load_skin(dir)
	var theme := Theme.new()
	var text := Color(str(skin.get("text", "#244e5c")))
	var fonts: Dictionary = skin.get("fonts", {})
	var sizes: Dictionary = skin.get("sizes", {})
	var textures: Dictionary = skin.get("textures", {})
	var body := variable_font(str(fonts.get("body")), 550)
	var number := variable_font(str(fonts.get("number", fonts.get("body"))), 600)
	theme.default_font = body
	theme.default_font_size = int(sizes.get("body", 16))
	for name in VARIATIONS:
		theme.add_type(name)
		theme.set_type_variation(name, VARIATIONS[name])
	for cls in ["Button", "CheckButton", "PrimaryButton"]:
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			theme.set_color(color_name, cls, text)
		theme.set_color("font_disabled_color", cls, Color("6d7c79"))
		var spec: Dictionary = textures.get("button_primary" if cls == "PrimaryButton" else "button_secondary", {})
		theme.set_stylebox("normal", cls, texture_box(dir, spec, "normal"))
		theme.set_stylebox("hover", cls, texture_box(dir, spec, "normal"))
		theme.set_stylebox("pressed", cls, texture_box(dir, spec, "pressed"))
		theme.set_stylebox("disabled", cls, texture_box(dir, spec, "disabled"))
		theme.set_stylebox("focus", cls, focus_overlay(Color(str(skin.get("focus", "#286778")))))
	theme.set_stylebox("panel", "PanelContainer", texture_box(dir, textures.get("panel", {})))
	theme.set_stylebox("panel", "Panel", texture_box(dir, textures.get("popup_frame", {})))
	theme.set_stylebox("panel", "PopupFrame", texture_box(dir, textures.get("popup_frame", {})))
	theme.set_stylebox("panel", "ChipPanel", texture_box(dir, textures.get("chip", {})))
	# 툴팁(잘린 재화 칩 원문 등)은 어두운 칩 판에 밝은 글자로 띄운다. 기본 Label 색은 반투명 회색 바탕에서 대비가 1.6:1 아래였다.
	theme.set_stylebox("panel", "TooltipPanel", texture_box(dir, textures.get("chip", {})))
	theme.set_color("font_color", "TooltipLabel", Color("fff7df"))
	# 한 줄 높이의 목록 행(순위, 짧은 카드)은 두꺼운 패널 대신 보조 버튼의 얇은 판을 쓴다.
	theme.set_stylebox("panel", "RowPanel", texture_box(dir, textures.get("button_secondary", {})))
	theme.set_stylebox("read_only", "LineEdit", texture_box(dir, textures.get("panel", {})))
	theme.set_color("font_uneditable_color", "LineEdit", text)
	theme.set_color("font_color", "Label", text)
	theme.set_font("font", "NumberLabel", number)
	theme.set_color("font_color", "NumberLabel", Color("fff7df"))
	theme.set_color("font_outline_color", "NumberLabel", Color("244e5c"))
	theme.set_constant("outline_size", "NumberLabel", 4)
	theme.set_color("font_color", "DisplayLabel", Color("fff8df"))
	theme.set_color("font_shadow_color", "DisplayLabel", Color("294c62"))
	theme.set_constant("shadow_offset_y", "DisplayLabel", 2)
	theme.set_color("font_outline_color", "DisplayLabel", Color("294c62"))
	theme.set_constant("outline_size", "DisplayLabel", 6)
	localize(theme, skin, language, func(value: int) -> int: return value)
	return theme

## 언어와 큰 글자 설정에 맞춰 역할 서체와 크기만 다시 적용한다. 스킨은 바꾸지 않는다.
static func localize(theme: Theme, skin: Dictionary, language: String, font_size: Callable) -> void:
	var sizes: Dictionary = skin.get("sizes", {})
	var display := display_font(skin, language)
	for cls in ["PrimaryButton", "DisplayLabel", "TitleLabel"]:
		theme.set_font("font", cls, display)
	theme.default_font_size = font_size.call(int(sizes.get("body", 16)))
	theme.set_font_size("font_size", "PrimaryButton", font_size.call(int(sizes.get("action", 22))))
	theme.set_font_size("font_size", "DisplayLabel", font_size.call(int(sizes.get("display", 34))))
	theme.set_font_size("font_size", "TitleLabel", font_size.call(int(sizes.get("title", 24))))
	theme.set_font_size("font_size", "NumberLabel", font_size.call(int(sizes.get("number", 18))))
	theme.set_font_size("font_size", "CaptionLabel", font_size.call(int(sizes.get("label", 14))))
