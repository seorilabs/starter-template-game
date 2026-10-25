# 실행 가능한 게임 템플릿

2026-10-25 사용자가 제공한 게임 템플릿과 공개 레퍼런스의 폴더 구조를 구현하라는 지시가 승인 근거다. 공통 원본은 game-foundation이며 제품 코드는 game에서 수정한다. GDScript core와 장면 가까운 features, 저장과 호스트 adapters를 쓴다. 상세 구조와 인수조건은 [공개 원본 설계](https://github.com/seorilabs/game-foundation/blob/feat/public-foundation/docs/design/2026-10-25-game-foundation/design.md)에 있다.

기본 타이틀, 안내, 별 3개 수집, 결과, 저장, 로비와 재실행을 제공한다. 초기화는 이름, 로컬 식별자와 세 홈 중 하나만 바꾼다. 미확정 마켓 값은 보존한다. 기존 godot/game/core와 firebase 골격은 실제 GDScript 구조와 로컬 모드로 대체한다. 기존 게임에는 적용하지 않는다.

AC-01 오프라인 복제 실행과 복원, AC-02 참조 분리, AC-03 해시 변조 차단, AC-04 공통 계약, AC-05 작은 화면과 두 언어, 큰 글자, 입력과 초점, AC-06 대역 export 제외와 소스 불변, AC-07 초기화의 범위 보존, AC-08 Pages 수동 실행과 PR 병합을 검사한다. L3 dev와 독립 기능 및 화면 3회다. 동일한 소프트 어드벤처 방향을 사용한다. release null이며 기기와 실제 결제, 운영 서비스 및 마켓은 제외한다. 복원은 이전 고정 묶음을 재설치하며 공통 파일 사용자 수정이 있으면 덮어쓰지 않는다.
