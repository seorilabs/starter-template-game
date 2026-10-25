#!/usr/bin/env python3
import re
import json
from pathlib import Path


def check(root, project='godot'):
    godot = root / project
    errors = []
    # Central inventory v2 optional paths must be omitted or contain nonempty globs.
    # seorilabs/.github/scripts/release/test-plan.mjs, validFeature/validVersionFields.
    inventory_path = root / 'docs/qa/feature-inventory.json'
    try:
        inventory = json.loads(inventory_path.read_text())
        entries = [('inventory', inventory), *[(str(f.get('id', 'feature')), f) for f in inventory['features']]]
        for label, entry in entries:
            for field in ('paths', 'platformPaths', 'regressionPaths'):
                if field not in entry:
                    continue
                value = entry[field]
                if not isinstance(value, list) or not value or any(not isinstance(p, str) or not p.strip() for p in value):
                    errors.append(label + ': ' + field + ' must be omitted or contain nonempty paths')
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        errors.append('feature inventory invalid: ' + str(error))
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
