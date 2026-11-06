# ui_kit 1.1.0 전환 독립 검수 1회차

- 검수자: 독립 검수 에이전트 1(구현자와 다른 에이전트)
- 후보 SHA: 921732833c15372286820840a26a2fc74c1d09d8 (브랜치 feat/ui-kit-1-1-0)
- 크기: 568x320 (가로, CI 크기)
- 실행 시각: 2026-11-06 02:33~02:40 UTC (journey.json 생성 02:40:33 UTC)
- 실행 환경: dev headless + 렌더링 캡처 (Godot 4.7.2-stable, `--audio-driver Dummy`, mode rendered)
- 격리 저장: 여정이 만든 임시 저장 `user://e2e-game-414220` (종료 시 여정이 삭제), 격리 worktree `scratchpad/qa-wt-1`
- 설계: docs/design/2026-11-06-ui-kit-1-1-0/design.md (AC-1~AC-7)

## 검수 계획

1. 정적 검증: `bundle.py verify`로 잠금 1.1.0과 source.commit `06f2519…` 확인(AC-1), `ui_gate.py` 8항목 PASS 확인(AC-2), `godot/game/`에 `StyleBoxFlat`이 없는지 grep(AC-5).
2. 실행 검증: `check.py --capture --size 568x320`으로 여정 전체 실행. 통과 기준은 출력 JSON `ok: true`, journey.json의 모든 시나리오 `passed`와 단계 실패 0, ui-kit.json과 ui-contract.json의 failures 0(AC-3, AC-4).
3. UX 검증: 캡처 24장을 하나씩 보고, 서체 역할 분리(디스플레이 Fredoka/Jua, 본문 Noto Sans), 버튼과 패널의 9분할 스킨과 이음매, 팝업 딤과 프레임, 보상 충격·정착 프레임, 재화 칩, 글자 잘림·겹침·넘침, 한국어와 큰 글자 가독성, 키보드 초점 가시성, 가로 568x320 레이아웃 붕괴를 확인. 의심 구간은 PIL로 3~6배 확대해 픽셀 단위로 확인.
4. 결함은 재현 상태와 틀린 내용을 적고, ui_kit과 무관한 기존 문제는 분리한다. 설계의 AC-7 기준은 "기능·UX 모두 통과"이므로 ui_kit 범위의 시각 결함이 하나라도 확인되면 fail로 판정한다.

## 실행 명령과 결과

| 명령 | 결과 |
|---|---|
| `git worktree add scratchpad/qa-wt-1 9217328…` | detached HEAD 9217328 |
| `godot --headless --path godot --import --quit-after 2` | exit 0 |
| `python3 tools/check.py --capture --size 568x320 --out build/qa-round-1` | `{"ok": true, "sourceSha": "9217328…", "scenarios": 8}`, exit 0, Godot 로그 15개 모두 오류 없음 |
| `python3 tools/bundle.py verify` | `{"ok": true, "version": "1.1.0", "source.commit": "06f2519f232f1d6332bfca39cf2fb05262f615d1", "files": 82}` |
| `ui_gate.py --root . --project godot` | 8항목 전부 PASS: display_font, painted_skin, popup_motion, button_sfx, reward_ceremony, particles, hud_layers, currency_chip |
| `grep -rn StyleBoxFlat godot/game/` | 없음 |
| build/qa-round-1/ui-kit.json | 40검사 통과, failures 0 (서체 역할 분리, 9분할 StyleBoxTexture, 팝업 모션·reduced, 보상 단계 순서·파티클·스킵) |
| build/qa-round-1/ui-contract.json | 87검사 통과, failures 0 |

캡처: 16장 + platform/ 8장, 전부 568x320. 사본은 `scratchpad/qa-round-1-captures/`.

## 기능 결과

| 시나리오 | 기능 태그 | 상태 |
|---|---|---|
| offline-first-play-restart | startup, tutorial, account_save, inbox, commerce, operations, observability, ui_leaderboard, ui_kit | passed (17단계, 실패 0) |
| settings-language-support-focus | settings_support, account_save, ui_support_entry, ui_analytics_opt_out, ui_locale_offline, ui_navigation | passed (14단계, 실패 0) |
| three-home-profiles | startup, tutorial, account_save, ui_navigation | passed (12단계, 실패 0) — 증거 범위 문제는 결함 D4 참고 |
| real-bootstrap-account-and-cloud | startup, account_save, platform_end_to_end, ui_landscape | passed (9단계) |
| actual-round-cloud-save | tutorial, account_save, platform_end_to_end | passed (7단계) |
| inbox-wallet-and-store | inbox, commerce, platform_end_to_end | passed (8단계) |
| ad-server-receipt-and-optout | observability, operations, platform_end_to_end | passed (11단계) |
| link-logout-recover-and-delete | account_save, platform_end_to_end, settings_support | passed (11단계) |

보상 흐름: `persisted reward` coins 10, 단계 impact → settle → done 순서로 통과, `reward restored` 재실행 뒤 10 유지(AC-4 기능 측면 충족).

## UX 결과

| 화면 | 확인 항목 | 결과 |
|---|---|---|
| title | 디스플레이 서체(제목·헤드라인·버튼)와 본문 서체(상태 문구) 분리, 주 버튼 9분할 노란 스킨, 하단 6개 보조 버튼 스킨과 아이콘, 이음매 | 통과. 서체 분리와 스킨 이음매 깨짐 없음 |
| title / home HUD | 재화 칩 | 미충족. 좌상단 "★ 0"은 칩 스킨 없는 흰 글자(결함 D3) |
| tutorial | 패널 프레임, ★ 버튼 스킨, 진행 점, 본문 가독성 | 프레임·버튼 정상. "Skip guide" 버튼이 프레임 하단 테두리에 잘림(결함 D2) |
| reward-impact | 플래시, 파티클, 코인 등장 | 노란 플래시와 코인 등장 확인. 파티클은 플래시에 가려 희미하나 settle 프레임에서 확인됨. "coins" 라벨이 프레임 아래 화면 밖으로 밀려 잘림(결함 D1) |
| reward-settle | 코인, +10 카운트, 파티클 | 코인·"+10" 숫자 서체·반짝임 파티클 확인. "coins" 라벨은 프레임 밖 어두운 배경 위에서 화면 하단에 잘림(결함 D1) |
| result | 결과 팝업, Continue 주 버튼, 연출 종료 후 잔상 없음 | 통과 |
| home | Play 주 버튼 PrimaryButton 스킨, 재화 "★ 10" 갱신 | 버튼 통과. 재화 칩은 D3와 동일 |
| popup-open | 딤과 프레임 pop_in 중간 프레임(프레임 축소·내용 페이드) | 통과. 딤과 프레임이 보임 |
| inbox | 프레임, 보조 버튼 2개, 목록 본문 | 버튼·서체 통과. "+5 coins" 글자가 프레임 하단 금색 테두리 위에 겹쳐 그려짐(결함 D2) |
| settings | 토글 행 패널 스킨, 설명 본문 | 통과. 글자 잘림 없음(스크롤된 상태) |
| support | 코드 입력 상자, 비활성 Copy code 스킨, 안내 문구 | 통과. 비활성 스킨 구분됨 |
| korean | 한국어 디스플레이 서체(Jua) 제목, 본문 Noto Sans KR, 체크 표시 | 통과. 가독성 양호 |
| large-text | 큰 글자 배율에서 토글 행과 제목 | 통과. 넘침 없음 |
| keyboard-focus | 지원코드 버튼 초점 링 | 통과. 초점 테두리가 버튼 스킨 위에 보임 |
| hero / map / world | 프로필별 홈 구성 | 세 장이 바이트 단위로 동일(md5 af3a23b3…). 가로에서는 `_camp_home`이 프로필을 무시하므로 템플릿 `home.gd`(DisplayLabel·PrimaryButton ▶)가 어떤 캡처에도 나오지 않음(결함 D4) |
| platform/signed-out-camp, connected-camp, maintenance-reason | 캠프 홈 상태 문구, 재화 표시, 긴 헤드라인 줄바꿈 | 통과. "Service maintenance, try again later." 두 줄 줄바꿈 정상. 재화 칩은 D3와 동일 |
| platform/server-identifiers | 코드 상자(모노 서체), Copy code 주 버튼, "Code copied" 상태 | 통과 |
| platform/server-mail-received | 비활성 Claim all 버튼, 목록 | "starter_test_ticket_1 ×1" 줄이 프레임 하단에 걸침(결함 D2) |
| platform/localized-store | 상품 카드 2개 스킨, 가격 | 통과 |
| platform/server-ad-confirmed | 주 버튼·비활성 보조 버튼 | "Check server confirmation" 버튼이 프레임 하단에 잘림(결함 D2) |
| platform/deletion-status | 계정 팝업 2열 버튼 | 하단 버튼 행이 프레임 하단에 잘림(결함 D2) |

## 결함

### D1. 가로 568x320 보상 연출에서 "coins" 라벨이 팝업 프레임 밖 화면 하단에 잘린다 (ui_kit, 기반 코드)

- 상태: 예제 라운드에서 Collect +10 뒤 결과 팝업, ceremony phase impact·settle.
- 틀린 것: `outgame_main.gd` 817행이 가로에서 연출 중심을 `Vector2(0.5, 0.86)`으로 두어 코인은 y≈235, "+10"은 y≈285에 놓이지만 카드의 "coins" 라벨은 y≈300 이후로 밀려 팝업 프레임(하단 테두리 y≈296~302) 밖의 어두운 배경 위에 그려지고 화면 하단(320)에서 잘린다. reward-impact.png·reward-settle.png 하단에서 글자 일부만 보인다.
- 기대: 설계 AC-4 "코인·+10 카운트" 정착 프레임에 라벨까지 프레임 안에 보인다.
- 원인 위치: `godot/addons/seorilabs_game/flow/outgame_main.gd` `_draw_result` (공통 묶음 1.1.0, game-foundation 06f2519). 템플릿이 아니라 기반 수정 또는 템플릿의 focus 보정이 필요하다.

### D2. 팝업 내용이 프레임 하단 테두리와 겹치거나 테두리에서 잘린다 (ui_kit 전환으로 드러난 문제)

- 상태: 내용이 세로로 넘치는 모든 팝업. 568x320에서 tutorial(Skip guide 버튼), inbox(+5 coins), platform/server-mail-received(×1 줄), platform/server-ad-confirmed(Check server confirmation 버튼), platform/deletion-status(하단 버튼 행).
- 틀린 것: `backing`은 상하 12px 안쪽(y 12~308)에 그려지고 9분할 `ui_popup_frame.svg`의 금색 하단 테두리는 y≈296~302에 칠해지는데, 내용 `_content_margin`의 하단 여백은 `16*_ui_scale()`(y≈304)이라 스크롤 내용이 테두리 위를 지나간다. 6배 확대에서 "+5 coins" 글자가 금색 테두리 위에 겹치고 글자 하단이 테두리 선에서 잘린다. "Skip guide"는 버튼 아래 절반이 테두리에서 끊긴다.
- 기대: 스크롤 영역이 프레임의 칠해진 테두리 안쪽에서 끝나고 글자가 테두리와 겹치지 않는다.
- 분류: 1.0.0의 `StyleBoxFlat` 얇은 테두리에서는 겹침이 드러나지 않았고 9분할 프레임의 두꺼운 테두리로 드러났다. main 재캡처는 하지 않았으므로 1.0.0에서의 정확한 모습은 확인하지 않았다. 원인 위치는 기반 `outgame_main.gd` 150~160행·277행의 여백 값과 `skin.json` popup_frame content 여백.

### D3. 가로 타이틀·홈 HUD에 재화 칩이 없다 (ui_kit, 기반 코드)

- 상태: 568x320 title.png, home.png, hero/map/world.png, platform/*-camp.png.
- 틀린 것: 설계 표 "타이틀·홈: 테마 스킨, 재화 칩, HUD 층, 디스플레이 서체"와 달리 좌상단 "★ 0"/"★ 10"은 `camp_home.gd` 24행의 평문 라벨이다. `CurrencyChip`(`ui_chip.svg` 스킨, 카운트업, fly_target)은 `_compact_home`·`_home`(세로 경로)에서만 붙는다. 그래서 보상 정착 단계도 target 없이(`present(..., null, null, ...)`) 날아가기 없이 끝난다.
- 기대: 가로 캠프 홈에도 재화 칩이 붙고 보상이 칩으로 날아간다. `ui_gate.py` currency_chip PASS는 구조 검사라 이 차이를 잡지 못한다.
- 원인 위치: 기반 `godot/addons/seorilabs_game/ui/camp_home.gd`.

### D4. three-home-profiles 캡처 3장이 동일하고 AC-5 검사가 템플릿 `home.gd`를 검증하지 않는다 (검수 증거 결함, 일부 기존 문제)

- 상태: 568x320 three-home-profiles 시나리오. hero.png, map.png, world.png md5 동일.
- 틀린 것: `outgame_main.gd` `_home()`은 `landscape`면 프로필과 무관하게 `_camp_home(false)`를 그린다. 그래서 이번 전환으로 바꾼 `godot/game/features/home/home.gd`(DisplayLabel 라벨, PrimaryButton ▶)는 568x320 어느 캡처에도 나오지 않고, 새로 추가된 단계 `"<profile> play is primary skin"`은 기반 `camp_home`의 "play" 버튼을 검사한다. AC-5의 여정 증거가 템플릿 화면을 포함하지 않는다.
- 분류: 가로에서 프로필을 무시하는 동작은 1.0.0 main에도 있었을 것으로 보이나(camp_home 경로 자체는 전환 전부터 존재) 이번 회차에서 main 재실행은 하지 않았다. 이번 PR이 추가한 검사 단계의 증거 범위는 이번 변경의 문제다. 1024x600(2회차)도 `landscape`가 true라 같은 경로로 추정되므로 세로 경로가 없는 한 `home.gd` 변경은 어떤 검수 회차에서도 렌더링되지 않는다.

### 기존 문제(ui_kit 무관, 설계가 이미 분리한 것)

- 세로 창 `collect reward` 실패, 가로 667x375 등 `platform_journey` 삭제 상태 버튼 실패는 설계 v2대로 이번 회차 크기에서 재현 대상이 아니며 568x320에서는 발생하지 않았다.

## 판정

fail. 기능 시나리오 8개와 정적 게이트는 모두 통과했지만, 568x320 캡처에서 보상 라벨 잘림(D1), 팝업 내용과 프레임 테두리 겹침(D2), 가로 홈의 재화 칩 부재(D3)가 설계가 요구한 화면 상태와 다르게 확인되었고 AC-5 증거가 템플릿 화면을 덮지 않는다(D4).
