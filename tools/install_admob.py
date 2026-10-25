#!/usr/bin/env python3
"""Install pinned, owned-unit AdMob native wrappers; mediation providers stay excluded."""
import argparse,hashlib,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
HASHES={'android':'f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee','ios':'6e7f1c807761f9c0ad45d335ac4c74acd4bba7a31f9e1c7cd16a5220010cce71'}
def install(platform):
    name=f'{platform}-template-v4.7.2.zip';archive=ROOT/'build/native-downloads'/name
    archive.parent.mkdir(parents=True,exist_ok=True)
    if not archive.exists():urllib.request.urlretrieve('https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/'+name,archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=HASHES[platform]:raise RuntimeError('AdMob native archive hash mismatch')
    target=ROOT/f'godot/addons/admob/{platform}/bin'
    with zipfile.ZipFile(archive) as z:
        for name in z.namelist():
            if name.endswith('/') or name!='package.gd' and not name.startswith(('ads/','consent/')):continue
            if '..' in Path(name).parts:raise RuntimeError('Unsafe AdMob native path')
            out=target/name;out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes(z.read(name))
    print('Pinned AdMob '+platform+' native wrappers installed')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('platform',choices=HASHES);install(p.parse_args().platform)
