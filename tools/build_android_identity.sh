#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$root/tools/install_android_build_template.sh"
"$root/godot/android/build/gradlew" -p "$root/native/android/seori_account_link" assembleDebug assembleRelease --console=plain
for kind in debug release; do
  mkdir -p "$root/godot/addons/seori_account_link/bin/$kind"
  cp "$root/native/android/seori_account_link/build/outputs/aar/SeoriAccountLink-$kind.aar" "$root/godot/addons/seori_account_link/bin/$kind/"
done
