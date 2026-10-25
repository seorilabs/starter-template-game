# Lizard Tycoon StoreKit 2 plugin

Godot 공식 integration 저장소 `godot-sdk-integrations/godot-storekit2`의
`beabb0464072175b59281cab825c9d23761fc237`를 repo `build.env`의 Godot `4.7.2-stable`에 맞춰 fork한
iOS 15+ 플러그인이다. 라이선스는 같은 디렉터리의 `LICENSE`를 따른다.

이 fork는 서버 권위형 IAP 계약을 위해 다음을 추가한다.

- 구매 시 Firebase uid에서 파생한 `appAccountToken` 전달
- transaction/original transaction ID 반환
- 서버 검증·entitlement commit 전 client-side `finish()` 금지
- current entitlement, unfinished transaction, 등록 상품별 latest 환불 거래 복구
- StoreKit 시스템 환불 요청 sheet와 접수·취소 상태 bridge
- foreground window scene 기반 App Store 인앱 리뷰 요청 bridge
- 익명 인증 session을 위한 iOS Keychain read/write/delete

커밋된 xcframework는 `ios/plugins/godot-storekit2`에 있다. 소스를 변경한 뒤에는
repo root에서 `scripts/build_ios_storekit_plugin.sh`를 실행한다.
