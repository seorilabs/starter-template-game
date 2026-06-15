#!/usr/bin/env bash
set -euo pipefail

required_dirs=(
  "packages/product-core/src/domain"
  "packages/product-core/src/use_cases"
  "packages/product-core/src/ports"
  "packages/product-core/tests"
)

for dir in "${required_dirs[@]}"; do
  if [ ! -d "${dir}" ]; then
    echo "Missing core directory: ${dir}" >&2
    exit 1
  fi
done

echo "Core test scaffold is present. Add product-specific pure tests under packages/product-core/tests."

