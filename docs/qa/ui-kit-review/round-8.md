# ui_kit 1.1.0 전환 독립 검수 8회차(3차 후보 2회차)

- 검수자: 독립 검수 에이전트 8(구현자, 1~7회차 검수자와 다른 에이전트)
- 후보 SHA: `bd3593ac88ee820d842969ea6aa8b69e7c67fa5a` (브랜치 `feat/ui-kit-1-1-0`, 이전 후보 `3ccc4a1` 위에 foundation #15 묶음 `17984c9` 설치와 템플릿 `platform_runtime.gd`의 ★ 제거)
- 크기: 1024x600(가로, 태블릿급)
- 실행 시각(UTC): 2026-11-06T05:26:39Z worktree 생성, 05:27:03Z import 시작, 05:27:40Z~05:28:33Z `check.py` 실행(53초), 05:28:30Z 자동 보고 기록
- 실행 환경: 개발 환경 headless E2E + 렌더링 캡처(Godot 4.7.2.stable, `--audio-driver Dummy`), macOS. 격리 worktree `scratchpad/qa-wt-8`(분리 HEAD, 작업 트리 깨끗함, 저장소 파일 수정·커밋 없음)
- 격리 저장: 여정이 만드는 임시 저장 `user://e2e-game-<usec>/`(여정 종료 시 삭제). 사용자 저장 영향 없음
- 캡처 사본: 검수 worktree `build/qa-round-8` 전체(PNG 24장, journey·ui-kit·ui-contract·automated JSON, godot 로그 15개)를 세션 scratchpad `qa-round-8-captures/`로 복사

## 검수 계획

설계 `docs/design/2026-11-06-ui-kit-1-1-0/design.md`(AC-1~AC-7)와 1·2·4·5회차 기록을 읽고, `git diff 3ccc4a1 bd3593a`로 이번 후보가 바꾼 네 곳을 먼저 파악했다. foundation `outgame_main.gd` `_draw_result`(가로면 HBox로 왼쪽 버튼 열 stretch 3, 오른쪽 `reward_stage` 열 stretch 2로 나누고 연출 초점을 내용 폭 0.8·세로 0.55로 둠), `reward_ceremony.gd`(열 하단 여유 16→48px), `camp_home.gd`(재화 칩이 자리 폭 370 설계 px를 넘으면 다음 프레임에 축소), 템플릿 `platform_runtime.gd`(resource_provider 문자열에서 "★ " 제거). 그 뒤 아래 순서로 본다.

1. 이전 결함 재확인(실패 시나리오 기준). (1) 5회차 R-1·2회차 결함 1: `reward-settle.png`에서 "coins" 글자 픽셀의 마지막 행이 프레임 하단 금색 테두리 첫 행보다 위에 있고, 글자가 오른쪽 열(x > Continue 버튼 오른쪽 끝)에 있으며 버튼 y 띠와 겹치지 않는다(픽셀 스캔). (2) 5회차 R-2: 플랫폼 캠프 칩에 코인 아이콘 뒤 "★"가 없다. (3) 4회차 D-2: 칩 오른쪽 끝이 헤드라인 글자 왼쪽 끝보다 왼쪽에 있다(픽셀 스캔). (4) 1회차 D2·D3, 3회차 D-2가 유지된다(팝업 내용의 테두리 침범 없음, 칩 스킨, 단계 이름).
2. 새 배치의 UX: 1024x600에서 왼쪽 버튼 열과 오른쪽 연출 열의 폭 비율, 버튼 폭, 빈 공간, 연출 열 세로 위치가 어색하지 않은지 본다.
3. 정적 조건: 잠금 1.1.0과 `source.commit` 17984c9, 프로필 `uiStandard.version` 1.1.0, `godot/game/` `StyleBoxFlat` 0건, `bundle.py verify` 통과(AC-1, AC-5).
4. 자동 실행: `check.py --capture --size 1024x600` `ok: true`, 시나리오 8개 전부 passed, 단계 실패 0, `ui-kit.json`·`ui-contract.json` 실패 0, `unittest discover` 통과, `check_architecture.py` 통과(AC-3, AC-4, AC-6). platform_journey가 180초를 넘기면 단독 재실행.
5. 화면 검수: `build/qa-round-8`의 PNG 전부(platform/ 포함)를 하나씩 본다. 9분할 스킨 왜곡, 서체 역할, 팝업 프레임·딤, 보상 3프레임, 재화 칩, 글자 잘림·겹침, 한국어·큰 글자, 키보드 초점.
6. 결함은 재현 상태·틀린 내용·코드 위치로 적고 취향·추측은 뺀다. ui_kit과 무관한 기존 문제는 분리한다.

## 실행 명령과 결과

| 명령 | 결과 |
|---|---|
| `git worktree add … bd3593ac…` | 분리 HEAD, 작업 트리 깨끗함 |
| `godot --headless --path godot --import --quit-after 2` | 종료 코드 0(37초) |
| `python3 tools/check.py --capture --size 1024x600 --out build/qa-round-8` | 종료 코드 0, 출력 `{"ok": true, "sourceSha": "bd3593ac…", "scenarios": 8}`, 전체 53초. platform_journey 포함 전체가 180초 미만이라 단독 재실행 불필요 |
| `build/qa-round-8/journey.json` | mode rendered, viewport [1024, 600], 시나리오 8개 모두 passed, 단계 89개 중 `ok: false` 0 |
| `build/qa-round-8/ui-kit.json` | passed true, 검사 42개 실패 0 |
| `build/qa-round-8/ui-contract.json` | passed true, 검사 87개 실패 0 |
| `build/qa-round-8/automated.json` | passed true, sourceSha bd3593ac…, recordedAt 2026-11-06T05:28:30Z |
| `python3 -m unittest discover -s tools -p 'test_*.py'` | 23 tests OK(49.4초, `test_bundle`·`test_init_game` 포함) |
| `python3 tools/check_architecture.py` | Architecture passed |
| `python3 tools/bundle.py verify` | ok, version 1.1.0, source.commit `17984c9603c10a69498cb2464413b86932437cc9`, files 82 |
| `grep -rn StyleBoxFlat godot/game/` | 0건 |
| `godot/data/outgame/outgame-profile.json` | `uiStandard.version` 1.1.0 |
| godot 로그 15개 | "error"·"script error" 문자열 없음 |
| `git diff 3ccc4a1 bd3593a --stat` | 9개 파일. 묶음 3개(`outgame_main.gd` +40/-18, `camp_home.gd` +7, `reward_ceremony.gd` +3/-1), 잠금, `platform_runtime.gd` 1줄, 설계 문구, 검수 기록 4~6회차 |

## 이전 결함 재확인

| 이전 결함 | 이번 확인 방법 | 결과 |
|---|---|---|
| 5회차 R-1(2회차 결함 1, 1회차 D1, 4회차 D-1 계열): "coins" 외곽선이 프레임 하단 테두리에 올라탐, 568x320에서는 Continue 버튼을 덮음 | `reward-settle.png` 픽셀 스캔. 오른쪽 열(x 620~1000)의 진한 글자 픽셀 행 묶음은 65~108(제목), 310~336("+10", x 771~828), 366~415("coins", x 726~873). 프레임 하단의 금색 선은 y 576, 바깥 테두리 띠는 582~586, 프레임 밖 배경은 588부터. Continue 버튼은 x 35~594, y 234~335 | 해소. "coins" 마지막 글자 행 415는 테두리 첫 행 576보다 161px 위에 있다. 연출 열(x 726~873)은 버튼 오른쪽 끝 594보다 132px 오른쪽이라 버튼과 겹치지 않는다. `result.png`의 퇴장 잔상도 같은 자리에서 페이드한다 |
| 5회차 R-2: 플랫폼 캠프 칩에 코인 아이콘 뒤 "★ 10" 중복 | `platform/signed-out-camp.png`·`connected-camp.png`·`maintenance-reason.png` 칩을 눈으로 확인 | 해소. 칩이 "코인 아이콘 10 / 티켓 아이콘 0 / (+)"로 ★ 없이 표시된다. `platform_runtime.gd` 64행 문자열이 `"%d    🎟 %s"`로 바뀌었다 |
| 4회차 D-2: 2줄 헤드라인 2번째 줄이 칩과 겹침 | `platform/maintenance-reason.png` 픽셀 스캔. 칩 몸통 x 29~318(오른쪽 (+) 포함), 헤드라인 "Service maintenance, try again later." 글자 x 372~951, y 163~196 한 줄 | 1024x600에서는 헤드라인이 한 줄이라 재현 조건 자체가 없고 칩 오른쪽 끝(318)과 헤드라인 시작(372) 사이 54px 여유. 568x320 재현은 7·9회차 범위 |
| 1회차 D2: 팝업 내용의 프레임 테두리 침범 | `tutorial.png`·`inbox.png`·`settings.png`·`support.png`·`platform/server-mail-received.png`·`server-ad-confirmed.png`·`server-identifiers.png` 하단 | 유지(해소 상태). 스크롤 클립이 금색 테두리 안쪽(y≈568)에서 끝나고 글자가 테두리 위에 없다 |
| 1회차 D3: 가로 타이틀·홈 재화 평문 | `title.png`(0)·`home.png`(10)·`hero/map/world.png`·platform 캠프 3장 | 유지(해소 상태). 어두운 알약 칩에 코인 아이콘+숫자. 연결 상태는 티켓·(+)까지 |
| 3회차 D-2: 여정 단계 이름 | `journey.json` `hero/map/world home play action is primary skin` 3건 passed | 유지 |

## 기능 결과

`build/qa-round-8/journey.json`(platform 여정 5건 합침). 시나리오별 단계 실패 0.

| 시나리오 | 기능 | status | 단계 |
|---|---|---|---|
| offline-first-play-restart | startup, tutorial, account_save, inbox, commerce, operations, observability, ui_leaderboard, ui_kit | passed | 17. `persisted reward` expected 10 actual 10, `reward ceremony impact`→`settle`→`finished`, `return to lobby`, `reward restored` 10(AC-4) |
| settings-language-support-focus | settings_support, account_save, ui_support_entry, ui_analytics_opt_out, ui_locale_offline, ui_navigation | passed | 14. 한국어 선택·큰 글자·키보드 초점 스크롤·재시작 유지 |
| three-home-profiles | startup, tutorial, account_save, ui_navigation | passed | 12. `<profile> home play action is primary skin` 3건(AC-5) |
| real-bootstrap-account-and-cloud | startup, account_save, platform_end_to_end, ui_landscape | passed | 9. `create via primary button`, UID·PUID 확인, 지원코드 복사 |
| actual-round-cloud-save | tutorial, account_save, platform_end_to_end | passed | 7 |
| inbox-wallet-and-store | inbox, commerce, platform_end_to_end | passed | 8. 서버 우편 수령, 티켓 지갑, 현지화 가격, 구매 완료 |
| ad-server-receipt-and-optout | observability, operations, platform_end_to_end | passed | 11 |
| link-logout-recover-and-delete | account_save, platform_end_to_end, settings_support | passed | 11 |

AC-1(잠금 17984c9·verify·`test_bundle`), AC-2(저장소 `gate-report.json` 8 PASS, 이번 후보 diff에 게이트 대상 구조 변경 없음), AC-3(`check.py` 여정·probe·unittest), AC-4(캡처 3장, coins 10), AC-5(여정 검사·grep 0건), AC-6(`test_init_game` 포함 23 tests OK) 통과. AC-7은 이 회차가 현재 후보의 1024x600 분량이다.

## UX 결과

캡처 24장(여정 16장, platform 8장) 모두 봤다. hero·map·world는 md5 동일(`5b85bc50…`)로 한 장과 같다.

| 화면 | 확인 항목 | 결과 |
|---|---|---|
| title.png | 캠프 배경, 디스플레이 서체 제목·"A new adventure begins", 본문 서체 "Connect your account", 칩(코인 0), "Begin adventure" 주 버튼, 하단 6버튼 간격 균등, Shop·Operations 비활성 회색, 9분할 모서리·띠 왜곡 없음 | 통과 |
| tutorial.png | 프레임 중앙, 모서리 장식 4개, 원 3개, ★ 큰 버튼 스킨 줄무늬 없음, "Skip guide"는 스크롤 아래 잘림(스크롤바 표시), 테두리 침범 없음 | 통과 |
| reward-impact.png | 전체 노란 플래시, 오른쪽 열에 코인·"+10"·"coins" 카드 펀치 인 중, 왼쪽 헤드라인·Continue는 플래시 아래 비침 | 통과 |
| reward-settle.png | 오른쪽 열 x 726~873에 코인 64px(y≈235~290), "+10"(310~336), "coins"(366~415), 파티클. 왼쪽 열 "+10 coins" 헤드라인(y 165~206)과 Continue(x 35~594, y 234~335). 서로 겹치지 않고 프레임 테두리까지 161px 여유 | 통과 |
| result.png | 왼쪽 "Expedition complete"·"+10 coins"·Continue 금색 주 버튼, 오른쪽 연출 퇴장 잔상이 같은 자리에서 페이드 | 통과 |
| 가로 결과 배치(3:2) | 왼쪽 열 폭 560px(x 35~594), 오른쪽 열 폭 ≈380px(x 610~990). Continue 폭 560px은 하단 6버튼(≈145px)과 상단 "My account"(≈260px)보다 넓고 1024px의 55%라 주 행동으로 충분하다. 연출 열은 Continue와 같은 세로 띠(초점 0.55→y≈330)에 있어 버튼과 연출이 한 줄로 읽힌다. Continue 아래(y 335~575)와 연출 아래가 비지만 결과 팝업이 전체 화면 프레임이라 생기는 빈 공간이고, 이전 후보의 전폭 버튼+하단 띠 배치에서도 같은 양의 빈 공간이 있었다. 글자·버튼 왜곡이나 비율 붕괴 없음 | 통과(결함 없음, 관찰 O-1 참고) |
| home.png | 칩 10으로 갱신, Play 주 버튼, 비활성 Shop·Operations 회색 | 통과 |
| popup-open.png | 우편 프레임이 축소·반투명으로 커지는 중, 중앙 정렬, 뒤에 캠프 배경 | 통과 |
| inbox.png | Claim all·Grant history 버튼, "Welcome gift"·"+5 coins", 다음 항목이 테두리 안쪽에서 클립 | 통과 |
| settings.png | Vibration 켜짐 녹색 행, Allow analytics 꺼짐, 안내 두 줄, 첫 행·마지막 버튼 일부는 스크롤 위치 | 통과(기존 관찰) |
| support.png | "Support code" 디스플레이 서체, 입력 상자 "—", 안내 2줄, 비활성 Copy code | 통과 |
| korean.png | "언어" 디스플레이 서체, 버튼 3개 한글 본문 서체, "✓ 한국어" | 통과 |
| large-text.png | "접근성", "큰 글자"(켜짐)·"움직임 줄이기" 확대 토글, 잘림·겹침 없음 | 통과 |
| keyboard-focus.png | "지원코드" 버튼 진한 초점 외곽선, 상단 글줄은 스크롤 위치 | 통과 |
| hero.png, map.png, world.png | md5 동일, 칩 0, Play 주 버튼 | 통과(기존 관찰) |
| platform/signed-out-camp.png | "Create account" 주 버튼, 칩 "코인 0 / 티켓 —", ★ 없음, 비활성 Shop | 통과 |
| platform/connected-camp.png | "Account connected", 칩 "코인 10 / 티켓 0 / (+)", ★ 없음, Shop 활성. 칩 오른쪽 끝 318, 헤드라인 시작 372 | 통과 |
| platform/maintenance-reason.png | "Service maintenance, try again later." 한 줄(x 372~951), 칩 티켓 2, 겹침 없음 | 통과 |
| platform/deletion-status.png | "Deletion request: completed", 2열 버튼 그리드 간격 균등 | 통과 |
| platform/localized-store.png | 상품 2개 이름·가격 2줄, 빈 공간은 목록 끝 | 통과 |
| platform/server-ad-confirmed.png | 안내 두 줄, "Confirmed test views: 1", Watch test ad 주 버튼, 아래 버튼은 스크롤 영역 | 통과 |
| platform/server-identifiers.png | STRT-TEST 숫자 서체, Copy code 주 버튼, "Code copied" | 통과 |
| platform/server-mail-received.png | 비활성 Claim all, "starter_test_ticket_1 ×1", 테두리 침범 없음 | 통과 |

큰 화면(1024x600)에서 9분할 스킨은 버튼·프레임·칩 모두 모서리 반경이 유지되고 가운데 띠에 줄무늬나 늘어난 장식이 없다. 이번 묶음의 `camp_home.gd` 칩 축소는 1024x600에서는 내용이 자리 폭 안이라 scale 1.0 그대로이며 칩 크기가 5회차와 같다.

## 결함

판정을 바꾸는 결함은 없다. 실패 시나리오로 재현되는 결함도 없다.

- O-1 (관찰, 결함 아님): 1024x600 결과 화면에서 Continue 아래와 연출 열 아래에 각각 약 240px 높이의 빈 띠가 남는다. 결과 팝업이 전체 화면 프레임(x 18~1005, y 18~581)인 구조 때문이고, 이전 후보(전폭 Continue+아래 연출)에도 같은 양의 빈 공간이 있었다. 순위 기능이 켜지면 왼쪽 열에 "View leaderboard"·점수 상태 줄이 추가되어 줄어든다. 배치 비율 3:2 자체는 버튼 폭(560px)과 연출 폭(380px) 모두 충분해 어색하지 않다.

ui_kit과 무관한 기존 관찰(기준 42e1536에도 있음, 판정에 넣지 않음): 가로에서 `home_profile`이 hero·map·world여도 `_camp_home`이 같은 화면을 그려 템플릿 `home.gd`가 렌더링되지 않는다(hero/map/world md5 동일). 설정 화면의 첫 토글 행과 마지막 버튼이 스크롤 위치상 일부만 보인다. 결과 화면 헤드라인 "+10 coins"는 왼쪽 정렬이다.

## 판정

pass — 자동 검사(여정 8개·단계 89개, ui-kit 42개, ui-contract 87개, unittest 23개, 아키텍처, bundle verify 17984c9)가 모두 통과했고, 1024x600 캡처 픽셀 스캔에서 5회차 R-1("coins" 마지막 행 415, 프레임 테두리 576, 버튼 오른쪽 끝 594 대비 연출 열 시작 726)과 R-2(★ 없음), 4회차 D-2(칩 끝 318, 헤드라인 시작 372)가 모두 해소됐으며 1~3회차 해소 상태가 유지되고 새 결함이 없다.
