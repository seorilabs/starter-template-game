# CI/CD 워크플로우 (org 표준 · Godot)

이 템플릿의 `.github/workflows/*`는 org 재사용 워크플로우(`seorilabs/.github`)를 호출하는 **얇은 caller**다. 전체 설계는 `seorilabs/.github`의 `docs/ci-cd/org-cicd-release-system.md` 참조.

## 워크플로우

| 파일 | 트리거 | 역할 | 러너 |
|---|---|---|---|
| `godot-checks.yml` | push/PR→main, dispatch | import→compile→smoke + core/architecture/docs | ARC(private)/ubuntu |
| `deploy-godot-pages.yml` | push→main, dispatch | Godot Web export + Pages(웹 채널) | ARC/ubuntu |
| `release-tag.yml` | dispatch | 명시적 SemVer 태그 | ARC |
| `deploy-apps-in-toss.yml` | dispatch, call | web export→래퍼 build→AppsInToss | ARC |
| `deploy-google-play.yml` | dispatch, call | Godot 서명 AAB + Google Play | ubuntu |
| `deploy-all.yml` | dispatch | 태그 1개로 AIT+GPS 한 번에 | — |
| `cleanup-actions-storage.yml` | dispatch | 아티팩트/캐시 정리 | ARC |
| `release-inventory.yml` | dispatch | 릴리즈 준비 점검 | — |

- **main = 정적 게이트만**(+ 웹 Pages는 별도 채널). 마켓 업로드는 명시적 Release/Tag 후 dispatch.
- App Store(Godot iOS)는 `godot-deploy-app-store.yml` 재사용 워크플로우 도입 후 추가.

## 게임별로 채워야 하는 것 (contract)

1. **`deploy-apps-in-toss.yml`의 `wrapper_dir`** 를 실제 AIT 웹 래퍼 경로로 확인/교체.
2. Godot 프로젝트는 `godot/`(= `project_dir: godot`). 다르면 caller의 `project_dir` 수정.
3. Google Play 업로드 도구(`tools/`): `set_google_play_version_code.py`, `upload_google_play_internal.py`,
   (선택) `install_android_build_template.sh`, `build_admob_plugin.sh`, `check_google_play_readiness.py`.
4. **secrets/variables**: org 공통 상속(`APPS_IN_TOSS_API_KEY`, `GOOGLE_PLAY_UPLOAD_*`, var `GOOGLE_PLAY_UPLOAD_KEY_ALIAS`/`GOOGLE_WORKLOAD_IDENTITY_PROVIDER`). repo var: `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL`, AdMob/Firebase vars(`ADMOB_APP_ID`, `FIREBASE_*`).
5. **GitHub Environments**: `apps-in-toss`, `google-play`.

## @ref 핀

caller의 `@main` — 안정화 후 태그/SHA 핀 권장.
