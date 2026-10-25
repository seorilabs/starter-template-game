#!/usr/bin/env python3
import re
from pathlib import Path


def check(root, project='godot'):
    godot = root / project
    errors = []
    for p in (godot / 'addons/seorilabs_game').rglob('*.gd'):
        text = p.read_text()
        if re.search(r'res://(?:game|reference)/', text):
            errors.append(str(p) + ': common depends on product')
    product = 'reference' if (godot / 'reference').exists() else 'game'
    for p in (godot / product / 'core').rglob('*.gd'):
        text = p.read_text()
        if re.search(r'\b(?:Node|Control|SceneTree|JavaScriptBridge|HTTPRequest|FileAccess)\b|res://(?:addons|game/adapters|reference/adapters)', text):
            errors.append(str(p) + ': core depends on engine or adapters')
    return errors

if __name__ == '__main__':
    errors = check(Path(__file__).resolve().parents[1])
    print('\n'.join(errors) if errors else 'Architecture passed')
    raise SystemExit(bool(errors))
