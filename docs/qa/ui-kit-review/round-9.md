# ui_kit 1.1.0 전환 독립 검수 9회차(3차 후보 3회차)

- 검수자: 독립 검수 에이전트 9(구현자, 1~8회차 검수자와 다른 에이전트)
- 후보 SHA: `bd3593ac88ee820d842969ea6aa8b69e7c67fa5a` (브랜치 `feat/ui-kit-1-1-0`, 기준 `42e1536e49eac777f82b42b0484acfc5a920b85b`, 이전 후보 `3ccc4a1`·`9217328`)
- 크기: 568x320
- 실행 시각(UTC): 2026-11-06T05:26:54Z worktree 생성·import, 05:27:39Z~05:28:34Z `check.py` 실행
- 실행 환경: 개발 환경 headless + 렌더링 캡처(`--audio-driver Dummy`, Godot 4.7.2-stable, macOS Apple M3, 실행 중 load average 35~46으로 7·8회차와 동시 실행)
- 격리 저장: 여정이 만드는 `user://e2e-game-<usec>/`, `user://platform-journey-<hex>/`(여정이 끝에서 삭제). 사용자 저장과 저장소 파일 수정 없음
- 격리 작업 트리: 스크래치 `qa-wt-9`(검수 후 제거). 캡처 사본: 스크래치 `qa-round-9-captures/`(여정 PNG 16장 + platform 8장, journey.json·ui-kit.json·ui-contract.json·automated.json·godot 로그 15개)

## 검수 계획

1. 설계 `docs/design/2026-11-06-ui-kit-1-1-0/design.md`(v2) AC-1~AC-7과 6회차 기록 `docs/qa/ui-kit-review/round-6.md`의 N-1·N-2를 읽고, 이번 후보에 들어간 변경(공통 묶음 `17984c9`, 템플릿 `platform_runtime.gd` 재화 문자열, 설계 후보 이력)을 `git diff 42e1536...HEAD`와 `git show HEAD`로 확정한다.
2. 격리 worktree에 후보 SHA를 올리고 `godot --import` 뒤 `tools/check.py --capture --size 568x320`을 실행해 ok와 시나리오 수를 적는다. `platform_journey`가 180초를 넘기면 단독 재실행한다.
3. `journey.json` 8개 시나리오 status와 `ui-kit.json` 42항목(팝업 시그널, 보상 단계 순서·finished·skip, 낮은 초점 열 위치, 효과음 연결, reduced_motion)을 대조한다.
4. 코드 검토: 템플릿 diff(`godot/game`, `godot/tests/game`, `tools/` 3개, 기능 목록, 프로필, 설계)와 묶음 `17984c9`의 변경(`outgame_main.gd` `_draw_result` 열 분리, `camp_home.gd` `_layout` 칩 축소, `reward_ceremony.gd` 48px 여유)을 읽어 N-1·N-2 해결 방식, 재화 문자열과 칩 표시의 일치, `StyleBoxFlat` 0건, 설계 후보 이력·AC-1·AC-7을 확인한다. `bundle.py verify`, unittest 2종, gate-report로 AC-1·AC-2·AC-6을 보조 확인한다.
5. 캡처 24장을 전부 보고 reward-impact/settle의 연출 열 위치와 버튼·프레임 겹침, popup-open 중간 프레임, korean/large-text 서체 역할과 넘침, keyboard-focus 초점 테두리, inbox/settings/support/platform 내용의 프레임 안 여부, 캠프 칩 폭과 ★ 중복을 확인한다. 칩과 헤드라인은 픽셀 좌표로 잰다.
6. 결함은 실패 시나리오로 적고 취향·추측은 제외한다. ui_kit과 무관한 기존 문제는 분리한다.

## 실행 명령과 결과

| 명령 | 결과 |
|---|---|
| `git worktree add <스크래치>/qa-wt-9 bd3593a…` | 분리 HEAD, 작업 트리 깨끗함 |
| `godot --headless --path godot --import --quit-after 2` | 종료 코드 0 |
| `python3 tools/check.py --capture --size 568x320 --out build/qa-round-9` (05:27:39Z~05:28:34Z) | 종료 코드 0, `{"ok": true, "sourceSha": "bd3593ac…", "scenarios": 8}`. 총 55초, 마지막 `platform_journey.gd`는 약 10초(로그 파일 시각 14:28:22→14:28:32 KST)라 재실행 불필요. godot 로그 15개에 `SCRIPT ERROR`·`ERROR:` 0건 |
| `python3 tools/bundle.py verify` | ok, version 1.1.0, source.commit `17984c9603c10a69498cb2464413b86932437cc9`, files 82 (AC-1) |
| `python3 -m unittest discover -s tools -p 'test_bundle.py'` / `'test_init_game.py'` | 6 tests OK / 3 tests OK (AC-1, AC-6) |
| `docs/game-design/ui/gate-report.json` | 8항목 모두 PASS (AC-2, 정적 보고) |
| `grep -rn StyleBoxFlat godot/game` | 0건 (AC-5) |

## 이전 지적 재확인

| 번호 | 내용 | 이번 후보 상태 | 근거 |
|---|---|---|---|
| N-1 (6회차) | 568x320 결과 화면에서 보상 카드 코인 아이콘이 Continue 버튼 아래 가장자리와 약 14px 겹침 | 고침 | `_draw_result`가 가로에서 HBox(왼쪽 버튼 열 비율 3, 오른쪽 `reward_stage` 비율 2)로 나누고 초점을 `(content.x + content폭×0.8)/화면폭, 0.55`로 잡는다. reward-impact/settle.png에서 연출 열(아이콘·"+10"·"coins")이 x≈395~475에 있고 Continue(x 34~322)·헤드라인(y 100~130)과 겹치지 않으며 프레임 하단 테두리(y≈296) 위에 있다. probe `low focus keeps the column on a 320px screen (column end 296)` PASS(6회차 312 → 48px 여유 반영) |
| N-2 (6회차) | 긴 재화 문자열로 칩이 x≈262까지 넓어져 두 줄 헤드라인 둘째 줄과 겹침 | 고침 | `camp_home.gd` `_layout`이 칩 내용 폭이 자리 폭(370 설계 px, 568x320에서 164px)을 넘으면 `node.scale`을 `slot/have`로 줄인다(deferred). maintenance-reason.png에서 칩 오른쪽 끝 x≈177, 헤드라인 둘째 줄 "later." 시작 x≈206으로 29px 떨어져 있다. 템플릿 `platform_runtime.gd`가 ★를 빼 칩이 코인 아이콘 + "10    🎟 2"를 보여 주고 ★ 중복이 없다 |
| R-1·R-2 (7·8회차) | 이번 후보의 7·8회차 기록이 저장소(`docs/qa/ui-kit-review/`)와 스크래치에 아직 없어 내용을 확인하지 못했다 | 확인 불가 | 동시 실행 중인 7·8회차 기록이 합쳐진 뒤 대조가 필요하다. 이 회차의 새 관찰 N-3·D-5가 같은 내용이면 번호를 맞춘다 |

## 기능 결과

`journey.json` mode `rendered`, viewport [568, 320]. 8개 시나리오 모두 passed, 실패 단계 0.

| 시나리오 | status | 단계 수 | 비고 |
|---|---|---|---|
| offline-first-play-restart | passed | 17 | `collect reward`, `persisted reward`(10), `reward ceremony impact`→`settle`→`finished` ok, 캡처 8장 |
| settings-language-support-focus | passed | 14 | 한국어 전환, 큰 글자, 키보드 초점, 재시작 뒤 유지 |
| three-home-profiles | passed | 12 | hero·map·world `home play action is primary skin` ok |
| real-bootstrap-account-and-cloud | passed | 9 | load average 35~46에서도 1차 실행에 통과(6회차 P-1 재현 없음) |
| actual-round-cloud-save | passed | 7 | |
| inbox-wallet-and-store | passed | 8 | |
| ad-server-receipt-and-optout | passed | 11 | |
| link-logout-recover-and-delete | passed | 11 | |

`ui-kit.json` passed true, failures 0, 42항목 전부 통과.

| 항목 | 결과 |
|---|---|
| 테마: theme.tres 로드, 디스플레이·본문·숫자 서체 분리, 버튼·패널 StyleBoxTexture, 초점 overlay, skin.json v2, 한글 디스플레이 서체 분리 | PASS |
| 팝업 일반: 딤·프레임 표시, `opened` 1회, 진입 3프레임 이상, 열린 상태 재open 무시, `closed` 뒤 숨김 | PASS |
| 팝업 reduced: 딤·프레임, `opened` 1회, 2프레임 안 열림(1), 재open 무시, `closed` 뒤 숨김 | PASS |
| 보상 일반·reduced: phase 순서 anticipation→impact→settle→done, `finished` 1회, impact 파티클, skip 1회 종료, skip 뒤 present 유지, 낮은 초점(0.86) 열 끝 296 ≤ 320 | PASS |
| 효과음: attach 멱등, 늦게 추가된 버튼 포함 4개 연결, button_down마다 재생, kind meta로 소리 선택, 5개 스트림 로드 | PASS |
| 칩: 천 단위 구분, 큰 수 축약, 아이콘+숫자+(+) | PASS |
| 층: 캔버스 층 6개 오름차순, 토스트 층·입력 무시·가로 중앙·시간 뒤 퇴장 | PASS |

## 코드 검토

- 템플릿 diff(기준 `42e1536` 대비 11개 파일)는 6회차와 같은 내용에 `platform_runtime.gd` 한 줄(`"★ %d    🎟 %s"` → `"%d    🎟 %s"`)이 더해졌다. `_currency_chip`은 `resource_provider`가 문자열을 주면 `set_text`로 숫자 라벨에 그대로 넣고 아이콘은 `skin.json`의 coin 아이콘을 따로 붙이므로, ★를 뺀 문자열이 "아이콘 10    🎟 2"로 표시된다. 캡처(connected-camp·maintenance-reason)와 일치한다. 템플릿 자체 `main.gd` 경로는 `resource_provider`를 두지 않아 정수 `set_value`로 "10"이 뜬다(home.png).
- `_draw_result`(묶음 `17984c9`): 가로에서 `row(HBox, separation 16)` 아래 `left(VBox, 비율 3)`와 `reward_stage(Control, 비율 2)`를 두고 헤드라인·순위 라벨·Continue·순위 보기 버튼을 모두 `column`(left)에 붙인다. `_button`의 세 번째 인자 `parent`로 열을 지정하므로 누락된 버튼이 없다. 초점 x는 `content.global_position.x + content.size.x*0.8`로 오른쪽 열 중심(비율 3/5 + 1/5)이고, 세로 경로(`Vector2(0.5, 0.62)`)는 그대로다. 결과 화면을 순위 갱신으로 다시 그릴 때 `_reward_presented` 가드로 연출을 반복하지 않는 로직도 유지된다.
- `reward_ceremony.gd`: 하단 여유 16→48px. 주석이 backing 12 + 테두리 띠 34를 근거로 적고, probe 실측 열 끝 296(=320-24)이 이를 뒷받침한다. 템플릿 `sample_round.gd`는 `amount`를 넣고 기반은 counter·target 없이 호출해 설계 보상 행("+10" 카드, 카운트업·비행 없음)과 일치한다.
- `camp_home.gd` `_layout`: 칩 자리 `Rect2(32, 244, 370, 76)`의 폭을 자리로 삼아 `scale = min(1, slot/have)`를 다음 프레임에 적용한다. `size = Vector2.ZERO` 뒤 최소 크기가 갱신되기 전이라 `call_deferred`가 맞다. 축소는 칩 전체(아이콘·숫자·(+) 버튼)에 걸리므로 (+)의 터치 영역도 같이 줄어든다(N-3). 헤드라인 자리 `Rect2(464, 178, 740, 112)`와는 겹치지 않는다.
- `tools/` 사본·`check.py`·`validate_outgame.py`·기능 목록·프로필·여정은 6회차 검토 내용과 같다. `check.py`가 `ui_kit_probe.gd`를 명령 루프에 넣고 예외 없이 끝난 뒤에만 `ui_kit_probe: true`를 적는다.
- 설계 문서: 목적 문단·의존 항목·AC-1의 묶음 커밋이 `17984c9…`로 갱신돼 잠금 `source.commit`과 같다. AC-7은 후보별 3회(1~3회차 `9217328`, 4~6회차 `3ccc4a1`, 7~9회차 현재 후보)로 바뀌어 이 회차 번호와 맞는다. 다만 AC-7 증거 칸은 여전히 `docs/qa/2026-11-06-ui-kit-review-{1,2,3}.md`라 실제 기록 위치 `docs/qa/ui-kit-review/round-N.md`와 다르다(D-5).
- `ui_kit_probe.gd` 120행 주석은 "초점이 아래쪽(0.86)"을 가로 결과 화면 사례로 들지만 이제 가로 결과 화면은 0.55를 쓴다. 검사 자체는 더 낮은 초점(0.86)을 그대로 돌려 보수적이므로 결함은 아니다.

## UX 결과

| 화면 | 확인 내용 | 결과 |
|---|---|---|
| title.png | 캠프 홈. "A new adventure begins" 디스플레이 서체, 재화 칩(코인 아이콘 + 0, 폭 ≈ 62px), "Begin adventure" PrimaryButton, 하단 6버튼 9분할 스킨 | 통과 |
| tutorial.png | 모달 프레임 스킨, "Gather three stars" 디스플레이 서체, ○○○ 진행 표시, ★ 버튼이 프레임 안, 스크롤바 | 통과 |
| reward-impact.png | 전체 노란 플래시, 오른쪽 열에 카드가 막 등장(흐림). 왼쪽 열 "+10 coins"·Continue와 분리 | 통과 |
| reward-settle.png | 플래시 없음, 오른쪽 열(x≈395~475)에 코인 아이콘·파티클·"+10"·"coins"(디스플레이 서체) 선명. Continue(x 34~322)·헤드라인·프레임 하단 테두리와 겹침 없음(N-1 고침) | 통과 |
| result.png | 카드 페이드아웃 중, Continue PrimaryButton | 통과 |
| home.png | 칩 코인 10, Play PrimaryButton | 통과 |
| popup-open.png | 프레임 확대 중·반투명, 내용 페이드 중, 딤 없음(설계 반영) | 통과 |
| inbox.png | 모션 완료, Claim all·Grant history 버튼, "Welcome gift"와 설명이 프레임 안, 스크롤바 | 통과 |
| settings.png | 토글 스킨 2개, 안내 두 줄이 프레임 안 | 통과 |
| support.png | 입력 패널 "—", 안내문 2줄, 비활성 버튼 윗부분이 스크롤 영역 아래에서 잘림(프레임 밖으로는 안 나감, 기존 스크롤) | 통과 |
| korean.png | "언어"는 둥근 한글 디스플레이 서체, 버튼 "기기 언어 따르기"·"English"·"✓ 한국어"는 본문 서체. 넘침 없음 | 통과 |
| large-text.png | 큰 글자 상태 접근성 화면. "접근성" 디스플레이 서체, "큰 글자" 켜짐, "움직임 줄이기" 꺼짐, 토글 줄이 패널 안 | 통과 |
| keyboard-focus.png | 큰 글자 설정 화면에서 "지원코드" 버튼에 두꺼운 어두운 초점 외곽선, 스킨 위 overlay, 스크롤 안 | 통과 |
| hero/map/world.png | 가로라 세 프로필 모두 캠프 홈, 칩·Play PrimaryButton | 통과 |
| platform/signed-out-camp.png | 칩 "코인 0  🎟 —"(★ 없음), Create account PrimaryButton, Shop 비활성 | 통과 |
| platform/server-identifiers.png | STRT-TEST, Copy code PrimaryButton, "Code copied" 프레임 안 | 통과 |
| platform/connected-camp.png | 칩 "코인 10  🎟 0 (+)"가 축소돼 x≈18~177, "Account connected". (+) 버튼 약 37x37px(N-3) | 통과(N-3 참고) |
| platform/server-mail-received.png | Claim all 비활성 스킨, "Camp supplies"·"Test ticket from the server" 프레임 안 | 통과 |
| platform/localized-store.png | 상품 2개 카드, $0.99 | 통과 |
| platform/server-ad-confirmed.png | 확인 1회, Watch test ad PrimaryButton 윗부분이 스크롤 영역 하단에 걸림(기존 스크롤) | 통과 |
| platform/maintenance-reason.png | 점검 사유 디스플레이 서체 2줄. 칩 오른쪽 끝 x≈177, 둘째 줄 "later." x≈206부터라 겹치지 않음(N-2 고침) | 통과 |
| platform/deletion-status.png | "Deletion request: completed", 버튼 첫 줄 2개 프레임 안, 둘째 줄은 스크롤 영역 아래(기존 스크롤. 이 화면 코드는 묶음 `bc21978`과 같다) | 통과 |

## 결함

취향·추측은 제외했다. 흐름을 막는 결함은 없다.

- N-3 (낮음, ui_kit 관련, 기반 `addons` 범위): 568x320 캠프 홈에서 긴 재화 문자열로 칩이 축소되면 (+) 버튼의 터치 영역이 약 37x37px로 줄어 `camp_home.gd`가 주석으로 둔 "캠프의 모든 버튼은 56px 이상" 규칙에서 벗어난다. 재현: 플랫폼 여정 `real-bootstrap-account-and-cloud`의 연결 상태(connected-camp.png, 칩 scale ≈ 0.66). 같은 화면의 하단 버튼은 85x56, 설정 톱니는 50x40이다. (+)는 Shop 버튼과 같은 상점 열기라 대체 경로가 있고 조작을 막지 않는다. 후속으로는 축소 대신 숫자 라벨 글자 축소나 (+)를 축소 대상에서 제외하는 방식이 맞다.
- D-5 (낮음, 설계 문서): AC-7 증거 칸 `docs/qa/2026-11-06-ui-kit-review-{1,2,3}.md`가 실제 기록 경로 `docs/qa/ui-kit-review/round-N.md`와 다르다. 후보 이력(7~9회차)과 설명은 맞다.

ui_kit과 무관한 기존 문제(이번 판정에 넣지 않음):

- 320px 높이에서 support·ad reward·account(deletion-status) 화면의 마지막 버튼 줄이 스크롤 영역에 반쯤 걸림(3·6회차와 같은 기존 스크롤 동작).
- 결과 화면 헤드라인 "+10 coins"가 왼쪽 정렬이라 중앙 제목과 어긋남(3·6회차 기록과 같음).
- 6회차 P-1(부하에서 `platform_journey` timeout)은 load average 35~46의 이번 실행에서 재현되지 않았다.

## 판정

pass. `check.py`가 1차 실행에서 ok로 8개 시나리오 전부 통과했고 ui-kit probe 42항목, `bundle.py verify`(17984c9), unittest 9건, gate 8 PASS, `StyleBoxFlat` 0건으로 AC-1~AC-6을 충족하며, 6회차 N-1(보상 열이 오른쪽 열로 분리)·N-2(칩 축소와 ★ 제거)가 캡처 픽셀 좌표로 확인됐다. 새 지적 N-3은 낮음이고 기반 묶음 범위, D-5는 문서 경로 오기라 이 PR에서 한 줄 수정하면 된다.
