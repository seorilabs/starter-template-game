extends Control
var profile := "map"
var begin: Callable

func _ready() -> void:
 var row := VBoxContainer.new()
 row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(row)
 var label := Label.new()
 label.text = "★  →  ★  →  ★" if profile == "map" else "★  ★  ★"
 label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 label.add_theme_font_size_override("font_size", 30)
 label.size_flags_vertical = Control.SIZE_EXPAND_FILL
 row.add_child(label)
 var play := Button.new()
 play.text = "▶"
 play.tooltip_text = "Play"
 play.custom_minimum_size.y = 48
 play.pressed.connect(begin)
 row.add_child(play)
