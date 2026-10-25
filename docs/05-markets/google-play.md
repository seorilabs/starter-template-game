# Google Play 내부 테스트

Seorilabs Game Starter, com.seorilabs.startergame, 기본 언어 en-US의 무료 게임이다. 실제 광고, 결제, 계정과 서버 전송은 없다. 앱 내부의 서비스 계약 예제는 운영 SDK 연동을 의미하지 않는다. 내보내기에서 테스트 대역을 제외한다.

Android 16 API 36, arm64, Gradle AAB와 앱 전용 업로드 키를 사용한다. 새 Play 앱 서명 설정은 대상 콘솔에서 확인하며 기존 다른 앱의 키를 쓰지 않는다. 배포 source는 play-store/google-play.config.json이고 자격증명은 저장소에 넣지 않는다.

Deploy Google Play는 명시적 태그만 받고 기본값은 업로드 없는 빌드다. upload=true일 때도 internal/completed만 전달한다. 버전과 키 fingerprint를 산출물에서 읽고 같은 versionCode가 실제 internal 트랙에 있는지 확인한다. 테스터를 선택하고 참여 링크까지 확인한다.

공개 스토어 이미지, IARC, 한국 게임 등급, Data Safety와 production access는 이번 내부 테스트 완료로 간주하지 않는다. 공개 출시는 승인되지 않았다.
