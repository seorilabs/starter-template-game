extends Control

const DEFAULT_TITLE: String = "Seorilabs Starter Template Game"

func _ready() -> void:
	var title_label: Label = get_node_or_null("Title") as Label
	if title_label == null:
		return

	var app_name: String = str(ProjectSettings.get_setting("application/config/name", DEFAULT_TITLE))
	if app_name.is_empty():
		title_label.text = DEFAULT_TITLE
		return

	title_label.text = app_name

