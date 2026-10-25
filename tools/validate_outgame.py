#!/usr/bin/env python3
"""Validate runnable bindings and revision-bound evidence, not prose checkboxes."""
import argparse
import datetime
import hashlib
import json
import subprocess
import re
import struct
import sys
from pathlib import Path

REQUIRED = ('startup', 'tutorial', 'account_save', 'settings_support', 'inbox', 'commerce', 'observability', 'operations')
OPTIONAL = ('attendance', 'missions', 'achievements', 'events', 'shop', 'pass', 'ranking', 'friends', 'guild', 'push', 'review')
SERVICES = ('auth', 'payments', 'ads', 'analytics', 'remote_config', 'mailbox')
UI_CHECKS = ('ui_support_entry', 'ui_analytics_opt_out', 'ui_locale_offline', 'ui_navigation', 'ui_leaderboard')
REPORT_CHECKS = {
    'render': ('startup', 'tutorial', 'reward', 'home', 'settings', 'inbox', 'empty', 'error', 'small_screen', 'large_text', 'touch_drag'),
    'device': ('startup', 'tutorial', 'resume', 'save', 'settings', 'inbox', 'touch'),
    'product_art': ('selected_direction', 'runtime_comparison', 'title_identity', 'title_loading', 'title_ready', 'real_progress'),
    'market_sdk': ('adopted_markets', 'service_states'),
}


def meaningful(value):
    return isinstance(value, str) and len(value.strip()) >= 3 and not any(term in value.lower() for term in ('not tested', 'not approved', 'todo', 'placeholder', 'unverified', '미검증', '확정 필요'))


def png_dimensions(path):
    raw = path.read_bytes()
    if len(raw) < 33 or raw[:8] != b'\x89PNG\r\n\x1a\n' or raw[12:16] != b'IHDR' or b'IEND' not in raw[-16:]:
        return None
    width, height = struct.unpack('>II', raw[16:24])
    return (width, height) if width >= 240 and height >= 240 else None


def video_container(path):
    with path.open('rb') as stream:
        header = stream.read(32)
    return len(header) >= 12 and (header[4:8] == b'ftyp' or header[:4] == b'\x1a\x45\xdf\xa3')


def safe_file(root, value):
    if not isinstance(value, str) or not value or Path(value).is_absolute():
        return None
    path = (root / value).resolve()
    return path if path.is_relative_to(root.resolve()) and path.is_file() else None


def fingerprint(root, profile):
    digest = hashlib.sha256()
    paths = sorted({p for f in profile.get('features', {}).values() if isinstance(f, dict) for p in f.get('bindings', []) if isinstance(p, str)} | {s['binding'] for s in profile.get('services', {}).values() if isinstance(s, dict) and isinstance(s.get('binding'), str) and s['binding']} | {profile.get('verification', {}).get('runner', '')})
    standard = profile.get('uiStandard', {})
    if isinstance(standard, dict):
        resources = standard.get('resources', [])
        paths = sorted(set(paths) | {p for p in resources if isinstance(p, str)} if isinstance(resources, list) else set(paths))
        paths = sorted(set(paths) |
                       {v['binding'] for v in standard.values() if isinstance(v, dict) and isinstance(v.get('binding'), str)})
        lock = safe_file(root, standard.get('bundleLock'))
        if lock:
            paths.append(standard['bundleLock'])
            try:
                files = json.loads(lock.read_text()).get('files', {})
                if isinstance(files, dict):
                    paths = sorted(set(paths) | set(files))
            except (ValueError, OSError, AttributeError):
                pass
    # Runtime, product adapters and verification tools all invalidate prior evidence.
    for folder in ('godot', 'tools'):
        for path in (root / folder).rglob('*'):
            if path.is_file() and path.suffix in ('.gd', '.tscn', '.tres', '.json', '.svg', '.png', '.ttf', '.py', '.cfg', '.godot') and not any(part in ('.godot', 'build', '__pycache__') for part in path.relative_to(root).parts):
                # The profile is hashed without its evidence below.
                if path.name != 'outgame-profile.json':
                    paths.append(path.relative_to(root).as_posix())
    for value in sorted(set(paths)):
        path = safe_file(root, value)
        if path:
            digest.update(value.encode() + b'\0' + path.read_bytes() + b'\0')
    digest.update(json.dumps({k:v for k,v in profile.items() if k != 'evidence'}, sort_keys=True).encode())
    return digest.hexdigest()


def headless_e2e_inventory(root):
    """중앙 기능 목록이 v2이면 headless E2E 틀이 있는 게임이다(seorilabs/.github 개발 워크플로우)."""
    path = Path(root) / 'docs' / 'qa' / 'feature-inventory.json'
    try:
        return json.loads(path.read_text()).get('schemaVersion') == 2
    except (OSError, ValueError, AttributeError):
        return False


def validate(root, profile, stage='implementation', require_ui_standard=False):
    errors = []
    def fail(kind, detail): errors.append({'category': kind, 'detail': detail})
    standard = profile.get('uiStandard')
    if require_ui_standard and not isinstance(standard, dict):
        fail('missing_ui_standard', 'uiStandard adoption marker')
    if standard is not None:
        if not isinstance(standard, dict):
            fail('missing_ui_standard', 'uiStandard object')
        else:
            if standard.get('version') != '1.0.0' or standard.get('homeProfile') not in ('hero', 'map', 'world') or standard.get('skin') != 'soft-adventure':
                fail('missing_ui_standard', 'version/homeProfile/skin')
            if not isinstance(standard.get('locales'), list) or not standard['locales'] or any(v not in ('en', 'ko') for v in standard['locales']):
                fail('missing_ui_standard', 'bundled locales')
            resources = standard.get('resources')
            if not isinstance(resources, list) or not resources or any(safe_file(root, p) is None for p in resources):
                fail('missing_ui_standard', 'skin and font resources')
            lock = safe_file(root, standard.get('bundleLock'))
            if lock is None:
                fail('missing_ui_standard', 'bundle lock')
            else:
                try:
                    locked = json.loads(lock.read_text())
                    files = locked.get('files', {})
                    if locked.get('version') != standard.get('version') or not isinstance(files, dict) or not files:
                        fail('missing_ui_standard', 'bundle lock version/files')
                    elif any(safe_file(root, p) is None or hashlib.sha256(safe_file(root, p).read_bytes()).hexdigest() != sha for p, sha in files.items()):
                        fail('stale_ui_bundle', 'shared bundle modified')
                except (ValueError, OSError, AttributeError):
                    fail('missing_ui_standard', 'bundle lock invalid')
            for name in ('support', 'analytics', 'leaderboard'):
                entry = standard.get(name, {})
                if not isinstance(entry, dict) or safe_file(root, entry.get('binding')) is None:
                    fail('missing_ui_standard', name + ' binding')
            if not isinstance(standard.get('support'), dict) or standard['support'].get('entrypoint') != 'settings.support':
                fail('missing_ui_standard', 'support entrypoint')
    if safe_file(root, profile.get('verification', {}).get('runner')) is None:
        fail('unconnected', 'verification runner')
    if profile.get('schemaVersion') != 1 or profile.get('mode') not in ('local', 'server'):
        fail('invalid_profile', 'schemaVersion/mode')
    for name in REQUIRED:
        feature = profile.get('features', {}).get(name, {})
        if not isinstance(feature, dict) or feature.get('implemented') is not True:
            fail('missing_required', name)
            continue
        bindings = feature.get('bindings')
        if not isinstance(bindings, list) or not bindings:
            fail('unconnected', name)
        else:
            for binding in bindings:
                if safe_file(root, binding) is None:
                    fail('unconnected', f'{name}: {binding}')
    for name in OPTIONAL:
        entry = profile.get('optional', {}).get(name, {})
        if not isinstance(entry.get('enabled'), bool) or not isinstance(entry.get('reason'), str) or not entry['reason'].strip():
            fail('missing_decision', name)
    for name in SERVICES:
        service = profile.get('services', {}).get(name, {})
        state = service.get('status')
        if state not in ('local', 'wired', 'unsupported') or not isinstance(service.get('exposed'), bool):
            fail('unconnected', name)
        elif state == 'unsupported' and service['exposed']:
            fail('unsupported_exposed', name)
        elif state in ('wired', 'local') and safe_file(root, service.get('binding')) is None:
            fail('unconnected', name)
        if profile.get('mode') == 'server' and name in ('auth', 'mailbox', 'remote_config') and state != 'wired':
            fail('unconnected', f'server: {name}')
    if any(profile.get('services', {}).get(n, {}).get('exposed') for n in ('payments','ads')) and safe_file(root, profile.get('bmProfile')) is None:
        fail('unconnected', 'bm-profile.json')
    tutorial = profile.get('tutorial', {})
    if not isinstance(tutorial.get('version'), int) or tutorial['version'] < 1 or not tutorial.get('actions') or not tutorial.get('rewardKey'):
        fail('unconnected', 'tutorial actions/version/rewardKey')
    # 기능 목록 v2(headless E2E 틀이 있는 Godot 게임)는 출시 단계의 일반 흐름을 headless E2E(automated)와 렌더링 캡처(render)로
    # 검증하고, 일반 흐름의 실기기 보고서(device)는 선택이다(제출하면 그대로 검사). 결제·로그인·광고의 market_sdk는 계속 필수다.
    # 그 밖의 게임은 device 보고서가 필수다.
    kinds = ('automated',) if stage == 'implementation' else ('automated', 'render', 'product_art', 'market_sdk')
    if stage != 'implementation' and (not headless_e2e_inventory(root) or 'device' in profile.get('evidence', {})):
        kinds += ('device',)
    if stage == 'release':
        markets = profile.get('adoptedMarkets', [])
        if not isinstance(markets, list) or not markets or len(set(markets)) != len(markets) or any(m not in ('google_play', 'app_store', 'apps_in_toss') for m in markets):
            fail('missing_decision', 'adoptedMarkets')
    expected = fingerprint(root, profile)
    used_paths = set()
    for kind in kinds:
        evidence = profile.get('evidence', {}).get(kind, {})
        path = safe_file(root, evidence.get('path'))
        if evidence.get('status') != 'passed' or path is None:
            fail('unverified', kind)
            continue
        if path in used_paths:
            fail('unverified', kind + ': reused report')
            continue
        used_paths.add(path)
        if evidence.get('sha256') != hashlib.sha256(path.read_bytes()).hexdigest() or evidence.get('implementationFingerprint') != expected:
            fail('stale_evidence', kind)
            continue
        try:
            report = json.loads(path.read_text())
            recorded = datetime.datetime.fromisoformat(report.get('recordedAt', '').replace('Z', '+00:00'))
            age = (datetime.datetime.now(datetime.timezone.utc) - recorded).total_seconds()
            if age < -60 or age > 168 * 3600:
                fail('stale_evidence', kind + ': age')
            head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
            if report.get('sourceSha') != head:
                fail('stale_evidence', kind + ': source SHA')
            if report.get('kind') != kind or report.get('passed') is not True or report.get('implementationFingerprint') != expected:
                fail('unverified', kind + ': report type/revision')
                continue
            checks = report.get('checks')
            if not isinstance(checks, dict) or not checks or any(v is not True for v in checks.values()):
                fail('unverified', kind + ': failed checks')
            required_checks = REQUIRED + (UI_CHECKS if isinstance(standard, dict) else ()) if kind == 'automated' else REPORT_CHECKS[kind]
            if not isinstance(checks, dict) or any(checks.get(feature) is not True for feature in required_checks):
                fail('unverified', kind + ': mandatory behavior checks')
            artifacts = report.get('artifacts', [])
            if not isinstance(artifacts, list) or not artifacts:
                fail('unverified', kind + ': raw artifacts')
            images = set()
            valid_artifacts = {}
            for artifact in artifacts:
                if not isinstance(artifact, dict):
                    fail('unverified', kind + ': invalid artifact'); continue
                raw = safe_file(root, artifact.get('path'))
                if raw is None or artifact.get('sha256') != hashlib.sha256(raw.read_bytes()).hexdigest():
                    fail('unverified', kind + ': raw artifact hash')
                else:
                    artifact_type = artifact.get('type')
                    if artifact_type == 'video' and not video_container(raw):
                        fail('unverified', kind + ': MP4/WebM capture required')
                    else:
                        valid_artifacts[artifact['path']] = artifact_type
                    if artifact.get('type') == 'image' and png_dimensions(raw):
                        images.add(raw)
            if kind in ('render', 'device', 'product_art') and not images:
                fail('unverified', kind + ': PNG capture required')
            if kind == 'render':
                if not meaningful(report.get('renderer')) or not meaningful(report.get('inspectionNotes')):
                    fail('unverified', 'render: renderer and visual inspection required')
                sizes = {png_dimensions(p) for p in images}
                if len(sizes) < 2 or not any(min(size) <= 360 for size in sizes):
                    fail('unverified', 'render: small and second viewport captures required')
            if kind == 'product_art':
                approval = report.get('userApproval', {})
                if not isinstance(approval, dict) or approval.get('decision') != 'approved' or not meaningful(approval.get('reference')) or len(images) < 2:
                    fail('unverified', 'product_art: user approval and target/runtime images required')
                title = report.get('titleReview', {})
                if not isinstance(title, dict):
                    fail('unverified', 'product_art: title comparison required')
                else:
                    captures = [safe_file(root, title.get(role)) for role in ('target', 'loading', 'ready')]
                    if any(p not in images for p in captures) or len(set(captures)) != 3:
                        fail('unverified', 'product_art: distinct title target/loading/ready PNGs required')
                    if not meaningful(title.get('inspectionNotes')) or valid_artifacts.get(title.get('progressEvidence')) not in ('log', 'report'):
                        fail('unverified', 'product_art: title inspection and actual progress evidence required')
                    motion = title.get('motion', {})
                    if not isinstance(motion, dict) or motion.get('mode') not in ('static', 'animated') or not meaningful(motion.get('reason')):
                        fail('unverified', 'product_art: title motion decision required')
                    elif motion['mode'] == 'animated':
                        motion_checks = motion.get('checks', {})
                        if valid_artifacts.get(motion.get('artifact')) != 'video' or not isinstance(motion_checks, dict) or any(motion_checks.get(c) is not True for c in ('reduced_motion', 'background_pause', 'frame_time')):
                            fail('unverified', 'product_art: title motion video and behavior checks required')
            if kind == 'device':
                device = report.get('device', {})
                if not isinstance(device, dict) or device.get('platform') not in ('android', 'ios') or not meaningful(device.get('model')) or not meaningful(device.get('osVersion')) or not re.fullmatch('[a-f0-9]{64}', str(device.get('hardwareIdHash', ''))) or device.get('captureSource') not in ('adb', 'xcode-device'):
                    fail('unverified', 'device: physical device and capture source required')
            if kind == 'market_sdk':
                markets = report.get('markets', [])
                if not isinstance(markets, list) or not markets:
                    fail('unverified', 'market_sdk: adopted market results required')
                else:
                    if {m.get('market') for m in markets if isinstance(m, dict)} != set(profile.get('adoptedMarkets', [])):
                        fail('unverified', 'market_sdk: all adopted markets required')
                    for market in markets:
                        if not isinstance(market, dict) or market.get('market') not in ('google_play', 'app_store', 'apps_in_toss') or market.get('passed') is not True or not meaningful(market.get('sdkVersion')) or not isinstance(market.get('services'), dict):
                            fail('unverified', 'market_sdk: invalid market result'); continue
                        for service in ('auth', 'payments', 'ads'):
                            adopted = profile.get('services', {}).get(service, {}).get('exposed')
                            result = market['services'].get(service, {})
                            if not adopted:
                                if result != {'status': 'not_adopted'}:
                                    fail('unverified', 'market_sdk: ' + service + ' decision')
                            else:
                                scenarios = ('cancelled', 'pending', 'failed', 'restore') if service == 'payments' else ('success', 'cancelled', 'failed')
                                if not isinstance(result, dict) or result.get('status') != 'passed' or any(result.get('checks', {}).get(scenario) is not True for scenario in scenarios):
                                    fail('unverified', 'market_sdk: ' + service + ' scenarios')
        except (ValueError, OSError, TypeError, AttributeError, subprocess.SubprocessError):
            fail('unverified', kind + ': invalid report')
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path('.'))
    parser.add_argument('--project', default='godot')
    parser.add_argument('--profile')
    parser.add_argument('--stage', choices=('implementation', 'release'), default='implementation')
    parser.add_argument('--require-ui-standard', action='store_true', help='New standard adoption path; legacy profiles remain unchanged.')
    args = parser.parse_args()
    try:
        profile_path = args.profile or args.project + '/data/outgame/outgame-profile.json'
        profile = json.loads((args.root / profile_path).read_text())
        errors = validate(args.root, profile, args.stage, args.require_ui_standard)
    except (OSError, ValueError, TypeError, AttributeError, subprocess.TimeoutExpired) as error:
        errors = [{'category':'invalid_profile', 'detail':str(error)}]
    print(json.dumps({'ok':not errors, 'stage':args.stage, 'errors':errors}, ensure_ascii=False, indent=2))
    return int(bool(errors))

if __name__ == '__main__':
    raise SystemExit(main())
