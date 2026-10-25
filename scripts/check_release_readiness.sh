#!/usr/bin/env bash
set -euo pipefail
python3 tools/check_native.py
printf '%s\n' 'Native internal-test build inputs are configured. The central development verifier must validate the approved plan before build and upload. Provider eligibility, signed artifacts and tester availability require separate readback.'
