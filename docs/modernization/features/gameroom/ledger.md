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
- Android import-review scoring, purchase-date normalization, duplicate-warning logic, and confidence badge rendering were moved out of `GameRoomScreen.kt` into `GameRoomImportHelpers.kt`, so the root file no longer mixes import helper logic with screen orchestration.
- Android GameRoom machine-route and settings-route headers now use the shared `AppScreenHeader` seam in `CommonUi.kt` instead of feature-local back-button plus title rows.
- iOS GameRoom import fetch and catalog-search task-state messaging now uses the shared `AppInlineTaskStatus` seam in `SharedTableUi.swift` instead of local spinner-plus-error stacks.
- Android GameRoom import fetch and catalog-search task-state messaging now uses the shared `AppInlineTaskStatus` seam in `CommonUi.kt`, and the edit surface now exposes catalog loading/error state explicitly instead of only a static result label.
- iOS and Android GameRoom now also use shared panel-empty cards for home and settings empty states instead of feature-local secondary text blocks inside cards.
- iOS GameRoom machine media/log empties plus issue/media import state now also use shared `SharedTableUi.swift` seams instead of raw `Text` and `ProgressView("Importing media…")` blocks.
- Android GameRoom machine media/log empties plus issue-draft media empties now also use the shared `CommonUi.kt` panel-empty seam instead of feature-local fallback text.
- iOS GameRoom media thumbnails and preview fallback state now also use shared media-preview and fullscreen-status seams instead of raw thumbnail `ProgressView()` blocks and a feature-local `"Media unavailable"` text fallback.
- Android GameRoom collection-card artwork, machine-list artwork, attachment-tile thumbnails, and fullscreen media preview loading/missing states now also use shared media-preview and fullscreen-status seams instead of raw `AsyncImage` loading/error behavior in `GameRoomUiComponents.kt` and `GameRoomPresentationComponents.kt`.
- iOS and Android GameRoom collection highlights now also use the PinProf brand layer, with mini-card selection borders, list-row selection borders, attention-dot outlines, and variant pills moving off older cyan, black, and white styling and onto the shared gold, ink, and chalk palette in `GameRoomHomeComponents.swift` and `GameRoomUiComponents.kt`.
- Android GameRoom collection-layout pills, settings-tab pills, and import-review filter pills now also use the shared `AppSelectionPill` seam in `CommonUi.kt` instead of three separate neutral selected-state implementations across `GameRoomRouteContent.kt` and `GameRoomSettingsSections.kt`.
- iOS and Android GameRoom import confidence pills now also use the shared tinted status-chip seams in `AppFilterControls.swift` and `CommonUi.kt` instead of feature-local colored capsules, aligning import scoring highlights with the broader PinProf brand layer.
- iOS GameRoom import-review rows and add-machine search rows now use the shared control-card chrome in `AppTheme.swift`, and Android GameRoom now uses the shared `AppControlCard` seam in `CommonUi.kt`, replacing local bordered row styling in the import/search flows.
- Android GameRoom log-row swipe actions now also use the shared swipe-action button seam in `CommonUi.kt` instead of a feature-local reveal-action helper in `GameRoomPresentationComponents.kt`.
- iOS and Android GameRoom variant pills now also route through the shared resource-chrome variant-pill seams in `AppResourceChrome.swift` and `AppResourceChrome.kt`, replacing the remaining feature-local GameRoom variant badge implementation beside Library and Practice.
- iOS and Android GameRoom selected-machine, collection, and machine-input card headings now also use the shared subheading seams in `SharedTableUi.swift` and `CommonUi.kt`, removing the last feature-local inner card-heading styling from the home and machine-detail routes.
- iOS and Android GameRoom machine-summary headings for `Current Snapshot` and `Media` now also use those shared subheading seams in `GameRoomMachineView.swift` and `GameRoomMachineRoute.kt`, closing the remaining machine-detail card-heading drift.
- Android GameRoom home-route cards now also use the shared subheading and panel-empty seams for `Selected Machine`, `Current Snapshot`, and `Collection` in `GameRoomRouteContent.kt`, closing the last obvious GameRoom home chrome gap against the iOS home route.
- Android GameRoom collection fetch/import CTAs plus the edit-name and area-save actions now also use the shared `AppPrimaryButton` seam in `CommonUi.kt`, and the area reset action now uses the shared `AppSecondaryButton` seam instead of keeping one more pocket of feature-local `Button` styling in `GameRoomSettingsSections.kt`.
- Android GameRoom machine-edit `Save` now also uses that shared `AppPrimaryButton` seam in `CommonUi.kt`, further reducing the remaining local action-row chrome in `GameRoomSettingsSections.kt`.
- Android GameRoom input-sheet footers, media picker launch rows, issue-draft removal chips, add-machine pagination rows, and machine-edit `Delete` / `Archive` actions now also route through shared `AppPrimaryButton`, `AppSecondaryButton`, `AppInlineActionChip`, and `AppDestructiveButton` seams in `CommonUi.kt`, reducing the last prominent pockets of feature-local action-row chrome in `GameRoomPresentationHost.kt` and `GameRoomSettingsSections.kt`.
- iOS and Android GameRoom snapshot metric rows now also route through shared metric-grid seams in `SharedTableUi.swift` and `CommonUi.kt`, so both the home selected-machine summary and the machine-detail `Current Snapshot` panel no longer keep feature-local two-column metadata layout helpers.
- iOS GameRoom fetch/import, pagination, venue save, area save/edit, and machine save/archive/delete CTAs now also route through shared `AppPrimaryActionButtonStyle`, `AppSecondaryActionButtonStyle`, and `AppDestructiveActionButtonStyle` seams in `AppFilterControls.swift`, replacing the remaining feature-local `.glass` CTA styling pockets in `GameRoomSettingsComponents.swift`.
- GameRoom is now considered structurally “clean enough” for the current modernization phase; follow-up work should shift to League and shell/theme cleanup unless behavior changes force GameRoom back into active refactor.

## Next audit targets

- verify that Android and iOS still match every `3.1` contract item after cleanup
- inventory repeated UI patterns that should move into shared platform UI layers
- revisit GameRoom only if parity drift or product changes reopen the feature
