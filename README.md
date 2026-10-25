# Seorilabs Game Template

Godot 4.7.2와 Python 3.11 이상이 설치돼 있으면 복제 후 네트워크나 개인 스킬 없이 실행한다.

```sh
npm start
npm test
npm run init:game -- --name "Orbit Stars" --id com.example.orbit --home hero
```

`hero`, `map`, `world` 중 홈을 선택한다. 초기화는 제품 이름, 로컬 ID와 홈 설정을 바꾸고 마켓 식별자, 미확정 값과 공통 코드를 보존한다. 기본 게임은 타이틀, 안내, 별 3개 수집, 결과, 로비와 저장 복원까지 동작한다.

공통 UI와 기능 원본은 [game-foundation](https://github.com/seorilabs/game-foundation)이다. addons는 검수한 배포본이며 common-bundle.lock.json의 원본 커밋과 해시로 고정한다. 수정은 원본에서 하고 검수한 묶음을 `python3 tools/bundle.py install --bundle /absolute/common.tar.gz`로 적용한다. 기존 공통 파일에 수정이 있으면 중단한다.

제품 규칙은 godot/game/core, 장면과 전용 그림은 features, 저장과 호스트 연결은 adapters, 서비스 연결은 bootstrap에 둔다. `stage_factory`, `launch_game`, `score_provider`와 서비스 주입을 사용한다. 기본 언어는 GDScript다. 서버는 기본 미채택이며 필요성이 확정될 때 firebase를 추가한다. AppsInToss 호스트는 apps/ait에 둔다.

`npm test`는 공통 계약과 실제 입력, 저장 복원을 실행하고 추적 파일을 바꾸지 않는다. `python3 tools/check.py --capture --size 320x568 --out build/review-320`으로 실제 렌더를 검사한다. 대역은 export에서 제외한다. 개발 실행, 기기, 실제 결제와 마켓 검증을 구분한다. 미실행은 통과가 아니다.

기본 CI는 검사만 실행한다. Pages와 마켓 workflow는 수동이다. 현재 demo 앱의 승인 범위는 Google Play 내부 테스트와 TestFlight 내부 배포까지다. 실제 기기 검증, 심사 제출과 공개 출시는 포함하지 않는다. Seorilabs PR은 최신 중앙 리뷰 정책을 적용하고 한국어 Ready로 작성한다. 사용자 작업은 보존한다.

첫 실행은 `python3 tools/run.py`로도 할 수 있습니다. `npm start`와 `npm test` 명령에는 Node.js 24가 필요합니다. 자원 준비는 네트워크를 사용하지 않으며 생성 캐시는 Git에 넣지 않습니다.

Android AAB와 iOS Xcode 프로젝트, CI 서명 archive와 내부 배포는 [네이티브 빌드](docs/06-release/native-builds.md)를 따른다. 두 채널의 실제 등록과 처리 상태는 코드와 분리해 읽는다.
