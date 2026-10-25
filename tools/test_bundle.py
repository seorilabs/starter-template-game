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
        self.root = Path(self.tmp.name)
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

if __name__ == '__main__': unittest.main()
