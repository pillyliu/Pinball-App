# Practice Ledger

## 2026-03-06

- Marked as a priority modernization target due to size and drift risk.

## 2026-03-07

- Category: `Doc-only`
- Established the first real Practice audit baseline.
- Recorded that Practice is currently a feature family with at least 11 route surfaces, not one screen.
- Recorded that iOS route and modal state remains heavily centralized in `PracticeScreen.swift`.
- Recorded that Android route structure is cleaner at the screen layer, but `PracticeStore.kt` is still a large responsibility center.
- Set Practice as the first feature-level modernization audit target.
- Wrote the first route-by-route Practice contract for Home, Game, Rulesheet, Playfield, IFPA Profile, Group Dashboard, Group Editor, Journal, Insights, Mechanics, and Settings.
- Recorded the current structural divergence: iOS uses a mixed route-plus-sheet model while Android models most primary surfaces as explicit routes.
- Wrote the first Game-route section contract: image preview, segmented workspace panel, game note, then resources.
- Recorded that `Summary`, `Input`, and `Log` are already functionally close across platforms, but component boundaries and ownership are still inconsistent.
- Recorded the current state-ownership split:
  - iOS root screen owns too much ephemeral route/UI state
  - Android screen-state layer is cleaner, but `PracticeStore.kt` still owns too much runtime/domain state
- Identified the first refactor seam as state ownership normalization before visual redesign.
- Added the first explicit file-responsibility map for `PracticeScreen.swift`, `PracticeDialogHost.swift`, `PracticeScreenRouteContent.swift`, `PracticeTypes.swift`, `PracticeScreen.kt`, `PracticeScreenState.kt`, `PracticeScreenRouteContent.kt`, and `PracticeStore.kt`.
- Wrote the target ownership model with four buckets:
  - route state
  - dialog/presentation state
  - route-local draft state
  - store/domain state
- Recorded the first implementation sequence:
  - normalize iOS route state
  - separate modal state from route state
  - split route-local drafts out of the root screen
  - then decompose Android store responsibilities
- Recorded that the first likely code change is an iOS route-state extraction rather than a visual rewrite.

- Category: `Code`
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreenState.swift` as the first explicit iOS Practice UI-state seam.
- Moved iOS route, dialog, journal-selection, mechanics, insights, settings-form, and other transient Practice state out of top-level `@State` declarations in `PracticeScreen.swift` and into the grouped `PracticeScreenState` value.
- Rewired `PracticeDialogHost.swift` and `PracticeScreenRouteContent.swift` to read and bind through the grouped iOS state seam.
- Verified that the extraction is behavior-preserving at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.
- Remaining iOS debt after this step:
  - `PracticeRoute` and `PracticeSheet` still do not model every Practice drill-in and sub-surface as one canonical contract
  - `PracticeScreen.swift` still owns most mutation/orchestration logic even though state is grouped more cleanly

- Category: `Code`
- Replaced the old iOS `PracticeNavRoute` wrapper and sheet booleans with explicit `PracticeRoute` and `PracticeSheet` enums in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeTypes.swift`.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeHomeRootView.swift`, `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift`, `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeDialogHost.swift`, and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreenRouteContent.swift` to use the explicit route/sheet model.
- iOS settings is now delivered as a pushed `PracticeRoute.settings` destination instead of a dedicated boolean navigation flag.
- iOS quick entry, group editor, group date editor, and journal entry editor are now delivered through one explicit `PracticeSheet` presentation slot instead of separate booleans/items.
- Verified the route/presentation normalization at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.

- Category: `Code`
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeRouteContentContext.swift` as the first explicit iOS route-content dependency seam.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreenRouteContent.swift` to consume the route-content context instead of directly reaching into `PracticeScreen` state and helper methods.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift` to construct the route-content context in one place.
- Verified the initial route-content context refactor at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.

- Category: `Code`
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeInsightsContext.swift` as a dedicated iOS dependency seam for the `Insights` route.
- Removed `Insights`-specific dependencies from the broader `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeRouteContentContext.swift`.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift` to construct `PracticeInsightsContext` separately from the shared route-content context.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreenRouteContent.swift` so the `Insights` route consumes `PracticeInsightsContext` instead of the generic route-content bundle.
- Verified the `Insights` extraction at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.

- Category: `Code`
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeJournalContext.swift` as a dedicated iOS dependency seam for the `Journal` route.
- Removed `Journal`-specific dependencies from the broader `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeRouteContentContext.swift`.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift` to construct `PracticeJournalContext` separately from the shared route-content context.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreenRouteContent.swift` so the `Journal` route consumes `PracticeJournalContext` instead of the generic route-content bundle.
- Verified the `Journal` extraction at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.

- Category: `Code`
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeMechanicsContext.swift` as a dedicated iOS dependency seam for the `Mechanics` route.
- Removed `Mechanics`-specific dependencies from the broader `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeRouteContentContext.swift`.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift` to construct `PracticeMechanicsContext` separately from the shared route-content context.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreenRouteContent.swift` so the `Mechanics` route consumes `PracticeMechanicsContext` instead of the generic route-content bundle.
- Verified the `Mechanics` extraction at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.

- Category: `Code`
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeSettingsContext.swift` as a dedicated iOS dependency seam for the `Settings` route.
- Removed `Settings`-specific dependencies from the broader `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeRouteContentContext.swift`.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift` to construct `PracticeSettingsContext` separately from the shared route-content context.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreenRouteContent.swift` so the `Settings` route consumes `PracticeSettingsContext` instead of the generic route-content bundle.
- Verified the `Settings` extraction at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.

- Category: `Code`
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardContext.swift` as a dedicated iOS dependency seam for the `GroupDashboard` route.
- Removed the now-obsolete `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeRouteContentContext.swift` catch-all route bundle after the remaining non-game routes had dedicated contexts.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeDialogHost.swift` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreenRouteContent.swift` so route dispatch now resolves per-route contexts directly instead of passing a generic context through the router.
- Verified the `GroupDashboard` extraction and route-dispatch cleanup at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.

- Category: `Code`
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticePresentationContext.swift` as a dedicated iOS dependency seam for Practice sheets and the reset alert.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticePresentationHost.swift` to render sheet and reset-alert content from the presentation context instead of assembling it inline inside `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeDialogHost.swift`.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift` to construct the presentation context in one place and keep modal behaviors behavior-preserving through explicit closures.

- Category: `Code`
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeHomeContext.swift` as a dedicated iOS dependency seam for the home/root Practice surface.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeHomeHost.swift` to render `PracticeHomeRootView` from the home context instead of assembling the full contract inline inside `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeDialogHost.swift`.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift` to construct the home context in one place and keep home behavior behavior-preserving through explicit closures.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeLifecycleContext.swift` as a dedicated iOS dependency seam for first-load and root-level Practice effect wiring.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeLifecycleHost.swift` to render `.task`, `.onChange`, and library-source observer behavior from the lifecycle context instead of assembling those effects inline inside `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeDialogHost.swift`.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift` to construct the lifecycle context in one place and keep effect behavior behavior-preserving through explicit closures.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreenActions.swift` so navigation, quick-entry, journal mutation, group-editor, and insights-refresh helpers no longer live inline in the root screen declaration.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift` to state, derived data, and context assembly instead of mixed declaration-plus-helper responsibilities.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceContext.swift` as the first explicit iOS dependency seam for the `Game` route.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceState.swift` so `Game` route transient UI state no longer lives as a long list of local `@State` properties in `PracticeGameSection.swift`.
- Updated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspace.swift` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift` so the workspace route now consumes explicit context plus grouped route-local state instead of raw store/binding plumbing plus scattered transient state.
- Verified the `Game` route context/state extraction at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceSubviews.swift` to isolate the `Summary`, `Input`, and `Log` workspace panels from the main game route file.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift` so it now focuses on route chrome, route-local sheet state, and panel composition instead of rendering all three workspace panels inline.
- Verified the workspace subview extraction at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameEntrySheets.swift` to isolate `GameScoreEntrySheet`, `GameNoteEntrySheet`, and `GameTaskEntrySheet` from the main game route file.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift` so it now focuses on route composition and route-local state instead of embedding modal form implementations inline.
- Verified the entry-sheet extraction at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameToolbarMenu.swift` to isolate the game/source picker toolbar, source inference, and fallback selection behavior from the main game route file.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift` so it no longer embeds the top-right game/source picker menu inline.
- Verified the game toolbar extraction at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGamePresentationContext.swift` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGamePresentationHost.swift` to isolate `Game` route sheets, log-entry edit/delete presentation, and save-banner feedback from the main game route file.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift` so it now focuses more tightly on route layout and local state synchronization instead of also owning modal and feedback presentation wiring.
- Verified the game presentation extraction at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameLifecycleContext.swift` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameLifecycleHost.swift` to isolate `Game` route first-load defaults, selected-game sync, browse tracking, and active-video fallback behavior from the main game route file.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift` so it no longer embeds `.onAppear` and `selectedGameID` change synchronization inline.
- Verified the game lifecycle extraction at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameRouteBody.swift` to isolate the `Game` route screenshot, segmented workspace card, note, and resource-card layout from the main game route file.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift` so it no longer owns the bulk of the route's layout tree inline.
- Verified the game route-body extraction at compile time with `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameWorkspacePanels.kt` to isolate the Android segmented workspace card plus the `Summary`, `Input`, and `Log` panels from the main game route file.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameSection.kt` so it now focuses more on route-level note/resources/dialog wiring instead of also owning the full workspace panel tree inline.
- Verified the Android workspace-panel extraction at compile time with `./gradlew app:assembleDebug`.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameDetailCards.kt` to isolate Android `Game Note` and `Game Resources` rendering plus resource helper chips from the main game route file.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameDialogs.kt` to isolate Android delete/edit dialog wiring from the main game route file.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameSection.kt` so it now focuses on route-local state plus high-level composition instead of also owning detail-card and dialog implementations inline.
- Verified the Android detail-card and dialog extraction at compile time with `./gradlew app:assembleDebug`.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameSectionState.kt` so Android `Game` route edit/delete/log-row UI state no longer lives as a group of local mutable variables inside `PracticeGameSection.kt`.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameSection.kt` so it now consumes an explicit route-local state seam instead of directly managing that transient UI state inline.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameRouteContext.kt` so Android `Game` route dependencies no longer live inside the shared `PracticeRouteContentContext`.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreenRouteContent.kt` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreen.kt` so route-specific `Game` wiring is assembled and passed separately instead of widening the shared route-content contract.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeTopBarGamePickerContext.kt` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeTopBarGamePicker.kt` so Android game/source picker behavior no longer lives inline inside the broader `PracticeTopBar.kt` component.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeTopBar.kt` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreen.kt` so top-bar display chrome is more separate from game/source picker behavior and state wiring.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeHomeRouteContext.kt`, `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGroupDashboardContext.kt`, `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeInsightsRouteContext.kt`, `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeMechanicsRouteContext.kt`, and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeSettingsRouteContext.kt` so the main Android non-game routes no longer widen one shared `PracticeRouteContentContext`.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeLibrarySourceSelection.kt` so Android home and top-bar source pickers now share one sentinel ID and normalization rule for the "All games" state.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreenRouteContent.kt` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreen.kt` so shared Android route wiring now carries only the remaining genuinely shared fields, while repeated "open game" and library-source selection rules are centralized once.
- Removed dead Android wiring by dropping the unused `ifpaPlayerID` parameter from `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeTopBar.kt` and the unused `selectedGameSlug` parameter from `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeMechanicsSection.kt`.
- Verified the Android non-game route-context split and shared selection-helper cleanup at compile time with `./gradlew app:assembleDebug`.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeJournalRouteContext.kt` so Android `Journal` route dependencies no longer widen the remaining shared `PracticeRouteContentContext`.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeJournalRows.kt` so Android journal timeline-row rendering and swipe-reveal behavior no longer live in the same file as section-level state orchestration.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeJournalEditDialog.kt` so Android journal entry editing no longer lives inline inside the main journal section file.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeJournalSection.kt` so it now focuses on route-level filtering, grouped timeline assembly, and section-local edit/delete state instead of also owning row rendering and dialog composition inline.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreenRouteContent.kt` again so `Journal` no longer leans on the shared route-content contract.
- Verified the Android journal route-context split and journal-section file decomposition at compile time with `./gradlew app:assembleDebug`.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreenActions.kt` so Android root navigation, selection, quick-entry, route drill-in, reset, and import helpers no longer live inline in the main screen declaration.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeLifecycleContext.kt` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeLifecycleHost.kt` so Android first-load, back handling, observer sync, and route-triggered effect wiring no longer live inline in the main screen declaration.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticePresentationContext.kt` so Android sheet/dialog dependencies no longer get threaded through `PracticeDialogHost.kt` as a long raw parameter list.
- Added `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeIfpaProfileContext.kt` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGroupEditorRouteContext.kt` so Android `IFPA Profile` and `GroupEditor` no longer depend on the last generic shared route-content context.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreen.kt` from the main concentration point for route effects, helper closures, and presentation wiring to a narrower orchestration layer that assembles explicit contexts.
- Reduced `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreenRouteContent.kt` so it now resolves only explicit route contexts and no longer declares a generic Android `PracticeRouteContentContext`.
- Verified the Android root-screen lifecycle/action/presentation split and final route-context cleanup at compile time with `./gradlew app:assembleDebug`.

## Next audit targets

- exact route-to-screen contract
- top-bar behavior per route
- state ownership split between screen, route model, and store
- journal section state ownership and further row/editor extraction opportunities
- remaining screen-state concentration in `PracticeScreenState.kt`
- repeated resource/video/rulesheet UI patterns
