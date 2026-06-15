# Firebase

Firebase를 사용하는 경우 rules, indexes, functions, emulator config를 이 폴더에 둔다.

MVP가 local-only면 Firebase를 추가하지 않는다.

## Guardrails

- service account JSON과 Admin SDK credential은 client export에 포함하지 않는다.
- privileged operation은 Cloud Functions 또는 Cloud Run으로 분리한다.
- Security Rules와 indexes는 release 전에 version control에 포함한다.

