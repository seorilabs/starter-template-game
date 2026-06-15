# Seorilabs Starter Template Game

Seorilabs Godot 게임을 Google Play, Apple App Store, AppsInToss까지 확장하기 위한 템플릿 레포다.

이 템플릿은 제품별 값을 임의로 채우지 않는다. 새 프로젝트를 만들면 `docs/01-planning/`, `docs/05-markets/`, `AGENTS.local.md`에서 `확정 필요` 항목을 먼저 정리한다.

## 구조

```text
docs/                  # 기획, 의사결정, 작업, 마켓, 릴리스 원장
packages/product-core/ # 엔진 독립 도메인/유스케이스/포트
godot/                 # Godot project, scenes, runtime scripts, smoke tests
apps/ait/              # AppsInToss Web wrapper 자리
firebase/              # Firebase rules/indexes/functions 자리
play-store/            # Google Play registration/release metadata
app-store/             # Apple App Store registration/release metadata
apps-in-toss/          # AppsInToss console/release metadata
scripts/               # local/CI quality gates
```

## 기본 명령

```bash
npm run test:core
npm run check:architecture
npm run test:godot
npm run check:docs
npm run check:release
npm run build:godot:web
```

`check:release`는 템플릿 placeholder가 남아 있으면 실패한다. 릴리스 직전 blocker inventory 용도다.

`main`에 push되면 GitHub Actions가 Godot Web export를 만들고 GitHub Pages에 배포한다. private repo의 Pages 사이트는 조직/플랜 설정에 따라 외부 공개될 수 있으므로, 민감한 리소스를 export에 포함하지 않는다.
