# TestFlight 내부 테스트

Seorilabs Game Starter의 Bundle ID는 com.seorilabs.startergame, SKU는 seorilabs-starter-game, Apple Team은 HCDUXX4Z3X다. 실제 수집과 전송, 광고, 결제와 로그인이 없는 로컬 게임이다. 비면제 암호화는 사용하지 않는다.

공개 저장소이므로 중앙 Godot App Store workflow와 GitHub-hosted macOS에서 기존 Apple Distribution과 앱 전용 App Store 프로파일로 서명한다. Xcode Cloud와 자체 macOS 러너를 사용하지 않는다. 빌드 번호는 중앙 태그 영수증을 유지한다. AppIcon은 기존 별 SVG를 사용하며 내보낸 iOS 아이콘의 alpha 채널을 제거한다.

exportOptions.plist의 testFlightInternalTestingOnly=true로 내부 테스트 전용 업로드를 한다. 처리 VALID, 내부 그룹에 해당 빌드 연결과 유효한 테스터를 각각 확인한다. 앱 등록은 웹 콘솔에서 수행하며 API는 Bundle ID로 앱을 찾는다. 추가 인증이 필요하면 그 상태를 보존한다.

테스트 안내: 안내를 완료하고 별 세 개를 모은 뒤 홈으로 돌아가세요. 앱을 다시 열어 진행이 복원되는지 확인하세요.

App Review, 외부 TestFlight, App Privacy 제출과 공개 배포는 실행하지 않는다. 실제 기기에서 실행했다고 주장하지 않는다.
