#!/usr/bin/env python3
"""Validate export identity, signing boundaries and release resource exclusions."""
import configparser
import hashlib
import json
from pathlib import Path
import plistlib
import re
ROOT=Path(__file__).resolve().parents[1]
# Web is the playtest preset; every other preset is a release build that must drop test-only files.
PLAYTEST_PRESET='Web'
# Preset names equal their Godot platform names.
RELEASE_PRESETS=['Android','iOS','Windows Desktop','macOS','Linux']
DESKTOP_PRESETS=['Windows Desktop','macOS','Linux']
TEST_ROOM='addons/seorilabs_game/dev/**'
def load_presets(root):
    cfg=configparser.ConfigParser(interpolation=None,strict=True)
    cfg.optionxform=str
    cfg.read(root/'godot/export_presets.cfg')
    return cfg
def value(cfg,section,key):
    try:return json.loads(cfg.get(section,key))
    except (ValueError,configparser.Error):return None
def items(cfg,section,key):
    return {x.strip() for x in (value(cfg,section,key) or '').split(',') if x.strip()}
def validate(root):
    errors=[];cfg=load_presets(root)
    try:
        lock=json.loads((root/'native/dependencies.lock.json').read_text())
        if lock.get('schemaVersion')!=2:errors.append('Unsupported native dependency lock schema')
        for entry in lock['sources']['admob']['localPatches']:
            path=root/entry['file']
            if hashlib.sha256(path.read_bytes()).hexdigest()!=entry['sha256']:
                errors.append('Native source patch hash mismatch: '+entry['file'])
    except (OSError,ValueError,KeyError,TypeError) as error:
        errors.append('Invalid native dependency lock: '+type(error).__name__)
    project=configparser.ConfigParser(interpolation=None);project.optionxform=str;project.read_string('[general]\n'+(root/'godot/project.godot').read_text())
    if value(project,'rendering','textures/vram_compression/import_etc2_astc') is not True:errors.append('Mobile texture import must be enabled for native exports')
    if value(project,'rendering','textures/vram_compression/import_s3tc_bptc') is not True:errors.append('Desktop texture import must be enabled for desktop exports')
    try:
        product=json.loads((root/'godot/config/product.json').read_text())
        play=json.loads((root/'play-store/google-play.config.json').read_text())
        apple=json.loads((root/'app-store/app-store.config.json').read_text())
        export=plistlib.loads((root/'app-store/exportOptions.plist').read_bytes())
    except (OSError,ValueError,plistlib.InvalidFileException) as error:return [str(error)]
    identity=product['id']
    if not re.fullmatch(r'[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+',identity):errors.append('Native product ID must be a reverse-DNS identifier')
    presets={}
    for section in cfg.sections():
        if not section.endswith('.options'):presets.setdefault(value(cfg,section,'name'),[]).append(section)
    for name in [PLAYTEST_PRESET,*RELEASE_PRESETS]:
        if len(presets.get(name,[]))!=1:errors.append('Missing or duplicate export preset: '+name)
    for name,bases in presets.items():
        for base in bases:
            exclude=items(cfg,base,'exclude_filter');features=items(cfg,base,'custom_features')
            if name==PLAYTEST_PRESET:
                if 'playtest' not in features:errors.append('Web playtest preset must enable the playtest feature')
                if TEST_ROOM in exclude:errors.append('Web playtest preset must keep '+TEST_ROOM)
                continue
            label=str(name)
            if 'playtest' in features:errors.append(label+' must not enable the playtest feature')
            for pattern in ['tests/**','game/scenarios/**',TEST_ROOM]:
                if pattern not in exclude:errors.append(label+' must exclude '+pattern)
            include=items(cfg,base,'include_filter')
            for license in ['addons/seorilabs_game/fonts/*-OFL.txt','addons/seorilabs_platform/LICENSE']:
                if license not in include:errors.append(label+' must retain '+license)
    for platform in RELEASE_PRESETS:
        bases=presets.get(platform,[])
        if len(bases)!=1:continue
        base=bases[0];options=base+'.options'
        if value(cfg,base,'platform')!=platform:errors.append(platform+' preset platform mismatch')
        if platform in DESKTOP_PRESETS:
            if platform=='macOS' and value(cfg,options,'application/bundle_identifier')!=identity:errors.append('macOS bundle identity mismatch')
            continue
        if value(cfg,base,'runnable') is not False:errors.append('Native automatic device discovery must stay disabled')
        if platform=='Android':
            if value(cfg,options,'package/unique_name')!=identity or play.get('packageName')!=identity:errors.append('Android package identity mismatch')
            if value(cfg,options,'package/name')!=product['name']:errors.append('Android display name mismatch')
            if value(cfg,options,'gradle_build/export_format')!=1 or value(cfg,options,'gradle_build/use_gradle_build') is not True:errors.append('Android must export a Gradle AAB')
            if int(value(cfg,options,'gradle_build/target_sdk') or 0)<36:errors.append('Android target SDK must be at least 36')
            if value(cfg,options,'package/signed') is not True:errors.append('Android release signing must be enabled')
            for key in ['keystore/release','keystore/release_user','keystore/release_password']:
                if value(cfg,options,key):errors.append('Signing values must come from the environment: '+key)
        else:
            if value(cfg,options,'application/bundle_identifier')!=identity or apple.get('bundleId')!=identity:errors.append('iOS bundle identity mismatch')
            if value(cfg,options,'application/app_store_team_id')!=apple.get('teamId') or export.get('teamID')!=apple.get('teamId'):errors.append('Apple signing team mismatch')
            if value(cfg,options,'application/export_project_only') is not True:errors.append('iOS must export the Xcode project for the archive lane')
    if play.get('track')!='internal':errors.append('This template deploys only to the internal track')
    if export.get('testFlightInternalTestingOnly') is not True:errors.append('TestFlight export must be internal only')
    if export.get('manageAppVersionAndBuildNumber') is not False:errors.append('Apple must preserve the tag-derived build number')
    return errors
if __name__=='__main__':
    errors=validate(ROOT)
    print(json.dumps({'ok':not errors,'errors':errors},ensure_ascii=False))
    raise SystemExit(bool(errors))
