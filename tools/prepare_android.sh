#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$root/tools/install_billing.py"
bash "$root/tools/build_android_identity.sh"
python3 "$root/tools/install_admob.py" android
