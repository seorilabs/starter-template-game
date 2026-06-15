# AppsInToss Wrapper

Godot Web export를 AppsInToss에 패키징하는 wrapper 자리다.

## 생성 전 확인

- AppsInToss `appName`: 확정 필요
- `brand.displayName`: 확정 필요
- `brand.icon`: 확정 필요
- Web export output path: 확정 필요
- Granite/Web framework version: 공식 문서 확인 후 확정

## Guardrails

- Godot runtime은 iframe으로 감싸지 않는다.
- Godot Web export의 JS runtime과 canvas를 wrapper에서 직접 로드한다.
- `.ait` 생성 성공은 콘솔 등록/이미지/sandbox QA 완료를 의미하지 않는다.

