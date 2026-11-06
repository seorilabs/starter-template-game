# 공통 기반

수정 원본은 seorilabs/game-foundation의 이 폴더다. 계약 1.1.0. 제품 이름과 그림은 bootstrap에서 주입한다. `stage_factory`, `launch_game`, `score_provider`, 서비스 포트와 `feature_routes`로 연결한다.

`ui_kit/`은 테마 조립(`skin.json` v2 → `theme.tres`), 모션(`juice.gd`), 버튼 효과음(`ui_sfx.gd`), HUD 층, 재화 칩, 팝업, 보상 연출을 제공한다. 제품은 `skins/<id>/skin.json`과 svg만 바꾸고 `build_theme.gd`로 `theme.tres`를 다시 만든다. 사용 지침은 agent-config의 `game-ui-commercial` 스킬 `references/godot-kit.md`를 따른다.
