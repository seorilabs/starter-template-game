# 설계: 마켓 재정의(앱인토스 제거와 PC 데스크톱 export)

- 설계 ID·버전·원본 커밋: 2026-11-26-markets-v2 v1, 기준 `bcb61a78580f001a33f27c7fb255f5dfc495c30e`(main)
- 상태: 승인(상위 설계의 starter 범위)
- 승인자·시각·근거: Ilhwan Seo, 2026-11-26. agent-config 설계 `docs/design/2026-11-26-game-skill-system-v2/design.md`(v1)와 같은 폴더의 `approval.json`을 선택 질문 "승인, 병합까지 진행"으로 승인했다. 그 설계의 "포함" 표 starter 행, "앱인토스 격리" 표, 인수조건 AC-12·AC-15·AC-16과 등급표(starter L3, 개발 환경)가 이 설계의 범위다. 상위 설계는 아직 agent-config에 병합되지 않아 승인 커밋은 그 PR 병합 뒤 적는다.
- 관련 Issue·PR·검수: PR은 이 설계와 같은 브랜치(`markets-v2`)로 연다. game-foundation 1.2.0 묶음 설치는 별도 후속 단계다.

## 목적·범위·근거

2026-11-26 결정으로 Seorilabs 게임은 모바일 또는 PC로 내고, 마켓은 Google Play, App Store, Steam이다. 새 게임은 앱인토스를 대상으로 하지 않는다. 이 템플릿은 새 게임의 출발점이라 지금 상태로 두면 새 게임이 앱인토스 호스트, 배포 workflow와 문서를 그대로 물려받고, PC로 낼 export preset은 하나도 없다.

| 구분 | 내용 |
|---|---|
| 포함 | 앱인토스 코드(`apps/ait/`, `apps-in-toss/`, `godot/game/adapters/ait_host.gd`), workflow(`deploy-apps-in-toss.yml`, 전체가 앱인토스 배포인 `nightly.yml`), 마켓 문서와 다른 문서·PR 양식·검사 스크립트·초기화 테스트의 언급 삭제. Windows Desktop, macOS, Linux export preset 추가, 데스크톱 텍스처 압축 설정, 출시 preset의 테스트실(`addons/seorilabs_game/dev/**`) 제외와 Web 플레이테스트 preset의 `playtest` 기능 태그, `check_native.py` 정적 검사와 단위 테스트, 출시 대상 문서 |
| 제외 | game-foundation 1.2.0 묶음 설치(후속 단계), `godot/addons/seorilabs_platform/**`의 `ait` 값과 `tools/validate_outgame.py`의 `apps_in_toss` 값(game-foundation이 소유한 공통 사본이고 기존 게임이 쓴다), Steamworks 등록·SteamPipe 업로드·GodotSteam 연결, PC 해상도·창 모드·키 설정 구현, 이미 생성된 게임의 전환, 마켓 업로드 |

전후 예시: 지금 `npm run init:game`으로 만든 새 게임에는 `apps/ait/host.js`와 `Deploy AppsInToss` workflow가 들어 있고, `godot --export-release "Linux" …`는 preset이 없어 실패한다. 변경 뒤 새 게임에는 앱인토스 파일이 없고 같은 명령이 Linux 실행 파일과 pck를 만든다.

## 사용자 흐름·화면 상태

게임 화면과 흐름은 바뀌지 않는다. 바뀌는 것은 개발자가 보는 흐름이다.

1. `npm run init:game`으로 새 게임을 만든다. 앱인토스 파일 없이 로컬 저장 모드로 시작한다.
2. 데스크톱 export 명령으로 Windows, macOS, Linux 산출물을 만든다. 테스트실과 테스트 파일은 들어가지 않는다.
3. Pages 웹 플레이테스트(Web preset)는 `playtest` 기능 태그로 테스트실을 포함한다.
4. Steam 출시 작업은 export 산출물을 만든 뒤 Steamworks 등록 단계에서 멈춘다.

## 구조·책임·의존성

| 파일 | 바뀌는 것 |
|---|---|
| `godot/export_presets.cfg` | Web에 `custom_features="playtest"`. Android, iOS에 `addons/seorilabs_game/dev/**` 제외 추가. preset 3 Windows Desktop(x86_64), 4 macOS(universal, 내장 ad-hoc 서명, 공증 없음, bundle identifier `com.seorilabs.startergame`), 5 Linux(x86_64). 데스크톱 세 preset은 모바일과 같은 include·exclude 목록을 쓰고 `runnable=false`다 |
| `godot/project.godot` | `rendering/textures/vram_compression/import_s3tc_bptc=true`. 기존 `import_etc2_astc=true`는 유지 |
| `tools/check_native.py`, `tools/test_native.py` | 아래 규칙을 검사하고 규칙마다 실패 사례를 단위 테스트로 둔다 |
| `tools/test_init_game.py` | 앱인토스 설정 고정 파일 삭제, export preset이 초기화 뒤에도 그대로인지 확인 |
| 문서 | `docs/01-planning/release-targets.md`(마켓 표), `docs/05-markets/README.md`(Steam 안내), `docs/06-release/native-builds.md`(데스크톱 export, 테스트실 규칙), `docs/06-release/ci-cd-workflows.md`, README, 그 밖의 앱인토스 언급 |

`check_native.py`가 강제하는 규칙:

- `Web`, `Android`, `iOS`, `Windows Desktop`, `macOS`, `Linux` preset이 각각 하나씩 있고 platform 값이 이름과 같다.
- Web을 뺀 모든 preset(나중에 추가하는 preset 포함)의 exclude_filter에 `tests/**`, `game/scenarios/**`, `addons/seorilabs_game/dev/**`가 있고, include_filter에 글꼴 OFL과 platform LICENSE가 있으며, `playtest` 기능 태그가 없다.
- Web preset은 `playtest` 태그가 있고 테스트실을 제외하지 않는다.
- `import_s3tc_bptc`와 `import_etc2_astc`가 둘 다 켜져 있다.
- macOS bundle identifier가 제품 ID와 같다. Android, iOS와 같이 init:game 뒤 마켓 식별자를 바꾸지 않았으면 불일치로 알린다.

의존: Godot 4.7.2와 같은 버전의 export 템플릿. 중앙 Godot 검사는 export하지 않으므로 실제 산출물은 로컬 export로 확인한다.

## 데이터·인터페이스·실패 처리

- 저장 형식과 `user://` 위치는 바뀌지 않는다. 데스크톱의 저장 위치는 Godot 기본값(`<사용자 데이터>/Godot/app_userdata/<config/name>`)이다.
- `ait_host.gd`는 어느 장면이나 스크립트에서도 참조하지 않았고(`SeorilabsHost` 브리지는 `apps/ait/host.js`만 설치했다), 지워도 실행 경로가 바뀌지 않는다.
- Godot은 export 출력 폴더를 만들지 않아 폴더가 없으면 export가 실패한다. 문서의 명령은 `mkdir -p`를 먼저 실행한다.
- export 템플릿이 없거나 버전이 다르면 Godot export가 실패한다. 템플릿 설치는 기존 `tools/ensure_godot.sh --with-export-templates`를 쓴다.
- 이 저장소의 내부 테스트 앱은 Platform 모드라 데스크톱에서 실행하면 홈의 주 버튼이 "계정 만들기"다. PC 로그인과 Platform의 PC 플랫폼 값은 상위 설계가 제외했다. init:game으로 만든 새 게임은 로컬 모드라 바로 플레이할 수 있다.

## 품질 요구사항

- 출시 빌드(모바일, 데스크톱)에 테스트실, 테스트, 검수 시나리오가 들어가지 않는다.
- 데스크톱 빌드가 1280×720에서 실행되어 타이틀과 플레이 화면을 보인다.
- 문서는 Steam의 현재 준비 단계(로컬 export까지)와 멈추는 지점(등록)을 사실대로 적는다.

## 대안·주요 결정

| 결정 | 고른 것 | 고르지 않은 것과 이유 |
|---|---|---|
| 테스트실 제외 범위 | Web을 뺀 모든 preset에 강제 | 데스크톱만: 모바일 출시 빌드에도 테스트실이 들어간다 |
| Web preset의 역할 | Pages 웹 플레이테스트 전용(`playtest` 태그, 테스트실 포함) | 출시용 Web preset 추가: 웹은 마켓이 아니다. 필요하면 이름이 다른 preset을 만들고 검사기가 테스트실 제외를 요구한다 |
| macOS 서명 | Godot 내장 ad-hoc(`codesign/codesign=1`), 공증 없음 | macOS 호스트 기본값인 Xcode codesign: 서명 identity가 없는 환경과 Linux에서 export가 실패한다. 배포 서명과 공증은 첫 Steam 출시 때 공식 문서로 확인한다 |
| macOS bundle identifier | 내부 테스트 앱과 같은 값, 검사기가 제품 ID와 비교 | 빈 값: macOS export가 거부한다. 별도 값: init 뒤 불일치를 Android, iOS와 같은 검사로 잡지 못한다 |
| 사용자 데이터 폴더(`use_custom_user_dir`) | 이번에 켜지 않음 | Godot 4.7.2는 `custom_user_dir_name`이 비면 `config/name`을 쓰므로 init:game이 바꾼 이름을 따라가게 할 수는 있다. 그러나 Web은 이 값을 `/userfs` 아래 경로에 붙여 Pages 플레이테스트 저장 위치가 바뀌고, 데스크톱 저장 위치는 Steam Cloud 경로와 함께 첫 Steam 출시 때 정할 일이다. Android와 iOS는 이 값을 쓰지 않는다 |
| `nightly.yml` | 파일 삭제 | 앱인토스 job만 빼기: 남는 job은 nightly 표식 태그를 옮기는 일뿐이다 |
| 과거 설계 기록의 앱인토스 언급 | 유지 | 승인 기록은 당시 결정이므로 고치지 않는다 |

## 인수조건·테스트·검수

| 조건 ID | 관찰할 동작·통과 기준 | 테스트 방법·환경 | 격리 데이터·시작 상태 | 기대 결과 | 증거 |
|---|---|---|---|---|---|
| AC-1 (상위 AC-15) | 앱인토스 파일·workflow·문서·테스트가 없고 `npm test`와 headless 여정이 통과한다 | `grep -rniE "apps-in-toss\|appsintoss\|앱인토스\|granite\|\bait\b"`, `npm test` | 후보 트리 | 검색 결과는 `godot/addons/seorilabs_platform/**`, 과거 설계 기록 한 줄, 이 설계 문서뿐. 테스트 통과 | 아래 검증 기록, CI |
| AC-2 (상위 AC-15) | init:game이 앱인토스 없이 동작하고 export preset을 보존한다 | `test_init_game.py`, 후보 복사본에서 `init_game.py --name "Orbit Stars" --id com.example.orbit --home hero` | 임시 복사본 | 초기화 성공, 로컬 모드, native 검사가 Android·iOS·macOS 식별자 불일치를 알림 | 검증 기록 |
| AC-3 (상위 AC-12) | 출시 preset에 테스트실이 없고 Web 플레이테스트 preset에만 있다 | `check_native.py`와 `test_native.py`, 임시 복사본에 `dev/test_room` 파일을 둔 6개 preset `--export-pack` 목록 | 임시 복사본 | 정적 검사 통과. 테스트실 파일이 Web pack에만 있다 | 검증 기록 |
| AC-4 (상위 AC-16) | macOS export가 실행되어 1280×720에서 타이틀과 플레이가 보인다. Windows·Linux export가 성공한다 | 로컬 `--export-release` 세 preset, macOS 앱을 `--write-movie`로 녹화하며 실행 | 격리 HOME | 실행 화면 캡처, 산출물 생성 | 검증 기록 |
| AC-5 | 데스크톱 preset 누락, 테스트실 제외 누락, 다른 preset의 `playtest` 태그, Web의 태그 누락·테스트실 제외, S3TC 설정 누락, macOS 식별자 불일치를 각각 거부한다 | `python3 -m unittest discover -s tools -p 'test_native.py'` | 임시 복사본 | 모든 사례에서 해당 오류 | 테스트 로그 |
| AC-6 | 출시 대상 문서가 Google Play, App Store, Steam(PC)과 Steam의 멈춤 지점을 적고, 마켓 문서가 PC·Steam 스킬 문서 경로를 가리킨다 | 문서 검토, `bash scripts/check_docs.sh` | 후보 트리 | 통과 | 검사 출력 |
| AC-7 | 이 테스트 계획이 중앙 검증기를 통과한다 | `testPlanProblems(test-plan.json, feature-inventory.json)` | 후보 트리 | `[]` | 검사 출력 |

- TDD 대상: `test_native.py`의 새 사례 6개를 먼저 추가해 실패를 확인한 뒤 `check_native.py`를 고쳤고, 그다음 preset과 project 설정을 바꿔 계약 테스트까지 통과시켰다.
- 테스트 계획: [test-plan.json](test-plan.json)

| 항목 | 값 |
|---|---|
| 등급 | L3 전체 회귀. `godot/game/**`의 파일 삭제와 export preset(`startup`의 platformPaths) 변경이 핵심 기능 14개를 건드린다 |
| 실행 환경 | 개발 환경(headless E2E, 로컬 데스크톱 export와 실행). 실기기 없음 |
| 검증기 하한과 낮춘 항목·사유 | 낮춘 항목 없음. 기능 목록에 foundation 기능이 없어 `foundationRerun` false |
| 새 화면·UI 개편 | 아니오 |
| 출시 마켓·끝 지점 | 없음(`release: null`). PR 병합에서 마친다 |

- 검수: 상위 설계 등급표대로 작성자와 다른 에이전트의 검토 또는 확인된 CI 실행을 PR에 남긴다.
- 실행 못할 조건·필요한 승인: Windows와 Linux 산출물은 macOS 개발 환경에서 실행하지 않았다. export 성공과 파일 생성까지만 확인했다. 기기 승인은 필요 없다.

### 구현 검증 기록(2026-11-26, macOS, Godot 4.7.2)

- `npm test`: 단위 테스트 29개 통과, native 검사 `ok`, 여정 8개 시나리오 통과.
- `python3 tools/check.py --capture --size 1280x720`: 8개 시나리오 통과, 타이틀·안내·결과·홈 1280×720 캡처.
- export: Windows Desktop exe 109 MB와 pck 10 MB, macOS universal 앱(zip 70 MB, 실행 파일 x86_64·arm64, ad-hoc 서명), Linux x86_64 실행 파일 74 MB와 pck 10 MB.
- macOS 실행: 내부 테스트 앱은 홈까지, init:game으로 만든 복사본은 홈에서 "모험 시작"을 눌러 별 세 개를 모으고 보상 버튼이 뜨는 데까지 1280×720으로 녹화했다. 캡처 원본은 NAS로 옮기고 이 저장소에는 넣지 않는다.
- `--export-pack`: 임시 복사본에 `addons/seorilabs_game/dev/test_room/test_room_probe.gd`를 두고 6개 preset을 내보냈다. 테스트실 파일은 Web pack에만 있었고, 모든 pack에 `tests/`와 `game/scenarios/`가 없었다.

## 적용·운영·되돌리기

1. 앱인토스 제거 → 데스크톱 preset과 검사(테스트 먼저) → 출시 대상 문서 → 이 설계와 test-plan 순서로 커밋한다. 로컬 `npm test`, 데스크톱 export, 로컬 mcode 리뷰 뒤 한국어 Ready PR을 열고 CI가 통과하면 병합한다.
2. 되돌리기: PR 전체를 revert한다. 저장 형식과 위치가 바뀌지 않아 데이터 영향은 없다. 앱인토스 파일은 revert로 돌아온다.
3. 후속 game-foundation 1.2.0 설치: 묶음이 `addons/seorilabs_game/dev/`를 설치하면 이미 들어간 제외 규칙이 출시 preset에서 빼고, Web은 포함한다. 설치 뒤 데스크톱 preset 하나를 `--export-pack`해 테스트실이 빠졌는지, 내보낸 빌드가 빠진 스크립트 오류 없이 시작하는지 다시 본다.
4. 남은 위험: Godot 에디터로 프로젝트를 열면 데스크톱 preset의 생략한 옵션이 기본값으로 채워져 `export_presets.cfg`에 변경이 생길 수 있다. 의미는 같으므로 그 변경을 커밋해도 된다.

## 승인·추적

- 원본: 이 문서와 `test-plan.json`의 같은 커밋.
- 상위 설계: agent-config `docs/design/2026-11-26-game-skill-system-v2/design.md` v1(2026-11-26 승인).
- PR과 CI 실행은 PR을 연 뒤 이 문서에 연결한다.
