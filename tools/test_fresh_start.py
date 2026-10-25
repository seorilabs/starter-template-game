import shutil
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def enable_admob_editor_plugin(text):
    plugin = '"res://addons/admob/plugin.cfg"'
    section = re.search(r'(?ms)^\[editor_plugins\]\s*\n(.*?)(?=^\[|\Z)', text)
    if section is None:
        return text + '\n[editor_plugins]\nenabled=PackedStringArray('+plugin+')\n'
    body = section.group(1)
    enabled = re.search(r'(?ms)^enabled=PackedStringArray\((.*?)\)\s*$', body)
    if enabled is None:
        if re.search(r'(?m)^enabled=', body):
            raise ValueError('Unsupported editor plugin setting')
        body += '\nenabled=PackedStringArray('+plugin+')\n'
    elif plugin not in enabled.group(1):
        entries = enabled.group(1).strip()
        body = body[:enabled.start(1)] + entries + (', ' if entries else '') + plugin + body[enabled.end(1):]
    return text[:section.start(1)] + body + text[section.end(1):]
class FreshStartTests(unittest.TestCase):
    def test_admob_is_enabled_alongside_existing_editor_plugins(self):
        original = '[editor_plugins]\nenabled=PackedStringArray("res://other/plugin.cfg")\n\n[rendering]\nmethod="gl_compatibility"\n'
        configured = enable_admob_editor_plugin(original)
        self.assertIn('"res://other/plugin.cfg", "res://addons/admob/plugin.cfg"', configured)
        self.assertTrue(configured.endswith('[rendering]\nmethod="gl_compatibility"\n'))
        self.assertEqual(configured, enable_admob_editor_plugin(configured))
    def test_admob_is_enabled_in_an_empty_existing_section(self):
        self.assertIn('enabled=PackedStringArray("res://addons/admob/plugin.cfg")', enable_admob_editor_plugin('[editor_plugins]\n'))
    def test_first_launch_prepares_missing_import_cache(self):
        with tempfile.TemporaryDirectory(prefix='fresh-game-start-') as folder:
            project = Path(folder)/'godot'
            tracked = subprocess.check_output(['git','ls-files','-z','godot'],cwd=ROOT).decode().split('\0')
            for name in filter(None,tracked):
                source=ROOT/name; target=Path(folder)/name
                if not source.is_file(): continue
                target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(source,target)
            self.assertFalse((project/'.godot').exists())
            qa_name='fresh-start-qa-'+Path(folder).name
            settings=project/'project.godot'
            text = settings.read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+qa_name+'"', 1)
            if (project/'addons/admob/plugin.cfg').exists():
                text = enable_admob_editor_plugin(text)
            settings.write_text(text)
            probe=Path(folder)/'boot.gd'
            probe.write_text('extends SceneTree\nfunc _initialize() -> void: call_deferred("run")\nfunc run() -> void:\n print("QA_USER_DIR="+OS.get_user_data_dir())\n print("QA_ARGS="+JSON.stringify(OS.get_cmdline_user_args()))\n var scene = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()\n root.add_child(scene)\n for i in 20: await process_frame\n quit()\n')
            command=['python3',str(ROOT/'tools/run.py'),'--project',str(project),'--headless','--script',str(probe),'--','--probe']
            if shutil.which('sandbox-exec'):
                command=['sandbox-exec','-p','(version 1) (allow default) (deny network*)',*command]
            environment = os.environ.copy()
            download_marker = Path(folder)/'unexpected-native-download'
            if os.name == 'posix':
                binaries = Path(folder)/'bin'; binaries.mkdir()
                for executable in ['curl', 'wget']:
                    fake_downloader = binaries/executable
                    fake_downloader.write_text('#!/bin/sh\nprintf attempted > "$FRESH_START_DOWNLOAD_MARKER"\nexit 1\n')
                    fake_downloader.chmod(0o700)
                environment['PATH'] = str(binaries) + os.pathsep + environment['PATH']
                environment['FRESH_START_DOWNLOAD_MARKER'] = str(download_marker)
            result=subprocess.run(command,cwd=ROOT,env=environment,capture_output=True,text=True,timeout=120)
            markers=[line.split('=',1)[1] for line in result.stdout.splitlines() if line.startswith('QA_USER_DIR=')]
            self.assertEqual(1,len(markers),f"launch exit={result.returncode}\n"+result.stdout+result.stderr)
            data=Path(markers[0]).resolve()
            self.assertEqual(qa_name,data.name)
            try:
                self.assertEqual(0,result.returncode,result.stdout+result.stderr)
                self.assertNotIn('No loader found',result.stdout+result.stderr)
                self.assertTrue((project/'.godot').is_dir())
                self.assertIn('QA_ARGS=["--probe"]',result.stdout)
                self.assertFalse(download_marker.exists(), 'Fresh import must not attempt native SDK downloads')
                self.assertNotIn('AdMob: Downloading synchronously', result.stdout+result.stderr)
                for platform in ['android', 'ios']:
                    self.assertFalse((project/'addons/admob'/platform/'bin').exists(), 'Fresh desktop launch must not download native SDKs')
            finally:
                if data.exists(): shutil.rmtree(data)
if __name__ == '__main__': unittest.main()
