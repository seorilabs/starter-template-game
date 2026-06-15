# GitHub Actions

## Workflows

- `Godot Compile`: Godot import, compile, smoke scene.
- `Repository Checks`: core, architecture, docs checks.
- `Release Inventory`: manual release blocker inventory.

## Runner Routing

- 템플릿 workflow는 public/private 양쪽에서 안전하게 동작하도록 `github.event.repository.private` 조건을 둔다.
- private repo에서는 `seorilabs-rpi-arm64`를 사용한다.
- public repo 또는 public PR path에서는 `ubuntu-latest` fallback을 사용한다.
- Android release build와 App Store build는 RPI ARC로 보내지 않는다.

## Central Source

수정 전 확인:

```bash
cat /Users/syous/Workspace/kubectl/github-actions-runners/global-versions.yaml
```

