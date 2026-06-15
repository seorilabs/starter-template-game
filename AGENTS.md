# Seorilabs Game Template Agent Instructions

## 기본 원칙

- 한글을 주 사용언어로 한다.
- 항상 간결하고 실무적으로 답변한다.
- 애매한 부분은 상상해서 채우지 말고, 파일, 로그, 설정, 실행 결과를 먼저 확인한다.
- 사용자의 말이 사실과 다르거나 기술적으로 부정확하면 바로잡는다.
- 복잡한 구조 설명은 가능하면 Mermaid 다이어그램으로 도식화한다.
- 대화 중 장기 지식으로 남길 만한 확인 사실은 문서화한다. 단, 이 레포의 실행 원장은 `docs/`이고 Obsidian은 보조 지식베이스다.

## Source Of Truth

- 기획, 의사결정, 작업 로그, 마켓 정보, 릴리스 준비 상태의 원장은 `docs/`다.
- Obsidian에는 범용 지식, 운영 노하우, 다른 프로젝트에도 재사용할 수 있는 학습 내용을 보조 기록한다.
- 콘솔에서만 바뀐 값은 release-ready로 보지 않는다. Google Play, App Store, AppsInToss, Firebase 관련 값은 가능한 한 repo-local config 또는 `docs/05-markets/`에 남긴다.
- 새 프로젝트에서 확정해야 하는 값은 `확정 필요`로 남기고 임의로 채우지 않는다.

## Local Overrides

- `AGENTS.local.md` 또는 `AGENT.local.md`가 있으면 먼저 읽고, 개별 프로젝트 지침으로 적용한다.
- local agent 파일은 개인 환경, signing path, bundle id, console app id, runner 예외 등 프로젝트별/개인별 설정만 담는다.
- local agent 파일은 커밋하지 않는다. 예시는 `AGENTS.local.example.md`를 사용한다.

## 구조 원칙

```mermaid
flowchart LR
  Docs["docs/ 원장"] --> Spec["기획/의사결정/마켓/릴리스"]
  Core["packages/product-core"] --> Ports["Ports"]
  Ports --> Godot["godot/"]
  Ports --> Firebase["firebase/"]
  Ports --> AIT["apps/ait"]
  Markets["play-store/app-store/apps-in-toss"] --> Release["release checks"]
```

- 게임 기본 스택은 Godot + Firebase다. Firebase가 필요 없는 MVP라면 추가하지 않는다.
- `packages/product-core`에는 엔진 독립 규칙, 유스케이스, 포트, 순수 테스트만 둔다.
- `packages/product-core`는 Godot, Firebase, AppsInToss, Google Play, App Store, 광고 SDK, 결제 SDK, 네트워크 클라이언트를 직접 import하지 않는다.
- Godot scene tree, rendering, input, animation, physics, lifecycle은 `godot/`에 둔다.
- 시장별 delivery/adapters는 `play-store/`, `app-store/`, `apps-in-toss/`, `apps/ait/`, `firebase/`로 분리한다.

## GitHub Actions / ARC

- Seorilabs GitHub Actions 또는 ARC runner 라우팅을 작성/수정/진단할 때는 `seorilabs-arc-runners` 스킬을 사용한다.
- 먼저 `/Users/syous/Workspace/kubectl/github-actions-runners/global-versions.yaml`을 확인한다. runner 이름, Node/Godot 버전, action 버전의 shared source of truth다.
- GitHub Actions action/module 버전은 GitHub 공식 repo/API 또는 공식 문서 기준 최신 stable major를 확인한다. `@latest`나 branch 참조보다 확인된 major tag를 선호한다.
- 현재 확인 기준: `actions/checkout@v6`, `actions/setup-node@v6`, `actions/upload-artifact@v7`.
- private repo의 JS/TS lint/test/typecheck, Web build, AppsInToss candidate, Godot Web/AIT candidate는 `seorilabs-rpi-arm64`를 우선 검토한다.
- ARM64/RPI Docker build는 `seorilabs-rpi-arm64-dind`를 사용한다.
- public PR 경로에는 Seorilabs private ARC runner를 노출하지 않는다. 템플릿 workflow는 `github.event.repository.private` 조건으로 fallback을 둔다.
- Android AAB/APK release build는 RPI ARC로 보내지 않는다. Android SDK Build Tools Linux `aapt2`가 x86-64 binary인 경로를 기본으로 본다.
- Apple App Store/Xcode build는 macOS runner가 필요하므로 RPI ARC로 보내지 않는다.

## 테스트 레이어

- `npm run test:core`: product core 구조/순수 테스트 확인.
- `npm run check:architecture`: core import boundary 확인.
- `npm run test:godot`: Godot import, compile, smoke scene 확인. Godot headless exit code만 믿지 말고 로그의 `SCRIPT ERROR` / `ERROR:`도 실패로 처리한다.
- `npm run check:docs`: docs 원장 구조 확인.
- `npm run check:release`: Google Play, App Store, AppsInToss, Firebase, privacy, signing, asset blocker inventory. 템플릿 placeholder가 남아 있으면 실패하는 것이 정상이다.

## 배포 게이트

- Planning approval 전에는 새 제품 코드, store registration, Firebase project, package/bundle id를 확정하지 않는다.
- Deployment approval 전에는 store submission, production track promotion, AppsInToss production release를 하지 않는다.
- `.ait` 생성 성공은 AppsInToss 콘솔 등록, 이미지, 광고, sandbox QA 완료를 의미하지 않는다.
- release candidate는 `test:core`, `check:architecture`, `test:godot`, 시장별 release inventory를 통과해야 한다.

## Git / PR

- GitHub PR 제목과 Description은 한글로 작성한다. 고유명사, 명령어, 코드, 에러 메시지는 원문 유지 가능하다.
- PR Description에 구조나 흐름 이해가 필요하면 Mermaid 다이어그램을 포함한다.
- Copilot Review는 보정 커밋 이후 명시적으로 re-request해야 한다.
- 사용자 변경은 되돌리지 않는다. 관련 없는 dirty worktree는 무시하고, 충돌하는 경우 먼저 확인한다.

