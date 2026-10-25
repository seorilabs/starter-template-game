#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${XCODE_PROJECT:?Exported Xcode project path required}"
icons="${XCODE_PROJECT%.xcodeproj}/Images.xcassets/AppIcon.appiconset"
[ -d "$icons" ] || { echo "Exported AppIcon set not found" >&2; exit 1; }
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
if ! "${GODOT:-godot}" --headless --path "$root/${PROJECT_DIR:-godot}" --script "$root/tools/opaque_ios_icons.gd" -- "$icons" > "$log" 2>&1; then
  cat "$log"
  exit 1
fi
cat "$log"
if grep -Eq '^(SCRIPT ERROR|ERROR:)' "$log"; then exit 1; fi
python3 - "$XCODE_PROJECT" <<'PY'
from pathlib import Path
import plistlib,sys
project=Path(sys.argv[1]);entitlements=project.with_suffix('')/(project.stem+'.entitlements')
if not entitlements.is_file():raise SystemExit('Exported signing entitlements not found')
value=plistlib.loads(entitlements.read_bytes())
value['com.apple.developer.applesignin']=['Default']
value['com.apple.developer.devicecheck.appattest-environment']='production'
entitlements.write_bytes(plistlib.dumps(value))
PY
