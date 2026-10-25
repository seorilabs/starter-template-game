#!/usr/bin/env python3
"""Build the pinned StoreKit fork, preserving account-token and explicit-finish contracts."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/native-ios-storekit'
SOURCE=ROOT/'native/ios/godot-storekit2'
def run(command):
    r=subprocess.run([str(x) for x in command],cwd=WORK,capture_output=True,text=True)
    with (WORK/'build.log').open('a') as f:f.write(r.stdout+r.stderr)
    if r.returncode:raise RuntimeError('StoreKit source build failed: '+(r.stdout+r.stderr)[-4000:])
def main():
    if sys.platform!='darwin':raise RuntimeError('macOS and Xcode required')
    headers=ROOT/'build/native-ios-identity/godot'
    if not (headers/'core/extension/gdextension_interface.gen.h').exists():raise RuntimeError('Run tools/build_ios_identity.py first')
    WORK.mkdir(parents=True,exist_ok=True)
    for path in SOURCE.iterdir():
        if path.name in ['godot','bin','.git']:continue
        target=WORK/path.name
        if target.exists():
            if target.is_dir():shutil.rmtree(target)
            else:target.unlink()
        if path.is_dir():shutil.copytree(path,target)
        else:shutil.copy2(path,target)
    if not (WORK/'godot').exists():(WORK/'godot').symlink_to(headers,target_is_directory=True)
    output=ROOT/'godot/ios/plugins/godot-storekit2';output.mkdir(parents=True,exist_ok=True)
    for config in ['Debug','Release']:
        archives=[]
        for sdk,destination in [('iphoneos','generic/platform=iOS'),('iphonesimulator','generic/platform=iOS Simulator')]:
            archive=WORK/f'{sdk}-{config}'
            run(['xcodebuild','archive','-project',WORK/'godot-storekit2.xcodeproj','-scheme','godot-storekit2','-sdk',sdk,'-destination',destination,'-configuration',config,'-archivePath',archive,'-derivedDataPath',WORK/f'derived-{sdk}-{config}','CODE_SIGNING_ALLOWED=NO','IPHONEOS_DEPLOYMENT_TARGET=16.0','SKIP_INSTALL=NO'])
            archives.append(archive.with_suffix('.xcarchive'))
        xc=output/f'godot-storekit2.{config.lower()}.xcframework'
        if xc.exists():shutil.rmtree(xc)
        run(['xcodebuild','-create-xcframework','-archive',archives[0],'-library','libgodot-storekit2.a','-archive',archives[1],'-library','libgodot-storekit2.a','-output',xc])
    for name in ['godot-storekit2.gdip','PrivacyInfo.xcprivacy']:shutil.copy2(SOURCE/'godot-storekit2'/name,output/name)
    shutil.copy2(SOURCE/'LICENSE',output/'LICENSE')
    files={str(p.relative_to(output)):hashlib.sha256(p.read_bytes()).hexdigest() for p in output.rglob('*') if p.is_file()}
    (WORK/'manifest.json').write_text(json.dumps({'minimumIOS':'16.0','files':files},indent=2)+'\n')
    print('StoreKit fork compiled. Manifest: build/native-ios-storekit/manifest.json')
if __name__=='__main__':main()
