# 공통 플랫폼 붙이기

인증·이벤트·RemoteConfig·결제를 직접 만들지 않는다. `seorilabs/platform`이
그 역할을 하고, 앱은 SDK만 가져다 쓴다.

조직에서 이것들이 제품마다 처음부터 다시 구현되고 있었다. 인증이 6벌,
IAP 서버검증이 3벌, 이벤트 전송 경로가 7가지였다. boolean 직렬화가
앱마다 달라 같은 이벤트가 다르게 쌓이기까지 했다.

## 언제 붙이는가

**신규 앱은 꺼진 상태로 시작한다.** `firebase/seori-platform.config.json`의
`enabled`가 `false`다.

붙일 준비가 되면 — 즉 플랫폼 registry에 앱이 등록되고 Firebase Auth가
연결되면 — `baseUrl`과 `appId`를 채우고 `enabled`를 켠다.

## 붙이는 법

`seorilabs/platform`의 레퍼런스 문서를 따른다.

| 앱 종류 | 문서 |
|---|---|
| Godot | `examples/reference-godot/README.md` |
| React Native | `examples/reference-rn/README.md` |

## 지켜야 할 것

플랫폼을 쓰든 안 쓰든 이 규칙은 같다.

- **익명 신원은 결제할 수 없다.** `getAnonymousKey()` 해시는 bearer
  자격증명이 아니라 타인 사칭이 가능하다
- **이벤트명을 마음대로 바꾸지 않는다.** GA4 시계열이 끊기고
  백오피스의 `AppMetricDaily`가 깨진다
- **응답에서 미지 필드를 무시한다.** 키 개수를 세면 서버가 필드를
  추가하는 순간 마켓에 배포된 구버전이 전부 깨진다
- **PII를 이벤트 파라미터에 넣지 않는다.** SDK가 거르지만 애초에
  넣지 않는 것이 맞다

## 붙이지 않을 때

플랫폼 없이도 앱은 동작해야 한다. `enabled: false`면 SDK 객체가
만들어지지 않고 기존 경로가 그대로 돈다.

이것이 롤백 경로이기도 하다. 문제가 생기면 값 하나를 되돌리고
재배포한다. 코드를 되돌려야 하는 롤백은 장애 중에 할 수 없다.
