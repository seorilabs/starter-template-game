# 공통 플랫폼

SDK 정식 v1.0.0이 addon에 고정돼 있으며 출처와 해시는 common-bundle.lock.json에 있다. godot/config/runtime.json의 로컬 모드에서는 SDK 객체와 운영 연결을 만들지 않는다. 서버가 필요해질 때 제품 등록과 실제 SDK 검증 범위를 승인받고 game/adapters와 bootstrap에서 연결한다. 공통 코드를 고쳐 제품 식별자나 비밀값을 넣지 않는다.
