import shutil
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
class FreshStartTests(unittest.TestCase):
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
            if (project/'addons/admob/plugin.cfg').exists() and '[editor_plugins]' not in text:
                text += '\n[editor_plugins]\nenabled=PackedStringArray("res://addons/admob/plugin.cfg")\n'
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
                fake_curl = binaries/'curl'
                fake_curl.write_text('#!/bin/sh\nprintf attempted > "$FRESH_START_DOWNLOAD_MARKER"\nexit 1\n')
                fake_curl.chmod(0o700)
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
                for platform in ['android', 'ios']:
                    self.assertFalse((project/'addons/admob'/platform/'bin').exists(), 'Fresh desktop launch must not download native SDKs')
            finally:
                if data.exists(): shutil.rmtree(data)
if __name__ == '__main__': unittest.main()
