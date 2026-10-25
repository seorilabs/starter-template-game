#!/usr/bin/env python3
"""제품 이름, 로컬 식별자와 홈 형식을 초기화한다. 마켓 설정과 공통 묶음은 유지한다."""
import argparse
import json
import re
from pathlib import Path
import bundle


def initialize(root, name, identity, home, dry_run=False):
    if not name.strip() or len(name) > 60 or any(ord(c) < 32 for c in name):
        raise ValueError('name must be 1-60 visible characters')
    if not re.fullmatch(r'[a-z][a-z0-9]*(?:[.-][a-z0-9]+)*', identity):
        raise ValueError('id must use lowercase letters, numbers, dots or hyphens')
    if home not in ('hero', 'map', 'world'):
        raise ValueError('unsupported home profile')
    bundle.verify(root, json.loads((root / 'common-bundle.lock.json').read_text()))
    config_path = root / 'godot/config/product.json'
    profile_path = root / 'godot/data/outgame/outgame-profile.json'
    project_path = root / 'godot/project.godot'
    product = json.loads(config_path.read_text())
    profile = json.loads(profile_path.read_text())
    product.update(name=name.strip(), id=identity, homeProfile=home)
    profile['gameId'] = identity; profile['uiStandard']['homeProfile'] = home
    profile['evidence'] = {}
    project, count = re.subn(r'^config/name=.*$', lambda _: 'config/name=' + json.dumps(name.strip(), ensure_ascii=False), project_path.read_text(), flags=re.M)
    if count != 1: raise ValueError('project application name missing or duplicated')
    is_new_product = product['id'] != 'com.seorilabs.startergame'
    if is_new_product:
        # Public test app identities belong to Starter, including its non-monetized ads.
        project = project.replace(', "res://addons/admob/plugin.cfg"', '')
        project = re.sub(r'^general/(?:android|ios)/app_id=.*\n?', '', project, flags=re.M)
    if not dry_run:
        config_path.write_text(json.dumps(product, ensure_ascii=False, indent=2) + '\n')
        profile_path.write_text(json.dumps(profile, ensure_ascii=False, indent=2) + '\n')
        project_path.write_text(project)
        if is_new_product:
            runtime_path = root / 'godot/config/runtime.json'
            runtime_path.write_text(json.dumps({'mode':'local','platformEnabled':False,'networkRequired':False}, indent=2)+'\n')
            binding = root / 'godot/config/platform.json'
            if binding.exists():
                binding.write_text(json.dumps({'firebase':{},'auth':{},'platform':{},'admob':{}}, indent=2)+'\n')
            firebase_binding = root / '.firebaserc'
            if firebase_binding.exists(): firebase_binding.write_text(json.dumps({'projects':{}}, indent=2)+'\n')
    return product


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    p.add_argument('--name', required=True); p.add_argument('--id', required=True)
    p.add_argument('--home', choices=('hero', 'map', 'world'), required=True)
    p.add_argument('--dry-run', action='store_true')
    a = p.parse_args()
    try: print(json.dumps(initialize(a.root.resolve(), a.name, a.id, a.home, a.dry_run), ensure_ascii=False))
    except (OSError, ValueError, KeyError) as e: p.exit(1, str(e) + '\n')

if __name__ == '__main__': main()
