extends SceneTree
## skin.json으로 theme.tres를 다시 만든다. svg를 먼저 import한 뒤 실행한다.
##   godot --headless --path godot --import --quit-after 2
##   godot --headless --path godot --script res://addons/seorilabs_game/ui_kit/build_theme.gd [-- --skin res://.../skins/<id>]
const Builder = preload("res://addons/seorilabs_game/ui_kit/theme_builder.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[args.find("--skin") + 1] if args.has("--skin") and args.find("--skin") + 1 < args.size() else Builder.DEFAULT_SKIN
	var theme := Builder.build(dir, "en")
	var path := dir.path_join("theme.tres")
	var error := ResourceSaver.save(theme, path)
	if error != OK:
		push_error("theme save failed: %d" % error)
		quit(1)
		return
	# uid는 .uid/.import처럼 생성 파일이므로 경로만 남긴다. 새 체크아웃에서도 같은 파일이 된다.
	var text := FileAccess.get_file_as_string(path)
	var regex := RegEx.new()
	regex.compile(' uid="uid://[^"]*"')
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(regex.sub(text, "", true))
	file.close()
	print("theme written: " + path)
	quit(0)
