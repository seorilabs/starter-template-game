# ui_kit 1.1.0 전환 독립 검수 5회차(새 후보 2회차)

- 검수자: 독립 검수 에이전트 5(구현자, 1~4회차 검수자와 다른 에이전트)
- 후보 SHA: `3ccc4a18c8d4fa684f2513c1bf3ac256fc74ea6f` (브랜치 `feat/ui-kit-1-1-0`, 이전 후보 `9217328` 위에 foundation #13 묶음 `bc21978` 설치)
- 크기: 1024x600(가로, 태블릿급)
- 실행 시각(UTC): 2026-11-06T04:27:20Z 시작, 2026-11-06T04:32:01Z 보고 기록
- 실행 환경: 개발 환경 headless E2E + 렌더링 캡처(Godot 4.7.2.stable, `--audio-driver Dummy`), 격리 worktree `scratchpad/qa-wt-5`(분리 HEAD, 작업 트리 깨끗함)
- 격리 저장: 여정이 만드는 임시 저장 `user://e2e-game-<usec>/`(여정 종료 시 삭제). 사용자 저장 영향 없음
- 캡처 사본: 검수 worktree `build/qa-round-5`(원본은 NAS 이관, 위치는 PR 본문)

## 검수 계획

설계 `docs/design/2026-11-06-ui-kit-1-1-0/design.md`(AC-1~AC-7)와 1·2·3회차 기록을 먼저 읽고, 이전 후보와의 diff(`git diff 9217328 3ccc4a1`)로 이번 후보가 바꾼 것(foundation `outgame_main.gd` 여백·skin_dir·칩, `reward_ceremony.gd` 열 높이 보정, `camp_home.gd` 재화 칩, `ui_kit_probe.gd` 320px 검사, 여정 단계 이름, 설계 문구)을 파악한 뒤 아래 순서로 본다.

1. 이전 결함 재확인(실패 시나리오 기준). (1) 2회차 결함 1·1회차 D1·3회차 D-1: 1024x600 `reward-settle.png`에서 "coins" 라벨 글자 전체가 y<600 안에 있고 마지막 행 599에 글자 픽셀이 없어야 한다(픽셀 스캔). `reward-impact.png`·`result.png`도 같은 위치를 본다. (2) 1회차 D2: 세로로 넘치는 팝업(tutorial, inbox, server-mail-received, server-ad-confirmed, deletion-status)의 스크롤 내용이 9분할 프레임 금색 테두리 안에서 끝나야 한다(하단 테두리 띠 픽셀 스캔). (3) 1회차 D3: title·home·hero/map/world·platform/*-camp의 재화가 평문 "★ N"이 아니라 칩 스킨(아이콘+숫자)이어야 한다. (4) 3회차 D-2: 여정 단계 이름이 실제 검사 대상(캠프 홈 play)과 일치해야 한다.
2. 정적 조건: 잠금 1.1.0과 `source.commit` bc21978, 프로필 `uiStandard.version` 1.1.0, `godot/game/` `StyleBoxFlat` 0건, `bundle.py verify` 통과(AC-1, AC-5).
3. 자동 실행: `check.py --capture --size 1024x600` `ok: true`, 시나리오 8개 전부 passed, 단계 실패 0, `ui-kit.json`·`ui-contract.json` 실패 0(새 320px 열 검사 포함), `unittest discover` 통과, `check_architecture.py` 통과(AC-3, AC-4, AC-6).
4. 화면 검수: `build/qa-round-5`의 PNG 전부(platform/ 포함)를 하나씩 본다. 큰 화면에서 9분할 스킨 모서리·띠 늘림 왜곡, 버튼 간격과 빈 공간, 디스플레이·본문 서체 역할, 팝업 프레임 중앙 정렬과 딤, 보상 3프레임, 재화 칩, 글자 잘림·겹침, 한국어·큰 글자, 키보드 초점을 본다.
5. 결함은 재현 상태와 틀린 내용, 코드 위치로 적고 취향·추측은 뺀다. ui_kit과 무관한 기존 문제는 분리한다.

## 실행 명령과 결과

| 명령 | 결과 |
|---|---|
| `git worktree add scratchpad/qa-wt-5 3ccc4a18…` | 분리 HEAD, 작업 트리 깨끗함 |
| `godot --headless --path godot --import --quit-after 2` | 종료 코드 0 |
| `python3 tools/check.py --capture --size 1024x600 --out build/qa-round-5` | 종료 코드 0, 출력 `{"ok": true, "sourceSha": "3ccc4a18…", "scenarios": 8}`, 28초(04:27:20Z~04:27:48Z) |
| `build/qa-round-5/journey.json` | mode rendered, viewport [1024, 600], 시나리오 8개 모두 passed, 실패 단계 0 |
| `build/qa-round-5/ui-kit.json` | passed true, 검사 42개 실패 0. 새로 추가된 `reward motion/reduced: low focus keeps the column on a 320px screen (column end 312)` 2건 통과 |
| `build/qa-round-5/ui-contract.json` | passed true, 검사 87개 실패 0 |
| `python3 -m unittest discover -s tools -p 'test_*.py'` | 23 tests OK (4.3초) |
| `python3 tools/check_architecture.py` | Architecture passed |
| `python3 tools/bundle.py verify` | ok, version 1.1.0, source.commit `bc21978f4f5a4ea0d3cdd0ff4be516fbc43a0fa2`, files 82 |
| `grep -rn StyleBoxFlat godot/game/` | 0건 |
| `godot/data/outgame/outgame-profile.json` | `uiStandard.version` 1.1.0 |
| `git diff 9217328 3ccc4a1 --stat` | 11개 파일. 묶음 4개(`outgame_main.gd`, `camp_home.gd`, `reward_ceremony.gd`, `ui_kit_probe.gd`)와 잠금, 여정 단계 이름, 설계 문구, gate-report, 검수 기록 1~3회차 |

## 이전 결함 재확인

| 이전 결함 | 이번 확인 방법 | 결과 |
|---|---|---|
| 2회차 결함 1, 1회차 D1, 3회차 D-1: 보상 정착 프레임 "coins" 라벨이 뷰포트 하단에 잘림 | `reward-settle.png`·`reward-impact.png`·`result.png`의 x 412~612 열을 픽셀 스캔. 밝은(글자·카드) 픽셀 마지막 행이 581이고 582~599 행은 밝은 픽셀 0. 4배 확대 크롭으로 "coins" 다섯 글자의 외곽선 하단이 모두 보이는 것을 눈으로 확인 | 해소. 라벨 전체가 뷰포트 안에 있고 글자 손실 없음. 코드는 `reward_ceremony.gd` `present()`가 열 최소 높이+16px가 화면 아래로 넘치면 `Stage.offset_top`을 끌어올린다(1024x600에서 코인 y≈395~455, "+10" y≈470~500, "coins" y≈535~581). 잔여 관찰은 결함 R-1 참고 |
| 1회차 D2: 팝업 내용이 프레임 하단 테두리와 겹침 | `tutorial.png`·`inbox.png`·`platform/server-mail-received.png`·`platform/server-ad-confirmed.png`·`platform/deletion-status.png` 하단을 4배 확대. 스크롤 클립이 y≈566~568에서 끝나고 프레임 금색 테두리는 y≈575~584에서 시작해 글자가 테두리 위에 올라가지 않음 | 해소. `outgame_main.gd` `_clear`가 여백을 `max(16*scale, 12 + 프레임 content 여백 22)`=34px로 두어 내용 영역이 칠해진 테두리 안쪽에서 끝난다 |
| 1회차 D3: 가로 타이틀·홈 재화가 평문 "★ N" | `title.png`(0)·`home.png`(10)·`hero/map/world.png`·`platform/signed-out-camp.png`·`platform/connected-camp.png`·`platform/maintenance-reason.png` 좌상단을 6배 확대 | 해소. 어두운 알약 스킨(`ui_chip.svg`) 안에 코인 아이콘과 숫자가 나란히 있는 칩이다. 상점이 있는 연결 상태에서는 (+) 버튼까지 붙는다(`camp_home.gd`가 `_currency_chip`을 쓴다) |
| 3회차 D-2: 여정 단계 이름 `play is primary skin`이 템플릿 `home.gd`를 검사하는 것처럼 읽힘 | `journey.json` 단계 이름과 설계 AC-5 문구 | 해소. 단계 이름이 `<profile> home play action is primary skin`으로 바뀌고 AC-5가 "가로 캠프 홈 `play`"와 "템플릿 `home.gd`의 ▶는 세로 프로필 전용 경로라 정적으로만 확인"으로 고쳐졌다. hero·map·world 캡처는 여전히 md5 동일(기존 관찰, 아래 참고) |
| 3회차 D-3·D-4: 설계 문구(딤, 카운트업) | 설계 v2 표 | 해소. "딤은 `popup_base` 팝업에만", "counter·target 없이 호출해 카운트업·비행은 없고 +10 카드" 문구로 고쳐졌다 |

## 기능 결과

`build/qa-round-5/journey.json`(platform 여정 5건 합침). 시나리오별 단계 실패 0.

| 시나리오 | 기능 | status | 단계 |
|---|---|---|---|
| offline-first-play-restart | startup, tutorial, account_save, inbox, commerce, operations, observability, ui_leaderboard, ui_kit | passed | 17. `persisted reward` 10, `reward ceremony impact`→`settle`→`finished`, `reward restored` 10(AC-4) |
| settings-language-support-focus | settings_support, account_save, ui_support_entry, ui_analytics_opt_out, ui_locale_offline, ui_navigation | passed | 14 |
| three-home-profiles | startup, tutorial, account_save, ui_navigation | passed | 12. `hero/map/world home play action is primary skin` 3건(AC-5) |
| real-bootstrap-account-and-cloud | startup, account_save, platform_end_to_end, ui_landscape | passed | 9. `create via primary button` |
| actual-round-cloud-save | tutorial, account_save, platform_end_to_end | passed | 7 |
| inbox-wallet-and-store | inbox, commerce, platform_end_to_end | passed | 8 |
| ad-server-receipt-and-optout | observability, operations, platform_end_to_end | passed | 11 |
| link-logout-recover-and-delete | account_save, platform_end_to_end, settings_support | passed | 11 |

AC-1(잠금·verify·unittest), AC-2(gate-report 8 PASS, 정적 보고 확인), AC-3(`check.py` 여정·probe, unittest), AC-4, AC-5, AC-6(`test_init_game` 포함 23 tests OK) 모두 통과. AC-7은 이 회차가 1024x600 분량이다.

## UX 결과

캡처 24장(여정 16장, platform 8장) 모두 봤다.

| 화면 | 확인 항목 | 결과 |
|---|---|---|
| title.png | 캠프 배경, 디스플레이 서체 제목·"A new adventure begins", 본문 서체 보조 문구, 재화 칩(코인 아이콘+0), 상단 HUD 버튼 2개와 하단 6버튼 간격 균등(버튼 폭 ≈145px, 간격 ≈18px), 9분할 버튼 모서리·띠 왜곡 없음 | 통과 |
| tutorial.png | 팝업 프레임 중앙 정렬, 모서리 장식 4개, ★ 큰 버튼(950x160) 스킨 늘림에 줄무늬 없음, "Skip guide"는 스크롤 영역 아래 잘림이며 스크롤바 표시, 테두리 침범 없음 | 통과 |
| reward-impact.png | 전체 노란 플래시, 코인·"+10"·"coins" 카드 펀치 인 중, 파티클 점 | 통과 |
| reward-settle.png | 코인 64px, "+10", "coins" 전부 노출, 파티클, 하단 잘림 없음 | 통과(R-1 관찰) |
| result.png | "Expedition complete", "+10 coins", Continue 주 버튼(금색), 연출 퇴장 잔상이 하단 띠 안에서 페이드 | 통과 |
| home.png | 칩 10으로 갱신, Play 주 버튼, 비활성 Shop·Ad reward·Operations 회색 변형 | 통과 |
| popup-open.png | 우편 프레임이 축소·반투명으로 커지는 중, 중앙 정렬 | 통과 |
| inbox.png | Claim all·Grant history 버튼, 본문 서체, "+5 coins"와 다음 항목이 테두리 안쪽에서 클립 | 통과 |
| settings.png | 토글 행 스킨(켜짐 녹색), 안내 두 줄, 스크롤 위치상 첫 행 일부·마지막 버튼 일부가 보이는 건 스크롤 | 통과 |
| support.png | 제목 디스플레이 서체, 입력 상자 "—", 비활성 Copy code | 통과 |
| korean.png | "언어" 한국어 디스플레이 서체, 버튼 3개 한글 본문 서체, "✓ 한국어" | 통과 |
| large-text.png | "접근성", "큰 글자"·"움직임 줄이기" 확대 토글 잘림·겹침 없음 | 통과 |
| keyboard-focus.png | "지원코드" 버튼 진한 초점 외곽선, 상단 글줄은 스크롤 위치 | 통과 |
| hero.png, map.png, world.png | 세 장 md5 동일(`5b85bc50…`), 칩 0, Play 주 버튼 | 통과(기존 관찰) |
| platform/signed-out-camp.png | "Create account" 주 버튼, 칩 "★ 0 🎟 —", 비활성 Shop | 통과(R-2 관찰) |
| platform/connected-camp.png | "Account connected", 칩 "★ 10 🎟 0" + (+) 버튼, Shop 활성 | 통과(R-2 관찰) |
| platform/maintenance-reason.png | "Service maintenance, try again later." 디스플레이 서체, 칩 티켓 2 | 통과 |
| platform/deletion-status.png | "Deletion request: completed", 2열 버튼 그리드 간격 균등 | 통과 |
| platform/localized-store.png | 상품 2개 이름·가격 2줄, 빈 공간은 목록 끝 | 통과 |
| platform/server-ad-confirmed.png | 안내 두 줄, "Confirmed test views: 1", Watch test ad 주 버튼, 아래 버튼은 스크롤 영역, 테두리 침범 없음 | 통과 |
| platform/server-identifiers.png | STRT-TEST 숫자 서체, Copy code 주 버튼, "Code copied" | 통과 |
| platform/server-mail-received.png | 비활성 Claim all, "starter_test_ticket_1 ×1", 테두리 침범 없음 | 통과 |

큰 화면(1024x600)에서 9분할 스킨은 버튼·프레임·칩 모두 모서리 반경이 유지되고 가운데 띠에 줄무늬나 늘어난 장식이 없다.

## 결함

판정을 바꾸는 결함은 없다. 아래는 재현 가능한 낮은 심각도 관찰이다.

- R-1 (낮음, 기반 묶음 `ui_kit/reward_ceremony.gd` 범위): 1024x600 정착 프레임에서 "coins" 글자 외곽선 하단(y≈579~581)이 결과 팝업 프레임의 금색 하단 테두리(y≈575~584) 위에 약 5px 올라탄다. 보정이 뷰포트 하단 기준 8px 여유만 두기 때문이다(`needed = 열 높이 + 16`). 글자는 외곽선 서체라 테두리 위에서도 전부 읽히고 손실이 없어 2회차 결함 1의 실패 조건(글자 손실)에는 해당하지 않는다. 테두리와 겹치지 않게 하려면 기반에서 여유를 프레임 content 여백만큼(≈34px) 두거나 wide focus를 0.86보다 낮추면 된다. `reward-impact.png`·`result.png`도 같은 위치다.
- R-2 (낮음, 템플릿 `godot/game/adapters/platform_runtime.gd:63-65` 범위): 플랫폼 연결 캠프 홈의 재화 칩이 코인 아이콘 뒤에 다시 "★ 10"을 적어 코인 표식이 두 번 보인다(`platform/connected-camp.png` 등 4장). `resource_provider`가 기준 커밋부터 "★ %d    🎟 %s" 문자열을 돌려주고, 이번 묶음의 `camp_home.gd`가 그 문자열을 아이콘 있는 칩에 그대로 넣어 드러났다. 문자열에서 "★ "을 빼거나 구조화된 값을 돌려주면 된다. 흐름·값에는 영향 없다.

ui_kit과 무관한 기존 관찰(기준 42e1536에도 있음, 판정에 넣지 않음): 가로에서 `home_profile`이 hero·map·world여도 `_camp_home`이 같은 화면을 그려 템플릿 `home.gd`가 렌더링되지 않는다(hero/map/world md5 동일). 설정 화면의 첫 토글 행과 마지막 버튼이 스크롤 위치상 일부만 보인다.

## 판정

pass — 자동 검사(여정 8개, ui-kit 42개, ui-contract 87개, unittest 23개, 아키텍처, bundle verify bc21978)가 모두 통과했고, 1024x600 캡처에서 2회차 fail 사유였던 "coins" 라벨 잘림이 픽셀 스캔(마지막 글자 행 581, 582~599 비어 있음)으로 해소됐으며 팝업 내용의 테두리 침범과 평문 재화도 해소됐다. 남은 관찰 R-1·R-2는 글자 손실·기능 영향이 없는 낮은 심각도다.
