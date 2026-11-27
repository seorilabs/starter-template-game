# First Light startup splash

Revision 1 · 2026-11-27

The coordinated design and acceptance criteria are in [First Light rollout](https://github.com/seorilabs/seorilabs-official/tree/821cb4ebf5b3eb888e7e0b1bed00c789f0983826/docs/design/2026-11-27-first-light). This repository follows the game scope and its local test plan.

Enable the bundled, silent First Light splash for new games. Show the orientation-appropriate crystal plate and English logo once per cold launch, allow dismissal without input reaching the title, and keep startup and error handling available. Validate the default in a generated game and compare portrait and landscape Godot renders over three independent review rounds. This change ships through the public source template and does not promote a game through any store.

See the [test plan](test-plan.json) for the development regression scope.
