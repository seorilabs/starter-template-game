# 설계: 공통 묶음 1.1.0 ui_kit 전환

- 설계 ID·버전·원본 커밋: 2026-11-06-ui-kit-1-1-0 v1, 기준 `42e1536e49eac777f82b42b0484acfc5a920b85b`(main)
- 상태: 승인(v2)
- 승인자·시각·근거·승인 커밋: Ilhwan Seo, 2026-11-06, 세션 질의 응답 "승인, 구현 시작", 승인 커밋 `20506b580092e7e5a60a9a6aa705c220d9e5386c`. v2(검수 크기 568x320·1024x600, 기존 문제 별도 이슈) 2026-11-06 같은 방식으로 승인
- 관련 Issue·PR·Wiki·검수: [#22](https://github.com/seorilabs/starter-template-game/issues/22), game-foundation [#11](https://github.com/seorilabs/game-foundation/pull/11)·[#12](https://github.com/seorilabs/game-foundation/pull/12), agent-config 스킬 `game-ui-commercial`

## 목적·범위·근거

이 템플릿으로 만든 새 게임은 공통 묶음 1.0.0을 쓰기 때문에 첫 빌드가 코드로 칠한 `StyleBoxFlat`, 서체 1종, 즉시 뜨는 화면, 무음 버튼으로 시작한다. game-foundation #11이 같은 재료를 `ui_kit`으로 기반에 넣었고(계약 1.1.0, main `06f2519f232f1d6332bfca39cf2fb05262f615d1`, 가로 보정 #13·#15 뒤 `17984c9603c10a69498cb2464413b86932437cc9`), 적용 전 기반은 필수 재료 게이트 8항목 전부 FAIL, 적용 뒤 전부 PASS였다. 템플릿을 1.1.0으로 올리면 새 게임이 설치만으로 재료를 받는다.

| 구분 | 내용 |
|---|---|
| 포함 | `tools/bundle.py`·`tools/test_bundle.py`·`tools/validate_outgame.py`를 game-foundation main 사본으로 갱신, 1.1.0 묶음 설치와 잠금, `uiStandard.version` 1.1.0, 기능 목록에 `ui_kit` 추가, 템플릿 자체 화면(홈·예제 라운드)의 테마 변형 적용, 보상 큐 payload에 `amount`, 여정에 `popup-open`·`reward-impact`·`reward-settle` 캡처, `docs/game-design/ui/gate-report.json`, 독립 검수 3회 기록 |
| 제외 | 새 스킨 그림(soft_adventure 기본 스킨 그대로), 이미 생성된 게임의 전환(별도 설계), 마켓 출시 |

전후 예시: 홈의 ▶ 버튼은 지금 Godot 기본 Button이다. 전환 뒤에는 `PrimaryButton` 변형(9분할 스킨, 눌림 펀치 모션, 탭·확인 효과음)이 되고, 별 3개 보상은 "+10 coins" 텍스트 팝업 대신 기대→충격(파티클·스팅)→정착(날아가기·카운트업) 3단계로 뜬다.

## 사용자 흐름·화면 상태

타이틀 → 시작 → 예제 라운드(별 3회 탭) → Collect → 보상 연출 → 홈 → 우편·설정·지원 → 재실행 복원. 흐름 자체는 바뀌지 않고 각 화면의 재료만 바뀐다.

| 화면 | 바뀌는 것 | 상태 |
|---|---|---|
| 타이틀·홈 | 테마 스킨, 재화 칩, HUD 층, 디스플레이 서체 | 작은 화면 320x568, 가로 568x320·844x390, 큰 글자, ko·en |
| 모달(우편·설정·지원) | 프레임 `pop_in`·내용 페이드(딤은 `popup_base` 팝업에만 있다) | reduced_motion이면 즉시 완료 |
| 보상 | 3단계 연출(기대→충격→정착), 탭 스킵, `finished` 뒤 홈 복귀 버튼. 기반 `_draw_result`는 counter·target 없이 호출해 카운트업·비행은 없고 "+10" 카드가 뜬다 | 연습 모드(replay)는 amount 0으로 카드에 수량 없음 |
| 예제 라운드 | ★ 버튼과 Collect에 효과음·펀치 | 기존 크기·글자 배율 유지 |

## 구조·책임·의존성

- 공통 묶음(`godot/addons/seorilabs_game/**`, `godot/tests/common/**`)은 game-foundation 원본을 그대로 설치하고 수정하지 않는다. 기반 `outgame_main.gd`가 테마·효과음·HUD 층·보상 연출을 연결한다.
- 템플릿 코드가 바꾸는 것: `godot/game/features/home/home.gd`(라벨 `DisplayLabel`, 버튼 `PrimaryButton` 변형), `godot/game/features/sample_round/sample_round.gd`(보상 payload `amount`), `godot/tests/game/outgame_journey.gd`(캡처 3장 추가), `godot/data/outgame/outgame-profile.json`, `docs/qa/feature-inventory.json`, `tools/` 사본 3개.
- 의존: game-foundation 로컬 체크아웃에서 `python3 tools/bundle.py pack --commit 17984c9603c10a69498cb2464413b86932437cc9`(#15 가로 보정 v2 병합 커밋)로 만든 묶음. 잠금 `source.commit`은 이 SHA다. 1차 후보 `9217328`은 `06f2519` 묶음이었고 독립 검수 1·2회차가 공통 묶음 결함으로 실패해 #13으로 고쳤다. 2차 후보 `3ccc4a1`(#13 묶음 `bc21978`)은 4회차가 겹침 2건으로 실패하고 5·6회차는 통과했으며 #15로 고쳤다.

## 데이터·인터페이스·실패 처리

- 저장 형식(`user://<id>.json`)과 state 스키마는 바뀌지 않는다. 기존 저장은 그대로 읽힌다.
- 묶음 설치는 1.0.0 위 1.1.0만 허용하고 역방향은 `bundle.py`가 거부한다. 해시가 다른 공통 파일이 있으면 설치가 멈춘다(사용자 수정 보존).
- `validate_outgame.py`는 잠금 버전과 프로필 `uiStandard.version`이 같아야 통과한다.
- 효과음은 headless에서 `--audio-driver Dummy`로 돌고 재생 실패가 흐름을 막지 않는다.

## 품질 요구사항

- `ui_gate.py` 8항목 PASS(정적). 캡처로 서체 역할 분리, 스킨 이음매, 팝업 딤, 보상 3프레임을 눈으로 확인.
- 모션 기본값은 기반 `skin.json`(팝업 220/140ms, 보상 400/200/500ms)을 그대로 쓴다. 2차 조사 관찰 범위 안이다.
- 접근성: 큰 글자 배율과 reduced_motion 경로를 여정이 계속 확인한다.

## 대안·주요 결정

| 대안 | 결정 |
|---|---|
| 템플릿만 `custom_theme`로 자체 테마 조립 | 기각. 기반이 `theme.tres`를 쓰므로 템플릿이 테마를 만들면 새 게임마다 재료를 다시 만든다 |
| `tools/` 사본을 부분 수정 | 기각. foundation main 사본으로 통째 갱신해야 다음 묶음 갱신도 같은 절차다 |
| 보상 payload에 `amount` 추가 | 채택. 기반 `_draw_result`가 `amount`로 카운트업한다. 없으면 텍스트만 뜬다 |
| 가로 전용 템플릿이라 세로 캡처 생략 | v1은 세로도 검수하기로 했으나 구현 중 확인한 결과 main(1.0.0)에서도 세로 390x844는 여정의 `collect reward` 단계가, 가로 667x375·812x375·844x390·960x540은 `platform_journey`의 `check deletion status with a button` 단계가 실패한다(ui_kit과 무관한 템플릿 기존 문제). 이 설계는 ui_kit 전환만 다루므로 검수 크기를 통과 가능한 568x320(CI 크기)과 1024x600으로 바꾸고, 기존 문제는 별도 이슈로 남긴다(v2, 2026-11-06 승인) |

## 인수조건·테스트·검수

| 조건 ID | 관찰할 동작·통과 기준 | 테스트 방법·환경 | 격리 데이터·시작 상태 | 기대 결과 | 증거 |
|---|---|---|---|---|---|
| AC-1 | 잠금이 1.1.0이고 `source.commit`이 `17984c9…`, `bundle.py verify` 통과, 1.0.0 위 설치 허용·역방향 거부 테스트 통과 | `python3 tools/bundle.py verify`, `python3 -m unittest discover -s tools -p 'test_bundle.py'` | 새 체크아웃 | 통과 | PR 로그 |
| AC-2 | 필수 재료 8항목 PASS | `ui_gate.py --root . --project godot --out docs/game-design/ui/gate-report.json` | — | 8 PASS, 예외 0 | gate-report.json |
| AC-3 | `npm test` 통과(단위, native, `check.py` 여정과 `ui_kit_probe`), `validate_outgame.py` 통과 | 개발 환경 headless | 여정이 만드는 격리 저장 | 모두 통과 | CI 실행 URL |
| AC-4 | 보상 연출이 기대→충격→정착 순서로 돌고 저장 코인이 10, 스킵 뒤 홈 복귀 | 여정 `reward-impact`·`reward-settle` 캡처, probe | 격리 저장 | 캡처 3장, coins 10 | e2e 보고 |
| AC-5 | 홈의 주 행동(가로 캠프 홈 `play`)이 `PrimaryButton` 변형이고 `godot/game/`에 `StyleBoxFlat` 없음. 템플릿 `home.gd`의 ▶는 세로 프로필 전용 경로라 정적으로만 확인 | 여정 검사와 grep | — | 통과 | e2e 보고 |
| AC-6 | `init_game.py`가 1.1.0 잠금에서 그대로 동작 | `python3 -m unittest discover -s tools -p 'test_init_game.py'` | 임시 복제 | 통과 | 로그 |
| AC-7 | 독립 검수 3회(기능·UX, 모든 기능)가 568x320·1024x600·568x320 캡처로 통과. 후보가 바뀔 때마다 새 3회를 돌리고 실패 회차 기록은 보존한다(1~3회차 후보 9217328, 4~6회차 후보 3ccc4a1, 7~9회차 현재 후보). v1의 844x390·390x844·320x568은 아래 '기존 문제'로 제외 | 구현자와 다른 에이전트가 `check.py --capture --size …` 실행 후 기록 | 격리 저장 | 3회 모두 pass | `docs/qa/2026-11-06-ui-kit-review-{1,2,3}.md` |

- `validate_outgame.py`는 `tools/check.py`가 여정 보고로 만든 `evidence.automated`를 넣어 호출하며 통과했다. 저장소의 프로필은 증거를 비워 두므로 단독 실행은 설계대로 `unverified`다.
- TDD 대상: `test_bundle.py`(1.1.0 설치·역방향 거부)는 foundation 사본이 먼저 실패 후 통과한다. 여정의 `reward-impact`·`reward-settle`·`popup-open` 단계와 `PrimaryButton` 검사는 전환 전 실패(캡처 없음·변형 없음), 전환 후 통과한다. 테마·효과음 자체는 기반 `ui_kit_probe`가 검사하므로 템플릿에 중복 테스트를 두지 않는다.
- 테스트 계획: [test-plan.json](test-plan.json)

| 항목 | 값 |
|---|---|
| 등급 | L3 전체 회귀(공통 묶음 `addons/**`가 회귀 경로) |
| 실행 환경 | 개발 환경(headless E2E, 렌더링 캡처). 실기기 없음 |
| 검증기 하한과 낮춘 항목·사유 | 낮춘 항목 없음. 기능 목록에 foundation 기능이 없어 `foundationRerun` false |
| 새 화면·UI 개편 | 예. L3·독립 검수 3회 |
| 출시 마켓·끝 지점 | 없음(`release: null`). 템플릿 자체는 출시하지 않는다 |

- 실행 못할 조건·필요한 승인·환경: 로컬 game-foundation 체크아웃(묶음 pack)과 Godot 4.7.2. 기기 승인 불필요.

## 적용·운영·되돌리기

1. `tools/` 사본 갱신 → 묶음 pack·install·verify → 프로필·기능 목록 → 템플릿 화면·여정 → 게이트 보고 → 로컬 `npm test`·캡처 → 독립 검수 3회 → PR(Ready, 한국어) → CI → 병합.
2. 되돌리기: `bundle.py`가 역방향 설치를 거부하므로 PR 전체를 revert한다. 저장 형식이 바뀌지 않아 데이터 영향은 없다.
3. 남은 위험: 이미 생성된 게임은 이 PR로 바뀌지 않는다. 각 게임은 자기 설계로 전환한다.
4. 기존 문제(이 PR 범위 밖, 별도 이슈): 세로 창에서 여정 `collect reward` 실패, 가로 667x375·812x375·844x390·960x540에서 `platform_journey` 삭제 상태 버튼 `scroll_into_view` 실패. 둘 다 main `42e1536`에서 재현했다.

## 승인·추적

- 원본: 이 문서와 `test-plan.json`의 같은 커밋.
- 티켓: #22. PR은 승인 뒤 연다.
