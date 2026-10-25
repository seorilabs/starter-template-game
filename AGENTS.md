# 게임 템플릿 작업 지침

한국어로 간결하게 보고한다. 제품 규칙은 GDScript의 godot/game/core, 장면과 전용 그림은 features, 저장과 호스트 구현은 adapters, 연결은 bootstrap에 둔다. 공통 수정은 game-foundation 원본에서 하고 검수한 묶음을 설치한다. addons의 고정 파일을 직접 고치지 않는다.

로컬 실행은 서버, 자격증명과 스킬 설치 없이 동작해야 한다. `npm test`, `npm run test:core`, `npm run check:architecture`와 작은 화면 렌더를 검증한다. 미실행을 통과로 기록하지 않는다. 출력은 build에 둔다.

최신 중앙 개발 계약과 리뷰 정책을 적용하고 한국어 Ready PR을 사용한다. 사용자 수정은 보존한다. 출시 범위는 승인한 test-plan.json을 따르며 release null이면 PR 병합에서 마친다. 기기 사용은 별도 명시적 승인이 필요하다.
