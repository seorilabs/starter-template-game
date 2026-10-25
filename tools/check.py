#!/usr/bin/env python3
"""복제한 저장소의 실제 Godot 여정을 실행한다. 추적 소스와 프로필을 고치지 않는다."""
import argparse
import copy
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import uuid
from pathlib import Path
import bundle
import check_architecture
import validate_outgame as gate


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def snapshot(root):
    names = subprocess.check_output(['git', '-C', str(root), 'ls-files', '-z']).decode().split('\0')
    return {name: digest(root / name) if (root / name).is_file() else None for name in names if name}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    p.add_argument('--project', default='godot')
    p.add_argument('--out', type=Path)
    p.add_argument('--capture', action='store_true')
    p.add_argument('--size', default='390x844')
    a = p.parse_args()
    root = a.root.resolve(); project = (root / a.project).resolve()
    if not project.is_relative_to(root): p.error('project must be inside repository')
    output = a.out or Path('build/e2e') / uuid.uuid4().hex
    out = output.resolve() if output.is_absolute() else (root / output).resolve()
    if not out.is_relative_to(root / 'build'): p.error('output must be under repository build/')
    if out.exists() and any(out.iterdir()): p.error('output must be new or empty')
    out.mkdir(parents=True, exist_ok=True)
    before = snapshot(root)
    try:
        errors = check_architecture.check(root, a.project)
        if errors: raise ValueError('\n'.join(errors))
        bundle.verify(root, json.loads((root / 'common-bundle.lock.json').read_text()))
        profile = json.loads((project / 'data/outgame/outgame-profile.json').read_text())
        kind = 'reference' if (project / 'reference').is_dir() else 'game'
        script = f'res://tests/{kind}/outgame_journey.gd'
        godot = os.environ.get('GODOT', 'godot')
        commands = [[godot, '--headless', '--path', str(project), '--import', '--quit-after', '2'],
                    [godot, '--headless', '--path', str(project), '--script', 'res://tests/common/outgame_contract_probe.gd'],
                    [godot, '--headless', '--path', str(project), '--script', 'res://tests/common/ui_standard_contract_probe.gd', '--', '--out', str(out / 'ui-contract.json')],
                    [godot, *(['--audio-driver', 'Dummy'] if a.capture else ['--headless']), '--path', str(project), '--script', script, '--', '--out', str(out), '--size', a.size, *(['--capture'] if a.capture else [])]]
        if (project / 'tests/game/core_probe.gd').is_file():
            commands.append([godot, '--headless', '--path', str(project), '--script', 'res://tests/game/core_probe.gd'])
        if (project / 'tests/game/native_market_probe.gd').is_file():
            commands.append([godot, '--headless', '--path', str(project), '--script', 'res://tests/game/native_market_probe.gd'])
        if kind == 'reference':
            commands.append([godot, *(['--audio-driver', 'Dummy'] if a.capture else ['--headless']), '--path', str(project), '--script', 'res://tests/reference/ui_navigation_probe.gd', '--', '--out', str(out / 'navigation'), *(['--capture'] if a.capture else [])])
        head = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
        env = {**os.environ, 'GITHUB_SHA': head}
        for i, command in enumerate(commands):
            run = subprocess.run(command, capture_output=True, text=True, timeout=180, env=env)
            log = run.stdout + run.stderr
            (out / f'godot-{i}.log').write_text(log)
            if run.returncode or re.search(r'^(?:SCRIPT ERROR|ERROR:)', log, re.M):
                raise ValueError('Godot failed: ' + ' '.join(command) + '\n' + log[-4000:])
        journey = json.loads((out / 'journey.json').read_text())
        if not journey.get('scenarios') or any(s['status'] != 'passed' for s in journey['scenarios']):
            raise ValueError('journey incomplete or failed')
        covered = {f for s in journey['scenarios'] for f in s['featureIds']}
        missing = set(gate.REQUIRED + gate.UI_CHECKS) - covered
        if missing: raise ValueError('missing feature journeys: ' + str(missing))
        checks = {n: True for n in gate.REQUIRED + gate.UI_CHECKS}
        checks.update({'contract_probe': True, 'bundle_hashes': True, 'architecture': True})
        report = {'kind': 'automated', 'passed': True, 'sourceSha': head,
                  'recordedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  'implementationFingerprint': gate.fingerprint(root, profile), 'checks': checks,
                  'artifacts': [{'path': str((out / 'journey.json').relative_to(root)), 'sha256': digest(out / 'journey.json'), 'type': 'report'}]}
        report_path = out / 'automated.json'
        report_path.write_text(json.dumps(report, indent=2) + '\n')
        profile['evidence']['automated'] = {'status': 'passed', 'path': str(report_path.relative_to(root)),
            'sha256': digest(report_path), 'implementationFingerprint': report['implementationFingerprint']}
        errors = gate.validate(root, profile, require_ui_standard=True)
        if errors: raise ValueError(json.dumps(errors))
        # Required adoption and stale evidence must fail before this verification can pass.
        for label, mutate, category in [
            ('adoption-marker', lambda q: q.pop('uiStandard'), 'missing_ui_standard'),
            ('support-entry', lambda q: q['uiStandard']['support'].update(entrypoint='missing'), 'missing_ui_standard'),
            ('stale-source', lambda q: q['tutorial'].update(version=q['tutorial']['version'] + 1), 'stale_evidence')]:
            candidate = copy.deepcopy(profile); mutate(candidate)
            if not any(e['category'] == category for e in gate.validate(root, candidate, require_ui_standard=True)):
                raise ValueError('mutation was not rejected: ' + label)
        (out / 'effective-profile.json').write_text(json.dumps(profile, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps({'ok': True, 'sourceSha': head, 'scenarios': len(journey['scenarios']), 'output': str(out)}))
    finally:
        if before != snapshot(root):
            active = sys.exception()
            if active is not None: active.add_note('verification changed tracked source files')
            else: raise ValueError('verification changed tracked source files')

if __name__ == '__main__':
    try: main()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        sys.exit('\n'.join([str(error), *getattr(error, '__notes__', [])]))
