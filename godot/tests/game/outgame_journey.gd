extends SceneTree
const Driver = preload("res://tests/common/e2e_driver.gd")
const State = preload("res://addons/seorilabs_game/flow/state.gd")
var d
var save_dir := ""

func _initialize() -> void: call_deferred("run")
func arg(args: PackedStringArray, key: String, fallback: String) -> String:
 return args[args.find(key) + 1] if args.has(key) else fallback
func b(main: Node, name: String) -> Control: return main.find_child(name, true, false) as Control
func text_button(main: Node, value: String) -> Button:
 for child in main.find_children("*", "Button", true, false):
  if child.text == value: return child
 return null
func mount_game(path: String, home: String = "") -> Control:
 var main: Control = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
 main.state = State.new(path)
 main.device_locale = "en-US"
 if not home.is_empty(): main.home_profile = home
 await d.mount(main)
 d.step("actual startup completes", await d.wait_for(func(): return main.initialized))
 return main
func run() -> void:
 var args := OS.get_cmdline_user_args()
 var size := arg(args, "--size", "390x844").split("x")
 d = Driver.new(self, Vector2i(int(size[0]), int(size[1])), arg(args, "--out", "user://e2e/game"), args.has("--capture"))
 save_dir = "user://e2e-game-%d" % Time.get_ticks_usec()
 DirAccess.make_dir_recursive_absolute(save_dir)
 print("Isolated save: ", ProjectSettings.globalize_path(save_dir))
 d.begin("offline-first-play-restart", ["startup", "tutorial", "account_save", "inbox", "commerce", "operations", "observability", "ui_leaderboard"])
 var main: Control = await mount_game(save_dir + "/play.json")
 await d.shot("title")
 d.step("start actual sample", await d.tap(b(main, "start")) and main.screen == "play")
 await d.shot("tutorial")
 for i in 3: d.step("collect star", await d.tap(text_button(main, "★")))
 d.step("collect reward", await d.tap(text_button(main, "Collect +10")))
 d.expect_equal("persisted reward", main.state.data.coins, 10)
 await d.shot("result")
 d.step("return to lobby", await d.tap(b(main, "reward_continue")) and main.screen == "home")
 d.step("unsupported commerce and ranking hidden", b(main, "shop") == null and b(main, "leaderboard") == null)
 await d.shot("home")
 d.step("open inbox", await d.tap(b(main, "inbox")) and main.screen == "inbox")
 await d.shot("inbox")
 d.step("close to home", await d.tap(b(main, "close")) and main.screen == "home")
 await d.unmount(main)
 main = await mount_game(save_dir + "/play.json")
 d.step("restart returns home", await d.tap(b(main, "start")) and main.screen == "home")
 d.expect_equal("reward restored", main.state.data.coins, 10)
 d.end()
 d.begin("settings-language-support-focus", ["settings_support", "account_save", "ui_support_entry", "ui_analytics_opt_out", "ui_locale_offline", "ui_navigation"])
 d.step("settings", await d.tap(b(main, "settings")))
 d.step("turn analytics off", await d.tap(b(main, "analytics")) and not main.state.data.settings.analytics and not main.analytics.effective)
 await d.shot("settings")
 d.step("support is directly reachable", await d.tap(b(main, "support")) and main.screen == "support")
 d.step("local support unavailable without invented identity", main.support.code.is_empty() and b(main, "copy").disabled)
 await d.shot("support")
 d.step("back restores settings", await d.tap(b(main, "back")) and main.screen == "settings")
 d.step("language", await d.tap(b(main, "language")))
 d.step("Korean selection", await d.tap(b(main, "ko")) and main.language() == "ko")
 await d.shot("korean")
 d.step("settings return", await d.tap(b(main, "back")))
 d.step("accessibility", await d.tap(b(main, "accessibility")))
 d.step("larger text", await d.tap(b(main, "large_text")) and main.state.data.settings.large_text)
 await d.shot("large-text")
 d.step("back to settings", await d.tap(b(main, "back")))
 var reached := false
 for i in 20:
  var ev := InputEventKey.new(); ev.keycode = KEY_TAB; ev.pressed = true
  d.viewport.push_input(ev, true)
  ev = InputEventKey.new(); ev.keycode = KEY_TAB; ev.pressed = false
  d.viewport.push_input(ev, true)
  await d.frames()
  var focus: Control = d.viewport.gui_get_focus_owner()
  if focus != null and focus.name == "support":
   var scroll: ScrollContainer = main.content.find_children("*", "ScrollContainer", true, false)[0]
   reached = scroll.get_global_rect().encloses(focus.get_global_rect())
   await d.shot("keyboard-focus")
   break
 d.step("keyboard focus scrolls into view", reached)
 await d.unmount(main)
 main = await mount_game(save_dir + "/play.json")
 d.step("language and analytics survive restart", main.language() == "ko" and not main.state.data.settings.analytics and main.state.data.settings.large_text)
 await d.unmount(main)
 d.end()
 d.begin("three-home-profiles", ["startup", "tutorial", "account_save", "ui_navigation"])
 for home in ["hero", "map", "world"]:
  var store = State.new(save_dir + "/" + home + ".json")
  store.load_state(); store.skip_tutorial()
  main = await mount_game(store.path, home)
  d.step(home + " start", await d.tap(b(main, "start")) and main.screen == "home")
  await d.shot(home)
  d.step(home + " playable", await d.tap(b(main, "play")) and main.screen == "play")
  await d.unmount(main)
 d.end()
 for name in DirAccess.get_files_at(save_dir): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir.path_join(name)))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir))
 quit(d.finish({"sourceSha": OS.get_environment("GITHUB_SHA")}))
