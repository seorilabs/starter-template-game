extends SceneTree
func _initialize() -> void:
 var args := OS.get_cmdline_user_args()
 if args.size() != 1:
  printerr("AppIcon directory argument required")
  quit(1)
  return
 var folder: String = args[0]
 var count := 0
 for file in DirAccess.get_files_at(folder):
  if not file.ends_with(".png"): continue
  var image := Image.new()
  var path := folder.path_join(file)
  if image.load(path) != OK:
   printerr("Cannot read exported icon: " + file)
   quit(1)
   return
  image.convert(Image.FORMAT_RGB8)
  if image.save_png(path) != OK:
   printerr("Cannot save opaque exported icon: " + file)
   quit(1)
   return
  count += 1
 print("Opaque iOS icons: ", count)
 quit(0 if count > 0 else 1)
