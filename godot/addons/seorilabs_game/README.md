# 공통 기반

수정 원본은 seorilabs/game-foundation의 이 폴더다. 계약 1.3.0. 제품 이름과 그림은 bootstrap에서 주입한다. `stage_factory`, `launch_game`, `score_provider`, 서비스 포트와 `feature_routes`로 연결한다.

`ui_kit/`은 테마 조립(`skin.json` v2 → `theme.tres`), 모션(`juice.gd`), 버튼 효과음(`ui_sfx.gd`), HUD 층, 재화 칩, 팝업, 보상 연출을 제공한다. 제품은 `skins/<id>/skin.json`과 svg만 바꾸고 `build_theme.gd`로 `theme.tres`를 다시 만든다. 사용 지침은 agent-config의 `game-ui-commercial` 스킬 `references/godot-kit.md`를 따른다.

`ui_kit/cutscene_player`는 프롤로그와 엔딩 같은 컷신을 재생한다. 제품은 `outgame_main`의 `intro_script`(첫 시작 1회, 본 기록은 저장의 선택 키 `intro_seen`), `ending_script`와 `play_cutscene(script)`, `set_ending_seen(true)`, `credits`(제작진과 AI 생성 콘텐츠 고지)를 채운다. 비워 두면 1.1.0과 같은 흐름이다. 설정의 크레딧은 늘 있고 `fonts/manifest.json`의 글꼴 라이선스를 함께 보여 준다.

`dev/test_room`은 디버그 실행과 `playtest` 기능 태그 빌드에서만 열린다. 제품은 bootstrap의 `_init()`에서 `test_room_setup`(테스트실을 받는 Callable)을 정하고, 그 안에서 `register_action`, `register_snapshots`, `register_replay`, `set_notes`로 행동을 등록한다. `test_room_setup`이 없으면 테스트실, F9, 설정 항목이 생기지 않는다. 행동이 값을 돌려주지 않으면 완료로 본다. 출시 export preset은 `exclude_filter`에 `addons/seorilabs_game/dev/**`를 넣는다.

## Seori Labs studio splash

Enable `show_studio_splash` on the game bootstrap scene. The splash shows the transparent Seori Labs lockup centered on Night Navy for one second per cold launch while the game title initializes. It blocks input until it closes and omits the closing fade if reduced motion is enabled.

The lockup is copied unchanged from the [Seori Labs studio page](https://www.seorilabs.com/en/studio/). Keep native launch and engine boot screens image-free with the same Night Navy color `#020B16`.
