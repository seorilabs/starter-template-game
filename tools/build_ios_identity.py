#!/usr/bin/env python3
"""Build the account/App Check bridge from repository source and pinned public SDKs."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/native-ios-identity'
GODOT_COMMIT = 'ed1daf0bf001b61586d9930840f2f1394092c079'
FIREBASE_VERSION = '12.16.0'
FIREBASE_HASH = 'f4c409ce42aa5c0506f12842bf524ce23ea1a2a6705bfdbc4b16e9e0845c13ba'
APP_CHECK = ['FirebaseAppCheck', 'AppCheckCore', 'FirebaseAppCheckInterop', 'RecaptchaInterop', 'Promises']
CORE = ['FirebaseCore', 'FirebaseCoreInternal', 'GoogleUtilities', 'FBLPromises', 'FirebaseInstallations']

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''): h.update(chunk)
    return h.hexdigest()

def run(args):
    result = subprocess.run([str(a) for a in args], cwd=ROOT, capture_output=True, text=True)
    with (WORK / 'build.log').open('a') as f: f.write(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError('Native identity build failed: ' + str(args[0]) + '\n' + (result.stdout + result.stderr)[-5000:])
    return result.stdout.strip()

def main():
    if sys.platform != 'darwin': raise RuntimeError('The iOS SDK build requires macOS and Xcode')
    WORK.mkdir(parents=True, exist_ok=True)
    (WORK / '.gdignore').touch()
    source = WORK / 'godot'
    if not source.exists():
        run(['git', 'clone', '--depth', '1', '--filter=blob:none', '--branch', '4.7.2-stable', 'https://github.com/godotengine/godot.git', source])
    if run(['git', '-C', source, 'rev-parse', 'HEAD']) != GODOT_COMMIT: raise RuntimeError('Godot header commit mismatch')
    # Generate headers directly. Starting a full engine build or killing another build is unnecessary.
    sys.path[:0] = [str(source), str(source / 'core/extension')]
    import make_interface_header
    from core import core_builders
    make_interface_header.run([str(source / 'core/extension/gdextension_interface.gen.h')], [str(source / 'core/extension/gdextension_interface.json')], None)
    class EmptyDisabled:
        def read(self): return []
    core_builders.disabled_class_builder([str(source / 'core/disabled_classes.gen.h')], [EmptyDisabled()], None)
    archive = ROOT / f'build/native-downloads/Firebase-{FIREBASE_VERSION}.zip'
    archive.parent.mkdir(parents=True, exist_ok=True)
    if not archive.exists():
        with urllib.request.urlopen(f'https://github.com/firebase/firebase-ios-sdk/releases/download/{FIREBASE_VERSION}/Firebase.zip', timeout=120) as src, archive.open('xb') as dest:
            shutil.copyfileobj(src, dest, 1024 * 1024)
    if sha(archive) != FIREBASE_HASH: raise RuntimeError('Firebase SDK checksum mismatch')
    extracted = WORK / 'firebase'
    slices = ['ios-arm64', 'ios-arm64_x86_64-simulator']
    with zipfile.ZipFile(archive) as z:
        prefixes = [f'Firebase/{section}/{name}.xcframework/{part}/' for section, names in [('FirebaseAppCheck', APP_CHECK), ('FirebaseAnalytics', CORE)] for name in names for part in slices]
        for member in z.infolist():
            if not member.is_dir() and any(member.filename.startswith(p) for p in prefixes):
                target = extracted / member.filename
                if '..' in Path(member.filename).parts: raise RuntimeError('Unsafe SDK archive entry')
                target.parent.mkdir(parents=True, exist_ok=True)
                with z.open(member) as src, target.open('wb') as dest: shutil.copyfileobj(src, dest)
        notices = z.read('Firebase/NOTICES')
    framework_dirs = {name: extracted / 'Firebase' / ('FirebaseAppCheck' if name in APP_CHECK else 'FirebaseAnalytics') / f'{name}.xcframework' for name in APP_CHECK + CORE}
    output = ROOT / 'godot/ios/plugins/SeoriAccountLink'
    output.mkdir(parents=True, exist_ok=True)
    native_source = ROOT / 'native/ios/seori_account_link/src'
    for config in ['debug', 'release']:
        libs = []
        for sdk, arch, part in [('iphoneos', 'arm64', slices[0]), ('iphonesimulator', 'arm64', slices[1]), ('iphonesimulator', 'x86_64', slices[1])]:
            folder = WORK / f'{config}-{sdk}-{arch}'; folder.mkdir(exist_ok=True)
            sdk_path = run(['xcrun', '--sdk', sdk, '--show-sdk-path'])
            target = f'{arch}-apple-ios16.0' + ('-simulator' if sdk == 'iphonesimulator' else '')
            objects = []
            for file in sorted(native_source.glob('*.mm')):
                obj = folder / (file.stem + '.o')
                defines = ['-DDEBUG_ENABLED', '-DDEBUG=1', '-D_DEBUG'] if config == 'debug' else ['-DNDEBUG', '-DNS_BLOCK_ASSERTIONS=1']
                flags = ['-std=gnu++17', '-O2', '-fobjc-arc', '-fobjc-exceptions', '-fmodules', '-fcxx-modules', '-fblocks', '-fvisibility=hidden', '-DPTRCALL_ENABLED', '-DNEED_LONG_INT', '-DLIBYUV_DISABLE_NEON', '-DIOS_ENABLED', '-DAPPLE_EMBEDDED_ENABLED', '-DUNIX_ENABLED', *defines]
                includes = [f'-I{p}' for p in [source, source / 'platform/ios', source / 'platform/apple_embedded', native_source]]
                frameworks = [f'-F{path / part}' for path in framework_dirs.values()]
                run(['xcrun', '--sdk', sdk, 'clang++', '-c', '-target', target, '-isysroot', sdk_path, *flags, *includes, *frameworks, file, '-o', obj])
                objects.append(obj)
            library = folder / 'libSeoriAccountLink.a'
            if library.exists(): library.unlink()
            run(['xcrun', '--sdk', sdk, 'libtool', '-static', '-o', library, *objects])
            libs.append(library)
        combined = WORK / f'libSeoriAccountLink-{config}-simulator.a'
        run(['lipo', '-create', libs[1], libs[2], '-output', combined])
        xc = output / f'SeoriAccountLink.{config}.xcframework'
        if xc.exists(): shutil.rmtree(xc)
        run(['xcodebuild', '-create-xcframework', '-library', libs[0], '-library', combined, '-output', xc])
    bundles = set()
    for name, path in framework_dirs.items():
        xc = output / f'{name}.xcframework'
        if xc.exists(): shutil.rmtree(xc)
        run(['xcodebuild', '-create-xcframework', '-framework', path / slices[0] / f'{name}.framework', '-framework', path / slices[1] / f'{name}.framework', '-output', xc])
        for bundle in (path / slices[0]).rglob('*.bundle'):
            dest = output / bundle.name
            if dest.exists(): shutil.rmtree(dest)
            shutil.copytree(bundle, dest)
            bundles.add(bundle.name)
    (output / 'Firebase-NOTICES.txt').write_bytes(notices)
    gdip = (ROOT / 'native/ios/seori_account_link/SeoriAccountLink.gdip').read_text()
    gdip = gdip.replace('binary="SeoriAccountLink.xcframework"', 'binary="SeoriAccountLink.xcframework"\nuse_swift_runtime=true')
    gdip = gdip.replace('linked=[', 'linked=[' + ', '.join(json.dumps(n + '.xcframework') for n in CORE) + ', ')
    gdip = gdip.replace('files=[]', 'files=' + json.dumps(sorted(bundles) + ['Firebase-NOTICES.txt']))
    (output / 'SeoriAccountLink.gdip').write_text(gdip)
    manifest = {'godotCommit': GODOT_COMMIT, 'firebaseVersion': FIREBASE_VERSION, 'firebaseArchiveSha256': FIREBASE_HASH, 'minimumIOS': '16.0', 'files': {str(p.relative_to(output)): sha(p) for p in sorted(output.rglob('*')) if p.is_file()}}
    (WORK / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('iOS identity and App Check SDKs built; source and dependency hashes recorded in build/native-ios-identity/manifest.json')

if __name__ == '__main__':
    try: main()
    except Exception as error: raise SystemExit(str(error))
