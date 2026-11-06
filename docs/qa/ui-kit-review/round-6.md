# ui_kit 1.1.0 전환 독립 검수 6회차(새 후보 3회차)

- 검수자: 독립 검수 에이전트 6(구현자, 1~5회차 검수자와 다른 에이전트)
- 후보 SHA: `3ccc4a18c8d4fa684f2513c1bf3ac256fc74ea6f` (브랜치 `feat/ui-kit-1-1-0`, 기준 `42e1536e49eac777f82b42b0484acfc5a920b85b`, 이전 후보 `9217328`)
- 크기: 568x320
- 실행 시각(UTC): 2026-11-06T04:27:18Z 시작(1차 실행), 04:31:40Z~04:32:05Z 2차 실행(최종 근거), 04:33Z 플랫폼 여정 반복 5회 종료
- 실행 환경: 개발 환경 headless + 렌더링 캡처(`--audio-driver Dummy`, Godot 4.7.2-stable, macOS Apple M3, 실행 중 load average 8~10)
- 격리 저장: 여정이 만드는 `user://e2e-game-<usec>/`, `user://platform-journey-<hex>/`(여정이 끝에서 삭제). 사용자 저장과 저장소 파일 수정 없음
- 격리 작업 트리: `scratchpad/qa-wt-6`(검수 후 제거). 캡처 사본: 검수 worktree `build/qa-round-6`(원본은 NAS 이관, 위치는 PR 본문)(최종 실행 24장, `run1-timeout/`에 1차 실행의 부분 산출물)

## 검수 계획

1. 설계 `docs/design/2026-11-06-ui-kit-1-1-0/design.md`(v2) AC-1~AC-7과 3회차 기록 `docs/qa/ui-kit-review/round-3.md`의 D-1~D-4를 읽고, 이번 후보에 들어간 변경(공통 묶음 `bc21978`, 설계 문구, 여정 단계 이름)을 `git diff 9217328...HEAD`로 확정한다.
2. 격리 worktree에 후보 SHA를 올리고 `godot --import` 뒤 `tools/check.py --capture --size 568x320`을 실행해 ok와 시나리오 수를 적는다.
3. `journey.json`의 8개 시나리오 status와 `ui-kit.json` 42항목(팝업 시그널, 보상 단계 순서·finished·skip, 낮은 초점 열 위치, 효과음 연결, reduced_motion)을 대조한다.
4. 기준 커밋 대비 템플릿 diff(`godot/game`, `godot/tests/game`, `tools/`, 기능 목록, 프로필, 설계)를 읽고 D-2·D-3·D-4가 설계에 반영됐는지, `StyleBoxFlat`이 0건인지, 보상 payload `amount`의 연습 모드 값을 확인한다. 묶음 `bc21978`의 변경(`outgame_main.gd` 여백 보정, `camp_home.gd` 재화 칩, `reward_ceremony.gd` 초점 보정, `ui_kit_probe.gd` 낮은 초점 검사)도 읽는다.
5. 캡처 24장을 전부 보고 reward-impact/settle의 "coins" 라벨, korean/large-text의 서체 역할과 넘침, keyboard-focus 초점 테두리, popup-open 중간 프레임, inbox/settings/support/platform 화면의 내용이 프레임 테두리 안인지, title/home의 재화 칩을 확인한다.
6. 결함은 실패 시나리오로 적고 취향·추측은 제외한다. ui_kit과 무관한 기존 문제는 분리한다. AC-1·AC-2·AC-6은 `bundle.py verify`, unittest, gate-report로 보조 확인한다.

## 실행 명령과 결과

| 명령 | 결과 |
|---|---|
| `git worktree add scratchpad/qa-wt-6 3ccc4a1…` | 분리 HEAD, 작업 트리 깨끗함 |
| `godot --headless --path godot --import --quit-after 2` | 종료 코드 0 |
| `python3 tools/check.py --capture --size 568x320 --out build/qa-round-6` (1차, 04:27Z) | 종료 코드 1. 여정·probe는 통과했으나 마지막 `platform_journey.gd`가 180초 timeout. 부분 보고에서 `real-bootstrap-account-and-cloud`의 `real Firebase adapter and SDK session establish a cloud-ready account` 단계 ok=false(아래 기존 문제 P-1) |
| `platform_journey.gd` 단독 재실행(04:31Z) | 종료 코드 0, 9초, 5개 시나리오 모두 passed |
| `python3 tools/check.py --capture --size 568x320 --out build/qa-round-6` (2차, 04:31:40Z~04:32:05Z) | 종료 코드 0, `{"ok": true, "sourceSha": "3ccc4a18…", "scenarios": 8}` |
| `platform_journey.gd` 5회 반복(load average 9~10) | 5/5 passed, 각 8~10초 |
| `python3 tools/bundle.py verify` | ok, version 1.1.0, source.commit `bc21978f4f5a4ea0d3cdd0ff4be516fbc43a0fa2`, files 82 (AC-1) |
| `python3 -m unittest discover -s tools -p 'test_bundle.py'` / `'test_init_game.py'` | 6 tests OK / 3 tests OK (AC-1, AC-6) |
| `docs/game-design/ui/gate-report.json` | 8항목 모두 PASS (AC-2, 정적 보고) |
| `grep -rn StyleBoxFlat godot/game` | 0건 (AC-5) |

최종 근거는 2차 실행 산출물이다. 1차 실행의 PNG 중 여정 16장은 같은 SHA에서 나왔고 2차와 내용이 같다.

## 이전 지적 재확인

| 번호 | 3회차 내용 | 이번 후보 상태 | 근거 |
|---|---|---|---|
| D-1 | 568x320에서 보상 카드 "coins" 라벨이 화면 아래로 잘림 | 고침 | `reward_ceremony.gd` `present()`가 열 최소 높이+16보다 아래면 `$Stage.offset_top`을 끌어올린다. probe `reward motion/reduced: low focus keeps the column on a 320px screen (column end 312)` PASS. reward-settle.png에서 아이콘·"+10"·"coins" 세 줄이 모두 보인다(다만 새 관찰 N-1) |
| D-2 | 여정 단계 이름 `play is primary skin`과 AC-5 "홈 ▶" 문구가 실제 검사 대상(캠프 홈 `play`)과 다름 | 고침 | 단계 이름 `<profile> home play action is primary skin`으로 변경, AC-5를 "홈의 주 행동(가로 캠프 홈 `play`)이 `PrimaryButton` 변형… 템플릿 `home.gd`의 ▶는 세로 프로필 전용 경로라 정적으로만 확인"으로 수정. hero·map·world 3건 모두 ok |
| D-3 | 설계 모달 표의 "딤"이 실제 화면에 없음 | 고침 | 설계 표를 "프레임 `pop_in`·내용 페이드(딤은 `popup_base` 팝업에만 있다)"로 수정. popup-open.png는 설계와 같이 딤 없이 프레임 확대·내용 페이드 중간 프레임 |
| D-4 | AC-4 "코인 10으로 카운트업"이 실행되지 않음 | 고침 | AC-4를 "저장 코인이 10"으로, 보상 행을 "`_draw_result`는 counter·target 없이 호출해 카운트업·비행은 없고 '+10' 카드가 뜬다"로 수정. 코드(`ceremony.present([reward], …, null, null, 0, 0, …)`)와 일치 |

## 기능 결과

`build/qa-round-6/journey.json` mode `rendered`, viewport [568, 320]. 8개 시나리오 모두 passed, 실패 단계 0.

| 시나리오 | status | 단계 수 | 비고 |
|---|---|---|---|
| offline-first-play-restart | passed | 17 | `collect reward`, `persisted reward`(10), `reward ceremony impact`→`settle`→`finished` 순서 ok, `reward restored` ok, 캡처 8장 |
| settings-language-support-focus | passed | 14 | 한국어 전환, 큰 글자, 키보드 초점, 재시작 뒤 유지 |
| three-home-profiles | passed | 12 | hero·map·world 각 `home play action is primary skin` ok |
| real-bootstrap-account-and-cloud | passed | 9 | 2차 실행. 1차 실행은 P-1 |
| actual-round-cloud-save | passed | 7 | |
| inbox-wallet-and-store | passed | 8 | |
| ad-server-receipt-and-optout | passed | 11 | |
| link-logout-recover-and-delete | passed | 11 | 568x320에서 삭제 상태 버튼 통과 |

`build/qa-round-6/ui-kit.json` passed true, failures 0, 42항목 전부 통과.

| 항목 | 결과 |
|---|---|
| 팝업 일반: 딤·프레임 표시, `opened` 1회, 진입 19프레임, 열린 상태 재open 무시, `closed` 뒤 숨김 | PASS |
| 팝업 reduced_motion: 딤·프레임 즉시, `opened` 1회, 2프레임 내 열림(실측 1), 재open 무시, `closed` 뒤 숨김 | PASS |
| 보상 일반·reduced: 단계 순서 `anticipation→impact→settle→done`, `finished` 1회, impact 파티클, skip 1회 종료, skip 뒤 present 유지, 낮은 초점(0.86)에서 열 끝 312 ≤ 320 | PASS |
| 효과음: attach 멱등, 늦게 추가된 버튼 포함 4개 연결, down마다 재생 4, kind 메타 선택, 5개 스트림 로드 | PASS |
| 재화 칩 천 단위·축약·아이콘+숫자+추가 버튼, HUD 6층 순서, 토스트 층·중앙·소멸 | PASS |
| 테마: display·body 분리, number 역할, 버튼·패널 StyleBoxTexture, 초점 overlay, skin.json v2, 한글 display 서체 상이 | PASS |

`automated.json` checks에 `ui_kit_probe: true`, sourceSha `3ccc4a18…`(AC-3 로컬 근거).

## 코드 검토

대상: `git diff 42e1536…HEAD -- godot/game godot/tests/game tools/check.py tools/bundle.py tools/validate_outgame.py docs/qa/feature-inventory.json godot/data/outgame/outgame-profile.json docs/design`와 `git diff 9217328…HEAD`(묶음 교체분).

- 보상 payload `amount`(`sample_round.gd` `_collect`): `host.state.data.coins - before`. 기반 `state.gd` 121~122행은 `tutorial.replay`가 false이고 `grants`에 `tutorial-first`가 없을 때만 coins를 10 더하므로 연습 모드(replay)와 재수령은 amount 0이다. `_draw_result`는 `int(item.get("amount", 0)) > 0`일 때만 아이콘·"+N"·"coins" 카드를 만들고, 0이면 `reward_text`("연습 완료")만 라벨로 띄운다. 설계 "연습 모드는 amount 0으로 카드에 수량 없음"과 일치한다.
- 여정: `reward ceremony impact/settle/finished`는 `main.ceremony.phase`를 최대 300프레임 폴링해 실제 phase 전이를 본다. `popup-open`은 `tap(inbox)` 직후(settle=false) 캡처라 220ms `pop_in` 중간 프레임이다. `home play action is primary skin`은 `theme_type_variation == &"PrimaryButton"`을 캠프 홈 `play`에서 본다(D-2 반영). `ui_kit` 기능 ID를 첫 시나리오에 선언해 `check.py`의 core 기능 누락 검사를 통과한다.
- `godot/game`에 `StyleBoxFlat` 0건. `home.gd`는 `DisplayLabel`·`PrimaryButton` 변형만 쓴다. `bootstrap/main.gd`가 `landscape = true`라 이 경로는 여정에서 실행되지 않으며 설계 AC-5가 그렇게 적었다.
- `check.py`: `ui_kit_probe.gd`를 `ui_standard_contract_probe` 다음에 넣고, 명령 루프가 종료 코드나 `SCRIPT ERROR`/`ERROR:`로 예외를 던진 뒤에만 `checks['ui_kit_probe'] = True`를 적는다. 1차 실행에서 timeout이 `subprocess.TimeoutExpired`로 올라와 종료 코드 1이 됐으니 미실행이 통과로 기록되지는 않는다.
- `bundle.py`: `VERSIONS = ('1.0.0', '1.1.0')`, `install`에서 역방향을 `ValueError`로 거부. `validate_outgame.py`는 1.0.0·1.1.0 허용. 잠금 `source.commit` `bc21978…`, 설계 AC-1과 같다.
- 묶음 `bc21978` 변경 중 이 크기에 영향이 있는 것: (1) `outgame_main.gd` `_clear`가 가로에서 내용 여백을 `max(16·배율, 12 + 프레임 content margin)`으로 올려 320 높이에서 하단 테두리와 겹치지 않게 했다. inbox·settings·support·platform 캡처에서 본문이 프레임 안에 있다. (2) `reward_ceremony.gd` 초점 보정(D-1). `$Stage`가 전체 앵커 CenterContainer이므로 `offset_top = H - (열 높이+16)`이면 열 끝은 H-8이고, probe 실측 312가 이를 뒷받침한다. (3) `camp_home.gd`가 평문 재화 라벨을 `_currency_chip`으로 바꿨다. `resource_provider`가 문자열("★ 10    🎟 2")을 주면 칩은 `set_text`로 그대로 표시한다. (4) `skin_dir` export 추가, `state.data.get("coins", 0)` 방어. 템플릿 코드와 충돌 없음.

## UX 결과

| 화면 | 확인 내용 | 결과 |
|---|---|---|
| title.png | 캠프 홈. "A new adventure begins" 디스플레이 서체, 재화 칩(코인 아이콘 + 0), "Begin adventure" PrimaryButton, 하단 6버튼 9분할 스킨 | 통과 |
| tutorial.png | 모달 프레임 스킨, 제목 디스플레이 서체, ★ 버튼이 프레임 안 | 통과 |
| reward-impact.png | 전체 노란 플래시, 카드가 막 등장(흐림) → impact 프레임. 아이콘·"+10"·"coins" 모두 화면 안 | 통과 |
| reward-settle.png | 플래시 없음, 코인 아이콘·파티클·"+10"·"coins" 선명, impact와 다른 프레임. 열 끝이 화면 안(D-1 고침). 코인 아이콘 윗부분이 Continue 버튼 아래 가장자리와 약 14px 겹침(N-1) | 통과(N-1 참고) |
| result.png | 카드 페이드아웃 중, Continue PrimaryButton | 통과 |
| home.png | 재화 칩 코인 10, Play PrimaryButton | 통과 |
| popup-open.png | 프레임 확대 중·반투명, 내용 페이드 중, 뒤 캠프가 밝게 보임(딤 없음은 설계 반영) | 통과 |
| inbox.png | 모션 완료, "Welcome gift"와 설명이 프레임 테두리 안(3회차의 하단 잘림이 여백 보정으로 사라짐), 스크롤바 표시 | 통과 |
| settings.png | 토글 스킨, 안내 두 줄이 프레임 안 | 통과 |
| support.png | 입력 패널, 안내문, 비활성 버튼 윗부분이 스크롤 영역 아래에서 잘림(프레임 테두리 밖으로 나가지는 않음, 기존 스크롤 동작) | 통과 |
| korean.png | "언어"는 둥근 한글 디스플레이 서체, 버튼 "기기 언어 따르기"는 본문 서체. 넘침 없음 | 통과 |
| large-text.png | 큰 글자 상태의 접근성 화면. 제목 디스플레이 서체, 토글 줄 글자가 커졌지만 패널 안 | 통과 |
| keyboard-focus.png | 큰 글자 설정 화면에서 "지원코드" 버튼에 두꺼운 어두운 초점 외곽선, 스킨 위 overlay, 스크롤 안 | 통과 |
| hero/map/world.png | 가로라 세 프로필 모두 캠프 홈, 재화 칩·Play PrimaryButton | 통과 |
| platform/signed-out-camp.png | 칩에 "★ 0  🎟 —", Create account PrimaryButton, Shop 비활성 | 통과 |
| platform/server-identifiers.png | STRT-TEST, Copy code PrimaryButton, "Code copied" 프레임 안 | 통과 |
| platform/connected-camp.png | 칩 "★ 10  🎟 0 (+)", 상태 "Account connected" | 통과 |
| platform/server-mail-received.png | Claim all 비활성 스킨, 서버 티켓 항목 프레임 안 | 통과 |
| platform/localized-store.png | 상품 2개 카드, 현지 가격 | 통과 |
| platform/server-ad-confirmed.png | 확인 1회, Watch test ad PrimaryButton 윗부분이 스크롤 영역 하단에 걸림(기존 스크롤) | 통과 |
| platform/maintenance-reason.png | 점검 사유 디스플레이 서체 2줄. 둘째 줄 "later."가 재화 칩 오른쪽 위 모서리와 겹침(N-2) | 통과(N-2 참고) |
| platform/deletion-status.png | 삭제 완료 상태, 버튼 2x2 프레임 안 | 통과 |

## 결함

취향·추측은 제외했다. 흐름을 막는 결함은 없다.

- N-1 (낮음, ui_kit 관련, 기반 `addons` 범위): 568x320 결과 화면에서 보상 카드의 코인 아이콘이 Continue 버튼 아래 가장자리와 약 14px 겹친다. 재현: 새 저장 → ★ 3회 → Collect +10 → settle 단계 프레임(reward-settle.png). D-1 보정이 열을 끌어올리면서 `present()` 주석의 "주 버튼을 가리지 않는 빈 영역"에서 벗어났다. 연출은 입력을 가로채지 않고 0.7초 안에 사라지므로 조작에는 영향이 없다. 기반 후속(초점 y를 낮추거나 카드 간격 축소) 대상.
- N-2 (낮음, ui_kit 관련, 기반 `addons` 범위): 캠프 홈에서 `resource_provider`가 긴 문자열("★ 10    🎟 2")을 주면 재화 칩이 x≈262까지 넓어져, 점검 사유처럼 헤드라인이 두 줄로 접힐 때 둘째 줄이 칩의 오른쪽 위 모서리와 겹친다(maintenance-reason.png, 헤드라인 영역 x 206~535·y 79~129와 칩 y 112~172). 재현: 플랫폼 여정 `ad-server-receipt-and-optout`의 점검 상태. 1.0.0의 평문 라벨(x 14~178)은 헤드라인 영역에 닿지 않았다. 템플릿 자체 `main.gd` 경로(칩 폭 ≈ 62px)에서는 발생하지 않는다.

ui_kit과 무관한 기존 문제(이번 판정에 넣지 않음):

- P-1: 1차 `check.py` 실행에서 `platform_journey.gd`가 180초 timeout으로 실패했다. 부분 보고의 실패 단계는 `real Firebase adapter and SDK session establish a cloud-ready account`로, `tap("start")` 직후 4프레임 안에 `accounts.connected()`와 `cloud.progress_ready`를 즉시 검사한다(대기 없음). 이 단계와 `platform_journey.gd`는 기준 커밋과 같고 이번 diff에 없다. 실행 당시 load average 8~10이었고 같은 조건의 단독 재실행 1회와 반복 5회, 2차 `check.py`는 모두 통과했다(7/7). 부하에 민감한 기존 여정 단계로 보이며, 별도 이슈(대기 폴링으로 바꾸기)를 권한다. 기준 커밋에서 같은 부하로 재현하지는 않았다.
- 320px 높이에서 support·ad reward 화면의 마지막 버튼이 스크롤 영역에 반쯤 걸림(3회차와 같은 기존 스크롤 동작).
- 결과 화면 헤드라인 "+10 coins"가 왼쪽 정렬이라 중앙 제목과 어긋남(3회차 기록과 같음).

## 판정

pass. 2차 `check.py`가 ok로 8개 시나리오 전부 통과했고 ui-kit probe 42항목, `bundle.py verify`(bc21978), unittest 9건, gate 8 PASS, `StyleBoxFlat` 0건으로 AC-1~AC-6을 충족하며, 3회차 D-1~D-4가 모두 코드 또는 설계에 반영됐다. 새 지적 N-1·N-2는 낮음이고 기반 묶음 범위라 game-foundation 후속 이슈로 넘기면 되고, P-1은 이 변경과 무관한 기존 여정의 부하 민감성이다.
