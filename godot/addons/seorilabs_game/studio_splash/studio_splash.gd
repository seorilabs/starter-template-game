extends Control

const ART_DIR := "res://addons/seorilabs_game/studio_splash/"
const BACKGROUND := Color("#020b16")
const NORMAL_DURATION := 1.15
const STILL_DURATION := 0.35

var reduced_motion := false
var selected_orientation := ""
var _elapsed := 0.0
var _portrait: Texture2D
var _landscape: Texture2D
var _upper: Texture2D
var _lower: Texture2D
var _wordmark: Texture2D


func load_art() -> bool:
	_landscape = _texture("first-light-background-landscape.webp")
	_portrait = _texture("first-light-background-portrait.webp")
	_upper = _texture("first-light-upper.svg")
	_lower = _texture("first-light-lower.svg")
	_wordmark = _texture("first-light-wordmark.svg")
	return _landscape != null and _portrait != null and _upper != null and _lower != null and _wordmark != null


func _texture(file_name: String) -> Texture2D:
	var path := ART_DIR + file_name
	return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= (STILL_DURATION if reduced_motion else NORMAL_DURATION):
		queue_free()
	else:
		queue_redraw()


func _input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
	elif not (event is InputEventKey or event is InputEventScreenTouch or event is InputEventJoypadButton):
		return
	queue_free()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _landscape == null:
		return
	var portrait := size.x < size.y
	selected_orientation = "portrait" if portrait else "landscape"
	var plate := _portrait if portrait else _landscape
	var dimensions := plate.get_size()
	var cover := dimensions * maxf(size.x / dimensions.x, size.y / dimensions.y)
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_texture_rect(plate, Rect2((size - cover) * 0.5, cover), false, _light(_reveal(0.0, 0.65)))

	var safe_width := minf(size.x, size.y * dimensions.aspect())
	var symbol_width := safe_width * (0.2912 if portrait else 0.131075)
	var name_width := safe_width * (0.82 if portrait else 0.434)
	var name_size := Vector2(name_width, name_width / _wordmark.get_size().aspect())
	var gap := safe_width * (0.022 if portrait else 0.0115)
	var top := (size.y - symbol_width - name_size.y - gap) * 0.5
	var symbol_position := Vector2((size.x - symbol_width) * 0.5, top)
	var name_position := Vector2((size.x - name_width) * 0.5, top + symbol_width + gap)

	_draw_half(_upper, symbol_position, symbol_width, Vector2(-0.3, -0.14), _reveal(0.12, 0.62))
	_draw_half(_lower, symbol_position, symbol_width, Vector2(0.3, 0.14), _reveal(0.17, 0.62))
	draw_texture_rect(_wordmark, Rect2(name_position, name_size), false, _light(_reveal(0.48, 0.35)))


func _draw_half(art: Texture2D, origin: Vector2, width: float, offset: Vector2, reveal: float) -> void:
	var position_on_screen := origin + offset * width * (1.0 - reveal)
	draw_texture_rect(art, Rect2(position_on_screen, Vector2(width, width)), false, _light(reveal))


func _reveal(delay: float, duration: float) -> float:
	return 1.0 if reduced_motion else smoothstep(0.0, 1.0, (_elapsed - delay) / duration)


func _light(alpha: float) -> Color:
	return Color(1.0, 1.0, 1.0, alpha)
