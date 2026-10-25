# 구조

공통 코드는 godot/addons/seorilabs_game 원본을 game-foundation에서 갱신한다. 제품은 game/bootstrap에서 이를 연결한다. game/core의 domain과 use_cases는 RefCounted 기반 순수 규칙이며 ports를 통해 저장한다. game/adapters는 그 포트를 구현한다. game/features에는 장면과 스크립트, 전용 assets를 함께 둔다. apps/ait는 호스트다. 서버는 기본 미채택이다. `npm run check:architecture`로 공통에서 제품 참조와 core에서 Node, UI 및 SDK 접근을 검사한다.
