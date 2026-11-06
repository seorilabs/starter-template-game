# ui_kit 1.1.0 전환 독립 검수 4회차(새 후보 1회차)

- 검수자: 독립 검수 에이전트 4(구현자, 1~3회차 검수자와 다른 에이전트)
- 후보 SHA: `3ccc4a18c8d4fa684f2513c1bf3ac256fc74ea6f` (브랜치 `feat/ui-kit-1-1-0`, 이전 후보 `9217328` 위에 공통 묶음 bc21978 설치)
- 크기: 568x320
- 실행 시각(UTC): 2026-11-06T04:27:18Z 시작, 04:27:47Z `check.py` 종료
- 실행 환경: 개발 환경 dev headless + 렌더링 캡처(Godot 4.7.2-stable, `--audio-driver Dummy`), 격리 worktree `scratchpad/qa-wt-4`
- 격리 저장: 여정이 만드는 임시 `user://e2e-game-<usec>/`(여정이 끝에서 삭제). 사용자 저장 영향 없음
- 캡처 사본: 검수 worktree `build/qa-round-4`(원본은 NAS 이관, 위치는 PR 본문)(PNG 24장, journey·ui-kit·ui-contract·automated JSON, godot 로그)

## 검수 계획

1. 설계 AC-1~AC-7과 1~3회차 기록을 읽고, 이번 회차의 통과 기준을 (a) 이전 결함 3건 해소, (b) 자동 검사(여정 8개·ui_kit probe·계약 probe·bundle verify·ui_gate 8항목) 전부 통과, (c) 캡처 24장에서 글자 잘림·겹침·넘침, 서체 역할 분리, 스킨 이음매, 팝업 프레임, 보상 충격·정착 프레임, 한국어·큰 글자, 키보드 초점에 새 결함이 없음으로 정한다.
2. 후보 SHA를 격리 worktree에 올리고 `godot --import` 뒤 `check.py --capture --size 568x320`을 실행해 ok와 시나리오 수를 적는다.
3. `journey.json`의 시나리오·단계 status, `ui-kit.json`·`ui-contract.json`의 failures, `bundle.py verify`의 `source.commit`, `ui_gate.py` 8항목을 대조한다.
4. 이전 후보(9217328)와의 코드 diff를 읽어 고친 범위(`outgame_main.gd` 여백, `camp_home.gd` 칩, `reward_ceremony.gd` 초점 보정, probe 추가)가 결함 3건에 대응하는지 본다.
5. PNG 24장을 하나씩 보고, 의심 지점은 4배 확대 crop과 픽셀 행 측정으로 확인한다.
6. 결함은 실패 시나리오로 적고 취향·추측은 제외한다. ui_kit과 무관한 기존 문제는 분리한다.

## 실행 명령과 결과

| 명령 | 결과 |
|---|---|
| `git worktree add scratchpad/qa-wt-4 3ccc4a1…` | 분리 HEAD, 작업 트리 깨끗함 |
| `godot --headless --path godot --import --quit-after 2` | 종료 코드 0 |
| `python3 tools/check.py --capture --size 568x320 --out build/qa-round-4` | 종료 코드 0, `{"ok": true, "sourceSha": "3ccc4a18…", "scenarios": 8}` |
| `python3 tools/bundle.py verify` | ok, version 1.1.0, source.commit `bc21978f4f5a4ea0d3cdd0ff4be516fbc43a0fa2`, files 82 (AC-1) |
| `python3 ~/.agent/skills/game-ui-commercial/scripts/ui_gate.py --root . --project godot` | display_font, painted_skin, popup_motion, button_sfx, reward_ceremony, particles, hud_layers, currency_chip 8항목 모두 PASS (AC-2) |
| `cd tools && python3 -m unittest test_bundle test_init_game` | 9 tests OK (AC-1, AC-6) |
| `grep -rn StyleBoxFlat godot/game` | 일치 없음 (AC-5) |
| `godot/data/outgame/outgame-profile.json` `uiStandard.version` | 1.1.0, 잠금과 일치 |
| `build/qa-round-4/automated.json` | passed true, checks 17개 모두 true(`ui_kit_probe`, `contract_probe`, `bundle_hashes`, `architecture` 포함) (AC-3 로컬 근거) |

## 이전 결함 재확인

| 이전 결함 | 이번 후보에서 확인한 것 | 결과 |
|---|---|---|
| (1) 보상 연출 "coins" 라벨이 화면 아래로 잘림(1회차 D1, 2회차 1, 3회차 D-1) | `reward-settle.png`에서 코인 아이콘 y 173~226, "+10" y 245~259, "coins" 라벨 y 약 280~303으로 라벨 전체가 320 안에 들어온다. `reward_ceremony.gd` 39~41행이 열 높이+16px가 화면을 넘으면 `Stage.offset_top`을 올리고, probe `low focus keeps the column on a 320px screen (column end 312)`가 일반·reduced 모두 PASS | 해소. 단 열이 올라오면서 코인 아이콘이 Continue 버튼과 겹친다(결함 D-1, 새 결함) |
| (2) 팝업 스크롤 내용이 9분할 프레임 하단 테두리와 겹침(1회차 D2) | `outgame_main.gd` 278~284행이 내용 여백을 `max(16*scale, 12 + 프레임 content 여백)`으로 잡는다. tutorial(★ 버튼 하단 y≈268), inbox("A local example reward…" 하단 y≈282), settings("Collection is currently…" y≈280), support(Copy code 버튼이 y≈288 스크롤 경계에서 잘림), platform/server-mail-received, server-ad-confirmed(Watch test ad 버튼 y≈288 경계), deletion-status(2번째 버튼 행 y≈288 경계) 모두 금색 테두리(y≈296~302) 위에 글자·버튼이 올라오지 않고, 잘림은 스크롤 영역 경계 안에서만 일어난다. 4배 crop으로 확인 | 해소 |
| (3) 타이틀·홈 재화가 평문 "★ 0" 라벨(1회차 D3) | `camp_home.gd` 22~24행이 `_currency_chip`을 붙이고 `_layout`에서 칩을 내용 크기로 둔다. title.png "코인 아이콘 + 0", home.png·hero/map/world.png "코인 아이콘 + 10" 어두운 캡슐 칩. platform/*-camp.png는 플랫폼 resource_provider 문자열(★ 10, 티켓 아이콘 0~2)에 (+) 버튼이 붙은 칩 | 해소 |

## 기능 결과

`build/qa-round-4/journey.json`: mode rendered, viewport [568, 320], Godot 4.7.2-stable. 시나리오 8개 모두 passed, 단계 89개 모두 ok.

| 시나리오 | 기능 ID | status | 단계 | 비고 |
|---|---|---|---|---|
| offline-first-play-restart | startup, tutorial, account_save, inbox, commerce, operations, observability, ui_leaderboard, ui_kit | passed | 17/17 | persisted reward expected 10 actual 10, reward ceremony impact→settle→finished, reward restored |
| settings-language-support-focus | settings_support, account_save, ui_support_entry, ui_analytics_opt_out, ui_locale_offline, ui_navigation | passed | 14/14 | 한국어 선택, 큰 글자, keyboard focus scrolls into view, 재시작 후 유지 |
| three-home-profiles | startup, tutorial, account_save, ui_navigation | passed | 12/12 | 단계 이름이 `home play action is primary skin`으로 바뀜(3회차 D-2 반영). hero·map·world 캡처는 여전히 md5 동일(가로 경로의 기존 동작) |
| real-bootstrap-account-and-cloud | startup, account_save, platform_end_to_end, ui_landscape | passed | 9/9 | |
| actual-round-cloud-save | tutorial, account_save, platform_end_to_end | passed | 7/7 | |
| inbox-wallet-and-store | inbox, commerce, platform_end_to_end | passed | 8/8 | |
| ad-server-receipt-and-optout | observability, operations, platform_end_to_end | passed | 11/11 | |
| link-logout-recover-and-delete | account_save, platform_end_to_end, settings_support | passed | 11/11 | `check deletion status with a button` 568x320에서 통과 |

`ui-kit.json`: passed true, failures 0, 42항목(3회차 40 + 이번에 추가된 `low focus keeps the column on a 320px screen` 일반·reduced 2개). 팝업 모션·reduced, 보상 단계 순서·finished 1회·파티클·skip, 효과음 연결, 칩 서식, HUD 6층, 토스트, 테마 서체 역할·StyleBoxTexture·초점 overlay·skin.json v2·한글 display 서체 모두 PASS.
`ui-contract.json`: passed true, failures 0, 87항목.

## UX 결과

| 화면 | 확인 내용 | 결과 |
|---|---|---|
| title.png | 디스플레이 서체 제목, 재화 칩(코인 아이콘+0), "Begin adventure" PrimaryButton, 하단 6버튼 9분할 스킨 이음매 깨짐 없음 | 통과 |
| home.png / hero·map·world.png | 칩 "10", "Play" PrimaryButton. 네 장 동일 | 통과 |
| tutorial.png | 모달 프레임, "Gather three stars" 디스플레이 서체, ★ 버튼이 테두리 안쪽에서 끝남 | 통과 |
| reward-impact.png | 노란 플래시 덮임, 카드 흐릿하게 등장(충격 프레임) | 통과 |
| reward-settle.png | 플래시 없음, 코인·파티클·"+10"(number 서체)·"coins"(display 서체) 선명. 라벨이 화면 안. 코인 아이콘이 Continue 버튼 하단(y 173~190)과 겹침 | 통과(D-1 참고) |
| result.png | 카드 페이드아웃, Continue PrimaryButton | 통과 |
| popup-open.png | 프레임 확대 중·반투명, 내용 페이드 중(모션 중간 프레임) | 통과 |
| inbox.png | Claim all·Grant history 버튼 스킨, 본문이 테두리 위로 올라오지 않음 | 통과 |
| settings.png | 토글 스킨, 안내문 2줄이 테두리 안쪽에서 끝남 | 통과 |
| support.png | 입력 패널, 비활성 Copy code가 스크롤 경계에서 잘림(테두리와 겹치지 않음) | 통과 |
| korean.png | "언어"는 둥근 한글 디스플레이 서체, 버튼 본문은 NotoSansKR. 넘침 없음 | 통과 |
| large-text.png | "접근성" 제목, 큰 글자 토글 행이 패널 안에 머묾 | 통과 |
| keyboard-focus.png | 큰 글자 설정 화면에서 "지원코드" 버튼에 두꺼운 외곽선 초점 overlay, 스크롤 안에 보임 | 통과 |
| platform/signed-out-camp.png | 칩(★ 0, 티켓 —), "Create account" PrimaryButton | 통과 |
| platform/server-identifiers.png | STRT-TEST, Copy code, "Code copied" | 통과 |
| platform/connected-camp.png | 칩(★ 10, 티켓 0, +). 헤드라인 1줄과 겹치지 않음 | 통과 |
| platform/server-mail-received.png | Claim all 비활성, "Test ticket from the server"가 테두리 안 | 통과 |
| platform/localized-store.png | 상품 카드 2개, 현지 가격 | 통과 |
| platform/server-ad-confirmed.png | 안내 2줄, Watch test ad 버튼이 스크롤 경계에서 잘림(테두리 겹침 없음) | 통과 |
| platform/maintenance-reason.png | 점검 사유가 2줄로 줄바꿈되어 2번째 줄 "later."(y 111~134, x 208~258)가 재화 칩의 (+) 버튼 위에 겹침 | 결함 D-2 |
| platform/deletion-status.png | 삭제 완료 상태, 2x2 버튼 중 하단 행이 스크롤 경계에서 잘림(테두리 겹침 없음) | 통과 |

## 결함

취향·추측은 제외했다. 둘 다 치명도 낮음이며 흐름·저장·입력을 막지 않는다. 둘 다 공통 묶음(bc21978, game-foundation) 범위라 템플릿 PR에서 고칠 수 없다.

- D-1 (ui_kit, 기반 `reward_ceremony.gd`·`outgame_main.gd`, 이번 보정으로 새로 생김): 568x320 결과 화면에서 보상 연출 열이 Continue 버튼을 덮는다. 재현: 새 저장 → 별 3회 → Collect +10 → settle 프레임(`reward-settle.png`). 코인 아이콘(y 173~226)이 Continue 버튼(y≈145~190)의 아래 17px와 겹쳐 "Continue" 글자 하단 가장자리에 닿고, "coins" 라벨 외곽선이 프레임 금색 테두리(y≈296~302) 위에 걸친다. `outgame_main.gd` 822행 주석 "넓은 화면은 … 아래 빈 띠에 연출한다"와 달리 빈 띠가 아니라 버튼 위에 그려진다. ceremony는 `mouse_filter` IGNORE라 버튼 탭은 막히지 않고 약 1.1초 뒤 페이드아웃한다. 기대: 연출 열이 Continue 버튼과 프레임 테두리 사이의 빈 띠 안에 머물거나(높이가 모자라면 아이콘 크기나 간격을 줄임), 결과 버튼 위치를 올린다.
- D-2 (ui_kit, 기반 `camp_home.gd`, 재화 칩 도입으로 새로 생김): 가로 캠프 홈에서 헤드라인이 2줄로 줄바꿈되면 2번째 줄이 재화 칩과 겹친다. 재현: 플랫폼 여정 `late maintenance blocks play`(`platform/maintenance-reason.png`), resource_provider가 "★ 10 · 티켓 2"를 돌려주고 상점이 있어 (+) 버튼이 붙은 상태. 칩이 내용 크기(`node.size = Vector2.ZERO`)로 커져 화면 x 18~258까지 차지하고, 헤드라인 rect(설계 좌표 x 464~)의 2번째 줄 "later."(x 208~258, y 111~134)가 (+) 버튼(y≈118~165) 위에 그려진다. 이전 후보의 평문 라벨은 x≈178에서 끝나 겹치지 않았다. 기대: 칩 폭이 헤드라인 rect 왼쪽 경계를 넘지 않거나, 헤드라인이 칩 폭만큼 오른쪽에서 시작한다.

ui_kit과 무관한 기존 문제(기준 커밋에도 있음, 판정에 넣지 않음): 가로에서 `home_profile`과 무관하게 `_camp_home`을 그려 hero·map·world 캡처가 동일하고 템플릿 `home.gd`는 정적으로만 확인됨(3회차 D-2, 이번 후보는 단계 이름만 고침), 320px 높이에서 우편·설정·지원 목록의 마지막 항목이 스크롤 경계에서 반만 보임(이제 테두리와는 겹치지 않음), 결과 화면 헤드라인 "+10 coins" 왼쪽 정렬.

## 판정

fail — 이전 결함 3건은 모두 해소됐고 자동 검사(여정 8/8, ui-kit 42/42, ui-contract 87/87, bundle verify bc21978, ui_gate 8/8, unittest 9)도 전부 통과했지만, 이번 묶음의 보정이 568x320 보상 정착 프레임에서 코인 아이콘을 Continue 버튼 위에 올리고(D-1) 재화 칩이 2줄 헤드라인과 겹치는(D-2) 새 겹침 2건이 ui_kit 범위 안에서 재현된다. 둘 다 game-foundation 수정 뒤 재캡처로 재검수하면 된다. 겹침을 경미한 시각 결함으로 보고 후속 이슈로 넘기기로 설계자가 결정하면 pass로 바꿀 수 있는 수준이다.
