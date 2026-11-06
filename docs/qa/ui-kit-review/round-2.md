# ui_kit 1.1.0 전환 독립 검수 2회차

- 검수자: 독립 검수 에이전트 2(구현자와 다른 에이전트)
- 후보 SHA: 921732833c15372286820840a26a2fc74c1d09d8 (브랜치 feat/ui-kit-1-1-0)
- 크기: 1024x600(가로, 태블릿급)
- 실행 시각: 2026-11-06T02:40:12Z ~ 02:40:34Z (UTC)
- 실행 환경: dev headless + 렌더링 캡처(Godot 4.7.2.stable, `--audio-driver Dummy`), 격리 worktree `scratchpad/qa-wt-2`
- 격리 저장: 여정이 만든 임시 저장(`user://e2e-game-<usec>/`, 여정 종료 시 삭제)
- 캡처 사본: 검수 worktree `build/qa-round-2`(원본은 NAS 이관, 위치는 PR 본문)

## 검수 계획

설계 `docs/design/2026-11-06-ui-kit-1-1-0/design.md`(AC-1~AC-7)를 먼저 읽고 아래 순서로 본다.

1. 정적 조건: 잠금 1.1.0과 `source.commit` 06f2519, 프로필 `uiStandard.version` 1.1.0, `godot/game/`에 `StyleBoxFlat` 없음(AC-1, AC-5). 통과 기준은 값 일치와 grep 0건.
2. 자동 실행: `check.py --capture --size 1024x600` 출력 `ok: true`, 시나리오 8개 전부 passed, 단계 실패 0, `ui-kit.json`·`ui-contract.json` 실패 0. `unittest discover`와 `check_architecture.py` 통과(AC-3, AC-4, AC-6).
3. 화면 검수: 캡처 PNG 23장(여정 15장, platform 8장)을 눈으로 본다. 확인 항목은 9분할 스킨 모서리·띠 줄무늬, 디스플레이 서체와 본문 서체 역할 분리, 팝업 딤과 프레임 중앙 정렬, 보상 충격 프레임(플래시·파티클)과 정착 프레임(코인·+10), 재화 칩, 버튼 간격과 빈 공간 균형, 글자 잘림·겹침, 한국어·큰 글자 가독성, 키보드 초점 가시성. 통과 기준은 위 항목에서 기능을 막거나 글자를 잃는 결함이 없는 것.
4. 결함은 재현 상태와 틀린 내용을 적고, 원인이 코드에서 확인되면 위치를 적는다. ui_kit과 무관한 기존 문제는 분리한다.

## 실행 명령과 결과

| 명령 | 결과 |
|---|---|
| `git worktree add … 9217328` | 격리 worktree 생성, HEAD 일치 |
| `godot --headless --path godot --import --quit-after 2` | 종료 코드 0 |
| `python3 tools/check.py --capture --size 1024x600 --out build/qa-round-2` | `{"ok": true, "sourceSha": "9217328…", "scenarios": 8}`, 22초 |
| `build/qa-round-2/journey.json` | viewport [1024, 600], mode rendered, 시나리오 8개 모두 passed, 실패 단계 0 |
| `build/qa-round-2/ui-kit.json` | passed true, 검사 40개 실패 0 |
| `build/qa-round-2/ui-contract.json` | passed true, 검사 87개 실패 0 |
| `python3 -m unittest discover -s tools -p 'test_*.py'` | 23 tests OK (5.8초) |
| `python3 tools/check_architecture.py` | Architecture passed |
| `grep -rn StyleBoxFlat godot/game/` | 0건 |
| `common-bundle.lock.json` | version 1.1.0, source.commit 06f2519f232f1d6332bfca39cf2fb05262f615d1 |
| `godot/data/outgame/outgame-profile.json` | `uiStandard.version` 1.1.0 |

## 기능 결과

| 시나리오 | 기능 태그 | 상태 |
|---|---|---|
| offline-first-play-restart (17단계) | startup, tutorial, account_save, inbox, commerce, operations, observability, ui_leaderboard, ui_kit | passed |
| settings-language-support-focus (14단계) | settings_support, account_save, ui_support_entry, ui_analytics_opt_out, ui_locale_offline, ui_navigation | passed |
| three-home-profiles (12단계) | startup, tutorial, account_save, ui_navigation | passed |
| real-bootstrap-account-and-cloud (9단계) | startup, account_save, platform_end_to_end, ui_landscape | passed |
| actual-round-cloud-save (7단계) | tutorial, account_save, platform_end_to_end | passed |
| inbox-wallet-and-store (8단계) | inbox, commerce, platform_end_to_end | passed |
| ad-server-receipt-and-optout (11단계) | observability, operations, platform_end_to_end | passed |
| link-logout-recover-and-delete (11단계) | account_save, platform_end_to_end, settings_support | passed |

보상 연출은 `reward ceremony impact` → `settle` → `finished` 순으로 단계가 통과했고 `persisted reward`·`reward restored`가 coins 10을 확인했다(AC-4). `hero/map/world play is primary skin` 3건은 홈 Play 버튼의 `theme_type_variation == PrimaryButton`을 확인했다(AC-5).

## UX 결과

| 화면 | 확인 항목 | 결과 |
|---|---|---|
| title.png | 캠프 배경, 디스플레이 서체 제목·"A new adventure begins"와 본문 서체 보조 문구 분리, 재화 칩 ★ 0, 상단 HUD(My account·설정)와 하단 6버튼 간격 균등, 9분할 버튼 모서리 왜곡 없음 | 통과 |
| tutorial.png | 팝업 프레임 중앙 정렬, 프레임 모서리 장식 4개 정상, ★ 큰 버튼 스킨 늘림에 띠 줄무늬 없음, "Skip guide"는 스크롤 영역 아래에 있고 스크롤바가 보여 잘림이 아닌 스크롤 | 통과 |
| reward-impact.png | 전체 화면 노란 플래시, 코인 아이콘과 파티클 점 등장, "+10"·"coins" 카드가 작은 크기에서 펀치 인 중 | 통과 |
| reward-settle.png | 코인 아이콘 64px, NumberLabel "+10", DisplayLabel "coins" 노출. "coins" 글자 아래쪽이 뷰포트 하단(y=600)에 잘림 | 결함 1 |
| result.png | 결과 팝업 제목·"+10 coins"·Continue 주 버튼(금색 스킨), 연출 퇴장 페이드 잔상이 아래 띠에 남는 것은 `pop_out` 0.2초 중 캡처로 설계 범위 | 통과(결함 1과 같은 위치에서 잔상도 잘림) |
| home.png | 보상 뒤 재화 칩 ★ 10 갱신, Play 주 버튼 PrimaryButton 스킨, 비활성 Shop·Ad reward·Operations가 회색 변형으로 구분, 겹침 없음 | 통과 |
| popup-open.png | 우편 프레임이 축소·반투명 상태로 중앙에서 커지는 중, 배경 딤 적용, 프레임 중앙 정렬 | 통과 |
| inbox.png | 프레임 완전 노출, Claim all·Grant history 버튼 스킨, 본문 서체 가독성, 하단 "Unread"는 스크롤 영역 | 통과 |
| settings.png | 토글 행 스킨(켜짐 녹색 띠), 본문 안내 두 줄 가독, 스크롤바 | 통과 |
| support.png | 제목 디스플레이 서체, 입력 상자 "—", 비활성 Copy code 회색 변형 | 통과 |
| korean.png | "언어" 디스플레이 서체가 한국어용 서체로 바뀜, 버튼 3개 본문 서체 한글 가독, 선택 표시 ✓ 한국어 | 통과 |
| large-text.png | "접근성" 제목과 "큰 글자"·"움직임 줄이기" 토글이 확대돼도 잘림·겹침 없음 | 통과 |
| keyboard-focus.png | "지원코드" 버튼에 진한 초점 외곽선이 보이고 스크롤 영역 안에 들어옴. 상단 잘린 글줄은 스크롤 위치 | 통과 |
| hero.png, map.png, world.png | 세 장이 픽셀 동일(홈 캡처와 칩 숫자만 다름). 가로 홈 `_camp_home`은 `home_profile`·`stage_factory`를 쓰지 않아 템플릿 `home.gd`의 ★ 라벨과 ▶ 버튼이 렌더링되지 않음. 기준 main(42e1536)도 같은 경로라 기존 동작 | 통과(기존 관찰 1) |
| platform/connected-camp.png | "Account connected", 재화 칩 ★ 10과 티켓 칩 0 나란히, 칩 아이콘·숫자 정렬 | 통과 |
| platform/deletion-status.png | My account 2열 버튼 그리드 간격 균등, "Deletion request: completed" 가독 | 통과 |
| platform/localized-store.png | 상품 버튼 2줄(이름·가격) 스킨 안에 정렬, 빈 공간은 스크롤 없는 목록 | 통과 |
| platform/maintenance-reason.png | 점검 문구가 디스플레이 서체로 홈 중앙에 표시, 겹침 없음 | 통과 |
| platform/server-ad-confirmed.png | 안내 본문 두 줄, Watch test ad 주 버튼 스킨, 아래 버튼은 스크롤 영역 | 통과 |
| platform/server-identifiers.png | 지원코드 STRT-TEST 숫자 서체, Copy code 주 버튼, "Code copied" 상태 | 통과 |
| platform/server-mail-received.png | 비활성 Claim all 회색 변형, 우편 항목 본문 가독 | 통과 |
| platform/signed-out-camp.png | "Create account" 주 버튼, 티켓 칩 "—" 표시, 비활성 Shop 구분 | 통과 |

## 결함

1. 가로 1024x600에서 보상 정착 프레임의 "coins" 라벨 아래쪽이 화면 밖으로 잘린다.
   - 재현: 예제 라운드에서 별 3개 수집 후 Collect +10 → 결과 팝업 위 보상 연출 settle 단계(`reward-settle.png`).
   - 관찰: 연출 카드가 코인(y≈418~482), "+10"(y≈496~522), "coins"(y≈552~)로 쌓이는데 "coins" 글자 픽셀이 마지막 행 599까지 이어지고 그 아래가 없다. 글자 몸통 아래가 평평하게 잘려 보인다. 읽히기는 하지만 보상의 핵심 프레임에서 글자가 손실된다. `result.png`의 퇴장 잔상도 같은 위치에서 잘린다.
   - 원인(코드 확인): `godot/addons/seorilabs_game/flow/outgame_main.gd:816-817`이 가로 화면이면 `focus = Vector2(0.5, 0.86)`으로 호출하고, `reward_ceremony.gd:20`이 `Stage.offset_top = (0.86-0.5)*2*size.y = 432`로 두어 Stage 높이가 168px가 된다. 아이콘 64 + 간격 12×2 + 숫자 라벨 + 디스플레이 라벨 열이 168px보다 커서 CenterContainer가 가운데 맞춘 열이 뷰포트 아래로 넘친다. 세로 화면(0.62)은 해당 없음.
   - 범위: 1.1.0 공통 묶음(foundation `outgame_main.gd`·`ui_kit/reward_ceremony.gd`)의 가로 배치 값이며 템플릿 코드가 아니다. 수정은 foundation에서 가로 focus.y를 낮추거나 Stage가 열 높이를 넘지 않게 보정해야 한다.
   - 심각도: 낮음(흐름·저장·카운트 영향 없음, 시각 잘림).

ui_kit과 무관한 기존 관찰(결함으로 세지 않음):

1. 가로 템플릿에서 `home_profile`이 hero·map·world여도 `_camp_home`이 같은 화면을 그려 템플릿 `godot/game/features/home/home.gd`(DisplayLabel ★ 라벨, PrimaryButton ▶)가 실제로 렌더링되지 않는다. 기준 main 42e1536의 `outgame_main.gd`도 `if landscape: _camp_home(true)`로 같은 경로다. 따라서 AC-5의 "홈 ▶가 PrimaryButton 변형"은 여정이 foundation Play 버튼의 변형으로 확인하며, 템플릿 `home.gd`의 변형 지정은 정적으로만 확인된다(`git diff`로 `theme_type_variation` 지정 확인).

## 판정

fail — 자동 검사(여정 8개, ui-kit 40개, ui-contract 87개, unittest 23개, 아키텍처)는 모두 통과했으나, 검수 크기 1024x600의 보상 정착 프레임에서 "coins" 디스플레이 라벨이 뷰포트 하단에 잘리는 글자 손실(결함 1)이 ui_kit 보상 연출 범위 안에서 재현된다. foundation의 가로 focus 값 보정 뒤 재캡처로 재검수하면 된다.
