# Android와 iOS 빌드

이 저장소 자체의 내부 테스트 앱은 Seorilabs Game Starter, com.seorilabs.startergame이다. 새 제품을 생성하면 이 마켓 식별자와 서명을 그대로 사용하지 않는다. init:game은 로컬 제품 설정만 바꾸므로 native 검사에서 마켓 불일치를 잡는다. 새 앱의 두 market config, Android package/name, iOS bundle/team과 exportOptions.plist를 명시적으로 설정하고 각 마켓에 새 앱을 등록한다. 원본 demo의 키와 프로파일은 복제되지 않는다.

## 개발 환경

Godot 4.7.2, export templates, Python 3.11 이상을 사용한다. npm 명령은 Node 24가 필요하다. Android는 JDK 17과 Android SDK 36, iOS는 macOS와 Xcode가 필요하다. 기본 로컬 게임 실행에는 SDK와 자격증명이 필요 없다.

```sh
npm test
npm run check:native
npm run check:release
npm run build:android
npm run build:ios
```

Android는 GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER와 GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD 환경 변수를 요구한다. 비밀번호를 명령 인자나 export_presets.cfg에 넣지 않는다. build:android는 서명 AAB를 build/android에 만든다. build:ios는 build/ios/startergame.xcodeproj를 만들며 서명 archive와 업로드는 중앙 workflow가 수행한다. Android build template와 Xcode 프로젝트는 Git에서 제외한다.

네이티브 프리셋의 runnable=false는 Godot의 자동 연결 기기 탐색을 막는다. 이름을 지정한 export와 archive에는 영향을 주지 않는다. 이를 켜거나 기기를 조회할 권한은 이 빌드 절차에 포함되지 않는다.

## 내부 배포

Initialize Release Version Ledger를 신규 저장소에서 먼저 실행하고, Release Tag에서 사용자가 정한 v1.0.0을 명시한다. 기존 출시 이력이 있는 제품은 실제 provider readback을 사용하는 중앙 원장 절차를 먼저 따른다. 태그나 번호를 직접 계산하거나 이동하지 않는다.

태그의 GitHub Release에 release-notes.json과 같은 후보 SHA의 development-evidence.google-play.before-build.json, development-evidence.app-store.before-build.json을 첨부한다. 중앙 검증은 실제 CI의 출처와 성공, 승인한 test-track 범위를 확인한다.

Deploy Google Play와 Deploy App Store Internal은 release_tag와 upload를 받는다. 기본 upload=false는 빌드만 한다. upload=true여도 Play internal과 TestFlight 내부 전용으로 한정한다. Deploy Native Internal Tests는 두 레인을 함께 실행하며, 한 마켓 실패로 다른 마켓 성공을 덮지 않는다. iOS는 공개 저장소의 GitHub-hosted macOS에서 Apple Distribution으로 서명한다.

GitHub environment google-play에는 앱 전용 업로드 키의 세 Secret과 기존 WIF provider, publisher email 및 alias 변수가 필요하다. app-store에는 중앙 workflow가 선언한 기존 Apple Distribution, 앱 전용 provisioning profile, API key와 임시 CI keychain Secret, APPLE_TEAM_ID 변수가 필요하다. 로컬 카탈로그 원본을 확인해 필요한 값만 명시적으로 연결한다. secrets: inherit는 사용하지 않는다.

서명된 파일의 실제 ID, 버전과 서명을 먼저 확인한다. 업로드 뒤 Play 트랙의 versionCode, TestFlight의 VALID, 내부 그룹과 테스터를 provider에서 다시 읽는다. workflow green이나 upload 응답을 내부 테스트 완료 또는 공개 출시로 대신하지 않는다.
