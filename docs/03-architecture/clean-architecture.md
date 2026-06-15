# Clean Architecture Boundary

## packages/product-core

허용:

- Domain entities
- Value objects
- Pure use cases
- Port interfaces
- Pure fixtures/fakes

금지:

- Godot scene tree, Node, Control, Resource 의존
- Firebase SDK, Admin SDK, service account
- AppsInToss SDK
- Google Play Billing, App Store StoreKit
- Ad SDK
- Network/client SDK 직접 호출

## godot

허용:

- Scenes
- Rendering/input/animation/physics
- Game lifecycle
- Port adapter wiring

## market adapters

시장별 release, metadata, config, wrapper는 다음 위치에 둔다.

- Google Play: `play-store/`
- App Store: `app-store/`
- AppsInToss: `apps-in-toss/`, `apps/ait/`
- Firebase: `firebase/`

