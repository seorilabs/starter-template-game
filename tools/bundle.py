#!/usr/bin/env python3
"""검수할 Git 커밋의 공통 파일을 묶고, 기존 고정 파일을 검증한 뒤 갱신한다."""
import argparse
import hashlib
import io
import json
import re
import subprocess
import tarfile
from pathlib import Path, PurePosixPath

ROOTS = ('godot/addons/seorilabs_game', 'godot/addons/seorilabs_platform', 'godot/tests/common')
REPOSITORY = 'https://github.com/seorilabs/game-foundation'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])

def permitted(name):
    p = PurePosixPath(name)
    return not p.is_absolute() and '..' not in p.parts and any(name.startswith(r + '/') for r in ROOTS)

def validate_manifest(lock):
    if lock.get('version') != '1.0.0' or lock.get('roots') != list(ROOTS):
        raise ValueError('invalid bundle contract')
    source = lock.get('source', {})
    if source.get('repository') != REPOSITORY or not re.fullmatch(r'[0-9a-f]{40}', source.get('commit', '')):
        raise ValueError('bundle source commit required')
    files = lock.get('files')
    if not isinstance(files, dict) or not files or not all(permitted(n) and re.fullmatch(r'[0-9a-f]{64}', h) for n, h in files.items()):
        raise ValueError('invalid bundle paths or hashes')
    if any(not any(n.startswith(r + '/') for n in files) for r in ROOTS):
        raise ValueError('bundle root omitted')

def verify(root, lock):
    validate_manifest(lock)
    files = lock['files']
    actual = set()
    for folder in ROOTS:
        if (root / folder).is_symlink():
            raise ValueError('symbolic link in common bundle root')
        for path in (root / folder).rglob('*'):
            if path.is_symlink():
                raise ValueError('symbolic link in common bundle: ' + str(path))
            if path.is_file() and path.suffix not in ('.uid', '.import'):
                actual.add(path.relative_to(root).as_posix())
    if actual != set(files):
        raise ValueError('common file inventory changed: ' + str(sorted(actual ^ set(files))))
    for name, expected in files.items():
        path = root / name
        if not path.is_file() or sha(path.read_bytes()) != expected:
            raise ValueError('common file modified: ' + name)

def pack(root, commit, out):
    commit = git(root, 'rev-parse', commit + '^{commit}').decode().strip()
    payload = {}
    records = git(root, 'ls-tree', '-r', commit, '--', *ROOTS).decode().splitlines()
    for record in records:
        metadata, name = record.split('\t', 1)
        mode, kind, oid = metadata.split()
        if mode != '100644' or kind != 'blob' or not permitted(name):
            raise ValueError('unsupported bundle entry: ' + name)
        if Path(name).suffix in ('.uid', '.import'):
            continue
        payload[name] = git(root, 'cat-file', 'blob', oid)
    lock = {'schemaVersion': 1, 'version': '1.0.0', 'roots': list(ROOTS),
            'source': {'repository': REPOSITORY, 'commit': commit},
            'sdk': {'version': '1.0.0', 'archiveSha256': '6a9be1f06fca92462e41fb82afb112672f83003887f15dc2fc239681285a2e13',
                    'source': 'https://github.com/seorilabs/platform/releases/tag/v1.0.0'},
            'files': {name: sha(data) for name, data in sorted(payload.items())}}
    validate_manifest(lock)
    # Exclusive creation avoids replacing a reviewed or user-owned bundle.
    with out.open('xb') as stream, tarfile.open(fileobj=stream, mode='w:gz') as archive:
        for name, data in {'common-bundle.lock.json': (json.dumps(lock, indent=2) + '\n').encode(), **payload}.items():
            info = tarfile.TarInfo(name)
            info.size = len(data)
            archive.addfile(info, io.BytesIO(data))
    return lock

def install(root, bundle):
    with tarfile.open(bundle) as archive:
        payload = {}
        for member in archive.getmembers():
            if not member.isfile() or (member.name != 'common-bundle.lock.json' and not permitted(member.name)) or member.name in payload:
                raise ValueError('unsafe bundle entry: ' + member.name)
            payload[member.name] = archive.extractfile(member).read()
    lock = json.loads(payload.pop('common-bundle.lock.json'))
    validate_manifest(lock)
    if set(payload) != set(lock['files']) or any(sha(data) != lock['files'][n] for n, data in payload.items()):
        raise ValueError('bundle bytes do not match manifest')
    old_path = root / 'common-bundle.lock.json'
    old = json.loads(old_path.read_text()) if old_path.exists() else None
    if old:
        verify(root, old)
    else:
        for folder in ROOTS:
            if (root / folder).exists() and any((root / folder).iterdir()):
                raise ValueError('unmanaged common directory: ' + folder)
    for folder in ROOTS:
        for part in [root, *list((root / folder).parents)[:-1], root / folder]:
            if part.is_symlink():
                raise ValueError('symbolic link in target path')
    for name in payload:
        path = root / name
        if path.is_symlink() or any(p.is_symlink() for p in path.parents):
            raise ValueError('symbolic link in target path')
        if path.exists() and (old is None or name not in old['files']):
            raise ValueError('unmanaged file would be overwritten: ' + name)
    # All validation completes before the first mutation. Only previously locked files may be removed.
    if old:
        for name in set(old['files']) - set(payload):
            (root / name).unlink()
    for name, data in payload.items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    old_path.write_text(json.dumps(lock, indent=2) + '\n')
    verify(root, lock)
    return lock

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    sub = p.add_subparsers(dest='command', required=True)
    packer = sub.add_parser('pack'); packer.add_argument('--commit', required=True); packer.add_argument('--out', type=Path, required=True)
    installer = sub.add_parser('install'); installer.add_argument('--bundle', type=Path, required=True)
    sub.add_parser('verify')
    a = p.parse_args()
    try:
        if a.command == 'pack': lock = pack(a.root.resolve(), a.commit, a.out)
        elif a.command == 'install': lock = install(a.root.resolve(), a.bundle)
        else:
            lock = json.loads((a.root / 'common-bundle.lock.json').read_text()); verify(a.root.resolve(), lock)
        print(json.dumps({'ok': True, 'version': lock['version'], 'source': lock['source'], 'files': len(lock['files'])}))
    except (OSError, ValueError, KeyError, tarfile.TarError, subprocess.SubprocessError) as error:
        p.exit(1, str(error) + '\n')

if __name__ == '__main__':
    main()
