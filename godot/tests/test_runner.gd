extends Node

func _ready() -> void:
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene.is_empty():
		push_error("application/run/main_scene is not configured")
		get_tree().quit(1)
		return

	if !ResourceLoader.exists(main_scene):
		push_error("Configured main scene does not exist: %s" % main_scene)
		get_tree().quit(1)
		return

	get_tree().quit(0)

