#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$root/tools/build_ios_identity.py"
python3 "$root/tools/build_ios_storekit.py"
python3 "$root/tools/install_admob.py" ios
