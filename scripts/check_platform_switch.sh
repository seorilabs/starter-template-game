#!/usr/bin/env bash
#
# 공통 플랫폼 전환 스위치가 꺼진 채 커밋되어 있는지 확인한다.
#
# 켠 채로 커밋되면 신규 앱이 검증하지 않은 경로로 시작한다.
# 템플릿에서 복사한 앱은 붙일 준비가 된 뒤에 켜야 한다.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="$(cd "$here/.." && pwd)/firebase/seori-platform.config.json"

if [[ ! -f "$config" ]]; then
  echo "전환 스위치 설정이 없다: $config" >&2
  exit 1
fi

enabled="$(python3 -c "import json;print(json.load(open('$config')).get('enabled'))")"

if [[ "$enabled" != "False" ]]; then
  echo "전환 스위치가 켜진 채 커밋되어 있다 (enabled=$enabled)." >&2
  echo "템플릿은 꺼진 상태로 시작한다. 붙일 준비가 된 앱에서만 켠다." >&2
  exit 1
fi

echo "전환 스위치 꺼짐 확인"
