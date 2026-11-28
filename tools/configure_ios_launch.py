"""Replace Godot's generated image launch screen with an image-free storyboard."""

import plistlib
from pathlib import Path
import shutil
import sys
from xml.etree import ElementTree


def configure(project: Path) -> None:
    app = project.parent / project.stem
    metadata_path = app / f"{project.stem}-Info.plist"
    metadata = plistlib.loads(metadata_path.read_bytes())
    if metadata.get("UILaunchStoryboardName") != "Launch Screen":
        raise ValueError("Unexpected Godot launch storyboard name")

    original = app / "Launch Screen.storyboard"
    replacement = app / f"{project.stem} Studio Launch.storyboard"
    storyboard = ElementTree.parse(original)
    view = storyboard.find(".//viewController/view[@key='view']")
    resources = storyboard.find("resources")
    if view is None or view.find("subviews/imageView[@image='SplashImage']") is None or resources is None:
        raise ValueError("Unexpected Godot launch storyboard layout")

    pbx_path = project / "project.pbxproj"
    pbx = pbx_path.read_text()
    if f'path = "{original.name}";' not in pbx:
        raise ValueError("Launch storyboard is missing from the Xcode project")

    view.remove(view.find("subviews"))
    view.remove(view.find("constraints"))
    storyboard.getroot().remove(resources)
    ElementTree.indent(storyboard, space="    ")
    storyboard.write(replacement, encoding="utf-8", xml_declaration=True)
    pbx_path.write_text(pbx.replace(original.name, replacement.name))
    metadata["UILaunchStoryboardName"] = replacement.stem
    metadata_path.write_bytes(plistlib.dumps(metadata, sort_keys=False))
    original.unlink()
    shutil.rmtree(app / "Images.xcassets" / "SplashImage.imageset")


if __name__ == "__main__":
    configure(Path(sys.argv[1]))
