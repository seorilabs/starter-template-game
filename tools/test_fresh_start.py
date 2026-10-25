import shutil
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
            settings.write_text(settings.read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+qa_name+'"', 1))
            probe=Path(folder)/'boot.gd'
            probe.write_text('extends SceneTree\nfunc _initialize() -> void: call_deferred("run")\nfunc run() -> void:\n print("QA_USER_DIR="+OS.get_user_data_dir())\n print("QA_ARGS="+JSON.stringify(OS.get_cmdline_user_args()))\n var scene = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()\n root.add_child(scene)\n for i in 20: await process_frame\n quit()\n')
            command=['python3',str(ROOT/'tools/run.py'),'--project',str(project),'--headless','--script',str(probe),'--','--probe']
            if shutil.which('sandbox-exec'):
                command=['sandbox-exec','-p','(version 1) (allow default) (deny network*)',*command]
            result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=120)
            markers=[line.split('=',1)[1] for line in result.stdout.splitlines() if line.startswith('QA_USER_DIR=')]
            self.assertEqual(1,len(markers),result.stdout+result.stderr)
            data=Path(markers[0]).resolve()
            self.assertEqual(qa_name,data.name)
            try:
                self.assertEqual(0,result.returncode,result.stdout+result.stderr)
                self.assertNotIn('No loader found',result.stdout+result.stderr)
                self.assertTrue((project/'.godot').is_dir())
                self.assertIn('QA_ARGS=["--probe"]',result.stdout)
            finally:
                if data.exists(): shutil.rmtree(data)
if __name__ == '__main__': unittest.main()
