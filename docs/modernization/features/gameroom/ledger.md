# GameRoom Ledger

## 2026-03-06

- `3.1` Android parity completion committed on `codex/3.1-gameroom`
- merged to `main`
- `3.2` branch created for modernization work

## 2026-03-07

- iOS GameRoom home, selected-machine summary, collection card, mini cards, list rows, and snapshot metric helpers were moved out of `GameRoomScreen.swift` into `GameRoomHomeComponents.swift`.
- Android GameRoom shared UI pieces were moved out of `GameRoomScreen.kt` into `GameRoomUiComponents.kt`, including mini cards, list rows, variant pills, dropdowns, snapshot metric grid, section headers, and shared date/attention helpers.
- Product behavior stayed stable; this is the first structural split milestone for post-3.1 cleanup.
- iOS machine detail, segmented subview layout, machine input sheets, event editing, media preview/edit presentation, and machine-log helpers were moved out of `GameRoomScreen.swift` into `GameRoomMachineView.swift`.
- Android machine route layout, summary/input/log panels, and machine-route event handlers were moved out of `GameRoomScreen.kt` into `GameRoomMachineRoute.kt`.
- iOS settings shell, import flow, edit-machines surface, and archive surface were moved out of `GameRoomScreen.swift` into `GameRoomSettingsComponents.swift`.
- Android settings import flow, edit surface, and archive surface were moved out of `GameRoomScreen.kt` into `GameRoomSettingsSections.kt`.
- Android log-row reveal UI, media attachment grid, and full-screen media preview dialog were moved out of `GameRoomScreen.kt` into `GameRoomPresentationComponents.kt`.
- iOS service-entry sheets, issue/media sheets, media preview/edit views, log-detail card, and event edit sheet were moved out of `GameRoomScreen.swift` into `GameRoomPresentationComponents.swift`.
- Android GameRoom machine-route and settings-route headers now use the shared `AppScreenHeader` seam in `CommonUi.kt` instead of feature-local back-button plus title rows.
- GameRoom is now considered structurally “clean enough” for the current modernization phase; follow-up work should shift to League and shell/theme cleanup unless behavior changes force GameRoom back into active refactor.

## Next audit targets

- verify that Android and iOS still match every `3.1` contract item after cleanup
- inventory repeated UI patterns that should move into shared platform UI layers
- revisit GameRoom only if parity drift or product changes reopen the feature
