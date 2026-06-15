# ADR 0001: docs를 실행 원장으로 둔다

- Status: accepted
- Date: 2026-06-15

## Context

기존에는 지식 문서가 Obsidian과 git에 혼재되어 있었다. GitHub 템플릿으로 반복 사용할 게임 레포에서는 기획, 의사결정, 작업, 마켓정보가 코드와 함께 versioned source of truth로 남아야 한다.

## Decision

- 제품별 실행 원장은 `docs/`로 둔다.
- Obsidian은 재사용 가능한 지식, 운영 노하우, 다른 프로젝트에도 적용되는 학습 내용을 보조로 기록한다.
- 마켓/릴리스/정책/콘솔 값은 `docs/05-markets/`와 repo-local config example을 우선 갱신한다.

## Consequences

- 레포만 clone해도 현재 제품 상태와 release blocker를 파악할 수 있다.
- Obsidian에는 요약과 재사용 지식만 남겨 중복 원장을 줄인다.
- 콘솔-only 변경은 drift로 간주하고 문서/config 반영이 필요하다.

