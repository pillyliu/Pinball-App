# League Ledger

## 2026-03-06

- Root About tab removal and nested League About flow are part of the shipped 3.1 baseline.

## 2026-03-07

- Android League home was split into a shell file plus explicit preview loader, preview model, and preview card files.
- The home screen still behaves the same, but preview loading and card rendering are no longer concentrated in `LeagueScreen.kt`.
- Android rotating preview timers and display-toggle state now live in `LeaguePreviewRotationState.kt` instead of staying inline in `LeagueScreen.kt`.
- iOS League home now splits into a small root navigation shell in `LeagueScreen.swift` plus `LeagueShellContent.swift` for the responsive card layout, destination links, and About footer.
- Android League home now also splits the responsive card layout, destination links, and About footer into `LeagueShellContent.kt`, leaving `LeagueScreen.kt` focused on shell orchestration and preview-state loading.

## Next audit targets

- confirm exact card content parity
- verify nested destination behavior on both platforms
- review whether destination contracts and nested route ownership should move into a dedicated shell/router seam next
