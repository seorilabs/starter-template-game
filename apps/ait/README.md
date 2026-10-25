# AppsInToss 호스트

Godot Web을 `public/`에 내보내고 이 폴더를 제품별 Granite 호스트에 연결한다. `granite.config.example.ts`의 미확정 appName과 아이콘은 마켓 등록 단계에서 확정한다. 현재 템플릿은 앱인토스 SDK나 운영 서버를 호출하지 않는다.

`host.js`의 `installHost`에 실제 서비스 핸들러를 등록하면 `godot/game/adapters/ait_host.gd`가 `SeorilabsHost` 경계를 사용한다. core는 호스트나 SDK를 직접 부르지 않는다. 기본 실행은 로컬 저장만 사용한다.

```sh
GODOT_WEB_OUTPUT_DIR=apps/ait/public npm run build:godot:web
```

위 명령은 로컬 Web 산출물만 만든다. 콘솔 업로드, 심사와 공개는 별도 제품 승인과 검증이 필요하다.
