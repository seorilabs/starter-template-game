import json
import shutil
import tempfile
import unittest
from pathlib import Path
import check_native
ROOT=Path(__file__).resolve().parents[1]
class NativeExportTests(unittest.TestCase):
    def test_native_export_contract(self):
        self.assertEqual([],check_native.validate(ROOT))
    def clone_config(self,folder):
        root=Path(folder)
        patches=json.loads((ROOT/'native/dependencies.lock.json').read_text())['sources']['admob']['localPatches']
        for name in ['native/dependencies.lock.json','godot/project.godot','godot/export_presets.cfg','godot/config/product.json','play-store/google-play.config.json','app-store/app-store.config.json','app-store/exportOptions.plist',*[entry['file'] for entry in patches]]:
            target=root/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
        return root
    def test_changed_vendor_patch_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'godot/addons/admob/admob.gd';p.write_text(p.read_text()+'\n# changed\n')
            self.assertIn('Native source patch hash mismatch: godot/addons/admob/admob.gd',check_native.validate(root))
    def test_mismatched_store_identity_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'play-store/google-play.config.json';data=json.loads(p.read_text());data['packageName']='com.other.wrong';p.write_text(json.dumps(data))
            self.assertIn('Android package identity mismatch',check_native.validate(root))
    def test_embedded_signing_secret_is_rejected_without_echo(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'godot/export_presets.cfg';p.write_text(p.read_text().replace('keystore/release_password=""','keystore/release_password="do-not-copy-this-value"'))
            errors=check_native.validate(root)
            self.assertTrue(any('Signing values must come from the environment' in x for x in errors))
            self.assertNotIn('do-not-copy-this-value',' '.join(errors))
    def test_native_presets_do_not_enable_device_discovery(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'godot/export_presets.cfg';text=p.read_text();index=text.index('[preset.1]');p.write_text(text[:index]+text[index:].replace('runnable=false','runnable=true',1))
            self.assertIn('Native automatic device discovery must stay disabled',check_native.validate(root))
    def test_missing_mobile_texture_import_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'godot/project.godot';p.write_text(p.read_text().replace('textures/vram_compression/import_etc2_astc=true','textures/vram_compression/import_etc2_astc=false'))
            self.assertIn('Mobile texture import must be enabled for native exports',check_native.validate(root))
if __name__=='__main__':unittest.main()
