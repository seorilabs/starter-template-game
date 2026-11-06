import copy
import io
import json
import tarfile
import tempfile
import unittest
from pathlib import Path
import bundle

class BundleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.lock = {'version': '1.0.0', 'roots': list(bundle.ROOTS),
                     'source': {'repository': bundle.REPOSITORY, 'commit': 'a' * 40},
                     'files': {r + '/one.gd': bundle.sha(b'original') for r in bundle.ROOTS}}
        for name in self.lock['files']:
            p = self.root / name; p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(b'original')
        (self.root / 'common-bundle.lock.json').write_text(json.dumps(self.lock))

    def test_modified_and_added_common_files_rejected(self):
        p = self.root / next(iter(self.lock['files']))
        p.write_bytes(b'modified')
        with self.assertRaisesRegex(ValueError, 'modified'): bundle.verify(self.root, self.lock)
        p.write_bytes(b'original')
        p.with_name('injected.gd').write_bytes(b'injected')
        with self.assertRaisesRegex(ValueError, 'inventory'): bundle.verify(self.root, self.lock)

    def test_generated_import_metadata_is_not_source(self):
        (self.root / next(iter(self.lock['files']))).with_suffix('.uid').write_text('generated')
        bundle.verify(self.root, self.lock)

    def test_paths_and_missing_roots_rejected(self):
        lock = copy.deepcopy(self.lock); lock['files']['../../escape'] = 'a' * 64
        with self.assertRaises(ValueError): bundle.validate_manifest(lock)
        lock = copy.deepcopy(self.lock); lock['files'].pop(next(iter(lock['files'])))
        with self.assertRaises(ValueError): bundle.validate_manifest(lock)

    def test_archive_traversal_rejected_without_mutation(self):
        path = self.root / 'bad.tar.gz'
        with tarfile.open(path, 'w:gz') as t:
            entry = tarfile.TarInfo('../escape'); entry.size = 3; t.addfile(entry, io.BytesIO(b'bad'))
        with self.assertRaises(ValueError): bundle.install(self.root, path)
        bundle.verify(self.root, self.lock)

    def test_dirty_existing_bundle_not_overwritten(self):
        payload = self.root / 'new.tar.gz'
        with tarfile.open(payload, 'w:gz') as t:
            for name, data in {'common-bundle.lock.json': json.dumps(self.lock).encode(), **{n: b'original' for n in self.lock['files']}}.items():
                item = tarfile.TarInfo(name); item.size = len(data); t.addfile(item, io.BytesIO(data))
        p = self.root / next(iter(self.lock['files'])); p.write_text('user work')
        with self.assertRaisesRegex(ValueError, 'modified'): bundle.install(self.root, payload)
        self.assertEqual('user work', p.read_text())

    def _archive(self, lock, data=b'original'):
        payload = self.root / ('bundle-%s.tar.gz' % lock['version'])
        with tarfile.open(payload, 'w:gz') as t:
            for name, body in {'common-bundle.lock.json': json.dumps(lock).encode(), **{n: data for n in lock['files']}}.items():
                item = tarfile.TarInfo(name); item.size = len(body); t.addfile(item, io.BytesIO(body))
        return payload

    def test_contract_1_1_0_installs_over_1_0_0_and_downgrade_refused(self):
        newer = copy.deepcopy(self.lock); newer['version'] = '1.1.0'
        newer['files'][bundle.ROOTS[0] + '/ui_kit/juice.gd'] = bundle.sha(b'original')
        bundle.validate_manifest(newer)
        installed = bundle.install(self.root, self._archive(newer))
        self.assertEqual('1.1.0', installed['version'])
        self.assertTrue((self.root / bundle.ROOTS[0] / 'ui_kit/juice.gd').is_file())
        with self.assertRaisesRegex(ValueError, 'downgrade'): bundle.install(self.root, self._archive(self.lock))
        self.assertEqual('1.1.0', json.loads((self.root / 'common-bundle.lock.json').read_text())['version'])
        unknown = copy.deepcopy(self.lock); unknown['version'] = '2.0.0'
        with self.assertRaises(ValueError): bundle.validate_manifest(unknown)

if __name__ == '__main__': unittest.main()
