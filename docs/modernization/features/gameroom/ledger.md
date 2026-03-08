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
- Android home-route and settings-route shell composition were moved out of `GameRoomScreen.kt` into `GameRoomRouteContent.kt`, so the root file now focuses on state, lifecycle, route switching, and modal orchestration instead of also owning the inline route bodies.
- Android input-sheet composition, event-edit sheet, and attachment preview/edit presentation were moved out of `GameRoomScreen.kt` into `GameRoomPresentationHost.kt`, so the root file now wires presentation state instead of still embedding the sheet bodies inline.
- Android GameRoom machine-route and settings-route headers now use the shared `AppScreenHeader` seam in `CommonUi.kt` instead of feature-local back-button plus title rows.
- iOS GameRoom import fetch and catalog-search task-state messaging now uses the shared `AppInlineTaskStatus` seam in `SharedTableUi.swift` instead of local spinner-plus-error stacks.
- Android GameRoom import fetch and catalog-search task-state messaging now uses the shared `AppInlineTaskStatus` seam in `CommonUi.kt`, and the edit surface now exposes catalog loading/error state explicitly instead of only a static result label.
- iOS and Android GameRoom now also use shared panel-empty cards for home and settings empty states instead of feature-local secondary text blocks inside cards.
- iOS GameRoom machine media/log empties plus issue/media import state now also use shared `SharedTableUi.swift` seams instead of raw `Text` and `ProgressView("Importing media…")` blocks.
- Android GameRoom machine media/log empties plus issue-draft media empties now also use the shared `CommonUi.kt` panel-empty seam instead of feature-local fallback text.
- iOS GameRoom media thumbnails and preview fallback state now also use shared media-preview and fullscreen-status seams instead of raw thumbnail `ProgressView()` blocks and a feature-local `"Media unavailable"` text fallback.
- Android GameRoom collection-card artwork, machine-list artwork, attachment-tile thumbnails, and fullscreen media preview loading/missing states now also use shared media-preview and fullscreen-status seams instead of raw `AsyncImage` loading/error behavior in `GameRoomUiComponents.kt` and `GameRoomPresentationComponents.kt`.
- GameRoom is now considered structurally “clean enough” for the current modernization phase; follow-up work should shift to League and shell/theme cleanup unless behavior changes force GameRoom back into active refactor.

## Next audit targets

- verify that Android and iOS still match every `3.1` contract item after cleanup
- inventory repeated UI patterns that should move into shared platform UI layers
- revisit GameRoom only if parity drift or product changes reopen the feature
