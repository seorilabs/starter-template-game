#!/usr/bin/env python3
"""Install only native libraries from the pinned official Billing release."""
from pathlib import Path
import hashlib,urllib.request,zipfile
ROOT=Path(__file__).resolve().parents[1]
ARCHIVE=ROOT/'build/native-downloads/godot-google-play-billing-3.3.0.zip'
SHA='20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568'
def main():
    ARCHIVE.parent.mkdir(parents=True,exist_ok=True)
    if not ARCHIVE.exists():urllib.request.urlretrieve('https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/3.3.0/godot-google-play-billing.zip',ARCHIVE)
    if hashlib.sha256(ARCHIVE.read_bytes()).hexdigest()!=SHA:raise RuntimeError('Google Play Billing archive hash mismatch')
    with zipfile.ZipFile(ARCHIVE) as archive:
        for kind in ['debug','release']:
            name=f'GodotGooglePlayBilling/bin/{kind}/GodotGooglePlayBilling-{kind}.aar'
            target=ROOT/'godot/addons'/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.read(name))
    print('Pinned Google Play Billing native libraries installed')
if __name__=='__main__':main()
