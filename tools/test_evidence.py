import copy
import datetime
import hashlib
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
import validate_outgame as gate

ROOT = Path(__file__).resolve().parents[1]

class EvidenceFreshnessTests(unittest.TestCase):
    def setUp(self):
        (ROOT / 'build').mkdir(exist_ok=True)
        self.tmp = tempfile.TemporaryDirectory(dir=ROOT / 'build'); self.addCleanup(self.tmp.cleanup)
        self.folder = Path(self.tmp.name)
        self.profile = json.loads((ROOT / 'godot/data/outgame/outgame-profile.json').read_text())
        self.artifact = self.folder / 'fixture.json'; self.artifact.write_text('{"fixture":true}')
        self.report = {'kind':'automated','passed':True,'sourceSha':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'recordedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'implementationFingerprint':gate.fingerprint(ROOT,self.profile),
            'checks':{f:True for f in gate.REQUIRED + gate.UI_CHECKS},
            'artifacts':[{'path':str(self.artifact.relative_to(ROOT)),'sha256':hashlib.sha256(self.artifact.read_bytes()).hexdigest(),'type':'report'}]}

    def errors(self):
        p = self.folder/'automated-fixture.json'; p.write_text(json.dumps(self.report))
        self.profile['evidence']['automated']={'status':'passed','path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'implementationFingerprint':self.report['implementationFingerprint']}
        return gate.validate(ROOT,self.profile,require_ui_standard=True)

    def test_expired_or_different_candidate_rejected(self):
        self.assertEqual([],self.errors())
        self.report['recordedAt']=(datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(days=8)).isoformat()
        self.assertTrue(any(e['category']=='stale_evidence' for e in self.errors()))
        self.report['recordedAt']=datetime.datetime.now(datetime.timezone.utc).isoformat()
        self.report['sourceSha']='f'*40
        self.assertTrue(any(e['category']=='stale_evidence' for e in self.errors()))

    def test_missing_support_and_artifact_rejected(self):
        self.report['checks'].pop('ui_support_entry')
        self.assertTrue(any(e['category']=='unverified' for e in self.errors()))
        self.report['checks']['ui_support_entry']=True
        self.artifact.write_text('changed')
        self.assertTrue(any(e['category']=='unverified' for e in self.errors()))

if __name__ == '__main__': unittest.main()
