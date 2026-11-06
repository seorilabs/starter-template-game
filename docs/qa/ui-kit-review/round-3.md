# ui_kit 1.1.0 전환 독립 검수 3회차

- 검수자: 독립 검수 에이전트 3(구현자와 다른 에이전트)
- 후보 SHA: `921732833c15372286820840a26a2fc74c1d09d8` (브랜치 `feat/ui-kit-1-1-0`, 기준 `42e1536e49eac777f82b42b0484acfc5a920b85b`)
- 크기: 568x320
- 실행 시각(UTC): 2026-11-06T02:40:04Z 시작, 02:40:32Z 보고 기록
- 실행 환경: 개발 환경 dev headless + 렌더링 캡처(`--audio-driver Dummy`, Godot 4.7.2-stable), 격리 worktree `scratchpad/qa-wt-3`
- 격리 저장: 여정이 만든 임시 저장 `user://e2e-game-<usec>/` (여정이 끝에서 삭제), 사용자 저장 영향 없음
- 캡처 사본: 검수 worktree `build/qa-round-3`(원본은 NAS 이관, 위치는 PR 본문)

## 검수 계획

1. 설계 `docs/design/2026-11-06-ui-kit-1-1-0/design.md` AC-1~AC-7을 읽고 이번 회차 범위(568x320, 모든 기능, 모션·접근성·코드 심화)를 확정한다.
2. 후보 SHA를 격리 worktree에 올리고 `godot --import` 뒤 `tools/check.py --capture --size 568x320`을 실행해 ok와 시나리오 수를 기록한다.
3. `journey.json`의 모든 시나리오·단계 status와 `ui-kit.json`의 팝업 시그널, 보상 단계 순서, finished 1회, skip, 버튼 효과음 연결, reduced_motion 즉시 완료 항목을 대조한다.
4. 기준 커밋과의 diff를 읽어 보상 payload `amount`의 연습 모드 값, 여정 새 단계가 실제 동작을 검사하는지, `godot/game` 아래 `StyleBoxFlat` 잔존 여부, `check.py`의 `ui_kit_probe` 삽입이 기존 흐름을 바꾸지 않는지 본다.
5. 캡처 PNG 24장(여정 16장, 플랫폼 여정 8장)을 모두 눈으로 보고 서체 역할, 큰 글자 넘침, 초점 테두리, 보상 단계 프레임 차이, 팝업 중간 프레임을 확인한다.
6. 결함은 실패 시나리오로 적고 ui_kit과 무관한 기존 문제는 분리한다. AC-1·AC-6의 단위 테스트와 `bundle.py verify`는 보조 근거로 실행한다.

## 실행 명령과 결과

| 명령 | 결과 |
|---|---|
| `git worktree add scratchpad/qa-wt-3 9217328…` | 분리 HEAD, 작업 트리 깨끗함 |
| `godot --headless --path godot --import --quit-after 2` | 종료 코드 0 |
| `python3 tools/check.py --capture --size 568x320 --out build/qa-round-3` | 종료 코드 0, 출력 `{"ok": true, "sourceSha": "9217328…", "scenarios": 8}` |
| `python3 tools/bundle.py verify` | ok, version 1.1.0, source.commit `06f2519f232f1d6332bfca39cf2fb05262f615d1`, files 82 |
| `cd tools && python3 -m unittest test_bundle test_init_game` | 9 tests OK (AC-1, AC-6) |
| `docs/game-design/ui/gate-report.json` | 8항목 모두 PASS (AC-2, 정적 보고 확인) |
| `grep -rn StyleBoxFlat godot/game` | 일치 없음 (AC-5) |

참고: 설계 AC-1·AC-6에 적힌 형태 `python3 -m unittest tools/test_bundle.py`는 저장소 루트에서 `ModuleNotFoundError: bundle`로 실패한다. `npm test`가 쓰는 `unittest discover -s tools` 형태나 `tools/` 안에서 실행하면 통과한다. 코드 결함이 아니라 설계 문서의 명령 표기 문제다.

## 기능 결과

`build/qa-round-3/journey.json`(플랫폼 여정 5건이 합쳐진 상태). mode `rendered`, viewport [568, 320].

| 시나리오 | 기능 ID | status | 단계 수 | 비고 |
|---|---|---|---|---|
| offline-first-play-restart | startup, tutorial, account_save, inbox, commerce, operations, observability, ui_leaderboard, ui_kit | passed | 17/17 OK | persisted reward 10, reward ceremony impact→settle→finished 순서 통과, reward restored 10 |
| settings-language-support-focus | settings_support, account_save, ui_support_entry, ui_analytics_opt_out, ui_locale_offline, ui_navigation | passed | 14/14 OK | 한국어 전환, 큰 글자, 키보드 초점 스크롤, 재시작 후 유지 |
| three-home-profiles | startup, tutorial, account_save, ui_navigation | passed | 12/12 OK | hero·map·world 각각 `play is primary skin` 통과(코드 검토 결함 D-2 참고) |
| real-bootstrap-account-and-cloud | startup, account_save, platform_end_to_end, ui_landscape | passed | 9/9 OK | |
| actual-round-cloud-save | tutorial, account_save, platform_end_to_end | passed | 7/7 OK | |
| inbox-wallet-and-store | inbox, commerce, platform_end_to_end | passed | 8/8 OK | |
| ad-server-receipt-and-optout | observability, operations, platform_end_to_end | passed | 11/11 OK | |
| link-logout-recover-and-delete | account_save, platform_end_to_end, settings_support | passed | 11/11 OK | 568x320에서는 `check deletion status with a button` 통과(설계가 적은 기존 실패는 다른 크기) |

`build/qa-round-3/ui-kit.json`(passed true, failures 0, 40항목):

| 항목 | 결과 |
|---|---|
| 팝업 open: 딤·프레임 표시, `opened` 시그널 1회, 진입 18프레임, 열린 상태 재open 무시, `closed` 시그널 뒤 숨김 | 모두 PASS |
| 팝업 reduced_motion: 딤·프레임 즉시 표시, `opened` 1회, 2프레임 내 열림(실측 1), 재open 무시, `closed` 뒤 숨김 | 모두 PASS |
| 보상 단계 순서 `["anticipation","impact","settle","done"]`, `finished` 1회, impact 파티클, skip 1회 종료, skip 뒤 present 유지 | 일반·reduced 모두 PASS |
| 효과음: attach 멱등, 늦게 추가된 버튼 포함 전부 연결(4), 버튼 down마다 재생(4), kind 메타로 소리 선택, 5개 스트림 로드 | PASS |
| 재화 칩 천 단위 구분·축약·아이콘+숫자+추가 버튼, HUD 6층 순서, 토스트 층·중앙·소멸 | PASS |
| 테마: display·body 서체 분리, number 역할, 버튼·패널 StyleBoxTexture, 초점 overlay, skin.json v2, 한글 display 서체 상이 | PASS |

`automated.json`의 checks에 `ui_kit_probe: true`가 들어갔고 `validate_outgame.py`가 이 증거로 통과했다(AC-3의 로컬 실행 근거).

## 코드 검토

대상 diff `42e1536…HEAD -- godot/game godot/tests/game tools/check.py tools/bundle.py tools/validate_outgame.py docs/qa/feature-inventory.json godot/data/outgame/outgame-profile.json` (8파일, +32/-8).

- 보상 payload `amount` (`sample_round.gd` `_collect`): `host.state.data.coins - before`를 그대로 넣는다. `state.gd` 120~123행은 `replay`가 false이고 `tutorial-first` grant가 없을 때만 coins를 10 더하므로 연습(replay) 모드와 재수령에서는 amount가 0이다. 기반 `_draw_result`는 `amount > 0`일 때만 코인 카드를 만들고 아니면 텍스트 라벨("연습 완료")만 연출하므로 설계의 "연습 모드는 amount 0으로 카운트업 없음"과 일치한다.
- 여정 새 단계: `reward ceremony impact/settle/done`은 `main.ceremony.phase`를 프레임마다 폴링(`wait_for`, 최대 300프레임)하므로 기반 `reward_ceremony.gd`의 실제 phase 전이(0.4s→0.26s→0.5s)를 검사한다. 캡처는 `settle=false`로 즉시 찍어 중간 프레임을 남긴다. `popup-open`은 `tap(inbox)`가 돌아온 직후(눌림·뗌 각 2프레임 뒤)에 찍으므로 `_clear`의 220ms `pop_in` 중간 프레임이다. `play is primary skin`은 `theme_type_variation == &"PrimaryButton"` 노드 속성을 검사한다. 다만 이 검사가 실제로 보는 버튼은 템플릿 `home.gd`의 ▶가 아니다(결함 D-2).
- `godot/game` 아래 `StyleBoxFlat` 없음. `home.gd`는 글꼴 크기 override 30을 `DisplayLabel` 변형으로 바꾸고 ▶ 버튼에 `PrimaryButton`을 붙였다. `sample_round.gd`의 ★ 버튼 `font_size` override는 글자 크기 조정이라 테마 재료와 충돌하지 않는다.
- `check.py`: `ui_kit_probe.gd`를 `ui_standard_contract_probe` 다음, 여정 앞에 넣었다. 명령 루프는 종료 코드나 `SCRIPT ERROR`/`ERROR:` 로그에서 예외를 던지므로 probe 실패는 전체 실패가 된다. `checks['ui_kit_probe'] = True`는 루프를 통과한 뒤에만 기록되므로 과장이 아니다. 로그 번호가 한 칸씩 밀리는 것 외에 기존 흐름(아키텍처·번들 검증·여정·플랫폼 여정·프로필 변이 거부)은 그대로다.
- `bundle.py`: `VERSIONS`로 1.0.0·1.1.0을 허용하고 `install`에서 역방향을 `ValueError`로 거부한다. `validate_outgame.py`는 `uiStandard.version` 1.0.0·1.1.0을 허용한다. 잠금은 1.1.0, `source.commit` `06f2519…`로 설계와 같다.
- `feature-inventory.json`에 `ui_kit`(core true, foundation false)을 추가했고 여정 첫 시나리오가 이 ID를 선언해 `check.py`의 누락 검사를 통과한다.
- 기반 `_draw_result`(addons, 이 PR이 수정하지 않는 사본)는 `ceremony.present([reward], …, target=null, counter=null, 0, 0, …)`로 부른다. counter·target이 null이라 `count_up`과 `fly_to`는 실행되지 않고 카드의 "+10" 숫자 라벨이 정적으로 뜬 뒤 페이드한다(결함 D-4).

## UX 결과

| 화면 | 확인 내용 | 결과 |
|---|---|---|
| title.png | 캠프 홈 타이틀. "A new adventure begins" 디스플레이 서체(Fredoka), 하단 6개 버튼 9분할 스킨, "Begin adventure" PrimaryButton 스킨 | 통과 |
| tutorial.png | 모달 프레임 스킨, 제목 "Gather three stars" 디스플레이 서체, ★ 버튼 큰 글자 | 통과 |
| reward-impact.png | 전체에 노란 플래시(알파 0.7) 덮임, 코인 카드가 흐릿하게 막 등장 → impact 단계 프레임 | 통과(단, "coins" 라벨이 아래로 잘림, D-1) |
| reward-settle.png | 플래시 없음, 코인 아이콘·파티클·"+10" 선명 → settle 단계 프레임. impact와 다른 프레임임 | 통과(D-1 동일) |
| result.png | 카드가 페이드아웃 중, Continue PrimaryButton | 통과 |
| home.png | 코인 ★ 10, Play PrimaryButton | 통과 |
| popup-open.png | 프레임이 94%→100% 확대 중이고 반투명, 내용 페이드 중, 뒤 캠프 보임 → 모션 중간 프레임 | 통과(딤 없음은 D-3) |
| inbox.png | 모션 완료, 목록 첫 항목 "+5 coins"가 하단에서 반쯤 잘림(스크롤 영역, ui_kit 무관 기존) | 통과 |
| settings.png | 토글 스킨, 본문 NotoSans. 위 항목이 스크롤로 잘려 선만 보임(ui_kit 무관 기존) | 통과 |
| support.png | 입력 패널 스킨, 비활성 PrimaryButton 스킨 | 통과 |
| korean.png | 제목 "언어"는 둥근 한글 디스플레이 서체(Jua), 버튼 본문 "기기 언어 따르기"는 NotoSansKR → 역할 분리 확인 | 통과 |
| large-text.png | 큰 글자를 켠 직후의 접근성 화면. 제목 "접근성"은 Jua, "큰 글자·움직임 줄이기"는 NotoSansKR. 토글 줄 글자가 커졌지만 패널 스킨 안에 머문다 | 통과 |
| keyboard-focus.png | 큰 글자 상태의 설정 화면에서 Tab으로 "지원코드" 버튼에 초점이 닿은 프레임. 버튼 둘레에 스킨 위로 어두운 두꺼운 외곽선(초점 overlay)이 보이고 스크롤 안에 있음. "설정"(Jua), 버튼 글자(NotoSansKR)가 스킨 밖으로 넘치지 않음 | 통과 |
| hero.png / map.png / world.png | 세 장이 md5까지 동일(`af3a23b3…`). 가로 모드라 세 프로필 모두 캠프 홈을 그림 | 통과(D-2 참고) |
| platform/signed-out-camp.png | "Create account" PrimaryButton, 티켓 칩 아이콘 | 통과 |
| platform/server-identifiers.png | 지원코드 STRT-TEST, Copy code PrimaryButton, "Code copied" 안내 | 통과 |
| platform/connected-camp.png | 계정 연결, ★ 10, 티켓 0 | 통과 |
| platform/server-mail-received.png | Claim all 비활성 스킨, 서버 티켓 항목(하단 잘림은 기존 스크롤) | 통과 |
| platform/localized-store.png | 상품 2개 카드 스킨, 현지 가격 | 통과 |
| platform/server-ad-confirmed.png | Watch test ad PrimaryButton, 확인 1회 | 통과 |
| platform/maintenance-reason.png | 점검 사유 디스플레이 서체 2줄 | 통과 |
| platform/deletion-status.png | 삭제 완료 상태, 버튼 2x2 스킨 | 통과 |

## 결함

취향·추측은 제외했다. 모두 치명도 낮음이며 흐름을 막지 않는다.

- D-1 (ui_kit 관련, 기반 `addons` 범위): 568x320 가로에서 보상 연출 카드의 "coins" 라벨이 화면 아래로 잘린다. 재현: 새 저장 → 별 3회 → Collect +10. 기반 `_draw_result`가 wide일 때 focus y 0.86에 카드(아이콘 64px + "+10" + "coins")를 놓아 마지막 라벨이 y 320 밖에 걸린다. reward-impact·reward-settle·result 캡처 모두에서 보인다. 템플릿 PR이 고칠 수 없는 기반 코드이므로 game-foundation 후속 이슈 대상.
- D-2 (템플릿 범위, 검증 근거): 여정 단계 `… play is primary skin`과 AC-5 "홈 ▶가 PrimaryButton 변형"의 증거가 템플릿 `home.gd`의 ▶ 버튼이 아니라 기반 `camp_home.gd`의 `play` 버튼을 본다. `main.gd`가 `landscape = true`를 두고 `_home()`이 landscape에서 `_camp_home`으로 바로 돌아가므로 `stage_factory`(= `home.gd`)는 호출되지 않고, hero·map·world 캡처가 바이트까지 같다. 결과적으로 이 PR의 `home.gd` 변경(DisplayLabel·PrimaryButton)은 어떤 여정에서도 실행되지 않은 채 "통과"로 기록된다. `landscape = true`와 `home.gd` 미도달은 기준 커밋에도 있던 상태라 동작 회귀는 아니지만, 단계 이름과 AC-5 문구가 실제 검사 대상과 다르다. 권장: 단계 이름을 캠프 홈 버튼으로 고치거나, `home.gd`를 인스턴스화하는 검사를 추가하거나, 설계 AC-5 문구를 캠프 홈 Play로 바꾼다.
- D-3 (설계 문구 불일치, 기반 범위): 설계 화면 표가 모달(우편·설정·지원)에 "딤"을 적었지만 템플릿의 이 화면들은 기반 `_clear`의 `backing` 패널 `pop_in`과 내용 페이드만 쓰고 딤 노드가 없다(popup-open.png에서 뒤 캠프가 밝게 보임). 딤은 ui_kit `popup_base`에만 있고 이 화면들은 그것을 쓰지 않는다. 패널이 12px 여백만 남기고 덮어 실사용 차이는 작다.
- D-4 (설계 문구 불일치, 기반 범위): AC-4 "코인 10으로 카운트업"은 실행되지 않는다. `_draw_result`가 counter·target을 null로 넘겨 `count_up`·`fly_to`가 돌지 않고 "+10" 숫자 라벨이 정적으로 떠서 페이드한다. 측정 가능한 기대 결과(캡처 3장, coins 10)는 충족한다.

ui_kit과 무관한 기존 문제(기준 커밋에도 있음, 이번 판정에 넣지 않음): 320px 높이에서 우편 목록과 설정 토글 목록이 스크롤로 잘려 첫·마지막 항목이 반만 보임, 결과 화면 헤드라인 "+10 coins"가 왼쪽 정렬이라 중앙 제목과 어긋남, 설계 AC-1·AC-6의 unittest 명령 표기.

## 판정

pass. AC-1~AC-6의 명령·여정·probe·캡처가 모두 통과했고 서체 역할, 스킨, 팝업 모션, 보상 3단계, reduced_motion, 접근성 경로가 568x320 캡처와 probe로 확인됐다. 결함 4건은 모두 낮음이며 D-1·D-3·D-4는 기반 묶음 범위, D-2는 검증 근거 표기 문제라 병합 전 단계 이름 또는 AC-5 문구를 바로잡기를 권한다.
