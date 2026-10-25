import hashlib
import json
import tempfile
import unittest
from pathlib import Path
import bundle
import init_game

class InitializationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        files = {r + '/source.gd': bundle.sha(b'fixed') for r in bundle.ROOTS}
        for name in files:
            p = self.root / name; p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(b'fixed')
        lock = {'version': '1.0.0', 'roots': list(bundle.ROOTS), 'source': {'repository': bundle.REPOSITORY, 'commit': 'a' * 40}, 'files': files}
        for name, data in {
            'common-bundle.lock.json': json.dumps(lock),
            'godot/config/runtime.json': json.dumps({'mode':'server','platformEnabled':True,'networkRequired':True}),
            'godot/config/platform.json': json.dumps({'platform':{'app_id':'starter-game'}}),
            'godot/config/product.json': json.dumps({'name':'Old','id':'old','homeProfile':'hero'}),
            'godot/data/outgame/outgame-profile.json': json.dumps({'gameId':'old','uiStandard':{'homeProfile':'hero'},'evidence':{'old':'stale'}}),
            'godot/project.godot': 'config_version=5\n[application]\nconfig/name="Old"\n',
            'app-store/app-store.config.json': '{"bundleId":"확정 필요"}',
            'apps-in-toss/apps-in-toss.config.json': '{"appName":"확정 필요"}',
        }.items():
            p = self.root / name; p.parent.mkdir(parents=True, exist_ok=True); p.write_text(data)

    def snapshot(self):
        return {p.relative_to(self.root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in self.root.rglob('*') if p.is_file()}

    def test_only_product_settings_change(self):
        before = self.snapshot()
        name = 'Orbit "Stars" \\ path'
        init_game.initialize(self.root, name, 'com.example.orbit', 'world')
        after = self.snapshot()
        self.assertEqual({n for n in before if before[n] != after[n]}, {'godot/config/product.json','godot/data/outgame/outgame-profile.json','godot/project.godot','godot/config/runtime.json','godot/config/platform.json'})
        self.assertIn('config/name=' + json.dumps(name, ensure_ascii=False), (self.root/'godot/project.godot').read_text())
        self.assertFalse(json.loads((self.root/'godot/config/runtime.json').read_text())['platformEnabled'])
        self.assertEqual({}, json.loads((self.root/'godot/config/platform.json').read_text())['platform'])
        self.assertEqual({}, json.loads((self.root/'godot/data/outgame/outgame-profile.json').read_text())['evidence'])
        bundle.verify(self.root, json.loads((self.root/'common-bundle.lock.json').read_text()))

    def test_invalid_id_and_dry_run_do_not_mutate(self):
        before = self.snapshot()
        for identity in ('../save', 'user://private', 'com.example/a', 'Bad App'):
            with self.assertRaises(ValueError): init_game.initialize(self.root, 'Example', identity, 'hero')
        init_game.initialize(self.root, 'Example', 'example', 'map', True)
        self.assertEqual(before, self.snapshot())

    def test_new_product_does_not_reuse_starter_admob_identity(self):
        project=self.root/'godot/project.godot'
        project.write_text(project.read_text()+'\n[editor_plugins]\nenabled=PackedStringArray("res://addons/seori_account_link/plugin.cfg", "res://addons/admob/plugin.cfg")\n[admob]\ngeneral/android/app_id="starter-admob-android"\ngeneral/ios/app_id="starter-admob-ios"\n')
        (self.root/'godot/config/platform.json').write_text(json.dumps({'platform':{'app_id':'starter-game'},'admob':{'android':{'appId':'starter-admob-android'}}}))
        (self.root/'.firebaserc').write_text(json.dumps({'projects':{'default':'seorilabs-starter-game'}}))
        init_game.initialize(self.root,'New Game','com.example.newgame','hero')
        self.assertNotIn('starter-admob',project.read_text())
        self.assertNotIn('addons/admob/plugin.cfg',project.read_text())
        self.assertIn('seori_account_link/plugin.cfg',project.read_text())
        self.assertEqual({},json.loads((self.root/'godot/config/platform.json').read_text())['admob'])
        self.assertEqual({},json.loads((self.root/'.firebaserc').read_text())['projects'])

if __name__ == '__main__': unittest.main()
