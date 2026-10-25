#!/usr/bin/env python3
"""Export Android AAB or an iOS Xcode project using local Godot and signing settings."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import check_native
ROOT=Path(__file__).resolve().parents[1]
def run(command, timeout):
    result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=timeout)
    log=result.stdout+result.stderr
    visible=log
    for name,value in os.environ.items():
        if value and any(word in name.upper() for word in ['PASSWORD','TOKEN','PRIVATE_KEY']):visible=visible.replace(value,'[redacted]')
    print(visible,end='')
    log=re.sub(r'\x1b\[[0-9;]*m','',log)
    if result.returncode or re.search(r'^(?:SCRIPT ERROR|ERROR:)',log,re.M):
        raise RuntimeError('Godot export failed; inspect the preceding output')
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform',choices=['Android','iOS'])
    args=parser.parse_args()
    errors=check_native.validate(ROOT)
    if errors:raise ValueError('\n'.join(errors))
    if args.platform=='Android':
        for name in ['GODOT_ANDROID_KEYSTORE_RELEASE_PATH','GODOT_ANDROID_KEYSTORE_RELEASE_USER','GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD']:
            if not os.environ.get(name):raise ValueError('Missing signing environment variable: '+name)
        subprocess.run(['bash',str(ROOT/'tools/install_android_build_template.sh')],cwd=ROOT,check=True)
    godot=os.environ.get('GODOT','godot')
    run([godot,'--headless','--path',str(ROOT/'godot'),'--import'],180)
    output=ROOT/('build/android/starter-template-game.aab' if args.platform=='Android' else 'build/ios/startergame.xcodeproj')
    output.parent.mkdir(parents=True,exist_ok=True)
    run([godot,'--headless','--path',str(ROOT/'godot'),'--export-release',args.platform,str(output)],900)
    if not output.exists():raise RuntimeError('Godot did not create the expected output')
    if args.platform=='iOS':
        subprocess.run(['bash',str(ROOT/'tools/prepare_ios_project.sh')],cwd=ROOT,env={**os.environ,'XCODE_PROJECT':str(output)},check=True)
    print(output)
if __name__=='__main__':
    try:main()
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError) as error:raise SystemExit(str(error))
