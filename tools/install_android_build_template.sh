#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="$root/${PROJECT_DIR:-godot}"
version="${GODOT_VERSION:-4.7.2}.${GODOT_STATUS:-stable}"
if [ "$(uname -s)" = Darwin ]; then
  templates="$HOME/Library/Application Support/Godot/export_templates/$version"
else
  templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version"
fi
archive="$templates/android_source.zip"
[ -f "$archive" ] || { echo "Godot $version export templates are required." >&2; exit 1; }
if [ ! -f "$project/android/build/gradlew" ]; then
  mkdir -p "$project/android/build"
  unzip -q "$archive" -d "$project/android/build"
  touch "$project/android/.gdignore"
fi
