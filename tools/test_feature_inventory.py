import json
import tempfile
import unittest
from pathlib import Path
import check_architecture
ROOT = Path(__file__).resolve().parents[1]
class FeatureInventoryTests(unittest.TestCase):
    def test_repository_paths_are_nonempty_when_present(self):
        inventory = json.loads((ROOT/'docs/qa/feature-inventory.json').read_text())
        for feature in inventory['features']:
            for field in ('paths','platformPaths'):
                if field in feature:
                    self.assertTrue(feature[field], feature['id'] + ':' + field)

    def test_command_rejects_empty_optional_path_list(self):
        inventory = json.loads((ROOT/'docs/qa/feature-inventory.json').read_text())
        inventory['features'][0]['platformPaths'] = []
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); (root/'docs/qa').mkdir(parents=True)
            (root/'docs/qa/feature-inventory.json').write_text(json.dumps(inventory))
            self.assertTrue(any('platformPaths' in e for e in check_architecture.check(root)))
if __name__ == '__main__': unittest.main()
