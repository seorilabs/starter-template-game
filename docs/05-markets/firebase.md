# Firebase

## Decision

- Firebase usage: 확정 필요
- Firebase project ID: 확정 필요
- Environments: dev / staging / production 확정 필요

## Candidate Capabilities

- Analytics: 확정 필요
- Crashlytics: 확정 필요
- Remote Config: 확정 필요
- Cloud save: 확정 필요
- Leaderboard: 확정 필요
- Entitlement validation: 확정 필요

## Guardrails

- service account JSON, private key, Admin SDK credential은 client export에 포함하지 않는다.
- Security Rules, indexes, functions는 version control에 포함한다.
- MVP가 local-only면 Firebase를 추가하지 않는다.

