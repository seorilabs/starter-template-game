#!/usr/bin/env bash
set -euo pipefail

scan_paths=(
  "packages/product-core/src"
  "packages/product-core/tests"
)

for path in "${scan_paths[@]}"; do
  if [ ! -d "${path}" ]; then
    echo "Missing architecture scan path: ${path}" >&2
    exit 1
  fi
done

forbidden_pattern='(from|import|require|extends|class_name).*(Godot|Firebase|firebase|Firestore|firestore|AppsInToss|Toss|StoreKit|BillingClient|AdMob|JavaScriptBridge|Node|Control|SceneTree)'

if rg -n "${forbidden_pattern}" "${scan_paths[@]}" --glob '!README.md'; then
  echo "Architecture boundary violation found in product core." >&2
  exit 1
fi

echo "Architecture boundary check passed."

