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

## Next audit targets

- exact route-to-screen contract
- top-bar behavior per route
- game workspace state dependencies and component boundaries
- state ownership split between screen, route model, and store
- repeated resource/video/rulesheet UI patterns
