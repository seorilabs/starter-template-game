extends Control

const LOGO: Texture2D = preload("res://addons/seorilabs_game/studio_splash/seori-labs-logo-stacked-reverse.svg")
const BACKGROUND := Color("#020b16")
const HOLD_MSEC := 1000
const FADE_SECONDS := 0.15

var reduced_motion := false
var _hold_until: int
var _original_quit_on_back: Variant


func _ready() -> void:
	if get_viewport() == get_tree().root:
		_original_quit_on_back = get_tree().is_quit_on_go_back()
		get_tree().set_quit_on_go_back(false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	set_process(false)
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	_hold_until = Time.get_ticks_msec() + HOLD_MSEC
	set_process(true)


func _exit_tree() -> void:
	if _original_quit_on_back != null:
		get_tree().set_quit_on_go_back(_original_quit_on_back)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() < _hold_until:
		return
	set_process(false)
	if not reduced_motion:
		var fade := create_tween().set_ignore_time_scale()
		fade.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
		await fade.finished
	queue_free()


func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func artwork_rect() -> Rect2:
	var available := Rect2(Vector2.ZERO, size)
	if get_viewport() == get_tree().root and (OS.has_feature("android") or OS.has_feature("ios")):
		var window_size := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if window_size.x > 0 and window_size.y > 0 and safe.has_area():
			var scale_to_view := size / window_size
			var safe_rect := Rect2(Vector2(safe.position) * scale_to_view, Vector2(safe.size) * scale_to_view)
			var clipped := available.intersection(safe_rect)
			if clipped.has_area():
				available = clipped
	var aspect := LOGO.get_size().aspect()
	var width := minf(320.0, minf(available.size.x * 0.56, available.size.y * 0.38 * aspect))
	var logo_size := Vector2(width, width / aspect)
	return Rect2(available.get_center() - logo_size * 0.5, logo_size)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_texture_rect(LOGO, artwork_rect(), false)
