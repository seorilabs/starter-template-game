extends SceneTree

const State = preload("res://addons/seorilabs_game/flow/state.gd")
const Driver = preload("res://tests/common/e2e_driver.gd")

var driver: RefCounted
var save_dir := "user://first-light-e2e-%d" % Time.get_ticks_usec()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[args.find("--out") + 1] if args.has("--out") else save_dir
	driver = Driver.new(self, Vector2i(1280, 720), out, args.has("--capture"))
	driver.begin("first-light-startup", ["startup"])
	var main := await _mount("regular")
	var splash := main.find_child("StudioSplash", true, false)
	if splash == null:
		_check(false, "The default game startup did not create the First Light splash")
		await driver.unmount(main)
		driver.end()
		quit(driver.finish())
		return
	await _exercise_regular(main, splash)
	await driver.unmount(main)
	await _exercise_motion_and_error()
	driver.end()
	quit(driver.finish({"sourceSha": OS.get_environment("GITHUB_SHA")}))


func _exercise_regular(main: Control, splash: Node) -> void:
	_check(splash.is_visible(), "The studio logo is visible on cold launch")
	_check(splash.has_method("artwork_rect"), "Artwork uses one contained official lockup")
	if not splash.has_method("artwork_rect"):
		return
	for viewport_size in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(568, 320), Vector2i(844, 390), Vector2i(768, 1024)]:
		driver.viewport.size = viewport_size
		await driver.frames()
		var rect: Rect2 = splash.artwork_rect()
		var bounds := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_check(bounds.encloses(rect) and rect.get_center().is_equal_approx(bounds.get_center()),
			"Full logo fits and is centered at %s" % viewport_size)
		_check(is_equal_approx(rect.size.aspect(), 384.0 / 168.0), "Logo proportions are preserved")
		if driver.capture:
			await driver.shot("studio-logo-%dx%d" % [viewport_size.x, viewport_size.y], false)
	_check(main.progress >= 2, "Initialization runs while the logo is visible")
	_check(await _closed(main, 1.3), "Splash automatically reveals the title")
	_check(main.screen == "title" and main.initialized, "Successful startup lands on the ready title")


func _exercise_motion_and_error() -> void:
	var main := await _mount("reduced", true)
	var splash := main.find_child("StudioSplash", true, false)
	_check(splash != null and splash.reduced_motion, "Splash reads saved reduced motion")
	_check(not await _closed(main, 0.75), "Reduced motion keeps the logo visible for a readable hold")
	_check(await _closed(main, 0.55), "Reduced motion reveals the title automatically")
	await driver.unmount(main)

	main = await _mount("input")
	for kind in ["keyboard", "mouse", "touch"]:
		var event: InputEvent
		if kind == "keyboard":
			var key := InputEventKey.new()
			key.keycode = KEY_ENTER
			key.pressed = true
			event = key
		elif kind == "mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.position = Vector2(driver.viewport.size) * 0.5
			mouse.pressed = true
			event = mouse
		else:
			var touch := InputEventScreenTouch.new()
			touch.position = Vector2(driver.viewport.size) * 0.5
			touch.pressed = true
			event = touch
		driver.viewport.push_input(event)
		event.pressed = false
		driver.viewport.push_input(event)
		await driver.frames()
		_check(main.find_child("StudioSplash", true, false) != null and main.screen == "title",
			"%s is blocked without skipping the logo or starting the game" % kind)
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(main.find_child("StudioSplash", true, false) != null and main.screen == "title",
		"Android back does not navigate under the splash")
	_check(await _closed(main, 1.3) and main.screen == "title", "Input does not interfere with the transition")
	await driver.unmount(main)

	main = await _mount("corrupt", false, true)
	_check(await _closed(main, 1.3) and not main.startup_error.is_empty() and not main.initialized,
		"Corrupt saves still show the title error after the splash")
	await driver.unmount(main)


func _mount(name: String, reduced := false, corrupt := false) -> Control:
	var path := save_dir + "/" + name + ".json"
	DirAccess.make_dir_recursive_absolute(save_dir)
	if reduced:
		var saved = State.new(path)
		saved.load_state()
		var data: Dictionary = saved.data.duplicate(true)
		data.settings.reduced_motion = true
		assert(saved.commit(data))
	elif corrupt:
		var invalid := FileAccess.open(path, FileAccess.WRITE)
		invalid.store_string("invalid save")
		invalid.close()
	var main: Control = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	if ResourceLoader.exists("res://game/bootstrap/main.gd"):
		main.set("connect_platform", false)
	main.state = State.new(path)
	main.device_locale = "en-US"
	await driver.mount(main)
	return main


func _closed(main: Control, budget: float) -> bool:
	var start := Time.get_ticks_msec()
	while main.find_child("StudioSplash", true, false) != null and Time.get_ticks_msec() - start < budget * 1000:
		await process_frame
	return main.find_child("StudioSplash", true, false) == null


func _check(result: bool, label: String) -> void:
	driver.step(label, result)
