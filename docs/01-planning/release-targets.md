# 출시 대상

이 템플릿으로 만드는 게임은 모바일 또는 PC로 내고, 마켓은 Google Play, App Store와 Steam 세 곳이다(2026-11-26 결정). 제품마다 설계에서 실제로 낼 마켓을 고르고 확정값을 이 문서에 적는다.

| 마켓 | 플랫폼 | export preset | 템플릿이 준비한 단계 |
|---|---|---|---|
| Google Play | Android | Android | 서명 AAB와 internal 트랙 업로드 workflow |
| App Store | iPhone | iOS | Xcode 프로젝트와 TestFlight 내부 업로드 workflow |
| Steam | PC: Windows, macOS, Linux | Windows Desktop, macOS, Linux | 로컬 export까지 |

Steam은 Steamworks 앱 등록, SteamPipe 업로드, GodotSteam 연결과 심사 절차가 아직 없다. Steam 출시 작업은 export 산출물을 만든 뒤 등록 단계에서 멈추고, 첫 Steam 출시 후보가 생기면 실제 계정으로 확인하며 절차를 만든다. Pages는 팀과 기획자가 보는 웹 플레이테스트 채널이며 마켓이 아니다.

## 이 저장소의 내부 테스트 앱

앱 이름은 Seorilabs Game Starter, Android 패키지와 iOS Bundle ID는 com.seorilabs.startergame이다. 첫 태그는 사용자가 선택한 v1.0.0이며 숫자 빌드는 중앙 원장이 할당한다. 코드의 기본 버전 값은 출시 버전 정본이 아니다.

- Google Play: internal 트랙과 테스터 참여 링크까지. 계정 소유권과 API 접근은 배포 시 콘솔에서 확인한다.
- App Store: TestFlight 내부 그룹까지. Apple Team은 HCDUXX4Z3X다. 앱은 iPhone을 대상으로 한다.
- Steam과 Pages: 이번 실행에서 배포하지 않는다.
- Platform과 Firebase: 실제 서비스에 연결하고, 광고는 AdMob 비수익 테스트 버전, 결제는 마켓 테스트 수단만 쓴다([네이티브 빌드](../06-release/native-builds.md)의 1.1.0 플랫폼 검수). init:game으로 만든 새 게임은 서버 없이 로컬 저장으로 시작한다.

기기 설치와 실행은 수행하지 않는다. 내부 배포 완료를 기기 QA나 공개 출시로 표현하지 않는다. 심사와 공개 출시는 별도 범위다.
