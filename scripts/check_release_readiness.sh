#!/usr/bin/env bash
set -euo pipefail
python3 tools/check_native.py
python3 - <<'CHECK'
import json
from pathlib import Path
p=Path('docs/design/2026-10-25-native-internal-test/test-plan.json')
plan=json.loads(p.read_text())
assert set(plan['release']['markets']) == {'google-play','app-store'}
assert plan['release']['until']=='test-track'
print('Native internal-test build inputs are configured. Provider eligibility, signed artifacts and tester availability require separate readback.')
CHECK
