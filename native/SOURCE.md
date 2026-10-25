# 네이티브 연결 출처

SeoriAccountLink의 Android 및 iOS 소스와 Android export plugin은 Seorilabs가 작성한 Bloomhand의 `90a13022cddc5cce834a2ae55d78677d41489345`에서 가져왔다. 공급자 nonce와 Apple authorization code, 실제 App Check 경계를 유지한다.

스타터에서는 다른 게임의 Firebase 초기화에 의존하지 않도록 공개 옵션을 받는 초기화 메서드를 추가한다. Godot 4.7.2 헤더로 iOS 16.0 대상 라이브러리를 다시 빌드하며 다른 작업을 종료하거나 홈 캐시를 필수 경로로 쓰지 않는다. Android는 같은 엔진 버전의 Gradle wrapper를 쓴다.

Firebase 및 Google 라이브러리는 공식 배포본의 버전과 해시를 빌드 도구에 고정하고 해당 라이선스를 보존한다. 관리자 키나 테스트 App Check 비밀값은 앱에 포함하지 않는다.

StoreKit 2 source uses the `seorilabs/lizard-tycoon` fork at `3044aa8916b4da369dd8b3b12d48a3a4e2339051`, under `native/ios/godot-storekit2`. The explicit transaction-finish and unused Photos bridge removal patches, plus market adapters, come from `seorilabs/merge-lizard` at `69f825c237f483c63dde1e81e6b0591fb16a58b8`. The patches are applied to the checked-in source. The original MIT license is retained. `tools/build_ios_storekit.py` compiles the sources with the same pinned Godot headers as the identity bridge.

Google Play Billing uses official `godot-sdk-integrations/godot-google-play-billing` 3.3.0 with Billing Library 9.1.0. The release archive SHA-256 is `20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568`. Wrapper source and its MIT license are retained; native binaries are fetched from this verified archive during build preparation.

광고는 Poing Studios AdMob 5.1.0 정식 배포본을 고정한다. GDScript 원본과 각 플랫폼의 Godot 4.7.2 native template 해시는 `dependencies.lock.json`에 있다. 미디에이션 사업자용 native binary는 설치하지 않는다. 개발 검수는 명시적인 경계 대역을 주입하므로 upstream의 자동 Editor mock 생성만 제거했다. 이 변경 파일과 이유를 잠금 파일에 기록하며 테스트 대역과 C# 예제는 출시 내보내기에서 제외한다.

iOS에서는 추적 허용 창을 요청하지 않고, 광고 초기화 전 이 앱에 남은 IAB 광고 선택 값을 정리하며 비개인화 요청을 사용한다. Android는 Google UMP의 실제 선택 결과를 확인한다. 광고 시청 callback은 지급 근거가 아니며 서버 SSV 확인과 영속 기록 후에 수령을 확인한다.

`tools/prepare_android.sh`와 `tools/prepare_ios.sh`가 복제한 저장소만으로 native SDK를 준비한다. iOS generic SDK용 컴파일은 기기나 시뮬레이터 실행 근거가 아니다. 런타임 연동과 UI는 별도 통합 검수에서 확인한다.

AdMob Editor의 Noto Sans CJK SC는 Adobe의 2014–2021 저작권과 SIL OFL 1.1을 보존한다. 같은 폴더의 `OFL.txt`와 잠금 파일에 원본 해시 및 라이선스 출처를 기록한다. Editor 전용 그림, 음악과 이 폰트는 출시 내보내기에서 제외한다.
