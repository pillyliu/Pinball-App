# GameRoom Ledger

## 2026-03-06

- `3.1` Android parity completion committed on `codex/3.1-gameroom`
- merged to `main`
- `3.2` branch created for modernization work

## 2026-03-07

- iOS GameRoom home, selected-machine summary, collection card, mini cards, list rows, and snapshot metric helpers were moved out of `GameRoomScreen.swift` into `GameRoomHomeComponents.swift`.
- Android GameRoom shared UI pieces were moved out of `GameRoomScreen.kt` into `GameRoomUiComponents.kt`, including mini cards, list rows, variant pills, dropdowns, snapshot metric grid, section headers, and shared date/attention helpers.
- Product behavior stayed stable; this is the first structural split milestone for post-3.1 cleanup.

## Next audit targets

- split oversized GameRoom screen files
- verify that Android and iOS still match every `3.1` contract item after cleanup
- inventory repeated UI patterns that should move into shared platform UI layers
- isolate machine-detail and event/media presentation clusters next
