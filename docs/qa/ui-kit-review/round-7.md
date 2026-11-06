# ui_kit 1.1.0 전환 독립 검수 7회차(3차 후보 1회차)

- 검수자: 독립 검수 에이전트 7(구현자, 1~6회차 검수자와 다른 에이전트)
- 후보 SHA: `bd3593ac88ee820d842969ea6aa8b69e7c67fa5a` (브랜치 `feat/ui-kit-1-1-0`, 이전 후보 `3ccc4a1` 위에 공통 묶음 `17984c9` 설치)
- 크기: 568x320
- 실행 시각(UTC): 2026-11-06T05:27:06Z import 시작, 05:27:49Z~05:28:48Z `check.py` 실행(59초)
- 실행 환경: 개발 환경 dev headless + 렌더링 캡처(Godot 4.7.2-stable, `--audio-driver Dummy`, macOS, 실행 중 load average 35~47)
- 격리 저장: 여정이 만드는 임시 `user://e2e-game-<usec>/`, `user://platform-journey-<hex>/`(여정이 끝에서 삭제). 사용자 저장과 저장소 파일 수정 없음
- 격리 작업 트리: `qa-wt-7`(검수 후 제거). 캡처 사본: 스크래치 `qa-round-7-captures`(PNG 24장, journey·ui-kit·ui-contract·automated JSON, godot 로그 15개, check 로그)

## 검수 계획

1. 설계 v2 AC-1~AC-7과 4~6회차 기록을 읽고 이번 후보의 변경을 `git diff 3ccc4a1..HEAD`로 확정한다. 확인된 변경: 잠금 `source.commit` 17984c9, `outgame_main.gd` `_draw_result` 가로 2열 분할(왼쪽 버튼 열 3 : 오른쪽 연출 열 2, focus x = 내용 폭 0.8·y 0.55), `reward_ceremony.gd` 열 보정 여유 16→48px, `camp_home.gd` 칩을 자리 폭 370 설계 px에 맞춰 축소, 템플릿 `platform_runtime.gd`의 resource_provider 문자열에서 `★` 제거.
2. 통과 기준을 정한다. (a) 4회차 D-1(코인이 Continue와 겹침)·D-2(칩이 2줄 헤드라인과 겹침) 해소, (b) 1~2회차 결함(coins 잘림, 팝업 내용과 프레임 테두리 겹침, 평문 재화) 유지 해소, (c) 플랫폼 캠프 칩에 ★ 중복 없음, (d) 자동 검사(여정 8개, ui_kit probe, 계약 probe, bundle verify 17984c9, ui_gate 8항목, unittest) 전부 통과, (e) 캡처 24장에서 새 잘림·겹침·넘침 없음.
3. 격리 worktree에서 `godot --import` 뒤 `check.py --capture --size 568x320`을 실행하고 ok·시나리오 수·소요 시간을 적는다. platform_journey가 180초를 넘기면 단독 재실행한다.
4. `journey.json` 시나리오·단계 status, `ui-kit.json`·`ui-contract.json` failures, `bundle.py verify`, `ui_gate.py`를 대조한다.
5. PNG 24장을 하나씩 보고, 의심 지점은 픽셀 좌표(PIL)로 측정한다.
6. 결함은 실패 시나리오로 적고 취향·추측은 제외한다. ui_kit과 무관한 기존 문제는 분리한다.

## 실행 명령과 결과

| 명령 | 결과 |
|---|---|
| `git worktree add qa-wt-7 bd3593a…` | 분리 HEAD, 작업 트리 깨끗함 |
| `godot --headless --path godot --import --quit-after 2` | 종료 코드 0 |
| `python3 tools/check.py --capture --size 568x320 --out build/qa-round-7` | 종료 코드 0, `{"ok": true, "sourceSha": "bd3593ac…", "scenarios": 8}`, 59초. platform_journey 단독 재실행 불필요(timeout 없음) |
| `python3 tools/bundle.py verify` | ok, version 1.1.0, source.commit `17984c9603c10a69498cb2464413b86932437cc9`, files 82 (AC-1) |
| `python3 ~/.agent/skills/game-ui-commercial/scripts/ui_gate.py --root . --project godot` | display_font, painted_skin, popup_motion, button_sfx, reward_ceremony, particles, hud_layers, currency_chip 8항목 모두 PASS (AC-2) |
| `cd tools && python3 -m unittest test_bundle test_init_game` | 9 tests OK (AC-1, AC-6) |
| `grep -rn StyleBoxFlat godot/game` | 0건 (AC-5) |
| `godot/data/outgame/outgame-profile.json` `uiStandard.version` | 1.1.0, 잠금과 일치 |
| `build/qa-round-7/automated.json` | passed true, sourceSha bd3593ac…, checks 17개 모두 true(`ui_kit_probe`, `contract_probe`, `bundle_hashes`, `architecture` 포함) (AC-3 로컬 근거) |

## 이전 결함 재확인

| 이전 결함 | 이번 후보에서 확인한 것 | 결과 |
|---|---|---|
| 4회차 D-1: 568x320 보상 정착 프레임에서 코인 아이콘이 Continue 버튼과 겹침 | `reward-settle.png` 픽셀 측정: Continue 버튼 x 33~322·y 141~188, 코인 원반 x 407~461·y 107~165, "+10"·"coins" 글자 x 395~474·y 179~238. 연출 열이 오른쪽 열(x≥358, 파티클 포함)에 있고 버튼과 x 범위가 겹치지 않는다. 프레임 하단 금색 테두리(y≈297~303)보다 "coins" 하단(238)이 59px 위다. probe `low focus keeps the column on a 320px screen (column end 296)` 일반·reduced PASS | 해소 |
| 4회차 D-2: 플랫폼 캠프 홈에서 2줄 헤드라인이 재화 칩 (+) 버튼과 겹침 | `platform/maintenance-reason.png`: 헤드라인 1줄 "Service maintenance, try again" x 207~484·y 85~102, 2줄 "later." x 207~252·y 113~126. 칩(코인 10, 티켓 2, +)은 축소돼 x 약 16~163·y 95~155에서 끝나 2줄과 x가 44px 이상 떨어진다. `connected-camp.png`도 칩이 x 약 175 안에서 끝나고 헤드라인은 1줄 | 해소 |
| 1회차 D1·2회차 1: "coins" 라벨이 화면 아래로 잘림 | 위 측정대로 "coins" 하단 y 238, 화면 안·프레임 안. `reward-impact.png`에서도 같은 자리에 카드가 흐릿하게 등장 | 유지 해소 |
| 1회차 D2: 팝업 스크롤 내용이 9분할 프레임 하단 테두리와 겹침 | tutorial(★ 버튼 하단 y≈268), inbox(본문 y≈282), settings(안내문 y≈280), support·server-ad-confirmed·deletion-status(버튼이 y≈288 스크롤 경계에서 잘림)에서 글자·버튼이 금색 테두리 위로 올라오지 않음. 잘림은 스크롤 영역 경계 안에서만 일어남 | 유지 해소 |
| 1회차 D3: 타이틀·홈 재화가 평문 "★ 0" 라벨 | title "코인 아이콘 + 0", home·hero·map·world "코인 아이콘 + 10" 캡슐 칩. 플랫폼 캠프는 코인 아이콘 + 숫자 + 티켓 아이콘 + 수량(+ 상점 버튼) 칩 | 유지 해소 |
| ★ 중복 표시(이번 회차 확인 항목) | `platform_runtime.gd`가 `"%d    🎟 %s"`로 바꿔 문자열에 ★가 없고, 칩 아이콘(코인)이 그 앞에 붙는다. signed-out·connected·maintenance 3장 모두 코인 아이콘 1개와 숫자만 보이고 ★ 문자는 없다 | 중복 없음 |

## 기능 결과

`build/qa-round-7/journey.json`: mode rendered, viewport [568, 320], Godot 4.7.2-stable. 시나리오 8개 모두 passed, 단계 89개 모두 ok, 실패 단계 0.

| 시나리오 | status | 단계 | 비고 |
|---|---|---|---|
| offline-first-play-restart | passed | 17 | `collect reward`, `persisted reward` expected 10 actual 10, `reward ceremony impact→settle→finished`, `reward restored`, 캡처 8장 |
| settings-language-support-focus | passed | 14 | 한국어 전환, 큰 글자, 키보드 초점 스크롤, 재시작 뒤 유지 |
| three-home-profiles | passed | 12 | hero·map·world `home play action is primary skin` 모두 ok(AC-5) |
| real-bootstrap-account-and-cloud | passed | 9 | 1차 실행에서 통과(6회차 P-1 재현 없음) |
| actual-round-cloud-save | passed | 7 | |
| inbox-wallet-and-store | passed | 8 | |
| ad-server-receipt-and-optout | passed | 11 | |
| link-logout-recover-and-delete | passed | 11 | `check deletion status with a button` 통과 |

`ui-kit.json`: passed true, failures 0, 42항목 모두 통과(팝업 모션·reduced, 보상 단계 순서·finished 1회·파티클·skip, 낮은 초점 열 끝 296 ≤ 320, 효과음 연결, 칩 서식, HUD 6층, 토스트, 테마 서체 역할·StyleBoxTexture·초점 overlay·skin.json v2·한글 display 서체).
`ui-contract.json`: passed true, failures 0, 87항목.
`platform/journey.json`: 5개 시나리오 모두 passed.

## UX 결과

| 화면 | 확인 내용 | 결과 |
|---|---|---|
| title.png | 디스플레이 서체 제목, 칩(코인+0), "Begin adventure" PrimaryButton, 하단 6버튼 스킨 이음매 깨짐 없음 | 통과 |
| home.png / hero·map·world.png | 칩 "10", "Play" PrimaryButton. 네 장 동일(기존 동작) | 통과 |
| tutorial.png | 모달 프레임, "Gather three stars" 디스플레이 서체, ★ 버튼이 테두리 안쪽에서 끝남 | 통과 |
| reward-impact.png | 노란 플래시, 오른쪽 열에 카드 흐릿하게 등장(충격 프레임) | 통과 |
| reward-settle.png | 왼쪽 열 "+10 coins" 헤드라인·Continue, 오른쪽 열 코인·파티클·"+10"(number 서체)·"coins"(display 서체). 버튼·테두리와 겹침 없음 | 통과 |
| result.png | 카드 페이드아웃 잔상이 오른쪽 열에 머묾, Continue PrimaryButton | 통과 |
| popup-open.png | 프레임 확대 중·반투명, 내용 페이드 중(모션 중간 프레임) | 통과 |
| inbox.png | Claim all·Grant history 버튼 스킨, 본문이 테두리 위로 올라오지 않음 | 통과 |
| settings.png | 토글 스킨, 안내문 2줄이 테두리 안쪽 | 통과 |
| support.png | 입력 패널, 비활성 Copy code가 스크롤 경계에서 잘림(테두리 겹침 없음) | 통과 |
| korean.png | "언어"는 한글 디스플레이 서체, 버튼 본문은 NotoSansKR. 넘침 없음 | 통과 |
| large-text.png | "접근성" 제목, 큰 글자 토글 행이 패널 안 | 통과 |
| keyboard-focus.png | 큰 글자 설정 화면에서 "지원코드" 버튼에 두꺼운 초점 외곽선, 스크롤 안에 보임 | 통과 |
| platform/signed-out-camp.png | 칩(코인 0, 티켓 —), "Create account" PrimaryButton, ★ 없음 | 통과 |
| platform/server-identifiers.png | STRT-TEST, Copy code, "Code copied" | 통과 |
| platform/connected-camp.png | 칩(코인 10, 티켓 0, +)이 x 약 175 안, 헤드라인 1줄과 겹치지 않음, ★ 없음 | 통과 |
| platform/server-mail-received.png | Claim all 비활성, "Test ticket from the server"가 테두리 안 | 통과 |
| platform/localized-store.png | 상품 카드 2개, 현지 가격 | 통과 |
| platform/server-ad-confirmed.png | 안내 2줄, Watch test ad 버튼이 스크롤 경계에서 잘림(테두리 겹침 없음) | 통과 |
| platform/maintenance-reason.png | 2줄 헤드라인 "later."(x 207~)가 축소된 칩(x ~163) 오른쪽에 있어 겹치지 않음, ★ 없음 | 통과 |
| platform/deletion-status.png | 삭제 완료 상태, 2x2 버튼 중 하단 행이 스크롤 경계에서 잘림(테두리 겹침 없음) | 통과 |

## 결함

ui_kit 범위의 새 결함 없음. 취향·추측은 제외했다.

ui_kit과 무관한 기존 문제(기준 커밋에도 있음, 판정에 넣지 않음): 가로에서 `home_profile`과 무관하게 `_camp_home`을 그려 hero·map·world 캡처가 동일하고 템플릿 `home.gd`는 정적으로만 확인됨(3회차 D-2, 설계 AC-5가 그렇게 적음), 320px 높이에서 지원·광고·계정 팝업의 마지막 버튼이 스크롤 경계에서 반만 보임(테두리와는 겹치지 않음), 결과 화면 헤드라인 "+10 coins" 왼쪽 정렬. 참고 관찰(결함 아님): 플랫폼 캠프 칩이 축소되면서 칩 글자가 타이틀·홈 칩보다 작아진다(설계대로 자리 폭 맞춤).

## 판정

pass — 4회차 겹침 2건(D-1 보상 열·Continue, D-2 칩·2줄 헤드라인)이 픽셀 측정으로 해소됐고 1~2회차 결함 3건과 ★ 중복 없음이 유지되며, 자동 검사(여정 8/8·단계 89/89, ui-kit 42/42, ui-contract 87/87, bundle verify 17984c9, ui_gate 8/8, unittest 9)가 전부 통과하고 캡처 24장에서 ui_kit 범위의 새 결함이 없다.
