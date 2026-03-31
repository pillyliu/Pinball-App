# iOS Sequential Code Review

This is a review log for the iOS app as it exists today, not a modernization plan.

Goals:
- inspect the iOS codebase in deterministic order
- record what each file does
- record what other code each file interacts with
- surface hidden coupling, duplicated behavior, competing logic, and unused code
- make only safe, behavior-preserving cleanup edits during the review unless a deeper fix is clearly justified
- keep Android parity in view when a review finding affects shared behavior or naming

Review rules:
- audit order is folder-by-folder, then alphabetical within each folder
- each file gets a responsibility summary, dependency map, findings, and recommended follow-up
- code changes made during the review are logged in the same pass entry
- anything that looks risky but not yet proven gets logged before it gets rewritten

Current deterministic order:
1. `app/`
2. `ui/`
3. `data/`
4. `info/`
5. `league/`
6. `library/`
7. `practice/`
8. `gameroom/`
9. `settings/`
10. `targets/`
11. `stats/`
12. `standings/`
13. `Pinball App 2Tests/`

Status legend:
- `reviewed`
- `reviewing`
- `queued`
- `change made`
- `follow-up`

## Pass 001: App Shell

Files in scope:
- `Pinball App 2/Pinball App 2/app/Pinball_App_2App.swift`
- `Pinball App 2/Pinball App 2/app/ContentView.swift`
- `Pinball App 2/Pinball App 2/app/AppShakeCoordinator.swift`
- `Pinball App 2/Pinball App 2/app/AppIntroOverlay.swift`
- `Pinball App 2/Pinball App 2/app/PinballPerformanceTrace.swift`

### `Pinball_App_2App.swift`

Status: `reviewed`

Responsibility summary:
- app entry point
- reads persisted display-mode preference
- boots the root shell
- runs app-level startup refresh tasks
- reruns selected refresh work when the scene becomes active

Line map:
- `10-17`: defines the `@main` app entry and resolves `AppDisplayMode` from `@AppStorage`
- `19-28`: launches `ContentView`, applies the preferred color scheme, and runs initial async startup work
- `29-36`: listens for `scenePhase` changes and reruns foreground refresh work on `.active`

Primary interactions:
- `ContentView.swift`: root shell view for the app window
- `ui/AppTheme.swift`: `AppDisplayMode` and `preferredColorScheme`
- `library/LibraryBuiltInSources.swift`: `migrateLegacyPinnedVenueImportsIfNeeded()`
- `data/SharedCSV.swift`: `refreshRedactedPlayersFromCSV()`
- `library/LibraryHostedData.swift`: `warmHostedCAFData()`
- `data/PinballDataCache.swift`: `PinballDataCache.shared.refreshMetadataFromForeground()`

Findings:
- `follow-up`: startup work is partially duplicated. `migrateLegacyPinnedVenueImportsIfNeeded()` and `refreshRedactedPlayersFromCSV()` run once in the initial `.task` and then again on the first `.active` scene transition. That may be harmless, but it is hidden duplicate work at launch.
- `follow-up`: the foreground refresh path uses an untracked `Task { ... }`. If scene phase flips rapidly, overlapping refresh jobs are possible.

Recommended follow-up:
- centralize startup and foreground refresh decisions behind one coordinator or one guarded bootstrap path
- decide which work is initial-only, foreground-only, or safe to rerun

Changes made in this pass:
- none

### `ContentView.swift`

Status: `change made`

Responsibility summary:
- defines the root tab contract
- owns the app-level navigation environment object
- owns app-wide shake warning overlay state
- owns app intro visibility state and dismissal persistence
- mounts the main `TabView`

Line map:
- `10-52`: `RootTab` defines the five root tabs, their labels, icons, and root views
- `54-58`: `AppNavigationModel` stores selected tab state plus cross-feature library navigation state
- `60-79`: `ContentView` owns root-scoped state, intro persistence, and one-launch intro visibility decisions
- `81-112`: builds the tab shell, applies shared gestures, and renders the shake warning plus intro overlay

Primary interactions:
- `league/LeagueScreen.swift`
- `library/LibraryScreen.swift`
- `practice/PracticeScreen.swift`
- `gameroom/GameRoomScreen.swift`
- `settings/SettingsScreen.swift`
- `ui/AppTheme.swift`: `dismissKeyboardOnTap()`
- `ui/SharedGestures.swift`: `appShakeMotionHandler`
- `app/AppShakeCoordinator.swift`
- `app/AppIntroOverlay.swift`
- `library/LibraryScreen.swift` and `library/LibraryListScreen.swift`: consume `libraryGameIDToOpen` and set `lastViewedLibraryGameID`
- `practice/PracticeScreen.swift`, `practice/PracticeScreenDerivedData.swift`, and `practice/PracticeLifecycleHost.swift`: consume `lastViewedLibraryGameID`

Findings:
- `reviewed`: `Combine` looks visually unused at first glance, but it is still required in this target because `ObservableObject` and `@Published` do not compile here without the explicit import. The review initially tried removing it and the simulator build failed, so the import was restored.
- `change made`: `AppNavigationModel.openLibraryGame(gameID:)` had no callers and was removed.
- `follow-up`: `AppNavigationModel.selectedTab` currently has no programmatic writers after the dead helper was removed. The property is still valid for `TabView(selection:)`, but it may not need to live in a shared environment object unless another feature starts mutating tabs directly again.
- `follow-up`: intro visibility is initialized from raw `UserDefaults` in `init()` while persistence later uses `@AppStorage`. The behavior is understandable, but the split storage access pattern is easy to forget when adjusting intro logic.

Recommended follow-up:
- keep `selectedTab` in the environment object only if cross-feature tab jumping is expected
- if intro rules grow, move the launch-decision logic into a tiny dedicated type instead of leaving it inline in the shell view

Changes made in this pass:
- removed unused `openLibraryGame(gameID:)` helper

### `AppShakeCoordinator.swift`

Status: `reviewed`

Responsibility summary:
- defines shake escalation levels and overlay copy
- decides when fallback shake warnings should appear
- suppresses fallback warnings when native undo should handle the shake
- drives warning overlay state and haptics
- renders the warning overlay and professor artwork fallback UI

Line map:
- `6-96`: `AppShakeWarningLevel` defines display text, art file names, colors, timing, and haptic delay per level
- `98-175`: `AppShakeCoordinator` escalates warning levels, suppresses fallback when native undo is active, and clears the overlay after a timed delay
- `177-321`: `AppShakeWarningHaptics` plays Core Haptics patterns with UIKit fallback
- `323-431`: `AppShakeWarningOverlay` renders the warning presentation in portrait or landscape
- `434-509`: professor artwork loading and fallback provider
- `511-579`: font helper, emergency placeholder, and first-responder lookup helper

Primary interactions:
- `app/ContentView.swift`: owns `AppShakeCoordinator` and displays `AppShakeWarningOverlay`
- `ui/SharedGestures.swift`: shake motion detection eventually calls `handleDetectedShake()`
- `ui/AppTheme.swift`: shared theme colors used by artwork fallback UI
- `library/LibraryResourceResolution.swift` and related library chrome indirectly provide `libraryMissingArtworkPath` and `loadCachedPinballData(...)` for bundled fallback artwork
- `Pinball App 2Tests/AppShakeCoordinatorTests.swift`: verifies escalation timing and shared-motion tuning expectations

Findings:
- `follow-up`: `AppShakeProfessorArt` loads local artwork twice for the same level during one presentation path. It initializes state with `localImage(for:)` and then reruns `localImage(for:)` again inside `.task`.
- `follow-up`: `AppShakeProfessorArtProvider.localImage(for:)` uses synchronous `Data(contentsOf:)` reads on the main actor and does not cache successful image loads.
- `follow-up`: `artAssetName` is now only used by tests and the emergency placeholder copy. Actual image resolution is file-name based, so the naming contract is partly legacy.

Recommended follow-up:
- collapse the artwork load path to one read per level and cache the resulting `UIImage`
- decide whether `artAssetName` is still part of the real contract or only a placeholder/debug detail

Changes made in this pass:
- none

### `AppIntroOverlay.swift`

Status: `change made`

Responsibility summary:
- defines the intro-card content model
- renders the full intro deck
- owns the bundled artwork loader for intro assets
- provides typography helpers and page-indicator chrome

Line map:
- `4-141`: intro enums and theme values define card metadata, quotes, accents, artwork names, and spotlight behavior
- `143-204`: `AppIntroOverlay` renders the paged deck and final dismiss button
- `206-576`: page composition, artwork frames, quote rendering, and professor spotlight UI
- `578-607`: `AppIntroBundledArtProvider` resolves and caches bundled intro images
- `610-624`: page indicators
- `626-682`: font helpers

Primary interactions:
- `app/ContentView.swift`: shows the overlay and persists dismissal
- `settings/SettingsScreen.swift`: toggles whether the intro should show again on next launch
- `settings/SettingsHomeSections.swift`: reuses the bundled intro artwork loader for the About logo

Findings:
- `change made`: `AppIntroGhostButtonStyle` had no call sites and was removed.
- `follow-up`: `AppIntroBundledArtProvider.image(named:)` still performs synchronous `Data(contentsOf:)` reads on first load. The `NSCache` avoids repeat cost, but first render still blocks on the main thread.
- `follow-up`: `AppIntroBundledArtProvider` is no longer purely intro-local because `SettingsHomeSections.swift` reuses it for the About section logo. That cross-feature reuse is fine, but it means intro asset loading now has a hidden settings dependency.

Recommended follow-up:
- either keep the provider shared intentionally and rename it to match that wider role, or move the shared logo load path out of the intro file
- consider switching initial image load to a less blocking path if more intro/settings media gets added

Changes made in this pass:
- removed unused `AppIntroGhostButtonStyle`

### `PinballPerformanceTrace.swift`

Status: `reviewed`

Responsibility summary:
- wraps signpost timing
- logs elapsed duration text for sync and async work
- exposes a small common performance-instrumentation API

Line map:
- `4-6`: shared subsystem and logger definitions
- `8-13`: interval value recorded by `begin`
- `15-51`: start and stop helpers emit signposts and log duration text
- `53-71`: sync and async `measure` wrappers

Primary interactions:
- `library/LibraryHostedData.swift`: hosted-data warmup timing
- `practice/PracticeStore.swift`, `practice/PracticeStoreDataLoaders.swift`, `practice/PracticeStorePersistence.swift`, `practice/PracticeStoreLeagueHelpers.swift`, and `practice/PracticeHomeBootstrapSnapshot.swift`: practice bootstrap and load timing
- Android parity file: `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/PinballPerformanceTrace.kt`

Findings:
- `follow-up`: the log message prefix is hard-coded as `practice_perf`, but the helper is already used outside Practice for hosted library warmup. The Android implementation mirrors the same naming mismatch, so this is a cross-platform observability debt item.

Recommended follow-up:
- rename the emitted log prefix to something feature-neutral on both platforms, or split Practice-specific logging from the generic performance helper

Changes made in this pass:
- none

## Pass 001 summary

Safe cleanup changes made:
- removed an unused dead helper from `ContentView.swift`
- removed an unused button style from `AppIntroOverlay.swift`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 283: Android GameRoom add-machine settings split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomEditSettingsPanels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomAddMachineSettingsSupport.kt`

Changes made in this pass:
- moved the add-machine search, advanced filters, catalog results list, and variant chooser out of `GameRoomEditSettingsPanels.kt`
- left the old settings-panels file focused on the smaller shared shell pieces instead of the full catalog-search workflow

Hidden seams surfaced and fixed:
1. the new add-machine support file still needed its own `clickable` import because the advanced-filter row was no longer inheriting that from the old mixed file
2. the split clarified that catalog search/filter state is its own UI flow rather than generic settings-card chrome

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 284: Android GameRoom area and edit-machine settings split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomEditSettingsPanels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomEditMachinesSettingsSupport.kt`

Changes made in this pass:
- moved the area-management card and the edit-machine card into a dedicated support file
- moved the `editMachineLabel(...)` helper alongside the edit-machine surface that actually uses it
- reduced `GameRoomEditSettingsPanels.kt` to a small shell file

Hidden seams surfaced and fixed:
1. `GameRoomAreaSettingsCard(...)` briefly existed in both files during the split, which exposed that the old file was still carrying a stale duplicate implementation
2. removing the duplicate left one truthful owner for both the area and machine editor surfaces

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 285: Android GameRoom media presentation split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPresentationComponents.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomMediaPresentationSupport.kt`

Changes made in this pass:
- moved the attachment grid and fullscreen media preview out of `GameRoomPresentationComponents.kt`
- left `GameRoomPresentationComponents.kt` focused on log-row presentation instead of also owning the full media surface

Hidden seams surfaced and fixed:
1. after the media move, the trimmed log-row file still needed `background` and `clickable`, which made the old accidental coupling visible right away
2. restoring only those imports confirmed the file boundary is now narrower and more honest

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 274: GameRoom issue and media form-body split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueLoggingSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueLogFormSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaEntrySupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaEntryFormSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaImportStatusSupport.swift`

Changes made in this pass:
- moved the issue logging form body out of `GameRoomIssueLoggingSupport.swift`
- moved the media entry form body out of `GameRoomMediaEntrySupport.swift`
- introduced one shared inline import-status surface for both sheets

Hidden seam surfaced and reduced:
1. both route sheets were still mixing navigation/picker lifecycle with the actual form layout, even after the earlier draft-state and import-state splits
2. the route files now read like route shells again, and the shared import-status view removes one more small duplication seam between issue logging and media entry

Behavioral outcome:
- no intended front-facing behavior changed
- `GameRoomIssueLoggingSupport.swift` dropped to 91 lines
- `GameRoomMediaEntrySupport.swift` dropped to 80 lines

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 275: GameRoom edit-machines shell split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinesView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinesShellSupport.swift`

Changes made in this pass:
- moved the edit-machines panel composition out of `GameRoomEditMachinesView.swift` into `GameRoomEditMachinesShellSupport.swift`
- left the main view focused on:
  - route lifecycle
  - selection sync
  - catalog search indexing
  - machine save/archive/delete orchestration

Hidden seam surfaced and reduced:
1. `GameRoomEditMachinesView.swift` was still the last obvious GameRoom coordinator that mixed shell routing with all four panel-builder surfaces
2. the shell split exposed one stale call-site mismatch around `machineMenuLabel`, which is now explicit and corrected instead of being hidden in the inline panel composition

Behavioral outcome:
- no intended front-facing behavior changed
- `GameRoomEditMachinesView.swift` is down to 296 lines and reads more like a coordinator than a catch-all view bucket

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 155: Markdown image and HTML support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownRenderingSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownImageSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownHTMLSupport.swift`

Changes made in this pass:
- moved markdown image descriptor parsing and remote image rendering out of `LibraryMarkdownRenderingSupport.swift`
- moved HTML/inline-markdown sanitizing out of `LibraryMarkdownRenderingSupport.swift`
- left `LibraryMarkdownRenderingSupport.swift` focused on:
  - block routing
  - inline text rendering
  - markdown table rendering

Hidden seam surfaced and reduced:
1. even after the earlier markdown file splits, the rendering file still mixed the block-view layer with two leaf buckets:
   - image descriptor/render support
   - HTML sanitizing/inline markdown cleanup
2. those leaf concerns now live in dedicated support files, which makes future markdown UI changes less likely to reopen the low-level sanitizing code

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 156: Library source-state support helper split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibrarySourceStateStore.swift`
- `Pinball App 2/Pinball App 2/library/LibrarySourceStateSupport.swift`

Changes made in this pass:
- moved the generic Library source-state helper bucket out of `LibrarySourceStateStore.swift`:
  - source-change notification posting
  - legacy dictionary-map normalization
  - pair deduping / dictionary-preserving-last-value helpers
- left `LibrarySourceStateStore.swift` focused on:
  - persisted state load/save
  - normalization/migration
  - synchronize/upsert/set/remove operations

Hidden seam surfaced and reduced:
1. `LibrarySourceStateStore.swift` was still carrying both the actual store behavior and a grab bag of support helpers used by other Library files
2. the store file is now closer to one responsibility, and the helper bucket has a dedicated home that other Library support files can share without making the store look larger than it is

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 144: Catalog payload-model split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogModels.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogPayloadModels.swift`

Changes made in this pass:
- moved the decoded catalog payload records out of `LibraryCatalogModels.swift` into `LibraryCatalogPayloadModels.swift`:
  - `NormalizedLibraryRoot`
  - `RawOPDBExportMachineRecord`
  - `CatalogManufacturerRecord`
  - `CatalogMachineRecord`
  - `CatalogSourceRecord`
  - `CatalogMembershipRecord`
  - `CatalogOverrideRecord`
  - `CatalogRulesheetLinkRecord`
  - `CatalogVideoLinkRecord`
- left `LibraryCatalogModels.swift` focused on app-facing catalog support types and derived records:
  - manufacturer search/display models
  - `ResolvedCatalogRecord`
  - provider enums
  - `LibraryExtraction`
  - `LegacyCuratedOverride`

Hidden seam surfaced and reduced:
1. `LibraryCatalogModels.swift` had become two different layers in one file:
   - wire-format decoding records
   - app-facing catalog/derived support models
2. splitting those layers makes future cleanup safer, because payload-schema edits and app-model edits no longer share one monolithic file

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 145: Rulesheet renderer viewport-restore split

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetRendererSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetRendererViewportRestoreSupport.swift`

Changes made in this pass:
- moved the `RulesheetRenderer.Coordinator` viewport-restore engine into `RulesheetRendererViewportRestoreSupport.swift`:
  - restore scheduling
  - viewport snapshot capture
  - restore retry logic
  - anchor capture/restore
  - restore-state reset and release handling
- left `RulesheetRendererSupport.swift` focused on:
  - `UIViewRepresentable` wiring
  - webview creation/update
  - navigation decisions
  - scroll progress updates
  - fragment scrolling and simple resume behavior

Hidden seam surfaced and fixed:
1. the split exposed a Swift nested-type access-control seam: coordinator state that used to be `private` in one file could no longer be reached from the extracted support file
2. I widened only the viewport-restore state and `currentScrollRatio` helper enough for the extracted support file to own that logic, then rebuilt successfully

Behavioral outcome:
- no intended front-facing behavior changed
- the viewport restore algorithm, retry thresholds, and fragment-scroll behavior were intentionally left unchanged

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 146: Native markdown document/rendering split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryMarkdown.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownDocumentSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownRenderingSupport.swift`

Changes made in this pass:
- moved markdown document-shaping support out of `LibraryMarkdown.swift`:
  - `NativeMarkdownDocumentBlock`
  - `NativeMarkdownDocumentBuilder`
  - `MarkdownBlockFramePreferenceKey`
- moved markdown block/image/rendering support out of `LibraryMarkdown.swift`:
  - `NativeMarkdownBlockView`
  - inline text rendering
  - table rendering
  - remote markdown images
  - HTML sanitizing
- left `LibraryMarkdown.swift` focused on the top-level `NativeMarkdownView` and `NativeMarkdownDocumentView`

Hidden seam surfaced and reduced:
1. `LibraryMarkdown.swift` was still acting as four layers at once:
   - document block construction
   - block rendering
   - remote image plumbing
   - HTML sanitizing
2. the file boundary now matches those responsibilities, so future changes to markdown parsing/sanitizing do not require reopening the top-level view shell

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 147: PinballGame decode and presentation support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryGame.swift`
- `Pinball App 2/Pinball App 2/library/LibraryGameDecodingSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryGamePresentationSupport.swift`

Changes made in this pass:
- moved the `Decodable` initializer out of `LibraryGame.swift` into `LibraryGameDecodingSupport.swift`
- moved `PinballGame` presentation helpers out of `LibraryGame.swift` into `LibraryGamePresentationSupport.swift`:
  - metadata display lines
  - location/bank formatting
  - image source URL helpers
  - YouTube ID extraction
- left `LibraryGame.swift` focused on:
  - stored model fields
  - nested payload/value types
  - the catalog-record initializer
  - identity keys

Hidden seam surfaced and fixed:
1. moving the decoder into its own file exposed that `PinballGame`'s `Decodable` conformance was relying on implicit file-local isolation assumptions under the project's default `MainActor` isolation
2. I fixed that by making the extracted decoder initializer explicitly `nonisolated`, which removed the stale concurrency warning from the build log

Behavioral outcome:
- no intended front-facing behavior changed
- the intentional `"Unknown Source"` malformed-payload fallback remains in place

## Pass 148: Markdown parser helper split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownParsing.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownParsingSupport.swift`

Changes made in this pass:
- moved markdown block-classification helpers out of `LibraryMarkdownParsing.swift`:
  - heading/list/hr parsing
  - table header/alignment helpers
  - anchor/image detection
  - raw HTML wrapper skipping
  - HTML table extraction/padding helpers
- left `LibraryMarkdownParsing.swift` focused on the main line-by-line parser state machine and block accumulation

Hidden seam surfaced and reduced:
1. `LibraryMarkdownParsing.swift` was carrying both the parser control flow and every helper used to classify or normalize lines
2. the parser loop is now easier to audit because the state machine reads top-to-bottom without the low-level HTML/table helper bucket embedded beneath it

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 149: Rulesheet renderer interaction support split

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetRendererSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetRendererInteractionSupport.swift`

Changes made in this pass:
- moved the remaining interaction/delegate layer out of `RulesheetRendererSupport.swift`:
  - navigation finish handling
  - link interception
  - script-message handling
  - scroll progress updates
  - resume-ratio application
  - fragment scroll behavior
  - content reload reset
  - rotation-triggered restore entrypoint
- left `RulesheetRendererSupport.swift` focused on:
  - the representable shell
  - webview construction/update
  - coordinator state

Hidden seam surfaced and reduced:
1. after the earlier viewport-restore split, `RulesheetRendererSupport.swift` still mixed three layers:
   - representable shell wiring
   - coordinator state
   - delegate/interaction behavior
2. the interaction behavior now lives in one dedicated support file, which makes the remaining coordinator state more explicit and keeps future rulesheet debugging from reopening the shell wiring again

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- follow-up check: `rg -n "warning:|error:" /tmp/pinprof-build-2026-03-29.log`
- result: no warnings or errors

## Pass 150: Seeded imported-source support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryImportedSourcesStore.swift`
- `Pinball App 2/Pinball App 2/library/LibrarySeededImportedSources.swift`

Changes made in this pass:
- moved the seeded default imported-source payloads out of `LibraryImportedSourcesStore.swift`
- left the store file focused on:
  - loading/saving imported sources
  - normalization
  - upsert/remove operations
  - first-run seeded-source injection

Hidden seam surfaced and reduced:
1. `LibraryImportedSourcesStore.swift` was carrying both persistence logic and the full seeded-source payload definition
2. separating the seeded records makes it easier to review future first-run Library changes without reopening store plumbing

Behavioral outcome:
- no intended front-facing behavior changed
- the default seeded source set stayed the same

## Pass 151: Library video-resolution support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryMediaResolutionSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryVideoResolutionSupport.swift`

Changes made in this pass:
- moved video ranking, deduping, and curated/video-link merge helpers out of `LibraryMediaResolutionSupport.swift`
- left `LibraryMediaResolutionSupport.swift` focused on the top-level rulesheet/video resolution entrypoints and curated-link composition

Hidden seam surfaced and reduced:
1. the media-resolution layer was still mixing two different resource families:
   - rulesheet merging/filtering
   - video ranking/deduping
2. the dedicated video support file now owns the video-specific policy without reopening rulesheet logic

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 152: Library source-parsing support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryPayloadParsing.swift`
- `Pinball App 2/Pinball App 2/library/LibrarySourceParsingSupport.swift`

Changes made in this pass:
- moved the source-payload parsing bucket out of `LibraryPayloadParsing.swift`:
  - `PinballLibraryRoot`
  - `PinballLibrarySourcePayload`
  - source-type parsing
  - source-ID canonicalization/slugging
  - source inference from payload games
- left `LibraryPayloadParsing.swift` focused on full payload decode plus sort-state parsing/defaulting

Hidden seam surfaced and reduced:
1. `LibraryPayloadParsing.swift` was still mixing full payload decode with a separate source-model parsing bucket
2. the parser now reads more like one responsibility, and source identity parsing has a single home

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 153: OPDB practice-identity support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogOPDBDecoding.swift`
- `Pinball App 2/Pinball App 2/library/LibraryOPDBPracticeIdentitySupport.swift`

Changes made in this pass:
- moved OPDB practice-identity support out of `LibraryCatalogOPDBDecoding.swift`:
  - practice-identity curations decode
  - practice-identity resolution from curated splits / OPDB group IDs
  - synthetic PinProf Labs machine insertion
- left `LibraryCatalogOPDBDecoding.swift` focused on:
  - raw OPDB export decode
  - `CatalogMachineRecord` construction
  - practice-catalog game/manufacturer option building

Hidden seam surfaced and fixed:
1. the initial split exposed a file-boundary access-control seam because the extracted curation helpers and synthetic-machine helper were still `private`
2. I widened only the extracted API surface needed by `LibraryCatalogOPDBDecoding.swift`, rebuilt, and kept the rest of the helper implementation private

Behavioral outcome:
- no intended front-facing behavior changed
- the synthetic PinProf Labs injection and curated practice-identity fallback order remained the same

## Pass 154: Remote rulesheet cache, catalog-resolution model, and playfield candidate support split

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetRemoteLoading.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetRemoteCacheSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogModels.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogResolutionModels.swift`
- `Pinball App 2/Pinball App 2/library/LibraryPlayfieldResolutionSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryPlayfieldCandidateSupport.swift`

Changes made in this pass:
- moved remote rulesheet cache/document/HTML-escaping support out of `RulesheetRemoteLoading.swift`
- moved `ResolvedCatalogRecord`, `LibraryExtraction`, and `LegacyCuratedOverride` out of `LibraryCatalogModels.swift`
- moved low-level playfield candidate assembly out of `LibraryPlayfieldResolutionSupport.swift`:
  - local asset-key inference
  - hosted/local/OPDB candidate gathering
  - playfield URL deduping
  - local playfield URL generation
- left the original files focused on higher-level orchestration:
  - remote rulesheet fetch/load policy
  - lightweight catalog enums/manufacturer metadata
  - public `PinballGame` playfield-facing API and candidate-group resolution

Hidden seams surfaced and fixed:
1. `RulesheetRemoteLoading.swift` was still carrying both the remote fetch policy and its cache/storage implementation
2. `LibraryCatalogModels.swift` had become a misleading mixed bucket of lightweight enums and the full resolved-record shape used during extraction
3. `LibraryPlayfieldResolutionSupport.swift` was still mixing the public game-facing playfield API with the low-level candidate assembly helpers that feed it
4. the catalog-model split briefly left a stale duplicate `ResolvedCatalogRecord` behind in the old file; I removed it and rebuilt successfully

Behavioral outcome:
- no intended front-facing behavior changed
- remote rulesheet caching, catalog record assembly, and playfield precedence/fallback behavior were intentionally preserved

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 136: Rulesheet renderer extraction and file-boundary cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetScreen.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetRendererSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetWebFallbackSupport.swift`

Changes made in this pass:
- moved the remaining renderer/web-view layer out of `RulesheetScreen.swift` into `RulesheetRendererSupport.swift`:
  - `RulesheetRenderer`
  - the large renderer `Coordinator`
- moved the fallback web rulesheet views into `RulesheetWebFallbackSupport.swift`:
  - `RulesheetWebFallbackView`
  - `ExternalRulesheetWebScreen`

Hidden seam surfaced and reduced:
1. `RulesheetScreen.swift` was still sharing one file with the full renderer/web-view engine even after the earlier shell cleanup
2. the extraction made the file boundary match the real ownership split: screen shell vs. renderer/fallback web support
3. the new support types cannot be `private`, because `RulesheetScreen.swift` intentionally composes them from sibling files

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 137: Rulesheet viewport-restore support split

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetRendererSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetViewportSupport.swift`

Changes made in this pass:
- moved viewport snapshot data models out of the renderer coordinator:
  - `RulesheetViewportLayoutSnapshot`
  - `RulesheetNativeViewportLayoutSnapshot`
  - `RulesheetCombinedViewportLayoutSnapshot`
- moved the pure viewport-restore comparison rules out of the coordinator into `RulesheetViewportRestoreSupport`:
  - layout stability checks
  - DOM/native coherence checks
  - baseline-vs-current restore-state change checks

Hidden seam surfaced and reduced:
1. the renderer coordinator was carrying both mutable scroll/restore state and the pure comparison policy that decides when restore can safely finish
2. the support split keeps the coordinator responsible for orchestration, while the pure restore heuristics now live in a reusable reviewable helper

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 138: Library list/menu support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryListScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryFilterMenuSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryGridSupport.swift`

Changes made in this pass:
- moved the Library source/sort/bank filter menu views out of `LibraryListScreen.swift` into `LibraryFilterMenuSupport.swift`
- moved the Library empty state, grouped/ungrouped grid flow, load-more footer, and image-card overlay views out of `LibraryListScreen.swift` into `LibraryGridSupport.swift`
- left `LibraryListScreen.swift` focused on the `LibraryScreen` extension wiring between view model state, layout metrics, and the extracted support views

Hidden seam surfaced and reduced:
1. `LibraryListScreen.swift` was still a mixed file that owned both screen-extension wiring and all of the menu/grid leaf views
2. the file boundary now matches the real split between:
   - `LibraryScreen` extension wiring
   - filter menu leaf views
   - grid/list/card leaf views

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`

## Pass 139: Library detail video/resource support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryDetailComponents.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDetailVideoSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDetailResourceSupport.swift`

Changes made in this pass:
- moved the Library detail video-card stack out of `LibraryDetailComponents.swift`:
  - `LibraryDetailVideosCard`
  - the video grid/tile views
  - `PinballVideoLaunchPanel`
  - the YouTube thumbnail helper
- moved the rulesheet/playfield resource chip views out of `LibraryDetailComponents.swift`:
  - `LibraryRulesheetResourcesRow`
  - `LibraryPlayfieldResourcesRow`
  - `LibraryRulesheetLinkChip`
  - `LibraryRulesheetChip`
- left `LibraryDetailComponents.swift` focused on:
  - screenshot section
  - summary card
  - game-info card

Hidden seam surfaced and reduced:
1. `LibraryDetailComponents.swift` had become a second mini-screen bucket, mixing summary/layout cards with all of the video-launch and resource-chip leaf views
2. the split makes the file boundary match the actual UI sections, so future cleanup can touch summary, media, or resource rows independently

Behavioral outcome:
- no intended front-facing behavior changed

Deferred hotspot intentionally left alone:
1. `RulesheetWebViewSupport.swift` still contains the large embedded JavaScript bridge
2. that is still a good later cleanup target, but it is a higher-risk string-heavy split than the Swift-only view decomposition in this batch

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`

## Pass 140: Rulesheet web bridge externalized as bundled JS resource

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetWebViewSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetWebBridge.js`

Changes made in this pass:
- moved the large embedded rulesheet web bridge out of `RulesheetWebViewSupport.swift` into the bundled `RulesheetWebBridge.js` resource
- kept the public bridge contract the same:
  - `__pinballSetAnchorScrollInset`
  - `__pinballScrollToFragment`
  - `__pinballCaptureViewportLayoutSnapshot`
  - `__pinballCaptureViewportAnchor`
  - `__pinballRestoreViewportAnchor`
- updated Swift to load the JS template from the app bundle and inject only the dynamic values:
  - chrome tap message name
  - fragment scroll message name
  - initial anchor inset

Hidden seam surfaced and reduced:
1. `RulesheetWebViewSupport.swift` was not just large, it was carrying a fragile 400-line JavaScript program inside one multiline Swift string
2. externalizing the bridge into a bundled JS resource makes future cleanup passes review the script as script, instead of editing it through Swift string escaping

Behavioral outcome:
- no intended front-facing behavior changed
- the bookmark/restore math and fragment-scroll behavior were intentionally left unchanged in this pass

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- verified bundled resource copy at `DerivedData/.../PinProf.app/RulesheetWebBridge.js`

Open follow-up items from this pass:
1. reduce duplicate launch/foreground startup work in `Pinball_App_2App.swift`
2. collapse and cache app-shake artwork loading in `AppShakeCoordinator.swift`
3. decide whether intro artwork loading should remain in `AppIntroOverlay.swift` now that Settings reuses it
4. rename the generic performance log prefix on both iOS and Android

Next files queued:
- `Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`
- `Pinball App 2/Pinball App 2/ui/AppPresentationChrome.swift`
- `Pinball App 2/Pinball App 2/ui/AppResourceChrome.swift`
- `Pinball App 2/Pinball App 2/ui/AppTheme.swift`
- `Pinball App 2/Pinball App 2/ui/AppToolbarActions.swift`

## Pass 141: Venue overlay and CAF asset support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogVenueSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryVenueMetadataOverlaySupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCAFAssetSupport.swift`

Changes made in this pass:
- moved venue overlay records, overlay key helpers, overlay parsing, and overlay merge behavior into `LibraryVenueMetadataOverlaySupport.swift`
- moved CAF asset decode records plus grouped rulesheet/video/override builders into `LibraryCAFAssetSupport.swift`
- left `LibraryCatalogVenueSupport.swift` focused on the curated-override lookup policy plus the CAF payload/extraction assembly path

Hidden seam surfaced and reduced:
1. `LibraryCatalogVenueSupport.swift` had become a mixed bucket for three different layers:
   - overlay metadata models and parsing
   - CAF asset decoding and grouped-link extraction
   - final CAF Library payload assembly
2. the split makes the file boundary match those responsibilities, so future venue/import cleanup can touch overlay or asset logic without reopening final payload assembly

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 142: Shared remote image support extracted from misnamed playfield file

Primary files:
- `Pinball App 2/Pinball App 2/library/RemoteUIImageSupport.swift`
- `Pinball App 2/Pinball App 2/library/RemoteImageViews.swift`
- `Pinball App 2/Pinball App 2/library/HostedImageScreen.swift`
- removed: `Pinball App 2/Pinball App 2/library/PlayfieldScreen.swift`

Changes made in this pass:
- moved shared remote image cache/repository/loader support into `RemoteUIImageSupport.swift`
- moved reusable async image card views into `RemoteImageViews.swift`
- moved fullscreen hosted-image viewing into `HostedImageScreen.swift`
- removed the old `PlayfieldScreen.swift` file, which no longer contained a `PlayfieldScreen` at all

Hidden seam surfaced and reduced:
1. `PlayfieldScreen.swift` had become misleadingly named shared infrastructure used across Library, Practice, GameRoom, and Settings
2. the split fixes the file-ownership mismatch, so future image-loading cleanup is no longer trapped behind a playfield-specific filename

Behavioral outcome:
- no intended front-facing behavior changed
- all existing shared image consumers continue to use the same cache/retry/fallback behavior

## Pass 143: Remote rulesheet helper split

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetRemoteLoading.swift`
- `Pinball App 2/Pinball App 2/library/TiltForumsRulesheetSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetHTMLCleanupSupport.swift`

Changes made in this pass:
- moved Tilt Forums payload decoding, canonical URL helpers, and `.json` endpoint normalization into `TiltForumsRulesheetSupport.swift`
- moved remote HTML cleanup helpers into `RulesheetHTMLCleanupSupport.swift`
- left `RulesheetRemoteLoading.swift` focused on provider routing, remote fetch/cache behavior, and attribution markup

Hidden seam surfaced and fixed:
1. the initial split exposed two access-control seams:
   - the Tilt Forums support types were too private for their extracted helpers
   - `htmlEscaped` was too private for the extracted HTML cleanup helpers
2. those were corrected without changing runtime behavior, and the follow-up build passed cleanly

Behavioral outcome:
- no intended front-facing behavior changed
- remote rulesheet fetch, stale-cache fallback, and provider-specific rendering behavior were intentionally left unchanged

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 002: Shared UI Seams

Files in scope:
- `Pinball App 2/Pinball App 2/ui/AppToolbarActions.swift`
- `Pinball App 2/Pinball App 2/ui/AppPresentationChrome.swift`
- `Pinball App 2/Pinball App 2/ui/AppTheme.swift`
- `Pinball App 2/Pinball App 2/ui/AppResourceChrome.swift`
- `Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`

### `AppToolbarActions.swift`

Status: `reviewed`

Responsibility summary:
- defines the shared toolbar button wrappers for `Cancel`, `Confirm`, and `Done`

Primary interactions:
- `practice/PracticeGameEntrySheets.swift`
- `practice/PracticeGroupEditorComponents.swift`
- `practice/PracticeJournalSettingsSections.swift`
- `practice/PracticePresentationHost.swift`
- `practice/PracticeQuickEntrySheet.swift`
- `gameroom/GameRoomPresentationComponents.swift`

Findings:
- no dead code found
- intentionally thin abstraction, but it is used widely enough to justify existing as a consistency seam

Changes made in this pass:
- none

### `AppPresentationChrome.swift`

Status: `reviewed`

Responsibility summary:
- defines the shared full-screen shell wrapper (`AppScreen`)
- defines shared sheet presentation chrome
- defines shared zoom-transition wiring

Primary interactions:
- root screens across League, Library, Practice, GameRoom, Settings, Targets, Standings, Stats, and About
- presentation hosts in Practice and GameRoom

Findings:
- no dead code found
- compact and cohesive; this is a healthy shared seam, not a cleanup hotspot

Changes made in this pass:
- none

### `AppTheme.swift`

Status: `change made`

Responsibility summary:
- owns display-mode values
- owns semantic color, spacing, shape, and typography tokens
- owns shared layout heuristics and the global background/panel/control modifiers

Primary interactions:
- effectively all iOS feature folders
- `app/Pinball_App_2App.swift` for display mode
- `app/ContentView.swift` and `ui/AppPresentationChrome.swift` for shell behavior

Findings:
- `change made`: removed `appGlassControlStyle()`, which no longer had any call sites.
- `follow-up`: this file exposes tokens through multiple access paths (`AppTheme.spacing` and `AppSpacing`, `AppTheme.shapes` and `AppRadii`). That works, but it expands the surface area of the design system and makes future cleanup harder.
- `follow-up`: this file is still cohesive, but it mixes foundational tokens with concrete view modifiers. If it keeps growing, it should eventually split into `tokens` and `view modifiers` rather than one long theme file.

Changes made in this pass:
- removed unused `appGlassControlStyle()`

### `AppResourceChrome.swift`

Status: `change made`

Responsibility summary:
- owns shared resource-chip button styles
- owns shared resource-row and chip-wrap layout seams
- owns shared variant, overlay, reading-progress, and media-placeholder helpers
- owns shared video-tile chrome

Primary interactions:
- `library/LibraryDetailComponents.swift`
- `library/RulesheetScreen.swift`
- `library/PlayfieldScreen.swift`
- `practice/PracticeVideoComponents.swift`
- `gameroom/GameRoomHomeComponents.swift`
- `gameroom/GameRoomMachineView.swift`
- `app/AppShakeCoordinator.swift`

Findings:
- `change made`: removed `PinballOverlayMetadataBadge`, which no longer had any call sites.
- `follow-up`: this file is a real shared seam, but it has also become a utility bucket for styles, layouts, overlay text, and placeholder states. It is still coherent around “resource/media chrome,” yet it is approaching the size where layout utilities and visual chrome may want separate files.
- `follow-up`: `PinballResourceRowView` depends on custom layout types defined in the same file, which is fine for now, but it makes the file harder to skim linearly.

Changes made in this pass:
- removed unused `PinballOverlayMetadataBadge`

### `AppFilterControls.swift`

Status: `reviewed`

Responsibility summary:
- owns shared press-feedback behavior
- owns shared action-button styles
- owns shared toolbar labels, dropdown labels, status chips, metric pills, and success banners

Primary interactions:
- used across Library, Practice, Settings, GameRoom, Stats, Standings, and Targets
- `ui/AppResourceChrome.swift` also depends on `AppPressFeedbackButtonStyleBody`, so these two shared seam files are coupled

Findings:
- no dead code confirmed in the currently used controls after symbol tracing
- this is a high-growth hotspot: one file now owns press-state behavior, multiple button families, toolbar labels, menu labels, status chips, metric chrome, and segmented-control styling
- the file is still legitimate shared UI, but it is a prime candidate for future split-by-concern if it keeps accumulating helpers

Changes made in this pass:
- none

## Pass 002 summary

Safe cleanup changes made:
- removed unused `appGlassControlStyle()` from `AppTheme.swift`
- removed unused `PinballOverlayMetadataBadge` from `AppResourceChrome.swift`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. decide whether `AppTheme.swift` should stay as one combined token-plus-modifier file
2. watch `AppFilterControls.swift` for further growth and split by concern before it turns into a second shared “misc” file
3. watch `AppResourceChrome.swift` for further growth and split layout helpers from visual helpers if new resource/media variants are added

Next files queued:
- `Pinball App 2/Pinball App 2/data/PinballDataCache.swift`
- `Pinball App 2/Pinball App 2/data/SharedCSV.swift`

## Pass 003: Data Foundations

Files in scope:
- `Pinball App 2/Pinball App 2/data/PinballDataCache.swift`
- `Pinball App 2/Pinball App 2/data/SharedCSV.swift`

### `PinballDataCache.swift`

Status: `change made`

Responsibility summary:
- owns the disk-cache root and hashed file layout for hosted pinball resources
- seeds the app-shipped preload bundle into the cache on first load
- refreshes remote cache metadata and update-log removals
- serves text and binary hosted resources with stale-on-failure behavior
- serves non-manifest remote images through a separate disk cache and background revalidation path
- exposes nonisolated cached-file readers for callers that need synchronous local fallback access

Line map:
- `4-63`: preload manifest helpers, cache-path normalization, hashed file resolution, and synchronous local fallback reads
- `65-171`: cache actor definition, concurrency limiter, manifest/update-log/index schemas, and actor state
- `173-247`: public text-load, force-refresh, hosted-library refresh, cache-clear, and age-bounded load APIs
- `249-343`: update checks, binary load path, remote-image fetches, and remote-image revalidation scheduling
- `345-527`: hosted-resource revalidation, network fetch/write paths, cached-file reads, and metadata refresh
- `529-619`: startup load, bundled preload seeding, and one-time legacy cache purge
- `621-715`: best-effort foreground refresh, persistence, remote-image pruning, and manifest-cache eligibility

Primary interactions:
- `app/Pinball_App_2App.swift`: foreground metadata refresh
- `app/AppShakeCoordinator.swift`: synchronous fallback-art reads via `loadCachedPinballData(path:)`
- `library/LibraryHostedData.swift`: age-bounded hosted JSON loads and hosted-data warmup
- `library/LibraryDataLoader.swift`: synchronous OPDB fallback reads
- `library/PlayfieldScreen.swift` and `gameroom/GameRoomPresentationComponents.swift`: binary/image data loads
- `settings/SettingsDataIntegration.swift`: force-refresh and clear-cache entry points
- `league/LeaguePreviewLoader.swift`
- `practice/PracticeStoreDataLoaders.swift`
- `practice/PracticeStoreLeagueHelpers.swift`
- `practice/PracticeStoreLeagueOps.swift`
- `standings/StandingsScreen.swift`
- `stats/StatsScreen.swift`
- `targets/TargetsScreen.swift`

Findings:
- `change made`: removed unused `cachePinballData(path:data:)` and unused `cachedUpdatedAt(path:)`. A repo-wide caller search found no references to either helper.
- `follow-up`: `clearAllCachedData()` clears disk state, but already-launched `Task.detached` revalidation jobs are not cancelled. Those background jobs can finish after a clear and silently repopulate `resources` or `remote-images`, which is competing behavior between the clear-cache action and the cache's own fire-and-forget maintenance work.
- `follow-up`: update-log checkpointing currently stores `updateLog.events.first?.generatedAt` as the new scan marker. That assumes the server always returns newest-first ordering. Android's `PinballDataCache.kt` already computes the newest timestamp explicitly, so iOS is the more fragile side of the parity pair here.
- `follow-up`: for `allowMissing` resources, `fetchBinaryFromNetwork` can mark a path missing purely because the refreshed manifest lacks the entry. That means manifest completeness, not just an actual `404`, is part of the runtime truth for optional league/library files.
- `follow-up`: bundled preload fallback is split across two surfaces. The actor only serves seeded disk files, while `loadCachedPinballData(path:)` still falls back directly to bundle files. After a runtime cache clear, actor-based consumers and synchronous-helper consumers can temporarily see different offline behavior until the app relaunches or data refetches.

Recommended follow-up:
- add a generation or cancellation guard so clear-cache cannot be undone by outstanding background revalidation
- compute the newest update-log timestamp explicitly on iOS, mirroring the more defensive Android implementation
- decide whether optional hosted files should trust manifest absence immediately or only after a direct fetch confirms they are gone
- decide whether bundled preload is a one-time bootstrap mechanism or a stable offline fallback contract, then make both access paths follow that same rule

Changes made in this pass:
- removed unused `cachePinballData(path:data:)`
- removed unused `cachedUpdatedAt(path:)`

### `SharedCSV.swift`

Status: `reviewed`

Responsibility summary:
- provides the shared CSV row parser used by league, standings, stats, and practice imports
- provides shared header and season normalization helpers
- owns LPL name-privacy keys and the client-side unlock gate
- formats player names for display while applying redaction rules
- refreshes the redacted-player set from hosted CSV data at app startup/foreground refresh

Line map:
- `4-30`: redaction constants, hosted redaction path alias, privacy keys, and the thread-safe redacted-player store
- `32-110`: CSV row parsing plus header and season normalization helpers
- `112-157`: display formatting, full-name unlock logic, redaction display helper, and hosted redaction refresh
- `159-205`: name normalization, redaction token generation, and redacted-player CSV parsing

Primary interactions:
- `app/Pinball_App_2App.swift`: boot/foreground refresh of redacted-player data
- `settings/SettingsHomeSections.swift`: unlock/full-name settings UI
- `practice/PracticeScreenDerivedData.swift`: explicit redacted-name display
- `practice/PracticeStoreDataLoaders.swift` and `practice/PracticeStoreLeagueHelpers.swift`: shared CSV parsing
- `league/LeaguePreviewParsing.swift`
- `standings/StandingsScreen.swift`
- `stats/StatsScreen.swift`
- `practice/PracticeScreenContexts.swift`, `practice/PracticeInsightsSection.swift`, `practice/PracticeJournalSettingsSections.swift`, `practice/PracticeStore.swift`, `league/LeagueTypes.swift`, `league/LeaguePreviewSections.swift`, and `league/LeagueCardPreviews.swift`: shared player-name display formatting

Findings:
- no dead code confirmed after tracing every public helper to current callers
- `follow-up`: this file mixes three concerns that have grown together over time: generic CSV parsing, name-privacy preference policy, and live redaction-data refresh. Android already splits the analogous behavior across `Csv.kt` and `LplNamePrivacy.kt`, so iOS carries more hidden cross-feature coupling here than Android does.
- `follow-up`: `formatLPLPlayerNameForDisplay` looks like a pure formatter at the call site, but it reads both `UserDefaults` and the global redacted-player store. That hides app-state dependencies inside render-time string formatting across Stats, Standings, League, and Practice.
- `follow-up`: `LPLNamePrivacySettings.fullNamePassword` is hard-coded in the client and mirrored on Android. That keeps parity, but it means the feature is a convenience gate, not a security boundary.

Recommended follow-up:
- split iOS CSV parsing from LPL privacy policy so the file boundaries match the real responsibilities more closely
- make the “show full last name” decision explicit at more call sites if clarity matters more than convenience
- document the full-name unlock behavior as a product gate rather than a protected secret, unless a stronger server-backed control is intended later

Changes made in this pass:
- none

## Pass 003 summary

Safe cleanup changes made:
- removed unused `cachePinballData(path:data:)` from `PinballDataCache.swift`
- removed unused `cachedUpdatedAt(path:)` from `PinballDataCache.swift`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. prevent detached cache revalidation work from repopulating disk after a user-initiated cache clear
2. mirror Android's more defensive update-log checkpointing on iOS
3. decide whether manifest absence is enough to mark optional hosted files missing
4. split `SharedCSV.swift` by concern before more privacy or parsing rules accumulate there

Next files queued:
- `Pinball App 2/Pinball App 2/info/AboutScreen.swift`

## Pass 004: Info

Files in scope:
- `Pinball App 2/Pinball App 2/info/AboutScreen.swift`
- `Pinball App 2/Pinball App 2/info/LPLLogo.webp`

### `AboutScreen.swift`

Status: `reviewed`

Responsibility summary:
- defines the reusable Lansing Pinball League logo view
- defines the reusable Lansing Pinball League about-content block
- wraps that content in a standalone screen for the root About route

Line map:
- `3-6`: external website and Facebook links
- `8-20`: bundled LPL logo loading and image rendering
- `22-114`: responsive About content layout, copy, external links, and width tracking
- `116-125`: standalone screen wrapper

Primary interactions:
- `league/LeagueDestinationView.swift`: reuses `LPLAboutContent()` for the League tab's About destination
- `league/LeagueShellContent.swift`: reuses `LPLLogoView`
- `ui/AppPresentationChrome.swift`: `AppScreen`
- shared theme/layout helpers such as `AppLayout`, `AppExternalLinkButtonLabel`, and `appReadableWidth`

Findings:
- no dead code found
- `follow-up`: `LPLLogoView` reads `LPLLogo.webp` synchronously with `Data(contentsOf:)` and decodes it inline on the main thread every time the view is rebuilt. There is no cache or shared provider here.
- `follow-up`: this file hard-codes time-sensitive league copy directly in SwiftUI view code. A live check against the official Lansing Pinball League site on March 26, 2026 shows the side-tournament finals are currently described there as top 4, while the in-app copy still says top 8 and anchors the schedule in more brittle prose. This is content drift hiding inside code.
- `reviewed`: `LPLAboutContent` is intentionally reused between the standalone About screen and League navigation, so any copy or media change here affects both surfaces together.

Recommended follow-up:
- centralize or cache bundled LPL logo loading instead of decoding the asset inline in the view body path
- move frequently changing league logistics out of hard-coded prose, or at least keep the copy in one explicitly maintained constant/model so seasonal updates are easier to spot

Changes made in this pass:
- none

## Pass 004 summary

Safe cleanup changes made:
- none

Verification:
- no code changes in this pass; prior simulator build still applies

Open follow-up items from this pass:
1. cache or centralize `LPLLogo.webp` loading
2. remove season-coupled or tournament-structure-coupled copy from `AboutScreen.swift`

Next files queued:
- `Pinball App 2/Pinball App 2/league/LeagueCardPreviews.swift`
- `Pinball App 2/Pinball App 2/league/LeagueDestinationView.swift`
- `Pinball App 2/Pinball App 2/league/LeaguePreviewLoader.swift`
- `Pinball App 2/Pinball App 2/league/LeaguePreviewModel.swift`
- `Pinball App 2/Pinball App 2/league/LeaguePreviewParsing.swift`
- `Pinball App 2/Pinball App 2/league/LeaguePreviewRotationState.swift`
- `Pinball App 2/Pinball App 2/league/LeaguePreviewSections.swift`
- `Pinball App 2/Pinball App 2/league/LeagueScreen.swift`
- `Pinball App 2/Pinball App 2/league/LeagueShellContent.swift`
- `Pinball App 2/Pinball App 2/league/LeagueTypes.swift`

## Pass 005: League

Files in scope:
- `Pinball App 2/Pinball App 2/league/LeagueCardPreviews.swift`
- `Pinball App 2/Pinball App 2/league/LeagueDestinationView.swift`
- `Pinball App 2/Pinball App 2/league/LeaguePreviewLoader.swift`
- `Pinball App 2/Pinball App 2/league/LeaguePreviewModel.swift`
- `Pinball App 2/Pinball App 2/league/LeaguePreviewParsing.swift`
- `Pinball App 2/Pinball App 2/league/LeaguePreviewRotationState.swift`
- `Pinball App 2/Pinball App 2/league/LeaguePreviewSections.swift`
- `Pinball App 2/Pinball App 2/league/LeagueScreen.swift`
- `Pinball App 2/Pinball App 2/league/LeagueShellContent.swift`
- `Pinball App 2/Pinball App 2/league/LeagueTypes.swift`

### `LeagueCardPreviews.swift`

Status: `reviewed`

Responsibility summary:
- renders the tappable preview cards for the League home screen
- owns rotating preview state per card
- formats the visible player label for preview stats cards

Primary interactions:
- `league/LeagueShellContent.swift`
- `league/LeaguePreviewModel.swift`
- `league/LeaguePreviewRotationState.swift`
- `league/LeaguePreviewSections.swift`
- `league/LeagueTypes.swift`
- `data/SharedCSV.swift`

Findings:
- `follow-up`: `@AppStorage(LPLNamePrivacySettings.showFullLastNameDefaultsKey)` is only touched through `_ = showFullLPLLastNames` so SwiftUI invalidates when the preference changes. The actual formatting decision still happens inside `formatLPLPlayerNameForDisplay`, which means the dependency is intentionally hidden twice.
- no dead code found

Changes made in this pass:
- none

### `LeagueDestinationView.swift`

Status: `reviewed`

Responsibility summary:
- routes each `LeagueDestination` to its full-screen destination view

Primary interactions:
- `stats/StatsScreen.swift`
- `standings/StandingsScreen.swift`
- `targets/TargetsScreen.swift`
- `info/AboutScreen.swift`

Findings:
- no dead code found
- intentionally small route seam; healthy as-is

Changes made in this pass:
- none

### `LeaguePreviewLoader.swift`

Status: `reviewed`

Responsibility summary:
- loads the three preview data sources in parallel
- resolves the preferred league player from Practice defaults
- constructs the combined League home snapshot

Primary interactions:
- `data/PinballDataCache.swift`
- `practice/PracticeStore.swift`
- `league/LeaguePreviewParsing.swift`
- `library/LibraryHostedData.swift` path constants

Findings:
- `follow-up`: one thrown fetch currently empties the whole League home snapshot because all three preview loads live inside one `do/catch` that falls back to `LeaguePreviewSnapshot()`. That creates cross-preview coupling between Targets, Standings, and Stats even though they are logically independent.
- `follow-up`: the preferred-player source comes directly from `PracticeStore.loadPreferredLeaguePlayerNameFromDefaults()`, so the League home screen has an implicit dependency on Practice preference state.

Changes made in this pass:
- none

### `LeaguePreviewModel.swift`

Status: `reviewed`

Responsibility summary:
- stores the League home preview snapshot for SwiftUI
- exposes one notification-based refresh trigger for cross-feature updates

Primary interactions:
- `league/LeagueScreen.swift`
- `stats/StatsScreen.swift`
- `standings/StandingsScreen.swift`
- `settings/SettingsDataIntegration.swift`

Findings:
- `follow-up`: preview refresh is coordinated through a global `NotificationCenter` notification. It works, but it is ambient coupling rather than an explicit dependency path, so refresh behavior is harder to trace from call sites.

Changes made in this pass:
- none

### `LeaguePreviewParsing.swift`

Status: `change made`

Responsibility summary:
- parses standings and stats preview data
- computes next-bank and around-you preview slices
- normalizes names and dates for preview selection
- defines the lightweight parsed-row payloads used by League previews

Line map:
- `3-14`: preview payload containers
- `16-114`: standings/stats preview construction
- `116-195`: standings/stats CSV parsing
- `197-231`: next-bank resolution and preview-selection helpers
- `233-285`: name normalization, around-you windowing, date formatter, and parsed row models

Primary interactions:
- `league/LeaguePreviewLoader.swift`
- `data/SharedCSV.swift`

Findings:
- `change made`: removed unused `parseLeagueTargetRows(_:)`, which is a leftover from the older CSV-based target preview path. The current loader uses resolved JSON targets instead.
- `change made`: removed unused `mergeLeagueTargetsWithLibrary(...)`, another leftover from the earlier target-preview shaping path.
- `follow-up`: preview parsing now lives in a separate local pipeline rather than reusing full-screen Stats/Standings loaders, so CSV interpretation logic is duplicated across the League preview stack and the full feature screens.

Changes made in this pass:
- removed unused `parseLeagueTargetRows(_:)`
- removed unused `mergeLeagueTargetsWithLibrary(...)`

### `LeaguePreviewRotationState.swift`

Status: `reviewed`

Responsibility summary:
- rotates the preview metric shown in Targets
- rotates the preview mode shown in Standings
- rotates the preview value shown in Stats

Primary interactions:
- `league/LeagueCardPreviews.swift`

Findings:
- `follow-up`: the state object starts three separate 4-second timers that all live for the lifetime of the view model. That is simple, but it means three independent publishers and three separate invalidation streams for one small preview surface.

Changes made in this pass:
- none

### `LeaguePreviewSections.swift`

Status: `reviewed`

Responsibility summary:
- renders the preview tables/chips for Targets, Standings, and Stats

Primary interactions:
- `league/LeagueCardPreviews.swift`
- `league/LeagueTypes.swift`
- `data/SharedCSV.swift`
- shared UI seams in `ui/AppFilterControls.swift` and `ui/AppTheme.swift`

Findings:
- `follow-up`: `StandingsPreview` repeats the same `_ = showFullLPLLastNames` invalidation pattern used by `LeagueCard`. That makes the preview UI depend on both `@AppStorage` and the global formatter side effect instead of one explicit formatting contract.
- no dead code found

Changes made in this pass:
- none

### `LeagueScreen.swift`

Status: `reviewed`

Responsibility summary:
- owns the League home preview model
- mounts the League shell content inside the root navigation stack
- listens for cross-feature preview refresh notifications

Primary interactions:
- `league/LeaguePreviewModel.swift`
- `league/LeagueShellContent.swift`
- `league/LeagueDestinationView.swift`

Findings:
- `follow-up`: `.onReceive` launches `Task { await previewModel.reload() }` for every notification without coalescing or cancellation. Rapid refresh notifications can overlap preview reload work.

Changes made in this pass:
- none

### `LeagueShellContent.swift`

Status: `reviewed`

Responsibility summary:
- lays out the League home navigation cards
- switches between portrait list and landscape grid presentation
- owns the reusable footer link to the About destination

Primary interactions:
- `league/LeagueCardPreviews.swift`
- `league/LeagueTypes.swift`
- `info/AboutScreen.swift`

Findings:
- no dead code found
- healthy shell file; most of the interesting complexity lives in preview content rather than layout

Changes made in this pass:
- none

### `LeagueTypes.swift`

Status: `change made`

Responsibility summary:
- defines League destinations, preview modes, and preview row types
- defines small number-formatting helpers used by the preview UI

Primary interactions:
- used throughout the entire `league/` folder
- `data/SharedCSV.swift` for formatted player names

Findings:
- `change made`: removed unused `LeagueStandingsPreviewRow.displayPlayer`.
- `follow-up`: the preview row types are intentionally lightweight, but name-display behavior still leaks in through `rawPlayer` plus the global formatter instead of one explicit presentation field.

Changes made in this pass:
- removed unused `LeagueStandingsPreviewRow.displayPlayer`

## Pass 005 summary

Safe cleanup changes made:
- removed unused `parseLeagueTargetRows(_:)` from `LeaguePreviewParsing.swift`
- removed unused `mergeLeagueTargetsWithLibrary(...)` from `LeaguePreviewParsing.swift`
- removed unused `LeagueStandingsPreviewRow.displayPlayer` from `LeagueTypes.swift`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. make League preview loading degrade per source instead of blanking the whole home snapshot on one failure
2. replace hidden `@AppStorage` invalidation hacks with a more explicit player-name formatting contract
3. decide whether NotificationCenter is still the right refresh seam for League previews
4. collapse the three preview-rotation timers if preview churn becomes noisy
5. decide whether preview CSV parsing should intentionally stay separate from the full-screen loaders

Next files queued:
- `Pinball App 2/Pinball App 2/library/LibraryActivityLog.swift`
- `Pinball App 2/Pinball App 2/library/LibraryBuiltInSources.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryContentLoading.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDataLoader.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDetailComponents.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDetailScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDomain.swift`
- `Pinball App 2/Pinball App 2/library/LibraryGameLookup.swift`
- `Pinball App 2/Pinball App 2/library/LibraryHostedData.swift`
- `Pinball App 2/Pinball App 2/library/LibraryListScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdown.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownParsing.swift`
- `Pinball App 2/Pinball App 2/library/LibraryPayloadParsing.swift`
- `Pinball App 2/Pinball App 2/library/LibraryResourceResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryVideoMetadata.swift`
- `Pinball App 2/Pinball App 2/library/PlayfieldScreen.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetScreen.swift`

## Pass 006: Library Foundations

Files in scope:
- `Pinball App 2/Pinball App 2/library/LibraryActivityLog.swift`
- `Pinball App 2/Pinball App 2/library/LibraryBuiltInSources.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryContentLoading.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDataLoader.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDetailComponents.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDetailScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDomain.swift`
- `Pinball App 2/Pinball App 2/library/LibraryGameLookup.swift`
- `Pinball App 2/Pinball App 2/library/LibraryHostedData.swift`

### `LibraryActivityLog.swift`

Status: `reviewed`

Responsibility summary:
- persists recent library interactions in `UserDefaults`
- deduplicates bursty repeated events
- exposes an in-memory cache plus revision number for consumers that need cheap refresh checks

Primary interactions:
- `library/LibraryScreen.swift`
- `library/LibraryDetailComponents.swift`
- `practice/PracticeStoreJournalHelpers.swift`
- `practice/PracticeScreenContexts.swift`

Findings:
- `follow-up`: the static `cachedEvents` plus `revision` pair is a benign but implicit threading contract. The code assumes all callers are effectively on the main/UI side even though the type itself is not actor-isolated.
- no dead code found

Changes made in this pass:
- none

### `LibraryBuiltInSources.swift`

Status: `change made`

Responsibility summary:
- defines canonical built-in venue IDs
- normalizes legacy source aliases
- describes built-in venue names
- repairs old pinned Pinball Map venue references by importing them on demand

Line map:
- `3-21`: built-in IDs, alias map, display names, and default-enabled source list
- `23-40`: legacy migration target definitions
- `42-73`: canonicalization helpers and small built-in source list constructor
- `75-115`: startup/foreground migration repair path for old pinned Pinball Map sources

Primary interactions:
- `app/Pinball_App_2App.swift`
- `library/LibraryCatalogStore.swift`
- `library/LibraryPayloadParsing.swift`
- `settings/SettingsDataIntegration.swift`
- `PinballMapClient`

Findings:
- `change made`: removed unused `builtinVenueSourceName(for:)`.
- `change made`: removed unused `pinballMapLocationID(for:)`.
- `follow-up`: `defaultBuiltinVenueSourceIDs` is intentionally empty. Built-in venue knowledge mostly exists now for aliasing, migration, and the special GameRoom source rather than for auto-enabled defaults.
- `follow-up`: `migrateLegacyPinnedVenueImportsIfNeeded()` is legitimate repair logic, but it is still hidden app-shell work that runs outside Settings and outside Library proper.

Changes made in this pass:
- removed unused `builtinVenueSourceName(for:)`
- removed unused `pinballMapLocationID(for:)`

### `LibraryCatalogResolution.swift`

Status: `reviewed`

Responsibility summary:
- resolves imported catalog machines into app-level `PinballGame` rows
- chooses preferred machines for manufacturer/group/variant lookups
- normalizes variant labels and display titles
- resolves imported rulesheet and video preference order

Line map:
- `3-72`: imported machine to `PinballGame` resolution
- `75-123`: preferred-machine comparators
- `125-222`: variant normalization and title/variant suffix interpretation
- `224-690`: preferred-variant/source lookup helpers plus imported rulesheet/video merge rules

Primary interactions:
- `library/LibraryCatalogStore.swift`
- `library/LibraryDataLoader.swift`
- `practice/PracticeStoreDataLoaders.swift`

Findings:
- `reviewed`: `catalogPreferredGroupDefaultMachine(_:_ )` looks visually redundant next to `catalogPreferredManufacturerMachine(_:_ )`, but it is still live through practice/export decode in `LibraryCatalogStore.swift`. The review briefly removed it and the simulator build failed, so the comparator was restored.
- `follow-up`: `catalogResolvedVariantLabel(title:explicitVariant:)` and `catalogResolvedDisplayTitle(title:explicitVariant:)` both parse the same parenthetical suffix shape. The behavior is correct, but the suffix-detection logic is duplicated.
- no dead code found beyond the disproved comparator-removal assumption above

Changes made in this pass:
- none

### `LibraryCatalogStore.swift`

Status: `change made`

Responsibility summary:
- persists source enable/pin/sort/bank state
- persists imported external sources
- posts the global Library source-change notification
- decodes OPDB export payloads into multiple library/practice shapes
- merges imported data, overrides, venue layout metadata, rulesheets, videos, and legacy overrides

Line map:
- `3-160`: library source-state model and persistence
- `162-287`: source-change notification seam plus imported-source persistence
- `289-1370`: decode and normalization helpers for imported records, OPDB export, venue metadata, and overrides
- `1372-2313`: library/practice extraction builders, imported-source merge logic, and legacy override application

Primary interactions:
- `library/LibraryBuiltInSources.swift`
- `library/LibraryCatalogResolution.swift`
- `library/LibraryDataLoader.swift`
- `library/LibraryDomain.swift`
- `settings/SettingsDataIntegration.swift`
- `practice/PracticeStoreDataLoaders.swift`

Findings:
- `change made`: removed unused `decodeCatalogManufacturerOptions(data:)`. The active callers already use `decodeCatalogManufacturerOptionsFromOPDBExport(data:)` directly.
- `change made`: removed unused `decodePracticeCatalogGames(data:)`. The active callers already use `decodePracticeCatalogGamesFromOPDBExport(data:)` directly.
- `change made`: replaced one remaining hard-coded `"venue--gameroom"` check with `gameRoomLibrarySourceID` so the special source contract now lives in one place.
- `follow-up`: `loadBundledDefaults()` currently returns `[]`. That is a real code path, but it behaves as a placeholder hook rather than as meaningful bundled data today.
- `follow-up`: the file owns both persistence and part of the global refresh contract. It posts `pinballLibrarySourcesDidChange` in some workflows, while other write paths rely on callers to post after mutations. That split makes refresh behavior harder to reason about.

Changes made in this pass:
- removed unused `decodeCatalogManufacturerOptions(data:)`
- removed unused `decodePracticeCatalogGames(data:)`
- replaced a hard-coded GameRoom source ID literal with `gameRoomLibrarySourceID`

### `LibraryContentLoading.swift`

Status: `change made`

Responsibility summary:
- defines the small shared load-state enum for library markdown/resource loaders
- loads local game-info markdown
- loads local rulesheet markdown
- falls back to remote rulesheet providers when local rulesheets are absent or broken

Line map:
- `5-22`: shared helper for first-available cached text loading
- `24-66`: `PinballGameInfoViewModel`
- `68-151`: `RulesheetScreenModel`

Primary interactions:
- `library/LibraryDetailScreen.swift`
- `library/RulesheetScreen.swift`
- `data/PinballDataCache.swift`
- `library/RulesheetScreen.swift` remote loader types

Findings:
- `change made`: removed unused `PinballGameInfoViewModel.init(slug:)`.
- `change made`: collapsed the duplicated local-path read loop into `libraryLoadFirstAvailableText(pathCandidates:)`.
- `change made`: collapsed the duplicated external-rulesheet fallback block in `RulesheetScreenModel` into `loadExternalFallbackIfNeeded()`.
- `follow-up`: both view models still mirror the same `didLoad` one-shot pattern and the same status transitions. That is reasonable now, but it is still a shared contract spread across two classes.

Changes made in this pass:
- removed unused `PinballGameInfoViewModel.init(slug:)`
- added `libraryLoadFirstAvailableText(pathCandidates:)` to centralize local text loading
- collapsed duplicate external rulesheet fallback logic in `RulesheetScreenModel`

### `LibraryDataLoader.swift`

Status: `change made`

Responsibility summary:
- loads hosted CAF extraction inputs
- builds library extraction data for Library and Practice
- loads the practice catalog search set from hosted OPDB export
- augments the public library extraction with locally persisted GameRoom machines

Line map:
- `3-46`: GameRoom OPDB/media support payloads
- `48-111`: top-level library/practice extraction load functions
- `113-306`: GameRoom augmentation and GameRoom row synthesis
- `308-676`: GameRoom template/media matching and legacy catalog merge helpers

Primary interactions:
- `library/LibraryCatalogStore.swift`
- `library/LibraryCatalogResolution.swift`
- `library/LibraryHostedData.swift`
- `gameroom/` persisted state codecs and store types
- `practice/PracticeStoreDataLoaders.swift`

Findings:
- `change made`: removed the local duplicate `LibraryDataLoader.gameRoomLibrarySourceID` constant and switched this file to the shared `gameRoomLibrarySourceID`.
- `follow-up`: this is a real cross-feature seam. Library extraction silently reaches into GameRoom persisted state and rehydrates those machines into the public catalog shape. That behavior is useful, but it is easy to miss when debugging data mismatches.
- no dead code found

Changes made in this pass:
- centralized GameRoom source ID usage on `gameRoomLibrarySourceID`

### `LibraryDetailComponents.swift`

Status: `reviewed`

Responsibility summary:
- renders the library detail screenshot, summary, resource, video, and game-info cards
- resolves live playfield options for a game
- fetches lightweight YouTube metadata for the selected video
- logs library activity events when resources are opened

Primary interactions:
- `library/LibraryResourceResolution.swift`
- `library/PlayfieldScreen.swift`
- `library/RulesheetScreen.swift`
- `library/LibraryVideoMetadata.swift`
- `library/LibraryActivityLog.swift`

Findings:
- `follow-up`: the detail surface is partly static and partly live-enriched. `LibraryLivePlayfieldStatusStore` and `YouTubeVideoMetadataService` both make extra network-backed decisions after the base `PinballGame` has already been loaded, which is easy to overlook if the detail UI looks like a pure render layer.
- no dead code found

Changes made in this pass:
- none

### `LibraryDetailScreen.swift`

Status: `reviewed`

Responsibility summary:
- thin detail wrapper that composes the screenshot, summary/resources, videos, and game-info cards
- owns the one game-info loader instance for the current game

Primary interactions:
- `library/LibraryDetailComponents.swift`
- `library/LibraryContentLoading.swift`

Findings:
- no dead code found
- intentionally small composition seam; healthy as-is

Changes made in this pass:
- none

### `LibraryDomain.swift`

Status: `reviewed`

Responsibility summary:
- defines library source types, search helpers, and sort options
- owns the `PinballLibraryViewModel`
- owns source selection, sort selection, pagination, and bank filter state
- decodes `PinballGame` and exposes many display/resource helper properties

Line map:
- `3-71`: source/search/sort domain helpers
- `73-351`: `PinballLibraryViewModel`
- `353-764`: `PinballGame` decode model plus presentation helpers

Primary interactions:
- `library/LibraryPayloadParsing.swift`
- `library/LibraryDataLoader.swift`
- `library/LibraryCatalogStore.swift`
- `library/LibraryResourceResolution.swift`
- `library/LibraryScreen.swift`

Findings:
- `follow-up`: selected source persistence is duplicated. `selectSource(_:)` and `loadGames()` both write the raw `preferred-library-source-id` `UserDefaults` key and also write `PinballLibrarySourceState.selectedSourceID`. That is hidden dual persistence for one preference.
- `follow-up`: `browsingState` pulls pinned source IDs from `PinballLibrarySourceStateStore.load()` every time the computed state is rebuilt. It works, but it means the view model is not the single owner of all browsing inputs.
- no dead code found

Changes made in this pass:
- none

### `LibraryGameLookup.swift`

Status: `change made`

Responsibility summary:
- normalizes machine names
- defines a tiny alias table for league/target matching
- exposes candidate/equivalent key generation used by Practice-side machine resolution

Primary interactions:
- `practice/PracticeStoreLeagueHelpers.swift`
- `practice/PracticeStoreDataLoaders.swift`
- `practice/ResolvedLeagueMachineMappings.swift`

Findings:
- `change made`: removed unused `LibraryGameLookupEntry`.
- `change made`: removed unused `buildEntries(games:)`.
- `change made`: removed unused `bestMatch(gameName:entries:)`.
- `change made`: removed unused `bestMatch(gameName:games:)`.
- `change made`: removed now-dead helper `weightedOrder(index:group:position:)`.
- `change made`: removed now-dead private `String.nilIfEmpty`.
- `reviewed`: the remaining alias/normalization helpers are still live through Practice league resolution code, so the file is now much smaller but still very real.

Changes made in this pass:
- removed unused `LibraryGameLookupEntry`
- removed unused `buildEntries(games:)`
- removed unused `bestMatch(gameName:entries:)`
- removed unused `bestMatch(gameName:games:)`
- removed unused `weightedOrder(index:group:position:)`
- removed unused private `String.nilIfEmpty`

### `LibraryHostedData.swift`

Status: `reviewed`

Responsibility summary:
- defines hosted library/league asset paths
- defines the hosted refresh target list
- provides shared hosted JSON load helpers
- warms hosted CAF data for app startup

Primary interactions:
- `app/Pinball_App_2App.swift`
- `library/LibraryDataLoader.swift`
- `library/LibraryCatalogStore.swift`
- `league/LeaguePreviewLoader.swift`
- `data/SharedCSV.swift`

Findings:
- `follow-up`: `warmHostedCAFData()` deliberately walks `hostedCAFDataPaths` serially inside one performance trace. That is fine for predictability, but it also means the warmup path is conservative rather than aggressive.
- no dead code found

Changes made in this pass:
- none

## Pass 006 summary

Safe cleanup changes made:
- removed unused `builtinVenueSourceName(for:)` from `LibraryBuiltInSources.swift`
- removed unused `pinballMapLocationID(for:)` from `LibraryBuiltInSources.swift`
- removed unused `decodeCatalogManufacturerOptions(data:)` from `LibraryCatalogStore.swift`
- removed unused `decodePracticeCatalogGames(data:)` from `LibraryCatalogStore.swift`
- removed unused `PinballGameInfoViewModel.init(slug:)` from `LibraryContentLoading.swift`
- collapsed duplicate local text loading in `LibraryContentLoading.swift`
- collapsed duplicate external rulesheet fallback logic in `LibraryContentLoading.swift`
- centralized GameRoom source ID usage in `LibraryDataLoader.swift`
- removed unused lookup-entry matching helpers from `LibraryGameLookup.swift`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. decide whether Library source selection should persist in one place instead of both `preferred-library-source-id` and `PinballLibrarySourceState.selectedSourceID`
2. decide whether `loadBundledDefaults()` should become real data or be removed as a placeholder seam
3. document or isolate the hidden GameRoom-to-Library extraction bridge in `LibraryDataLoader.swift`
4. decide whether `LibraryActivityLog` should stay implicitly single-threaded or move behind actor/main-actor isolation
5. decide whether `catalogResolvedVariantLabel` and `catalogResolvedDisplayTitle` should share one parenthetical-suffix parser

Next files queued:
- `Pinball App 2/Pinball App 2/library/LibraryListScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdown.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownParsing.swift`
- `Pinball App 2/Pinball App 2/library/LibraryPayloadParsing.swift`
- `Pinball App 2/Pinball App 2/library/LibraryResourceResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryVideoMetadata.swift`
- `Pinball App 2/Pinball App 2/library/PlayfieldScreen.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetScreen.swift`

## Pass 007: Library Presentation And Media

Files in scope:
- `Pinball App 2/Pinball App 2/library/LibraryListScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdown.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownParsing.swift`
- `Pinball App 2/Pinball App 2/library/LibraryPayloadParsing.swift`
- `Pinball App 2/Pinball App 2/library/LibraryResourceResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryVideoMetadata.swift`
- `Pinball App 2/Pinball App 2/library/PlayfieldScreen.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetScreen.swift`

### `LibraryListScreen.swift`

Status: `reviewed`

Responsibility summary:
- renders the Library source/sort/bank menus
- renders grouped and ungrouped game-card grids
- renders the card overlay title/manufacturer/location chrome
- consumes pending library deep links when a target game exists

Line map:
- `4-64`: filter-menu sections
- `67-126`: empty/loading/content shell
- `128-219`: game card rendering, load-more trigger, and deep-link consumption
- `221-341`: UIKit-backed attributed card-title label

Primary interactions:
- `library/LibraryScreen.swift`
- `library/PlayfieldScreen.swift`
- `library/LibraryResourceResolution.swift`

Findings:
- `follow-up`: `consumeLibraryDeepLink()` only clears `appNavigation.libraryGameIDToOpen` after the target game exists in the loaded data set. That is intentional, but it means navigation success is coupled to load timing and refresh timing rather than to one explicit routing coordinator.
- no dead code found

Changes made in this pass:
- none

### `LibraryMarkdown.swift`

Status: `reviewed`

Responsibility summary:
- converts parsed markdown blocks into renderable document blocks
- sanitizes inline HTML/markdown fragments
- renders headings, paragraphs, lists, blockquotes, code, tables, and images
- owns renderer-side regex helper extensions for inline transforms

Primary interactions:
- `library/LibraryMarkdownParsing.swift`
- `library/PlayfieldScreen.swift`
- `library/LibraryDetailComponents.swift`
- `library/RulesheetScreen.swift`

Findings:
- `follow-up`: renderer-side regex helpers (`firstRegexCapture`, `firstRegexMatch`, transformed `replacingOccurrences`) overlap with similar capture helpers in `LibraryMarkdownParsing.swift`. The split works, but the mini regex utility surface is duplicated.
- `follow-up`: markdown image rendering reuses `FallbackAsyncImageView`, so the markdown stack quietly depends on the library/practice/gameroom shared image-loading infrastructure.
- no dead code found

Changes made in this pass:
- none

### `LibraryMarkdownParsing.swift`

Status: `reviewed`

Responsibility summary:
- parses markdown-ish text into the app’s custom `MarkdownBlock` model
- handles headings, lists, tables, blockquotes, code fences, anchors, and raw HTML tables
- owns parser-side regex helpers for HTML table extraction and image capture

Primary interactions:
- `library/LibraryMarkdown.swift`

Findings:
- `follow-up`: the parser duplicates a second set of regex helper utilities instead of sharing one internal utility layer with the renderer.
- `reviewed`: the custom parser is still justified. It handles HTML table content and image cases that the built-in attributed-markdown parser would not cover cleanly by itself.

Changes made in this pass:
- none

### `LibraryPayloadParsing.swift`

Status: `change made`

Responsibility summary:
- defines the lightweight library payload/source decode wrappers
- normalizes source IDs and source types
- computes Library browsing state, visible sources, sort options, filters, grouping, and sectioning

Line map:
- `3-31`: payload and source-payload decode wrappers
- `33-78`: source-ID/type normalization helpers
- `80-322`: browsing state and visible/sorted/sectioned game derivation

Primary interactions:
- `library/LibraryDomain.swift`
- `library/LibraryBuiltInSources.swift`

Findings:
- `change made`: replaced the hard-coded GameRoom source ID literal in `visibleSources` with `gameRoomLibrarySourceID`.
- `follow-up`: Library source visibility rules are split across this browsing-state type and `PinballLibraryViewModel`. The file owns pinned-source filtering and GameRoom source forcing, while the view model owns selection and persistence.
- no dead code found

Changes made in this pass:
- centralized GameRoom source ID usage on `gameRoomLibrarySourceID`

### `LibraryResourceResolution.swift`

Status: `reviewed`

Responsibility summary:
- normalizes library resource URLs and cache paths
- classifies playfield and rulesheet source kinds
- loads live PinProf playfield-status metadata
- extends `PinballGame` with derived playfield/rulesheet/resource candidate logic

Line map:
- `3-14`: source-path constants and bundled-only exception IDs
- `15-104`: live playfield status model and fetch store
- `106-178`: URL/cache-path normalization helpers
- `180-628`: `PinballGame` resource derivation and rulesheet source classification

Primary interactions:
- `library/LibraryDetailComponents.swift`
- `library/PlayfieldScreen.swift`
- `practice/PracticeVideoComponents.swift`
- `gameroom/GameRoomPresentationComponents.swift`
- `app/AppShakeCoordinator.swift`

Findings:
- `follow-up`: this is a high-coupling seam. Library, Practice, GameRoom, and the app-shake fallback art path all rely on this file for URL normalization or missing-artwork behavior.
- `follow-up`: `LibraryLivePlayfieldStatusStore` performs live network reads but does not keep a durable cache or publish a refresh policy. Every consumer simply asks the actor for the current status and accepts `nil` on failure.
- `follow-up`: bundled-only exception behavior is encoded as the hard-coded `libraryBundledOnlyAppGroupIDs` set. That is a real business rule, but it lives as code rather than as data/config.

Changes made in this pass:
- none

### `LibraryScreen.swift`

Status: `reviewed`

Responsibility summary:
- owns the Library root navigation stack
- owns the Library view model and the card transition namespace
- mounts search, filter, refresh, and navigation-destination wiring
- logs browse events when a game detail screen opens

Line map:
- `3-46`: viewport/layout-derived card sizing
- `47-127`: root shell, search/filter toolbar, refresh/deep-link triggers, and navigation destination

Primary interactions:
- `library/LibraryListScreen.swift`
- `library/LibraryDomain.swift`
- `library/LibraryDetailScreen.swift`
- `library/LibraryCatalogStore.swift`
- `app/ContentView.swift`
- `library/LibraryActivityLog.swift`

Findings:
- `follow-up`: `.onReceive(NotificationCenter.default.publisher(for: .pinballLibrarySourcesDidChange))` launches an untracked `Task { ... }`. Rapid source-change notifications can overlap refresh work.
- `follow-up`: deep-link consumption is intentionally retried from four separate triggers: initial `.task`, library-source change refresh, `appNavigation.libraryGameIDToOpen` changes, and `viewModel.games.count` changes. The behavior works, but the routing contract is spread out.
- no dead code found

Changes made in this pass:
- none

### `LibraryVideoMetadata.swift`

Status: `reviewed`

Responsibility summary:
- fetches YouTube oEmbed metadata for selected videos
- caches fetched metadata in memory for the current app session

Primary interactions:
- `library/LibraryDetailComponents.swift`

Findings:
- `follow-up`: cache lifetime is in-memory only and has no TTL/eviction policy beyond process lifetime. That is acceptable for this small use, but it is still an implicit caching contract.
- no dead code found

Changes made in this pass:
- none

### `PlayfieldScreen.swift`

Status: `reviewed`

Responsibility summary:
- provides the shared in-memory `UIImage` cache
- renders fallback candidate-based async images with retry
- renders fullscreen hosted-image viewing with zoom chrome
- provides constrained image preview helpers reused outside Library

Line map:
- `5-41`: image layout mode enum and shared memory cache
- `43-153`: candidate-based fallback async image loader view
- `155-191`: content-mode view modifier
- `193-458`: fullscreen hosted image viewer, shared async loader, preview, and zoomable UIKit bridge

Primary interactions:
- `library/LibraryListScreen.swift`
- `library/LibraryDetailComponents.swift`
- `library/LibraryMarkdown.swift`
- `practice/PracticeHomeComponents.swift`
- `practice/PracticeVideoComponents.swift`
- `gameroom/GameRoomPresentationComponents.swift`
- `settings/SettingsDataIntegration.swift`

Findings:
- `follow-up`: `FallbackAsyncImageView` and `RemoteUIImageLoader` both iterate candidate URLs, consult `RemoteUIImageMemoryCache`, and load remote images. They serve different UI shapes, but there is still duplicated candidate-load orchestration.
- `follow-up`: `RemoteUIImageMemoryCache` is effectively shared infrastructure across Library, Practice, GameRoom, and Settings cache-clearing behavior. That is fine, but it is broader than the file name suggests.
- no dead code found

Changes made in this pass:
- none

### `RulesheetScreen.swift`

Status: `reviewed`

Responsibility summary:
- renders the full-screen rulesheet reader
- persists and restores per-rulesheet reading progress
- hosts the custom WebKit-based markdown/HTML reader with anchor restoration
- provides web fallback and remote rulesheet provider loading/caching

Line map:
- `6-220`: reader shell, progress persistence, and UI chrome
- `236-1678`: WebKit renderer, viewport-anchor restore, HTML template generation, and fallback web view
- `1680-1885`: render-content model, remote-source model, and remote rulesheet loader
- `1887-2241`: remote fetch cleanup, cache implementation, and small string helpers

Primary interactions:
- `library/LibraryContentLoading.swift`
- `library/LibraryDetailComponents.swift`
- `practice/PracticeScreenRouteContent.swift`
- `settings/SettingsDataIntegration.swift`

Findings:
- `follow-up`: this file is a major growth hotspot. View chrome, WKWebView coordination, HTML templating, provider-specific remote fetch cleanup, and remote caching all live together in one file.
- `follow-up`: rulesheet reading progress is keyed by `slug` in `UserDefaults`, so Library and Practice implicitly share the same reading-progress history whenever they open the same rulesheet slug.
- `reviewed`: the remote provider layer is real and still active. `RemoteRulesheetLoader`, `RulesheetRemoteSource`, and `RemoteRulesheetCache` are all in use by Library, Practice, and Settings cache-clearing.
- no dead code found

Changes made in this pass:
- none

## Pass 007 summary

Safe cleanup changes made:
- centralized GameRoom source ID usage in `LibraryPayloadParsing.swift`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. decide whether Library deep-link handling should move behind one explicit coordinator instead of four retry triggers
2. decide whether renderer/parser regex helpers should be shared between `LibraryMarkdown.swift` and `LibraryMarkdownParsing.swift`
3. decide whether `LibraryLivePlayfieldStatusStore` needs an explicit caching policy or refresh strategy
4. decide whether `FallbackAsyncImageView` and `RemoteUIImageLoader` should share one candidate-loading core
5. split `RulesheetScreen.swift` if future growth continues, because it already owns reader UI, web bridge, provider parsing, and remote caching

Next files queued:
- `Pinball App 2/Pinball App 2/practice/CameraPreviewView.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeCatalogSearchSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeDialogHost.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeDisplayTitles.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeEntryGlassStyle.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameDropdownOrder.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameEntrySheets.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameLifecycleContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameLifecycleHost.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGamePresentationContext.swift`

## Pass 008: Practice Intake Seams

Files in scope:
- `Pinball App 2/Pinball App 2/practice/CameraPreviewView.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeCatalogSearchSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeDialogHost.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeDisplayTitles.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeEntryGlassStyle.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameDropdownOrder.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameEntrySheets.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameLifecycleContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameLifecycleHost.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGamePresentationContext.swift`

### `CameraPreviewView.swift`

Status: `reviewed`

Responsibility summary:
- wraps `AVCaptureVideoPreviewLayer` in SwiftUI
- hands the configured preview layer back to scanner flows once layout is ready

Primary interactions:
- `practice/ScoreScannerView.swift`
- `practice/ScoreScannerCameraTestView.swift`

Findings:
- `follow-up`: `onPreviewLayerReady` can fire from both `updateUIView` and `layoutSubviews`. That is fine as long as callers treat it as an idempotent readiness callback rather than a one-shot event.
- no dead code found

Changes made in this pass:
- none

### `PracticeCatalogSearchSupport.swift`

Status: `reviewed`

Responsibility summary:
- defines Practice catalog-search filters and result rows
- builds the grouped game search index from library games
- stores recent search selections in `UserDefaults`

Line map:
- `3-47`: search filter enums and filter state
- `49-121`: `PracticeGameSearchIndex`
- `123-142`: recent-search persistence
- `144-219`: grouped search-result builders and manufacturer/year/type extraction helpers

Primary interactions:
- `practice/PracticeGameSearchSheet.swift`
- `practice/PracticeDisplayTitles.swift`
- `library/LibraryDomain.swift` search-token helpers

Findings:
- `follow-up`: Practice catalog search depends directly on `PinballGame` plus the library-side `normalizedSearchTokens` and `matchesSearchTokens` helpers. Search behavior is therefore partly owned by Library code even though the feature lives in Practice.
- `follow-up`: machine-type filtering is inferred directly from raw OPDB fields (`opdbDisplay` and `opdbType`) instead of one shared machine-type normalization seam.
- no dead code found

Changes made in this pass:
- none

### `PracticeDialogHost.swift`

Status: `reviewed`

Responsibility summary:
- wraps the Practice root content with lifecycle/reset-alert/presentation hosts
- mounts Practice route destinations and sheet presentation
- inserts the navigation interaction shield overlay

Line map:
- `4-6`: trivial root-content alias
- `8-36`: route/sheet/reset/lifecycle host wiring
- `38-54`: `PracticeGameWorkspace` construction and callback bridging

Primary interactions:
- `practice/PracticeScreen.swift`
- `practice/PracticeLifecycleHost.swift`
- `practice/PracticePresentationHost.swift`
- `practice/PracticeGameWorkspace.swift`
- `practice/PracticeScreenActions.swift`

Findings:
- `follow-up`: route wiring, sheet wiring, lifecycle wiring, and workspace callback bridging are all split across several small Practice seam files. The structure is intentionally modular, but navigation ownership is distributed rather than centered.
- no dead code found

Changes made in this pass:
- none

### `PracticeDisplayTitles.swift`

Status: `reviewed`

Responsibility summary:
- chooses the preferred display title for grouped Practice games
- strips trailing parenthetical suffixes from candidate names
- ranks title candidates by frequency, then by shorter/lexicographically earlier preference

Primary interactions:
- `practice/PracticeCatalogSearchSupport.swift`
- `practice/PracticeStore.swift`
- `practice/PracticeGameToolbarMenu.swift`

Findings:
- `follow-up`: Practice maintains its own parenthetical-title cleanup logic instead of reusing Library’s `catalogResolvedDisplayTitle(...)`. The behaviors are related but not currently unified.
- no dead code found

Changes made in this pass:
- none

### `PracticeEntryGlassStyle.swift`

Status: `reviewed`

Responsibility summary:
- provides the shared glass-card container for Practice entry sheets
- provides the shared sheet-chrome modifier for Practice modal entry flows

Primary interactions:
- `practice/PracticeGamePresentationHost.swift`
- `practice/PracticePresentationHost.swift`
- `practice/PracticeQuickEntrySheet.swift`
- `practice/PracticeGameEntrySheets.swift`

Findings:
- no dead code found
- healthy styling seam; simple and intentionally shared

Changes made in this pass:
- none

### `PracticeGameDropdownOrder.swift`

Status: `reviewed`

Responsibility summary:
- orders games for dropdown/picker presentation
- optionally deduplicates grouped games by canonical practice identity

Primary interactions:
- `practice/PracticeGameLifecycleHost.swift`
- `practice/PracticeHomeSection.swift`
- `practice/PracticeQuickEntrySheet.swift`
- `practice/PracticeScreenActions.swift`
- `practice/PracticeGroupEditorComponents.swift`

Findings:
- `follow-up`: dropdown ordering is based on raw `game.name`, then `year`, then `canonicalPracticeKey`. That can differ slightly from the grouped display-title rules in `PracticeDisplayTitles.swift`, so picker ordering and search-result naming are not driven by exactly the same presentation logic.
- no dead code found

Changes made in this pass:
- none

### `PracticeGameEntrySheets.swift`

Status: `change made`

Responsibility summary:
- renders the score-entry sheet
- renders the note-entry sheet
- renders the rulesheet/video/playfield/practice task-entry sheet
- validates and translates sheet input into `PracticeStore` mutations

Line map:
- `3-152`: score-entry sheet and score input formatter
- `154-244`: note-entry sheet
- `246-554`: task-entry sheet, shared field helpers, and save logic

Primary interactions:
- `practice/PracticeGamePresentationHost.swift`
- `practice/PracticeStore.swift`
- `practice/ScoreScannerView.swift`
- `practice/PracticeVideoLoggingHelpers.swift`
- `practice/PracticeTimePopoverField.swift`

Findings:
- `change made`: removed unused `selectedGame`.
- `change made`: collapsed the repeated selected-video-source reset block into `syncSelectedVideoSource()`.
- `follow-up`: `formatScoreInputWithCommas(_:)` is duplicated in `PracticeQuickEntrySheet.swift`, which means score-formatting behavior is already split across two Practice entry surfaces.
- `follow-up`: this file is a clear growth hotspot. Three distinct sheet flows plus their inline save rules live together here.

Changes made in this pass:
- removed unused `selectedGame`
- collapsed repeated selected-video-source reset logic into `syncSelectedVideoSource()`

### `PracticeGameLifecycleContext.swift`

Status: `reviewed`

Responsibility summary:
- tiny dependency bag for `PracticeGameLifecycleHost`

Primary interactions:
- `practice/PracticeGameSection.swift`
- `practice/PracticeGameLifecycleHost.swift`

Findings:
- no dead code found
- intentional seam file; healthy as-is

Changes made in this pass:
- none

### `PracticeGameLifecycleHost.swift`

Status: `change made`

Responsibility summary:
- bootstraps the selected Practice game when one is missing
- syncs the per-game summary draft
- syncs the active video fallback when game selection changes
- schedules delayed browse logging into `PracticeStore`

Line map:
- `3-32`: on-appear/on-change lifecycle orchestration
- `34-42`: selected-game sync into summary draft and optional viewed callback
- `44-57`: delayed browse-log task scheduling

Primary interactions:
- `practice/PracticeGameLifecycleContext.swift`
- `practice/PracticeGameDropdownOrder.swift`
- `practice/PracticeStore.swift`
- `practice/PracticeGameSection.swift`

Findings:
- `change made`: avoided duplicate initial sync work when the host bootstraps the first selected game on `.onAppear`. Before this cleanup, the bootstrap selection path could run `syncSelectedGame(...)` immediately and then again through `.onChange`.
- `follow-up`: browse logging still relies on a delayed `Task` owned by view state. That is reasonable, but it is another ambient timing contract between UI lifecycle and store mutation.

Changes made in this pass:
- collapsed duplicate bootstrap-selection sync work on first appearance

### `PracticeGamePresentationContext.swift`

Status: `reviewed`

Responsibility summary:
- tiny dependency bag for Practice game sheet presentation state

Primary interactions:
- `practice/PracticeGameSection.swift`
- `practice/PracticeGamePresentationHost.swift`

Findings:
- no dead code found
- intentional seam file; healthy as-is

Changes made in this pass:
- none

## Pass 008 summary

Safe cleanup changes made:
- removed unused `selectedGame` from `PracticeGameEntrySheets.swift`
- collapsed repeated selected-video-source reset logic in `PracticeGameEntrySheets.swift`
- collapsed duplicate bootstrap-selection sync work in `PracticeGameLifecycleHost.swift`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. decide whether Practice display-title cleanup should share more logic with Library title normalization
2. decide whether Practice machine-type search filters should rely on one normalized machine-type seam instead of raw OPDB fields
3. collapse the duplicated `formatScoreInputWithCommas(_:)` helper when `PracticeQuickEntrySheet.swift` comes into scope
4. split `PracticeGameEntrySheets.swift` if entry flow logic keeps growing
5. decide whether delayed browse logging belongs in the lifecycle host or in store-level navigation semantics

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeGamePresentationHost.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameRouteBody.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameSearchSheet.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameSummaryComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameToolbarMenu.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameWorkspace.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceState.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceSubviews.swift`

## Pass 009: Practice Workspace Navigation

Files reviewed:
- `Pinball App 2/Pinball App 2/practice/PracticeGamePresentationHost.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameRouteBody.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameSearchSheet.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameSummaryComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameToolbarMenu.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameWorkspace.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceState.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceSubviews.swift`

### `PracticeGamePresentationHost.swift`

Status: `reviewed`

Responsibility summary:
- central presentation seam for the game-specific Practice workspace
- owns task-entry, score-entry, journal-edit, and delete-entry modal presentation
- overlays the transient save banner above the workspace content

Line map:
- `3-48`: sheet, alert, overlay, and animation composition
- `50-55`: delete-alert binding adapter
- `57-68`: shared task-entry sheet builder

Primary interactions:
- `practice/PracticeGamePresentationContext.swift`
- `practice/PracticeGameEntrySheets.swift`
- `practice/PracticeJournalSettingsSections.swift`
- `practice/PracticeGameSection.swift`

Findings:
- no dead code found
- intentional presentation seam; healthy as-is
- `follow-up`: this host is concise, but every new modal path still has to stay in lockstep with the state exposed by `PracticeGamePresentationContext`

Changes made in this pass:
- none

### `PracticeGameRouteBody.swift`

Status: `change made`

Responsibility summary:
- renders the shared screenshot, segmented workspace card, and game-note shell around the selected Practice game
- switches between the summary, input, study, and log subviews

Line map:
- `3-19`: game-workspace subview enum and labels
- `21-57`: outer scroll layout and note-card composition
- `59-93`: segmented workspace card and route switching

Primary interactions:
- `practice/PracticeGameSection.swift`
- `practice/PracticeGameSummaryComponents.swift`
- `practice/PracticeGameWorkspaceSubviews.swift`

Findings:
- `change made`: removed an unused `Foundation` import
- no dead code found after cleanup

Changes made in this pass:
- removed the unused `Foundation` import

### `PracticeGameSearchSheet.swift`

Status: `reviewed`

Responsibility summary:
- loads the full searchable game catalog for manual Practice selection
- manages text filters, manufacturer suggestions, recent selections, and index rebuilds

Line map:
- `3-8`: sheet tab enum
- `10-83`: local state and task-based loading/index orchestration
- `85-176`: search tab UI and advanced filters
- `178-190`: recent tab UI
- `192-220`: result row rendering and search-index rebuild helper

Primary interactions:
- `practice/PracticeCatalogSearchSupport.swift`
- `practice/PracticeDialogHost.swift`

Findings:
- no dead code found
- `follow-up`: `searchIndexRevision` rebuilds one large concatenated string from every searchable field to drive `.task(id:)`. That keeps invalidation deterministic, but it also turns indexing into a hidden cross-file contract with `PracticeGameSearchIndex(games:)`

Changes made in this pass:
- none

### `PracticeGameSection.swift`

Status: `reviewed`

Responsibility summary:
- composition root for the selected-game Practice experience
- wires lifecycle host, presentation host, route body, toolbar, and the log/input/summary/study subviews
- owns transient save-banner and navigation-title state

Line map:
- `3-58`: derived dependency helpers and selected-game/video state
- `60-79`: composed lifecycle and presentation tree
- `81-95`: navigation and toolbar wiring
- `97-134`: log, input, summary, and study subview builders
- `136-148`: save-banner and navigation-title helpers

Primary interactions:
- `practice/PracticeGameLifecycleHost.swift`
- `practice/PracticeGamePresentationHost.swift`
- `practice/PracticeGameRouteBody.swift`
- `practice/PracticeGameToolbarMenu.swift`
- `practice/PracticeGameWorkspaceSubviews.swift`
- `practice/PracticeVideoComponents.swift`

Findings:
- no dead code found
- `follow-up`: `showSaveBanner(_:)` clears UI state through an untracked delayed `Task`. The equality guard prevents most accidental clears, but the timing contract still lives in view state
- `follow-up`: `syncNavigationTitle()` only runs when `selectedGameID` changes. If richer game data arrives later for the same selected ID, the visible title can stay on the caller-provided fallback until another selection event occurs

Changes made in this pass:
- none

### `PracticeGameSummaryComponents.swift`

Status: `reviewed`

Responsibility summary:
- small chrome helpers for the game artwork preview and editable per-game note card

Line map:
- `3-29`: screenshot/artwork preview with empty placeholder
- `31-58`: editable note card and save button

Primary interactions:
- `practice/PracticeGameRouteBody.swift`
- `practice/PracticeGameSection.swift`

Findings:
- no dead code found
- intentional small view seam; healthy as-is

Changes made in this pass:
- none

### `PracticeGameToolbarMenu.swift`

Status: `change made`

Responsibility summary:
- renders the Practice top-bar menu for source filtering and direct game selection
- keeps the selected game stable when the active Practice source changes

Line map:
- `3-13`: available library-source resolution
- `15-18`: ordered dropdown game options
- `20-50`: menu composition
- `52-61`: source-selection application and selected-game fallback

Primary interactions:
- `practice/PracticeStore.swift`
- `practice/PracticeGameDropdownOrder.swift`
- `practice/PracticeDisplayTitles.swift`
- `library/LibraryPayloadParsing.swift`

Findings:
- `change made`: removed the local duplicate source-inference helper and reused the shared `libraryInferSources(from:)` helper from the Library layer
- `follow-up`: when `store.librarySources` is empty, this menu silently derives source filters from whatever game list is currently available. That fallback is useful, but it is also a hidden Practice-to-Library coupling seam

Changes made in this pass:
- replaced the local duplicate source-inference logic with shared `libraryInferSources(from:)`

### `PracticeGameWorkspace.swift`

Status: `change made`

Responsibility summary:
- thin wrapper that converts the selected-game Practice dependencies into `PracticeGameWorkspaceContext`
- renders `PracticeGameSection`

Line map:
- `3-20`: dependency capture and context construction
- `22-24`: section rendering

Primary interactions:
- `practice/PracticeDialogHost.swift`
- `practice/PracticeGameWorkspaceContext.swift`
- `practice/PracticeGameSection.swift`

Findings:
- `change made`: removed unused `onOpenPlayfield`, `onPrepareRulesheet`, `onPrepareExternalRulesheet`, and `onPreparePlayfield` parameters. This wrapper was forwarding dead closures that nothing in the reviewed workspace path consumed
- now that the dead forwarding is gone, this file is a clean seam again

Changes made in this pass:
- removed four unused forwarded workspace parameters

### `PracticeGameWorkspaceContext.swift`

Status: `change made`

Responsibility summary:
- minimal dependency bag for `PracticeGameSection`

Line map:
- `3-10`: stored dependencies and callbacks

Primary interactions:
- `practice/PracticeGameWorkspace.swift`
- `practice/PracticeGameSection.swift`

Findings:
- `change made`: removed unused playfield-opening and rulesheet/playfield-preparation closures that were no longer consumed by `PracticeGameSection`
- this is now a tighter representation of the actual game-workspace dependency surface

Changes made in this pass:
- removed dead unused closure fields from the workspace context

### `PracticeGameWorkspaceState.swift`

Status: `reviewed`

Responsibility summary:
- local UI state bag for the selected-game Practice workspace

Primary interactions:
- `practice/PracticeGameSection.swift`
- `practice/PracticeGamePresentationHost.swift`
- `practice/PracticeGameRouteBody.swift`

Findings:
- no dead code found
- intentional state seam; healthy as-is

Changes made in this pass:
- none

### `PracticeGameWorkspaceSubviews.swift`

Status: `reviewed`

Responsibility summary:
- contains the selected-game log panel, task-input panel, and summary dashboard panel
- owns score-stat formatting, next-action guidance, alert rendering, and embedded list sizing

Line map:
- `3-71`: log panel and editable row handling
- `73-109`: task-input shortcuts
- `111-321`: summary dashboard, stat helpers, and coaching heuristics
- `323-328`: shortcut model

Primary interactions:
- `practice/PracticeStore.swift`
- `practice/PracticeGameSection.swift`
- `practice/PracticeJournalSummaryStyling.swift`
- `practice/PracticeModels.swift`

Findings:
- no dead code found
- `follow-up`: this is more than a subviews bucket. `nextAction(gameID:)`, `scoreStats(for:)`, consistency guidance, and alert coloring make it a real behavior owner
- `follow-up`: `formatScore(_:)` creates a fresh `NumberFormatter` on each call while the summary panel renders. That is not wrong, but it is avoidable formatting churn inside a frequently recomputed view

Changes made in this pass:
- none

### Related cleanup: `PracticeDialogHost.swift`

Status: `change made`

Responsibility summary:
- Practice route host that wires navigation destinations and shared presentation around the overall Practice screen

Primary interactions:
- `practice/PracticeGameWorkspace.swift`
- `practice/PracticeScreen.swift`

Findings:
- `change made`: removed dead forwarding of `onOpenPlayfield`, `onPrepareRulesheet`, `onPrepareExternalRulesheet`, and `onPreparePlayfield` into `PracticeGameWorkspace(...)`. The reviewed workspace path no longer consumed those closures at all

Changes made in this pass:
- removed unused workspace-closure forwarding from `practiceGameWorkspace(gameID:navigationTitle:)`

## Pass 009 summary

Safe cleanup changes made:
- removed the unused `Foundation` import from `PracticeGameRouteBody.swift`
- removed the local duplicate source-inference helper from `PracticeGameToolbarMenu.swift`
- removed dead forwarded playfield/rulesheet-preparation closures from `PracticeDialogHost.swift`
- removed the corresponding unused parameters from `PracticeGameWorkspace.swift`
- removed the corresponding unused fields from `PracticeGameWorkspaceContext.swift`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. decide whether `PracticeGameSearchSheet.swift` should invalidate its search index with a cheaper explicit revision signal instead of the concatenated all-fields string
2. decide whether `PracticeGameSection.swift` should resync its navigation title when selected-game data changes without an ID change
3. decide whether `PracticeGameWorkspaceSubviews.swift` should move coaching/stat heuristics into a dedicated Practice summary seam
4. collapse repeated score-formatting behavior when `PracticeQuickEntrySheet.swift` comes into scope

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupEditorComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeBootstrapIntegration.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeBootstrapSnapshot.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeHost.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeRootView.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeWidgets.swift`

## Pass 010: Practice Groups And Home Bootstrap

Files reviewed:
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupEditorComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeBootstrapIntegration.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeBootstrapSnapshot.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeHost.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeRootView.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeWidgets.swift`

### `PracticeGroupDashboardContext.swift`

Status: `reviewed`

Responsibility summary:
- tiny dependency bag for the Practice group dashboard route

Line map:
- `3-10`: stored group-dashboard dependencies and callbacks

Primary interactions:
- `practice/PracticeScreenContexts.swift`
- `practice/PracticeScreenRouteContent.swift`
- `practice/PracticeGroupDashboardSection.swift`

Findings:
- no dead code found
- intentional seam file; healthy as-is

Changes made in this pass:
- none

### `PracticeGroupDashboardSection.swift`

Status: `change made`

Responsibility summary:
- renders the selected-group dashboard summary, dashboard snapshots, and editable group list
- owns inline date-popover editing and selected-group detail loading

Line map:
- `3-108`: selected-group dashboard summary and async detail loading trigger
- `110-212`: group list card and embedded swipeable rows
- `214-258`: inline start/end date popover calendar
- `261-334`: formatting helpers, dashboard task key, and detail-loading helpers
- `336-439`: swipeable group row chrome and actions

Primary interactions:
- `practice/PracticeGroupDashboardContext.swift`
- `practice/PracticeScreenRouteContent.swift`
- `practice/PracticeStore.swift`
- `practice/PracticeGroupEditorComponents.swift`

Findings:
- `change made`: removed a duplicate `DateFormatter` and reused the existing `groupDateFormatter`
- `follow-up`: `selectedGroupDashboardTaskKey` only tracks group ID, game IDs, and group start/end dates. Practice progress, scores, and journal changes do not invalidate the async dashboard detail load, so the dashboard can silently lag behind live data until another group-shape change occurs
- `follow-up`: `progressSummary(taskProgress:)` duplicates the same task-label summary concept already present in other Practice surfaces

Changes made in this pass:
- removed the duplicate short dashboard date formatter

### `PracticeGroupEditorComponents.swift`

Status: `change made`

Responsibility summary:
- contains the group progress wheel, the full group editor screen, the title picker, drag/drop reorder delegates, and the adaptive popover helper

Line map:
- `5-61`: `GroupProgressWheel`
- `63-82`: template and date enums
- `84-773`: `GroupEditorScreen` and its editor/save/template/date helpers
- `775-897`: `GroupGameSelectionScreen`
- `899-1055`: drag/drop delegates and adaptive popover support

Primary interactions:
- `practice/PracticeStore.swift`
- `practice/PracticeHomeComponents.swift`
- `practice/PracticeCatalogSearchSupport.swift`
- `library/LibraryPayloadParsing.swift`

Findings:
- `change made`: removed the duplicate local library-source inference helper from the group picker and reused shared `libraryInferSources(from:)`
- `follow-up`: this file is now over 1,000 lines and owns several unrelated concerns. It is a clear growth hotspot and a good future split candidate
- `follow-up`: `GroupGameSelectionScreen` still depends on `quickEntryAllGamesLibraryID`, which is a hidden cross-feature coupling between group editing and quick-entry source-filter semantics

Changes made in this pass:
- replaced the group-picker duplicate source-inference helper with shared `libraryInferSources(from:)`

### `PracticeHomeBootstrapIntegration.swift`

Status: `change made`

Responsibility summary:
- owns async home bootstrap restoration, bootstrap snapshot saving, and the lookup-game pool used by fast home resume

Line map:
- `3-13`: async bootstrap restoration
- `15-32`: applying a bootstrap snapshot into `PracticeStore`
- `34-52`: save/build snapshot flow
- `54-73`: lookup-game pool construction

Primary interactions:
- `practice/PracticeStore.swift`
- `practice/PracticeHomeBootstrapSnapshot.swift`
- `practice/PracticeScreenActions.swift`

Findings:
- `change made`: removed the unused synchronous `restoreHomeBootstrapSnapshotIfAvailable()` helper. The async restore path is the live one
- `follow-up`: `applyHomeBootstrapSnapshot(_:)` starts from `PracticePersistedState.empty` and restores only a subset of Practice state. Any new bootstrap-critical fields now have to be remembered in two places
- `follow-up`: `currentHomeBootstrapLookupGames()` is a hidden cross-feature seam. It mixes visible games, full library games, search catalog games, bank template games, and the last-viewed resume candidate into one deduplicated lookup pool

Changes made in this pass:
- removed the unused synchronous bootstrap-restore helper

### `PracticeHomeBootstrapSnapshot.swift`

Status: `reviewed`

Responsibility summary:
- defines the home bootstrap snapshot schema
- loads and saves the snapshot on disk
- rehydrates a minimal `PinballGame` from snapshot payload data

Line map:
- `3-99`: snapshot schema and nested `Source` / `Game` payloads
- `101-178`: snapshot store load/save helpers
- `180-223`: `PinballGame` snapshot initializer

Primary interactions:
- `practice/PracticeHomeBootstrapIntegration.swift`
- `practice/PracticeStore.swift`
- `app/PinballPerformanceTrace.swift`

Findings:
- no dead code found
- `follow-up`: the snapshot schema duplicates a large slice of `PinballGame`. That is practical for fast bootstrap, but it is also a drift risk any time the live model changes
- `follow-up`: `loadFileURL()` and `saveFileURL()` are intentionally separate because save needs directory creation, but the path-building logic is still duplicated

Changes made in this pass:
- none

### `PracticeHomeComponents.swift`

Status: `reviewed`

Responsibility summary:
- home-card chrome for selected games and the shared artwork background layer

Line map:
- `3-29`: selected-game mini card
- `31-58`: resume card
- `60-84`: shared mini-card title band
- `86-119`: shared card background image layer

Primary interactions:
- `practice/PracticeHomeSection.swift`
- `library/LibraryResourceResolution.swift`

Findings:
- no dead code found
- intentional presentation helper file; healthy as-is

Changes made in this pass:
- none

### `PracticeHomeContext.swift`

Status: `reviewed`

Responsibility summary:
- dependency bag for the Practice home route and its related search/bootstrap callbacks

Line map:
- `3-29`: stored home-route data and callbacks

Primary interactions:
- `practice/PracticeScreenContexts.swift`
- `practice/PracticeHomeHost.swift`
- `practice/PracticeScreenRouteContent.swift`

Findings:
- no dead code found
- `note`: `searchGames` remains live even though `PracticeHomeRootView` no longer uses it, because the Practice search route still reads it from this context

Changes made in this pass:
- none

### `PracticeHomeHost.swift`

Status: `change made`

Responsibility summary:
- adapter from `PracticeScreen` state into `PracticeHomeRootView`
- reports viewport height changes back into `PracticeScreen` state

Line map:
- `3-70`: root-view wiring and viewport-height background measurement

Primary interactions:
- `practice/PracticeScreen.swift`
- `practice/PracticeHomeContext.swift`
- `practice/PracticeHomeRootView.swift`

Findings:
- `change made`: removed unused `searchGames` forwarding into `PracticeHomeRootView`
- healthy thin adapter after cleanup

Changes made in this pass:
- removed unused `searchGames` forwarding

### `PracticeHomeRootView.swift`

Status: `change made`

Responsibility summary:
- renders the Practice home root, including bootstrapping overlays, greeting chrome, the home section, hub cards, and the welcome prompt overlay

Line map:
- `3-114`: root home layout and overlays
- `116-136`: greeting header logic

Primary interactions:
- `practice/PracticeHomeHost.swift`
- `practice/PracticeHomeSection.swift`
- `practice/PracticeHomeWidgets.swift`

Findings:
- `change made`: removed unused `searchGames` input
- no dead code found after cleanup

Changes made in this pass:
- removed the unused `searchGames` property

### `PracticeHomeSection.swift`

Status: `change made`

Responsibility summary:
- renders the resume card, library/game menus, quick-entry actions, active-group carousels, and the welcome overlay

Line map:
- `3-173`: home section, source/game menus, quick-entry actions, and active-group rows
- `175-181`: resume-control preference key
- `183-256`: welcome overlay

Primary interactions:
- `practice/PracticeHomeComponents.swift`
- `practice/PracticeScreenContexts.swift`
- `practice/PracticeGroupEditorComponents.swift`

Findings:
- `change made`: promoted `practiceHomeAllGamesSourceMenuID` into a shared module constant so the home menu and `PracticeScreenContexts.swift` now use the same source-filter sentinel instead of a private constant plus a raw string literal
- `follow-up`: the `Game List` menu still labels entries with `listGame.name`, which may eventually drift from any shared Practice display-title normalization the app adopts elsewhere

Changes made in this pass:
- shared the home "All games" source sentinel across files

### `PracticeHomeWidgets.swift`

Status: `reviewed`

Responsibility summary:
- small dashboard card used for Practice hub destinations

Line map:
- `3-29`: hub mini-card chrome

Primary interactions:
- `practice/PracticeHomeRootView.swift`
- `practice/PracticeModels.swift`

Findings:
- no dead code found
- intentional presentation seam; healthy as-is

Changes made in this pass:
- none

### Related cleanup: `PracticeScreenContexts.swift`

Status: `change made`

Responsibility summary:
- constructs route-specific dependency bags for the Practice screen

Primary interactions:
- `practice/PracticeHomeContext.swift`
- `practice/PracticeHomeSection.swift`

Findings:
- `change made`: replaced the raw `"__practice_home_all_games__"` literal with shared `practiceHomeAllGamesSourceMenuID`, eliminating a hidden cross-file sentinel duplication

Changes made in this pass:
- switched home source-filter normalization to the shared constant

## Pass 010 summary

Safe cleanup changes made:
- removed the unused synchronous bootstrap-restore helper from `PracticeHomeBootstrapIntegration.swift`
- removed unused `searchGames` forwarding from `PracticeHomeHost.swift`
- removed the unused `searchGames` property from `PracticeHomeRootView.swift`
- shared the home "All games" source sentinel between `PracticeHomeSection.swift` and `PracticeScreenContexts.swift`
- removed the duplicate group-picker source-inference helper from `PracticeGroupEditorComponents.swift`
- removed the duplicate date formatter from `PracticeGroupDashboardSection.swift`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. decide whether `PracticeGroupDashboardSection.swift` should invalidate dashboard detail loads when practice progress or scores change, not just when group metadata changes
2. split `PracticeGroupEditorComponents.swift` into smaller seams so group CRUD, title picking, drag/drop, and adaptive popover logic stop growing in one file
3. decide whether the home bootstrap snapshot should share more schema or mapping logic with the live `PinballGame` and persisted Practice state models to reduce drift risk
4. decide whether `PracticeHomeSection.swift` should use the same normalized display-title seam as other Practice selection surfaces

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeIFPAProfileScreen.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeIdentityKeying.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeInsightsContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeInsightsSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeInsightsWidgets.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSummaryStyling.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeLifecycleContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeLifecycleHost.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeMechanicsContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeMechanicsSection.swift`

## Pass 011: Practice Identity, Insights, Journal, And Lifecycle

Files reviewed:
- `Pinball App 2/Pinball App 2/practice/PracticeIFPAProfileScreen.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeIdentityKeying.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeInsightsContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeInsightsSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeInsightsWidgets.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSummaryStyling.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeLifecycleContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeLifecycleHost.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeMechanicsContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeMechanicsSection.swift`

### `PracticeIFPAProfileScreen.swift`

Status: `reviewed`

Responsibility summary:
- renders the Practice IFPA profile screen
- fetches and parses the public IFPA player page into a lightweight local profile model

Line map:
- `4-26`: IFPA profile and recent-tournament models
- `28-58`: screen state and load trigger
- `60-78`: missing-ID and retry/error cards
- `80-227`: profile content and screen-level loading helpers
- `230-393`: public IFPA fetch/parsing service
- `395-413`: IFPA error surface
- `415-437`: HTML cleanup/slicing string helpers

Primary interactions:
- `practice/PracticeHomeRootView.swift`
- `practice/PracticeJournalSettingsSections.swift`
- `practice/PracticeScreenRouteContent.swift`

Findings:
- no dead code found
- `follow-up`: this file scrapes live HTML from the public IFPA site with regexes. That is workable, but it is a brittle contract: any markup change can break parsing immediately
- `follow-up`: the screen owns network fetch, parse rules, and presentation in one file, so correctness changes and UI changes are tightly coupled

Changes made in this pass:
- none

### `PracticeIdentityKeying.swift`

Status: `change made`

Responsibility summary:
- defines canonical Practice IDs, source-scoped Practice IDs, representative-game selection, and state/default migration toward canonical IDs

Line map:
- `3-64`: canonical key helpers, source-scoped ID helpers, and representative scoring
- `66-140`: lookup pools, canonical ID resolution, and `gameForAnyID(_:)`
- `143-163`: deduped Practice-game list and migration entrypoint
- `166-273`: state/default migration and legacy key matching
- `275-279`: small string helper

Primary interactions:
- `practice/PracticeStore.swift`
- `practice/PracticeScreenActions.swift`
- `practice/PracticeGroupEditorComponents.swift`
- `practice/PracticeGameToolbarMenu.swift`

Findings:
- `change made`: removed the dead alias layer from canonical Practice ID resolution. `practiceIdentityAliases` was an empty dictionary, so that branch no longer carried any real behavior
- `follow-up`: canonical ID resolution depends on several lookup pools (`allLibraryGames`, `searchCatalogGames`, `bankTemplateGames`, `leagueCatalogGames`). That makes this file a real cross-feature identity seam, not just a utility

Changes made in this pass:
- removed the empty alias dictionary and simplified canonical ID resolution accordingly

### `PracticeInsightsContext.swift`

Status: `reviewed`

Responsibility summary:
- dependency bag for the Practice insights route

Line map:
- `3-19`: stored insight data, bindings, and async refresh callbacks

Primary interactions:
- `practice/PracticeScreenContexts.swift`
- `practice/PracticeInsightsSection.swift`

Findings:
- no dead code found
- intentional seam file; healthy as-is

Changes made in this pass:
- none

### `PracticeInsightsSection.swift`

Status: `change made`

Responsibility summary:
- renders score stats, sparkline trends, and head-to-head comparison for the selected Practice game and opponent

Line map:
- `3-37`: selected-game helpers and route state
- `38-148`: stats card, head-to-head card, and async refresh tasks
- `150-199`: game and opponent dropdowns
- `201-221`: privacy-display, chart-height, and score-format helpers

Primary interactions:
- `practice/PracticeInsightsContext.swift`
- `practice/PracticeInsightsWidgets.swift`
- `practice/PracticeStore.swift`

Findings:
- `change made`: replaced the local whole-score formatter duplication with shared `formatPracticeWholeScoreDisplay(_:)`
- `follow-up`: this view still relies on the `_ = showFullLPLLastNames` invalidation trick to react to last-name privacy changes. That is a hidden Observation contract and should eventually become an explicit display seam
- `follow-up`: the game dropdown still labels rows with raw `game.name`, which can drift from any future shared Practice display-title normalization

Changes made in this pass:
- switched whole-score formatting to the shared helper used by the insights widgets

### `PracticeInsightsWidgets.swift`

Status: `change made`

Responsibility summary:
- chart and row widgets for head-to-head comparison, score trends, and mechanics trends

Line map:
- `3-14`: shared whole-score formatting helper
- `16-40`: head-to-head game row
- `42-84`: mechanics trend sparkline
- `86-205`: score trend sparkline
- `207-273`: head-to-head delta bars

Primary interactions:
- `practice/PracticeInsightsSection.swift`
- `practice/PracticeMechanicsSection.swift`
- `practice/PracticeModels.swift`

Findings:
- `change made`: collapsed repeated whole-score formatting onto shared `formatPracticeWholeScoreDisplay(_:)`
- `follow-up`: this file is a legitimate chart seam, but it still mixes rendering with inline chart math and abbreviated-number rules, so it is another place where behavior can drift quietly

Changes made in this pass:
- added the shared whole-score formatter helper and reused it across insights widgets

### `PracticeJournalContext.swift`

Status: `reviewed`

Responsibility summary:
- dependency bag for the Practice journal route

Line map:
- `3-13`: stored journal bindings, transition namespace, and row actions

Primary interactions:
- `practice/PracticeScreenContexts.swift`
- `practice/PracticeScreenRouteContent.swift`
- `practice/PracticeJournalSettingsSections.swift`

Findings:
- no dead code found
- intentional seam file; healthy as-is

Changes made in this pass:
- none

### `PracticeJournalSettingsSections.swift`

Status: `reviewed`

Responsibility summary:
- defines journal item/day models, grouped journal rendering, journal-entry editing, score-input formatting, and the Practice settings section

Line map:
- `3-36`: journal models and day grouping
- `38-227`: journal list view and row rendering
- `229-247`: static editable-row chrome
- `249-555`: journal entry editor sheet and save logic
- `557-569`: score input formatter
- `571-730`: Practice settings section

Primary interactions:
- `practice/PracticeJournalSummaryStyling.swift`
- `practice/PracticeStore.swift`
- `practice/PracticeScreenActions.swift`
- `practice/PracticeIFPAProfileScreen.swift`

Findings:
- no dead code found
- `follow-up`: this file has become a large mixed seam. Journal rendering, journal editing, score-input formatting, and Practice settings now live together
- `follow-up`: `formatJournalScoreInputWithCommas(_:)` is another copy of the score-input formatting logic already noted elsewhere in Practice entry flows
- `follow-up`: the settings section uses the same `_ = showFullLPLLastNames` invalidation trick as the insights screen

Changes made in this pass:
- none

### `PracticeJournalSummaryStyling.swift`

Status: `reviewed`

Responsibility summary:
- tokenizes and colorizes Practice journal summary text into styled `Text`
- caches parsed token sequences for reuse

Line map:
- `4-44`: token models, cache, and array helpers
- `46-92`: public renderer and token-color resolution
- `94-168`: summary dispatch, score parsing, and bullet-game parsing
- `170-257`: structured Practice/game-note/study parsers
- `259-315`: library-summary parsing and string helpers
- `316-450`: video/progress/browsed summary parsers and helper splits

Primary interactions:
- `practice/PracticeJournalSettingsSections.swift`
- `practice/PracticeGameWorkspaceSubviews.swift`
- `practice/PracticeScreenActions.swift`

Findings:
- no dead code found
- `follow-up`: this parser is a hidden schema layer. It depends on literal summary-string formats emitted by multiple other Practice and Library surfaces, so wording changes elsewhere can quietly break styling here

Changes made in this pass:
- none

### `PracticeLifecycleContext.swift`

Status: `reviewed`

Responsibility summary:
- dependency bag for app-level Practice lifecycle events

Line map:
- `3-14`: stored lifecycle values and callbacks

Primary interactions:
- `practice/PracticeLifecycleHost.swift`
- `practice/PracticeScreen.swift`

Findings:
- no dead code found
- intentional seam file; healthy as-is

Changes made in this pass:
- none

### `PracticeLifecycleHost.swift`

Status: `reviewed`

Responsibility summary:
- centralizes Practice initial load, scene-phase reactions, library-viewed sync, journal-filter sync, sheet sync, and library-source change handling

Line map:
- `3-30`: lifecycle/event host wiring

Primary interactions:
- `practice/PracticeLifecycleContext.swift`
- `practice/PracticeDialogHost.swift`
- `practice/PracticeScreen.swift`

Findings:
- no dead code found
- `follow-up`: this host is the app-level side-effect seam for Practice. Initial load, scene changes, sheet changes, and notification-driven refreshes all run through view-owned hooks here, so timing behavior is spread across multiple event sources

Changes made in this pass:
- none

### `PracticeMechanicsContext.swift`

Status: `reviewed`

Responsibility summary:
- dependency bag for the mechanics route

Line map:
- `3-15`: stored mechanics bindings, closures, and height limit

Primary interactions:
- `practice/PracticeScreenContexts.swift`
- `practice/PracticeMechanicsSection.swift`

Findings:
- no dead code found
- intentional seam file; healthy as-is

Changes made in this pass:
- none

### `PracticeMechanicsSection.swift`

Status: `reviewed`

Responsibility summary:
- renders mechanics skill logging, summary metrics, per-skill history, and an external tutorial link

Line map:
- `3-140`: mechanics screen content
- `142-150`: compact trend and selected-skill helpers

Primary interactions:
- `practice/PracticeMechanicsContext.swift`
- `practice/PracticeInsightsWidgets.swift`
- `practice/PracticeStore.swift`

Findings:
- no dead code found
- lightweight route file overall; healthy as-is
- `follow-up`: the route mixes skill logging and history rendering with the hard-coded external tutorial link, which is small but still another behavior/UI seam worth keeping an eye on

Changes made in this pass:
- none

## Pass 011 summary

Safe cleanup changes made:
- removed the dead alias layer from `PracticeIdentityKeying.swift`
- added shared whole-score formatting in `PracticeInsightsWidgets.swift`
- switched `PracticeInsightsSection.swift` to the shared whole-score formatter

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. decide whether the IFPA profile surface should keep scraping public HTML directly or move behind a more stable parsing/service seam
2. replace the repeated `_ = showFullLPLLastNames` invalidation trick with an explicit privacy-aware LPL name display seam
3. collapse the remaining duplicated score-input formatting helpers across Practice entry and journal surfaces
4. decide whether `PracticeJournalSummaryStyling.swift` should consume a more structured summary payload instead of parsing literal emitted strings
5. decide whether the Practice lifecycle host should own fewer async side effects directly in view event hooks

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeModels.swift`
- `Pinball App 2/Pinball App 2/practice/PracticePresentationContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticePresentationHost.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeQuickEntrySheet.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeScreen.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeScreenActions.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeScreenContexts.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeScreenDerivedData.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeScreenRouteContent.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeScreenState.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeSettingsContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeSettingsCopy.swift`

## Pass 012: `practice/` core screen, presentation, and settings seams

### `PracticeModels.swift`

Status: `reviewed`

Responsibility summary:
- defines the core Practice domain enums, event/log models, group/settings models, persisted-state schema, and percentile helper

Line map:
- `3-111`: Practice enums and user-facing labels
- `113-259`: study, video, score, note, and journal entry models
- `261-410`: group, league, sync, analytics, and practice settings models
- `412-513`: persisted-state schema and decode defaults
- `515-536`: score summary shell and percentile math helper

Primary interactions:
- `practice/PracticeStore.swift`
- `practice/PracticeStorePersistence.swift`
- `practice/PracticeStoreEntryMutations.swift`
- most Practice UI/context files

Findings:
- no dead code found
- `follow-up`: this is the main Practice schema seam. `PracticePersistedState.currentSchemaVersion` is `4`, so any future parity or cleanup work that changes stored fields needs to stay in lockstep with persistence and migration behavior
- decode-time fallback defaults are intentional, but they also make schema drift harder to notice during review because older payloads silently hydrate into current state

Changes made in this pass:
- none

### `PracticePresentationContext.swift`

Status: `reviewed`

Responsibility summary:
- packages the bindings and callbacks needed by the screen-level Practice sheet host

Line map:
- `3-18`: stored presentation bindings, values, and callbacks

Primary interactions:
- `practice/PracticePresentationHost.swift`
- `practice/PracticeDialogHost.swift`
- `practice/PracticeScreenContexts.swift`

Findings:
- no dead code found after cleanup
- intentional seam file; healthy as-is

Changes made in this pass:
- removed the dead reset-prompt bindings and callback after confirming the root-level reset alert path was orphaned

### `PracticePresentationHost.swift`

Status: `reviewed`

Responsibility summary:
- routes live Practice sheet presentation to quick entry, group date editing, and journal entry editing

Line map:
- `4-73`: sheet-content switch and sheet chrome for the three presentation cases

Primary interactions:
- `practice/PracticePresentationContext.swift`
- `practice/PracticeQuickEntrySheet.swift`
- `practice/PracticeJournalSettingsSections.swift`
- `practice/PracticeScreenContexts.swift`

Findings:
- no dead code found after cleanup
- central presentation seam is healthy overall now that only the live sheet paths remain

Changes made in this pass:
- removed the dead root-level reset alert helper after confirming Settings already owns the only live reset confirmation UI

### `PracticeQuickEntrySheet.swift`

Status: `reviewed`

Responsibility summary:
- renders the quick-entry sheet for score, study, practice, and mechanics logging, including filtering, scanner presentation, and save-time entry composition

Line map:
- `3-35`: library-filter constants and initial filter-resolution helpers
- `37-188`: view state and derived picker/source labels
- `190-477`: quick-entry UI, scanner presentation, and state-sync hooks
- `479-602`: shared local subviews and picker builders
- `604-694`: save pipeline for every quick-entry activity
- `697-709`: local score-input comma formatter

Primary interactions:
- `practice/PracticeScreenActions.swift`
- `practice/PracticeScreenContexts.swift`
- `practice/PracticeStoreEntryMutations.swift`
- `library/LibraryPayloadParsing.swift`

Findings:
- no dead code found after cleanup
- `follow-up`: this is a major growth hotspot. Filtering, remembered selection, score scanning, activity-specific forms, and save-time note composition all live in one file
- `follow-up`: `preferredLibrarySourceDefaultsKey` intentionally shares the same UserDefaults key string as Library and `PracticeStoreDataLoaders`, so source preference behavior is coupled across features through literal storage contracts
- `follow-up`: score-input comma formatting is still duplicated with `PracticeGameEntrySheets.swift`
- `follow-up`: mechanics note composition is duplicated with `practiceMechanicsContext.onLogMechanicsSession` in `PracticeScreenContexts.swift`

Changes made in this pass:
- replaced the local library-source inference helper with shared `libraryInferSources(from:)`
- removed the dead duplicate `inferPracticeLibrarySources(from:)`

### `PracticeScreen.swift`

Status: `reviewed`

Responsibility summary:
- owns the root Practice store, global Practice app-storage keys, screen-local UI state, and the top-level navigation shell

Line map:
- `3-31`: store ownership, app-storage wiring, and root navigation shell
- `34-36`: preview

Primary interactions:
- `practice/PracticeScreenState.swift`
- `practice/PracticeDialogHost.swift`
- `practice/PracticeScreenContexts.swift`
- `practice/PracticeLifecycleHost.swift`

Findings:
- no dead code found
- intentionally thin root file; healthy overall
- `follow-up`: the `@AppStorage` keys here are a hidden global-state seam tying Practice resume behavior, quick-entry defaults, and prompt behavior to persisted keys outside the store

Changes made in this pass:
- none

### `PracticeScreenActions.swift`

Status: `reviewed`

Responsibility summary:
- centralizes Practice navigation, quick-entry opening, sheet/editor setup, journal deletion, and async data refresh actions

Line map:
- `4-15`: navigation interaction shield
- `17-35`: post-load default application
- `37-102`: route opening and rulesheet/playfield preparation
- `104-148`: quick-entry remembered-selection logic
- `150-219`: viewed-state, group editor, and journal editing helpers
- `221-261`: icon and activity summary helpers
- `263-297`: score trend and async insights refresh helpers

Primary interactions:
- `practice/PracticeScreenContexts.swift`
- `practice/PracticeScreenRouteContent.swift`
- `practice/PracticeQuickEntrySheet.swift`
- `practice/PracticeStore.swift`

Findings:
- no dead code found
- `follow-up`: this is a large behavior seam. Navigation, remembered quick-entry defaults, sheet setup, and async insight refreshes are all coordinated here through direct `uiState` mutation
- `follow-up`: quick-entry game defaulting is split between this file and `PracticeQuickEntrySheet.swift`, which makes selection behavior harder to reason about during parity review

Changes made in this pass:
- none

### `PracticeScreenContexts.swift`

Status: `reviewed`

Responsibility summary:
- constructs every major Practice view context and inlines the screen-level orchestration for home, journal, mechanics, settings, presentation, lifecycle, and insights

Line map:
- `4-79`: home context
- `81-99`: group dashboard context
- `101-125`: journal context
- `127-154`: mechanics context
- `156-206`: settings context
- `208-261`: presentation context
- `263-311`: lifecycle context
- `313-350`: insights context

Primary interactions:
- `practice/PracticeScreen.swift`
- `practice/PracticeScreenActions.swift`
- `practice/PracticeLifecycleHost.swift`
- all `Practice*Context.swift` seam files

Findings:
- no dead code found after cleanup
- `follow-up`: this is one of the biggest coordination seams in Practice. View wiring, async side effects, reset behavior, profile sync, import flows, and privacy/redaction callbacks all live inline here
- `follow-up`: mechanics logging string composition is duplicated with `PracticeQuickEntrySheet.swift`, including the `#mechanics` fallback and `competency x/5` note format
- `follow-up`: initial load, scene refresh, library-source reload, and name-prompt behavior are still embedded directly in context construction rather than behind narrower orchestration helpers

Changes made in this pass:
- removed the orphaned presentation-layer reset prompt plumbing that no live UI path was using

### `PracticeScreenDerivedData.swift`

Status: `reviewed`

Responsibility summary:
- derives Practice resume state, greeting text, selected group, and journal filter data from root screen state

Line map:
- `4-18`: resume-game selection logic
- `20-25`: default game and selected group helpers
- `28-40`: greeting-name derivation
- `42-48`: journal sections and filter decoding

Primary interactions:
- `practice/PracticeScreen.swift`
- `practice/PracticeScreenContexts.swift`
- `app/AppNavigationModel.swift`
- `practice/PracticeStore.swift`

Findings:
- no dead code found
- `follow-up`: `resumeGame` is a hidden cross-feature contract because it resolves between Library and Practice by comparing separate timestamp keys

Changes made in this pass:
- none

### `PracticeScreenRouteContent.swift`

Status: `reviewed`

Responsibility summary:
- switches Practice routes into concrete screens and wraps the major section views with shared route-level screen chrome

Line map:
- `5-107`: route switch for search, rulesheet, playfield, dashboard, journal, insights, mechanics, settings, and IFPA profile
- `109-130`: shared scroll and viewport screen wrappers
- `132-174`: group dashboard wrapper
- `176-187`: journal wrapper
- `189-219`: insights wrapper
- `221-245`: mechanics wrapper
- `247-274`: settings wrapper
- `276-279`: mechanics history sizing helper

Primary interactions:
- `practice/PracticeScreenContexts.swift`
- `practice/PracticeScreenActions.swift`
- `practice/PracticeJournalSettingsSections.swift`
- `library/RulesheetScreen.swift`

Findings:
- no dead code found
- `follow-up`: route switching and wrapper composition for all major Practice sub-screens still live together here, so navigation and presentation concerns are tightly coupled
- `follow-up`: the search route still depends on `practiceHomeContext.searchGames`, which keeps the home/search context seam indirectly coupled

Changes made in this pass:
- none

### `PracticeScreenState.swift`

Status: `reviewed`

Responsibility summary:
- stores the full view-owned transient Practice UI state bag

Line map:
- `4-38`: root Practice UI state fields

Primary interactions:
- `practice/PracticeScreen.swift`
- `practice/PracticeScreenActions.swift`
- `practice/PracticeScreenContexts.swift`
- `practice/PracticeDialogHost.swift`

Findings:
- no dead code found after cleanup
- healthy state-bag file overall, though it is now the main accumulation point for any view-local Practice state that is not yet lifted into a narrower seam

Changes made in this pass:
- removed the dead root-level reset prompt state after confirming no live UI path ever toggled it

### `PracticeSettingsContext.swift`

Status: `reviewed`

Responsibility summary:
- dependency bag for the Practice settings route

Line map:
- `3-16`: stored settings bindings, counts, status text, and callbacks

Primary interactions:
- `practice/PracticeScreenContexts.swift`
- `practice/PracticeScreenRouteContent.swift`
- `practice/PracticeJournalSettingsSections.swift`

Findings:
- no dead code found
- intentional seam file; healthy as-is

Changes made in this pass:
- none

### `PracticeSettingsCopy.swift`

Status: `reviewed`

Responsibility summary:
- centralizes Practice settings copy for league-import recovery messaging

Line map:
- `1-45`: static copy builders for imported-league-score summaries, button titles, alerts, and status text

Primary interactions:
- `practice/PracticeJournalSettingsSections.swift`
- `practice/PracticeScreenContexts.swift`

Findings:
- no dead code found after cleanup
- small copy-only seam; healthy as-is

Changes made in this pass:
- removed an unused `Foundation` import

## Pass 012 summary

Safe cleanup changes made:
- removed the orphaned root-level Practice reset prompt plumbing spanning `PracticeDialogHost.swift`, `PracticePresentationContext.swift`, `PracticePresentationHost.swift`, `PracticeScreenContexts.swift`, and `PracticeScreenState.swift`
- switched `PracticeQuickEntrySheet.swift` to shared `libraryInferSources(from:)` and removed its dead duplicate inference helper
- removed an unused `Foundation` import from `PracticeSettingsCopy.swift`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. decide whether quick-entry source preference should keep sharing the Library UserDefaults key literally or move behind an explicit shared preference seam
2. collapse the duplicated score-input formatting helpers across quick-entry and in-game Practice entry surfaces
3. collapse the duplicated mechanics note-composition logic shared by quick entry and the mechanics route
4. decide whether `PracticeScreenContexts.swift` should keep owning so much inline orchestration or split lifecycle/settings/presentation behavior into narrower coordinators
5. keep migration-sensitive parity changes around `PracticePersistedState` explicitly aligned with persistence and decode-default behavior

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeStore.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreAnalytics.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreDataLoaders.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreGroupHelpers.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreJournalHelpers.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreLeagueHelpers.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreLeagueOps.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreMechanicsHelpers.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStorePersistence.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeTimePopoverField.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeTypes.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeVideoComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeVideoLoggingHelpers.swift`
- `Pinball App 2/Pinball App 2/practice/ResolvedLeagueMachineMappings.swift`
- `Pinball App 2/Pinball App 2/practice/ResolvedLeagueTargets.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreConfirmationSheet.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreOCRService.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreParsingService.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerCameraTestView.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerModels.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerView.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerViewModel.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreStabilityService.swift`

## Pass 014: `practice/` video helpers, resolved league assets, and score-scanner stack

### `PracticeTypes.swift`

Status: `reviewed`

Responsibility summary:
- defines the lightweight Practice navigation, sheet, quick-entry, and journal filter enums used by the rest of the Practice UI

Line map:
- `3-46`: hub destinations, labels, icons, and route mapping
- `48-60`: route enum
- `62-68`: sheet enum
- `70-90`: quick-entry sheet enum and default activity mapping
- `92-126`: quick-entry activity enum and `StudyTaskKind` mapping
- `128-148`: journal filter enum

Primary interactions:
- `practice/PracticeHomeRootView.swift`
- `practice/PracticePresentationHost.swift`
- `practice/PracticeQuickEntrySheet.swift`
- `practice/PracticeStoreJournalHelpers.swift`

Findings:
- no dead code found
- healthy seam overall
- `follow-up`: this is still a parity-sensitive contract layer because route or enum-case churn propagates widely through Practice state restoration, navigation, and filtering

Changes made in this pass:
- none

### `PracticeVideoComponents.swift`

Status: `reviewed`

Responsibility summary:
- renders the Practice resource card, including rulesheet chips, live playfield options, featured video launch panel, and selectable video tiles

Line map:
- `3-120`: game resource card and rulesheet/playfield/video composition
- `122-131`: featured video launch panel wrapper
- `133-157`: selectable video tile
- `159-171`: YouTube thumbnail loader

Primary interactions:
- `practice/PracticeGameSection.swift`
- `library/LibraryHostedData.swift`
- `ui/AppResourceChrome.swift`

Findings:
- no dead code found
- healthy UI seam overall
- `follow-up`: this file depends on a shared `LibraryLivePlayfieldStatusStore` side channel, so playfield availability is not purely a function of the `PinballGame` payload passed into the card

Changes made in this pass:
- none

### `PracticeVideoLoggingHelpers.swift`

Status: `reviewed`

Responsibility summary:
- centralizes Practice video input-mode labels, source-option derivation, and watched-progress string construction

Line map:
- `3-19`: draft model and shared video input-mode labels/options
- `21-95`: source-option discovery across game/library candidates
- `97-129`: video log draft builder
- `131-159`: `hh:mm:ss` parsing and formatting helpers
- `161-165`: integer clamping helper

Primary interactions:
- `practice/PracticeQuickEntrySheet.swift`
- `practice/PracticeGameEntrySheets.swift`
- `practice/PracticeStoreEntryMutations.swift`

Findings:
- no dead code found
- `follow-up`: placeholder labels like `"Tutorial -"` and `"Gameplay -"` are part of the persisted note/value contract here, so video logs can be saved even when there is no concrete referenced video
- `follow-up`: source selection across multiple library candidates prefers the caller’s preferred source and then the candidate with the most matching video options, which is a hidden cross-source heuristic seam

Changes made in this pass:
- none

### `ResolvedLeagueMachineMappings.swift`

Status: `reviewed`

Responsibility summary:
- decodes the resolved league machine-mapping JSON payload into normalized machine-name lookups

Line map:
- `3-18`: decodable record and JSON root
- `20-34`: parser and normalized-name dictionary assembly

Primary interactions:
- `practice/PracticeStoreLeagueHelpers.swift`
- `library/LibraryGameLookup.swift`

Findings:
- no dead code found
- `follow-up`: duplicate machine names collapse silently because the normalized-name dictionary overwrites earlier records with later ones
- small parse seam otherwise healthy

Changes made in this pass:
- none

### `ResolvedLeagueTargets.swift`

Status: `reviewed`

Responsibility summary:
- decodes resolved league-target JSON rows and projects them into per-identity score targets

Line map:
- `3-40`: decodable target record and computed score projection
- `42-54`: versioned JSON parser
- `56-66`: score-target lookup by practice identity

Primary interactions:
- `practice/PracticeStoreDataLoaders.swift`
- `league/LeaguePreviewLoader.swift`
- `targets/TargetsScreen.swift`

Findings:
- no dead code found
- `follow-up`: duplicate `practiceIdentity` values overwrite silently in `resolvedLeagueTargetScoresByPracticeIdentity(records:)`, so bad upstream data is not surfaced
- healthy parse seam overall

Changes made in this pass:
- none

### `ScoreConfirmationSheet.swift`

Status: `reviewed`

Responsibility summary:
- renders the frozen scanner confirmation card, including OCR echo, manual correction formatting, validation, and confirmation actions

Line map:
- `3-25`: bindings, formatted manual-entry wrapper, and validation gate
- `27-95`: confirmation UI

Primary interactions:
- `practice/ScoreScannerView.swift`
- `practice/ScoreParsingService.swift`

Findings:
- no dead code found
- healthy focused seam overall
- `follow-up`: the confirm button only depends on manual-input normalization, so frozen-scanner state and manual-entry state intentionally collapse into one validation path

Changes made in this pass:
- none

### `ScoreOCRService.swift`

Status: `reviewed`

Responsibility summary:
- runs Vision OCR against live and final-pass score images, including multiple CI-filter variants and display-mode-specific minimum text-height tuning

Line map:
- `6-32`: OCR entrypoint and candidate ranking handoff
- `34-58`: Vision request configuration and observation conversion
- `60-132`: final-pass image-variant generation
- `134-149`: display-mode-specific minimum text-height thresholds

Primary interactions:
- `practice/ScoreParsingService.swift`
- `practice/ScoreScannerViewModel.swift`
- `Vision`
- `CoreImage`

Findings:
- no dead code found
- `follow-up`: this is a heuristic hotspot. CI filter recipes, confidence multipliers, and text-height thresholds are all hard-coded and not externally tunable
- `follow-up`: scanner display-mode support exists here, but the live scanner currently never switches away from `.lcd`, so DMD and segmented tuning paths are dormant today

Changes made in this pass:
- none

### `ScoreParsingService.swift`

Status: `reviewed`

Responsibility summary:
- normalizes OCR text into ranked score candidates, applies separator and leading-digit rescue heuristics, and formats manual score input

Line map:
- `5-44`: normalization models and public formatting/parser entrypoints
- `47-85`: candidate construction and ranking
- `87-213`: OCR text normalization and run-candidate expansion
- `215-452`: grouped rescue heuristics and run sorting
- `454-530`: format-quality scoring and separator helpers

Primary interactions:
- `practice/ScoreOCRService.swift`
- `practice/ScoreScannerViewModel.swift`
- `practice/ScoreConfirmationSheet.swift`
- `practice/PracticeQuickEntrySheet.swift`

Findings:
- no dead code found after cleanup
- `follow-up`: this is the core score-scanner heuristic seam. Zero-confusion rescue, missing-leading-digit rescue, and quality scoring all contain embedded OCR assumptions that can drift from Android easily
- `follow-up`: rescue logic intentionally mutates ambiguous leading digits like `0 -> 6/8` and `1 -> 7` under certain grouping patterns, which is powerful but also makes false-positive “corrections” harder to reason about during regressions

Changes made in this pass:
- removed the dead `bestCandidate(from:)` helper after confirming all callers go through `rankedCandidates(from:)`

### `ScoreScannerCameraTestView.swift`

Status: `reviewed`

Responsibility summary:
- implements a preview-only rear-camera test screen and local view model for manual on-device scanner setup checks

Line map:
- `5-99`: full-screen camera test UI and permission card
- `101-246`: local view model for permission flow, preview startup, and portrait rotation

Primary interactions:
- `practice/CameraPreviewView.swift`
- `AVFoundation`
- `UIApplication.openSettingsURLString`

Findings:
- no dead code found inside the file itself
- `follow-up`: repo-wide search found no instantiation call sites for `ScoreScannerCameraTestView`, so this currently looks like orphaned manual QA code rather than a live product path
- `follow-up`: the preview utility starts and stops the camera session on the main actor, which would be worth fixing only if the file remains in active use

Changes made in this pass:
- none

### `ScoreScannerModels.swift`

Status: `reviewed`

Responsibility summary:
- defines scanner display/status enums, OCR and locked-reading models, preview-to-frame mapping helpers, and target-box layout rules

Line map:
- `5-11`: display-mode enum
- `13-59`: scanner status copy
- `61-107`: OCR observation, candidate, analysis, and locked-reading models
- `109-176`: frame-mapping helpers
- `178-188`: target-box layout

Primary interactions:
- `practice/ScoreOCRService.swift`
- `practice/ScoreScannerViewModel.swift`
- `practice/ScoreScannerView.swift`

Findings:
- no dead code found after cleanup
- `follow-up`: `ScoreScannerDisplayMode` is currently a dormant seam because the live scanner never changes its fixed `.lcd` mode
- `follow-up`: target-box layout and crop mapping are hidden UX contracts; even small geometry changes here affect OCR candidate quality and live overlay positioning

Changes made in this pass:
- removed dead confidence-only fields from `ScoreScannerLockedReading` after confirming no UI or scanner behavior read them

### `ScoreScannerView.swift`

Status: `reviewed`

Responsibility summary:
- renders the full-screen scanner shell, target overlay, live reading panel, frozen confirmation flow, keyboard handling, and camera-permission overlays

Line map:
- `5-117`: scanner shell, lifecycle, viewport stabilization, and top-level presentation
- `119-184`: top bar, header, and tappable live-reading panel
- `186-359`: zoom/freeze controls, status styling, and permission overlays
- `361-385`: use-reading action and frozen preview rendering
- `387-428`: keyboard overlap observer
- `430-491`: target overlay highlight rendering

Primary interactions:
- `practice/ScoreScannerViewModel.swift`
- `practice/ScoreConfirmationSheet.swift`
- `practice/CameraPreviewView.swift`
- `UIKit`

Findings:
- no dead code found after cleanup
- `follow-up`: viewport stabilization and keyboard-overlap handling are doing real layout work here, so scanner geometry now depends on both camera state and keyboard state
- `follow-up`: zoom affordances are hard-coded to `1x` and `8x`, even though the slider already exposes the device’s actual max zoom range

Changes made in this pass:
- removed the dead empty `FreezeButtonLayoutModifier`

### `ScoreScannerViewModel.swift`

Status: `reviewed`

Responsibility summary:
- owns camera authorization, session setup, live OCR throttling, freeze buffering, candidate filtering, confirmation-state updates, and final-pass lock logic

Line map:
- `8-59`: scanner state, capture services, queues, and tuning constants
- `61-108`: lifecycle, preview-layer attachment, target mapping, and zoom control
- `110-166`: freeze, retake, and manual-score validation
- `168-285`: camera authorization and capture-session configuration
- `287-349`: freeze pipeline and final-pass OCR
- `351-429`: live OCR processing and locked-reading derivation
- `431-553`: crop, render, buffer, and candidate-filter helpers
- `555-642`: frame handling and video-output delegate

Primary interactions:
- `practice/ScoreScannerView.swift`
- `practice/ScoreOCRService.swift`
- `practice/ScoreStabilityService.swift`
- `practice/ScoreScannerModels.swift`
- `AVFoundation`

Findings:
- no dead code found after cleanup
- `follow-up`: this is now one of the highest-risk hidden-behavior seams in Practice. Capture-session configuration, OCR timing, buffered freeze selection, and UI state updates are all coordinated here
- `follow-up`: `displayMode` is fixed to `.lcd`, so the scanner’s DMD and segmented OCR tuning paths are currently unreachable
- `follow-up`: `processingPaused`, `isProcessingFrame`, `lastOCRTime`, and `latestSnapshot` are mutated from multiple queues/actors with mixed `sync` and `async` access, which makes the live scanner vulnerable to racey state transitions and duplicate OCR work

Changes made in this pass:
- removed dead `rawReadingText` state that never left the view model
- removed dead confidence-only payload wiring from `ScoreScannerLockedReading` construction

### `ScoreStabilityService.swift`

Status: `reviewed`

Responsibility summary:
- reduces live OCR candidates into scanner status snapshots using recent-reading consensus, confidence thresholds, and miss-count fallback behavior

Line map:
- `4-33`: configuration, reading/snapshot models, and initialization
- `35-98`: reset and ingest state machine
- `100-123`: dominant-consensus ranking

Primary interactions:
- `practice/ScoreScannerViewModel.swift`
- `practice/ScoreScannerModels.swift`

Findings:
- no dead code found
- `follow-up`: required matches, confidence threshold, recent-reading window, and failed-after-misses thresholds are all hard-coded here
- `follow-up`: consensus groups only by normalized score, so alternate candidates with identical numbers but very different boxes/text get merged intentionally

Changes made in this pass:
- none

## Pass 014 summary

Safe cleanup changes made:
- removed the dead `ScoreParsingService.bestCandidate(from:)` helper
- removed dead confidence-only fields from `ScoreScannerLockedReading`
- removed dead `rawReadingText` state from `ScoreScannerViewModel.swift`
- removed the dead empty `FreezeButtonLayoutModifier` from `ScoreScannerView.swift`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. decide whether `ScoreScannerCameraTestView.swift` should remain as an intentional manual QA utility or be removed as orphaned scanner code
2. expose or delete the dormant DMD/segmented scanner tuning path so `ScoreScannerDisplayMode` is either real product behavior or no longer misleading
3. isolate `ScoreScannerViewModel` queue/actor state so OCR throttling and freeze flow stop depending on unsynchronized shared mutable fields
4. decide whether video logs should keep allowing placeholder-only source labels like `"Tutorial -"` and `"Gameplay -"` to persist
5. make duplicate handling explicit in resolved league asset loaders instead of silently overwriting repeated normalized machine names or practice identities

Next files queued:
- `Pinball App 2/Pinball App 2/settings/MatchPlayClient.swift`
- `Pinball App 2/Pinball App 2/settings/PinballMapClient.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsDataIntegration.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsHomeSections.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsImportScreens.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsRouteContent.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsScreen.swift`
- `Pinball App 2/Pinball App 2/standings/StandingsScreen.swift`
- `Pinball App 2/Pinball App 2/stats/StatsScreen.swift`
- `Pinball App 2/Pinball App 2/targets/TargetsScreen.swift`
- `Pinball App 2/Pinball App 2/ui/SharedFullscreenChrome.swift`
- `Pinball App 2/Pinball App 2/ui/SharedGestures.swift`
- `Pinball App 2/Pinball App 2/ui/SharedTableUi.swift`

## Pass 015: `settings/` import clients, data integration, and settings shell

### `MatchPlayClient.swift`

Status: `reviewed`

Responsibility summary:
- fetches Match Play tournament metadata and extracts OPDB-linked arena machine IDs for settings imports

Line map:
- `3-7`: import-result model
- `9-43`: tournament fetch pipeline
- `45-60`: user-facing error mapping
- `62-84`: Match Play payload models
- `86-90`: local blank-string helper

Primary interactions:
- `settings/SettingsImportScreens.swift`
- `settings/SettingsDataIntegration.swift`

Findings:
- no dead code found
- healthy network seam overall
- `follow-up`: this file imports only OPDB-linked arenas, so tournaments without OPDB mappings appear as partially empty imports even if Match Play has more arena data

Changes made in this pass:
- none

### `PinballMapClient.swift`

Status: `reviewed`

Responsibility summary:
- searches Pinball Map venues by address or lat/lon and fetches per-venue machine IDs for settings imports

Line map:
- `3-27`: venue search entrypoints
- `30-74`: shared fetch helpers and machine-ID import
- `77-89`: user-facing HTTP error mapping
- `91-127`: Pinball Map payload models

Primary interactions:
- `settings/SettingsImportScreens.swift`
- `settings/SettingsDataIntegration.swift`
- `library/LibraryBuiltInSources.swift`

Findings:
- no dead code found after cleanup
- `follow-up`: this is a live external contract seam. Address search, current-location search, venue import, and legacy venue migration all depend on the Pinball Map API shape here
- `follow-up`: venue IDs are still projected into the app’s internal `"venue--pm-<id>"` source format outside this file, so provider/app ID translation remains a hidden multi-file contract
- on March 27, 2026, I verified The Avenue (`Pinball Map` location `8760`) currently returns distinct OPDB IDs for `Godzilla (LE)` and `Godzilla (Premium)`, so the dedupe added here does not collapse that venue pair
- `follow-up`: exact duplicate OPDB IDs are already collapsed later by imported-source normalization in `LibraryCatalogStore.swift`, so true same-ID multiplicity is not represented anywhere in the current venue-import model

Changes made in this pass:
- aligned HTTP status handling with `MatchPlayClient` so Pinball Map failures no longer decode silently from non-2xx responses
- normalized imported venue machine IDs to drop blank strings and dedupe duplicates before they enter Library source records

### `SettingsDataIntegration.swift`

Status: `reviewed`

Responsibility summary:
- loads settings snapshots, refreshes hosted data, clears runtime caches, and mutates imported Library source records from settings flows

Line map:
- `3-12`: snapshot shells
- `14-33`: snapshot loading, hosted refresh, and cache clearing
- `35-116`: add, remove, and refresh helpers for manufacturer, venue, and tournament imports
- `118-123`: shared source-state snapshot builder

Primary interactions:
- `settings/SettingsScreen.swift`
- `settings/PinballMapClient.swift`
- `settings/MatchPlayClient.swift`
- `data/PinballDataCache.swift`

Findings:
- no dead code found
- `follow-up`: this is the write seam for Library source imports. Settings UI stays thin because all mutation side effects route through these helpers
- `follow-up`: `clearAppRuntimeCaches()` intentionally clears hosted-data/runtime caches without touching settings, Practice history, or GameRoom data, so cache-reset expectations are distributed across copy and code

Changes made in this pass:
- none

### `SettingsHomeSections.swift`

Status: `reviewed`

Responsibility summary:
- renders the main settings home content, including appearance, Library source management, hosted-data refresh, privacy controls, and about content

Line map:
- `3-58`: top-level content and appearance section
- `60-114`: Library add-source section
- `116-175`: hosted refresh and cache-clear section
- `177-318`: source table, row projection, subtitles, and toggle actions
- `320-362`: privacy section
- `364-409`: about section and hidden intro-toggle affordance

Primary interactions:
- `settings/SettingsScreen.swift`
- `settings/SettingsImportScreens.swift`
- `library/LibraryCatalogStore.swift`
- `app/AppIntroOverlay.swift`

Findings:
- no dead code found
- `follow-up`: this is a growth hotspot at 400+ lines and currently owns most of the live settings UI composition
- intentional hidden owner affordance: the about logo’s double-tap toggle for next-launch intro behavior is user-confirmed and should stay in place during cleanup review
- `follow-up`: Library source management depends on a wide cross-feature contract between imported-source records, source-state toggles, pinned-source limits, and Library/Practice source filters

Changes made in this pass:
- none

### `SettingsImportScreens.swift`

Status: `reviewed`

Responsibility summary:
- implements manufacturer, venue, and tournament import flows, plus shared import-row UI and location/tournament parsing helpers

Line map:
- `4-88`: add-manufacturer flow
- `90-134`: manufacturer bucket enum and filtering heuristic
- `136-354`: add-venue flow
- `356-447`: location error handling and current-location requester
- `449-517`: add-tournament flow
- `519-574`: shared provider caption and import result row
- `576-590`: tournament-ID extraction helper

Primary interactions:
- `settings/SettingsScreen.swift`
- `settings/PinballMapClient.swift`
- `settings/MatchPlayClient.swift`
- `CoreLocation`

Findings:
- no dead code found after cleanup
- `follow-up`: classic-manufacturer bucketing is heuristic-driven here; the “Classic” bucket is the top 20 non-modern manufacturers by game count, and “Other” is everything else
- `follow-up`: the venue minimum-game filter is persisted in `@AppStorage`, so import UI behavior survives between launches through a hidden user-defaults seam
- `follow-up`: `extractTournamentID(from:)` only recognizes raw digits or URLs containing `tournaments/<digits>`, so some Match Play share-link variants may still be rejected

Changes made in this pass:
- activated the previously dead `servicesDisabled` path by checking `CLLocationManager.locationServicesEnabled()` before requesting current location

### `SettingsRouteContent.swift`

Status: `reviewed`

Responsibility summary:
- maps settings routes to the three concrete import screens

Line map:
- `3-16`: route switch

Primary interactions:
- `settings/SettingsScreen.swift`
- `settings/SettingsImportScreens.swift`

Findings:
- no dead code found
- intentional seam file; healthy as-is

Changes made in this pass:
- none

### `SettingsScreen.swift`

Status: `reviewed`

Responsibility summary:
- defines settings routes, owns the settings view model, coordinates snapshot loading and source mutations, and hosts the root settings navigation shell

Line map:
- `4-8`: route enum
- `10-171`: settings view model
- `173-242`: root settings screen and intro-toggle banner behavior

Primary interactions:
- `settings/SettingsHomeSections.swift`
- `settings/SettingsDataIntegration.swift`
- `settings/SettingsRouteContent.swift`
- `library/LibraryCatalogStore.swift`

Findings:
- no dead code found after cleanup
- `follow-up`: this is the app-level settings coordination seam. Source mutation, hosted refresh, cache clearing, and notification-driven reload behavior all converge here
- `follow-up`: settings refresh still depends on observing `.pinballLibrarySourcesDidChange`, so the screen’s freshness is coupled to notification discipline in other code paths
- `follow-up`: the view model’s `didLoad` guard assumes one long-lived screen instance, which is fine today but worth keeping in mind if settings ever gains explicit reload/reset flows

Changes made in this pass:
- cleared stale top-level `errorMessage` state on successful source toggles, imports, removals, and refreshes so old error banners no longer linger after later successful actions

## Pass 015 summary

Safe cleanup changes made:
- aligned `PinballMapClient.swift` with `MatchPlayClient.swift` by checking HTTP status codes explicitly
- normalized Pinball Map machine imports to remove blank OPDB IDs and dedupe duplicates
- activated the dead location-services-disabled error path in `VenueLocationRequester`
- cleared stale success-path settings errors in `SettingsViewModel`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. make Library source ID translation more explicit so `"venue--pm-"` and `"tournament--mp-"` contracts are not spread across multiple settings and library files
2. decide whether the top-20 “Classic” manufacturer heuristic should stay hard-coded in UI code or move behind a shared bucketing policy
3. audit whether settings refresh should keep depending on notification rebroadcasts or move to a more explicit shared source-state model
4. expand Match Play tournament ID parsing if the app should accept more share-link formats than `tournaments/<digits>`
5. if venue imports ever need to preserve true duplicate exact OPDB IDs as counts, add explicit multiplicity support instead of continuing to treat `machineIDs` as a set

Next files queued:
- `Pinball App 2/Pinball App 2/standings/StandingsScreen.swift`
- `Pinball App 2/Pinball App 2/stats/StatsScreen.swift`
- `Pinball App 2/Pinball App 2/targets/TargetsScreen.swift`
- `Pinball App 2/Pinball App 2/ui/SharedFullscreenChrome.swift`
- `Pinball App 2/Pinball App 2/ui/SharedGestures.swift`
- `Pinball App 2/Pinball App 2/ui/SharedTableUi.swift`

## Pass 013: `practice/` store, league-import, and persistence seams

### `PracticeStore.swift`

Status: `reviewed`

Responsibility summary:
- owns the central Practice store object, published library and persisted state, transient cache fields, bootstrap flags, league snapshots, and shared lookup invalidation helpers

Line map:
- `1-129`: store support structs, snapshots, and `LeagueImportResult`
- `137-230`: published state, caches, bootstrap flags, and initialization
- `233-299`: target lookup, name resolution, and cache invalidation helpers

Primary interactions:
- `practice/PracticeStoreDataLoaders.swift`
- `practice/PracticeStoreEntryMutations.swift`
- `practice/PracticeStorePersistence.swift`
- nearly every Practice screen/context file

Findings:
- no dead code found after cleanup
- `follow-up`: this is the main Practice ownership seam. Library state, league caches, journal caches, dashboard caches, and persisted state all converge here, so parity drift tends to become hidden inside store-level side effects
- `follow-up`: `LeagueImportResult` still acts as a broad cross-file contract for import summaries, journal recording, and settings recovery UI, so field changes need coordinated review across multiple store helpers

Changes made in this pass:
- removed the dead `LeagueImportResult.sourcePath` field after confirming it had no callers

### `PracticeStoreAnalytics.swift`

Status: `reviewed`

Responsibility summary:
- derives Practice dashboard alerts, timeline summaries, focus priorities, and gap/completion heuristics from persisted activity state

Line map:
- `4-18`: priority candidate and focus-game ranking
- `20-60`: dashboard alerts
- `62-100`: timeline summary derivation
- `103-200`: completion, gap severity, and focus-priority heuristics
- `203-211`: adjacent date-gap helper

Primary interactions:
- `practice/PracticeInsightsSection.swift`
- `practice/PracticeInsightsWidgets.swift`
- `practice/PracticeHomeBootstrapSnapshot.swift`
- `practice/PracticeStore.swift`

Findings:
- no dead code found
- `follow-up`: this is a parity-sensitive behavior seam because alert thresholds and focus heuristics are hard-coded here rather than sourced from a shared policy layer
- `follow-up`: embedded constants like the 90-day rulesheet window, 14-day practice gap, and `0.6` spread threshold are easy to drift from Android if they change opportunistically

Changes made in this pass:
- none

### `PracticeStoreDataLoaders.swift`

Status: `reviewed`

Responsibility summary:
- loads Practice library/search state, hydrates stored references, parses target CSV content, resolves preferred source selection, and assembles Avenue bank templates

Line map:
- `3-9`: load-result shell
- `11-124`: library, search, bank, and target load orchestration
- `126-197`: target CSV parsing
- `199-253`: source selection and applied library state
- `256-307`: stored-reference hydration checks
- `310-421`: Avenue bank-template assembly from OPDB and venue assets

Primary interactions:
- `practice/PracticeStore.swift`
- `practice/PracticeQuickEntrySheet.swift`
- `library/LibraryCatalogStore.swift`
- `library/LibraryPayloadParsing.swift`

Findings:
- no dead code found
- `follow-up`: `preferredLibrarySourceDefaultsKey = "preferred-library-source-id"` is a hidden literal contract shared with Library and quick-entry flows, so source preference behavior is coupled through storage-key reuse
- `follow-up`: load/apply source selection is split across `UserDefaults` and `PinballLibrarySourceStateStore`, which makes parity review harder because selection state comes from more than one persistence path
- `follow-up`: `loadInitialLibraryState()` still reports a “practice upgrade” failure message that now looks stale relative to the actual failure modes in this file

Changes made in this pass:
- none

### `PracticeStoreEntryMutations.swift`

Status: `reviewed`

Responsibility summary:
- mutates Practice tasks, videos, scores, notes, journal edits, imported-league cleanup, and settings/reset flows, then reconciles journal edits back into the underlying state arrays

Line map:
- `4-27`: study getters and update wrapper
- `29-142`: add task, video, score, and note mutations
- `144-209`: browse, settings, import, and reset mutations
- `211-372`: journal edit and delete entrypoints
- `374-496`: array-matching and reconciliation helpers

Primary interactions:
- `practice/PracticeStore.swift`
- `practice/PracticeStoreJournalHelpers.swift`
- `practice/PracticeJournalSettingsSections.swift`
- `practice/PracticeQuickEntrySheet.swift`

Findings:
- no dead code found after cleanup
- `follow-up`: journal edit/delete reconciliation is fragile because it tries to match back into parallel arrays using timestamp and field heuristics rather than stable IDs
- `follow-up`: `resetPracticeState()` removes the storage key and immediately calls `saveState()`, so reset does not leave storage empty; it overwrites persistence with canonical `.empty` state instead
- `follow-up`: imported-league cleanup depends partly on the literal note prefix `"Imported from LPL stats CSV"`, which is a hidden string contract

Changes made in this pass:
- removed the dead `updateSyncSettings(cloudSyncEnabled:)` helper after confirming nothing called it

### `PracticeStoreGroupHelpers.swift`

Status: `reviewed`

Responsibility summary:
- manages Practice groups, template import, dashboard detail derivation, group ordering, archived recommendations, and duplicate detection

Line map:
- `4-40`: create-group flow
- `42-74`: bank-template and selected-group resolution
- `76-138`: update and delete group flows
- `140-200`: auto-archive, reorder, and remove-game helpers
- `202-300`: group games, progress, dashboard detail, recommendations, and dedupe

Primary interactions:
- `practice/PracticeGroupDashboardSection.swift`
- `practice/PracticeGroupEditorComponents.swift`
- `practice/PracticeHomeSection.swift`
- `practice/PracticeStore.swift`

Findings:
- no dead code found
- `follow-up`: this file is a meaningful parity seam because group recommendation, archive, and dedupe behavior all live in store helpers rather than UI-only composition
- `follow-up`: dashboard detail and group progress calculations are tightly coupled to current Practice state shape, so schema cleanup needs to keep this logic aligned

Changes made in this pass:
- none

### `PracticeStoreJournalHelpers.swift`

Status: `reviewed`

Responsibility summary:
- builds Practice journal payloads, score summaries, icon/summary text, filtered journal projections, and cached journal lookup data

Line map:
- `3-7`: cached journal payload shell
- `9-179`: journal, score, and note summary helpers
- `181-233`: cached journal payload and score-entry caches
- `236-343`: filter, icon, summary, and private formatting helpers

Primary interactions:
- `practice/PracticeJournalSettingsSections.swift`
- `practice/PracticeScreenActions.swift`
- `practice/PracticeInsightsSection.swift`
- `practice/PracticeStore.swift`

Findings:
- no dead code found after cleanup
- `follow-up`: league journal filtering depends on `entry.note` containing `"league import"`, so imported-summary visibility is controlled by literal note text rather than explicit entry metadata
- `follow-up`: `parsedPracticeSessionParts(from:)` is a hidden schema seam because it parses human-readable `"Practice session..."` strings produced elsewhere
- `follow-up`: icon/summary formatting here overlaps conceptually with screen-level helpers, which makes it easy for presentation drift to hide in duplicate formatting code

Changes made in this pass:
- removed dead journal helpers: `journalItems(filter:)`, `recentJournalEntries(limit:)`, `allJournalEntries()`, and `clearJournalLog()`

### `PracticeStoreLeagueHelpers.swift`

Status: `reviewed`

Responsibility summary:
- normalizes league names, parses LPL CSVs, loads IFPA and machine-mapping snapshots, resolves games and targets, and coordinates imported-league recovery/note behavior

Line map:
- `3-56`: human-name normalization helpers
- `58-160`: league row/player structs, formatter, and head-to-head comparison
- `167-279`: available players, IFPA matching, league settings, and resume/note helpers
- `281-340`: league CSV parsing
- `343-479`: stats, IFPA, and machine-mapping snapshot loads
- `481-633`: event timestamp, game resolution, duplicate repair, and target lookup
- `636-655`: approved-player array matching helper

Primary interactions:
- `practice/PracticeStoreLeagueOps.swift`
- `practice/PracticeSettingsCopy.swift`
- `practice/ResolvedLeagueMachineMappings.swift`
- `practice/ResolvedLeagueTargets.swift`

Findings:
- no dead code found
- `follow-up`: this is one of the highest-coupling Practice seams. Name normalization, IFPA approval matching, machine resolution, timestamp normalization, and recovery-note logic all live together here
- `follow-up`: `leagueEventTimestamp(for:)` canonicalizes imported league events to `22:00` local time, which is a hidden persistence contract also mirrored elsewhere
- `follow-up`: `updateGameSummaryNote()` is a dual-write seam because it both updates summary state and writes a journal note when the saved text changes
- `follow-up`: IFPA matching falls back from approved CSV matching to raw league-player matching with nil IFPA IDs, which is permissive behavior worth keeping explicit for parity review

Changes made in this pass:
- none

### `PracticeStoreLeagueOps.swift`

Status: `reviewed`

Responsibility summary:
- executes the league CSV import pipeline and auto-import gating, including optional journal summary recording and settings-status updates

Line map:
- `4-108`: CSV import pipeline
- `110-145`: auto-import gating

Primary interactions:
- `practice/PracticeStoreLeagueHelpers.swift`
- `practice/PracticeStoreEntryMutations.swift`
- `practice/PracticeStore.swift`
- `practice/PracticeSettingsCopy.swift`

Findings:
- no dead code found after cleanup
- `follow-up`: import summary recording is a hidden schema overload because the summary gets appended as a `.scoreLogged` journal entry with no score and only a note payload
- `follow-up`: the imported-summary row stays visible in league filters because `summaryLine` currently begins with `"League import"`, which is another literal text dependency

Changes made in this pass:
- removed dead `sourcePath:` initializer wiring after the backing field was deleted from `LeagueImportResult`

### `PracticeStoreMechanicsHelpers.swift`

Status: `reviewed`

Responsibility summary:
- defines curated mechanics skills, infers mechanics sessions from notes, expands aliases, and parses/stylizes mechanics comfort summaries

Line map:
- `4-23`: curated mechanics skill list
- `25-75`: detection and log-expansion helpers
- `77-128`: summary and comfort parsing
- `130-160`: aliases and mechanics-entry detection

Primary interactions:
- `practice/PracticeMechanicsSection.swift`
- `practice/PracticeQuickEntrySheet.swift`
- `practice/PracticeScreenContexts.swift`
- `practice/PracticeStoreJournalHelpers.swift`

Findings:
- dead-code cleanup was not needed, but a real parse bug was present
- `follow-up`: mechanics parsing depends on the curated `mechanicsSkills` list, so free-form user wording still falls outside the inferred summary system
- `follow-up`: this file is another hidden schema seam because it parses note text written by other Practice entry surfaces

Changes made in this pass:
- fixed `parseComfortValue(from:)` so it accepts both `comfort x/5` and `competency x/5`; before this change, mechanics summaries failed to parse values from notes the app itself was saving

### `PracticeStorePersistence.swift`

Status: `reviewed`

Responsibility summary:
- loads persisted Practice state from defaults, normalizes imported-league timestamps on decode, and saves canonical state back through `PracticeStateCodec`

Line map:
- `3-34`: loaded-state shell and defaults loader
- `36-91`: imported-league timestamp normalization
- `94-150`: async load/apply/save persistence helpers

Primary interactions:
- `practice/PracticeModels.swift`
- `practice/PracticeStateCodec.swift`
- `practice/PracticeStore.swift`
- `practice/PracticeStoreLeagueHelpers.swift`

Findings:
- no dead code found
- `follow-up`: imported-league timestamp normalization is duplicated conceptually with `PracticeStoreLeagueHelpers.leagueEventTimestamp(for:)`, so future cleanup should avoid silent divergence between import and decode paths
- `follow-up`: decode-time normalization silently marks `requiresCanonicalSave`, which is healthy migration behavior but also makes old imported timestamps self-heal without any explicit user-visible signal

Changes made in this pass:
- none

### `PracticeTimePopoverField.swift`

Status: `reviewed`

Responsibility summary:
- renders a compact popover-backed `hh:mm:ss` duration field with a finite wheel-picker editor

Line map:
- `3-89`: field UI, formatting, and binding behavior
- `91-115`: finite wheel picker

Primary interactions:
- `practice/PracticeQuickEntrySheet.swift`
- `practice/PracticeGameEntrySheets.swift`

Findings:
- no dead code found
- healthy small seam overall
- `follow-up`: the hours picker uses an upper bound of `24`, so users can currently compose durations up to `24:59:59`

Changes made in this pass:
- none

## Pass 013 summary

Safe cleanup changes made:
- removed dead `LeagueImportResult.sourcePath` from `PracticeStore.swift` and the dead initializer wiring in `PracticeStoreLeagueOps.swift`
- removed dead journal helper APIs from `PracticeStoreJournalHelpers.swift`
- removed dead `updateSyncSettings(cloudSyncEnabled:)` from `PracticeStoreEntryMutations.swift`
- removed dead duplicate icon/summary helpers from `PracticeScreenActions.swift` and removed dead `cloudSyncEnabled` UI state from `PracticeScreenState.swift`
- fixed the real mechanics-note parsing bug in `PracticeStoreMechanicsHelpers.swift` so stored `competency x/5` notes now parse correctly

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. replace timestamp-and-field journal reconciliation heuristics with stable entry identity so edit/delete flows cannot silently target the wrong underlying arrays
2. make imported-league summary rows explicit journal metadata instead of relying on literal note text like `"league import"` and `"Imported from LPL stats CSV"`
3. unify imported-league timestamp normalization so import-time and decode-time canonicalization do not drift from each other
4. decide whether Library source preference should keep sharing the same literal defaults key across Library, quick-entry, and Practice store loading
5. consider separating league parsing/matching from recovery-note and summary-writing logic inside `PracticeStoreLeagueHelpers.swift`

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeTypes.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeVideoComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeVideoLoggingHelpers.swift`
- `Pinball App 2/Pinball App 2/practice/ResolvedLeagueMachineMappings.swift`
- `Pinball App 2/Pinball App 2/practice/ResolvedLeagueTargets.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreConfirmationSheet.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreOCRService.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreParsingService.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerCameraTestView.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerModels.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerView.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerViewModel.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreStabilityService.swift`

## Pass 016: standings, stats, targets, and shared UI primitives

### `StandingsScreen.swift`

Status: `reviewed`

Responsibility summary:
- renders the season standings screen, loads hosted standings CSV data through cache, and projects ranked bank totals into a horizontally scalable table

Line map:
- `11-109`: root screen shell, width scaling, toolbar/season selector, refresh row, and load lifecycle
- `111-227`: toolbar summary, refresh/filter controls, and table header
- `230-291`: row rendering, podium coloring, and privacy-aware player-name display
- `293-419`: standings view model, refresh flow, and remote-update indicator
- `421-507`: standings models, CSV loader, parse errors, and rounded-number formatting

Primary interactions:
- `data/PinballDataCache.swift`
- `ui/AppFilterControls.swift`
- `ui/SharedTableUi.swift`
- `settings/SettingsHomeSections.swift`
- league preview refresh notification path via `notifyLeaguePreviewNeedsRefresh()`

Findings:
- dead code found and removed: `Standing.displayPlayer` was unused
- `follow-up`: rank ordering is all-or-nothing. If any row in a season is missing `rank`, `standings` ignores every CSV rank and falls back to sorting only by `seasonTotal`
- `follow-up`: `displayLPLPlayerName(_:)` still uses the `_ = showFullLPLLastNames` invalidation trick, which keeps the privacy toggle reactive but remains a hidden dependency seam

Changes made in this pass:
- removed dead `Standing.displayPlayer`

### `StatsScreen.swift`

Status: `reviewed`

Responsibility summary:
- renders the filterable league stats screen, adapts between split and stacked layouts, loads the hosted stats CSV, and computes scoped machine/bank stats in memory

Line map:
- `11-195`: root screen shell, adaptive layout, and initial load
- `197-315`: filter controls and toolbar filter menu
- `317-453`: stats table, refresh row, height measurement helper, and local formatting helpers
- `469-644`: table row rendering and machine-stats panel/table
- `646-928`: stats view model, filter reconciliation, refresh flow, and stat computation
- `930-1046`: row/stat models, CSV loader, and score/points formatting

Primary interactions:
- `data/PinballDataCache.swift`
- `ui/AppFilterControls.swift`
- `ui/SharedTableUi.swift`
- `settings/SettingsHomeSections.swift`

Findings:
- no dead code found
- `follow-up`: filter reconciliation silently clears other filters. Changing season, player, or bank can reset player, bank, or machine inside `reconcile*Selections()` with no explicit UI explanation
- `follow-up`: `CSVScoreLoader.parse` returns `[]` when required columns are missing instead of surfacing a schema error, so malformed stats CSVs can collapse into a blank table without a parse-specific message
- `follow-up`: privacy-name formatting is duplicated twice here and both call sites still depend on the `_ = showFullLPLLastNames` invalidation trick

Changes made in this pass:
- none

### `TargetsScreen.swift`

Status: `reviewed`

Responsibility summary:
- renders the LPL benchmark targets screen, loads resolved league targets when available, falls back to bundled targets, and supports sort/bank filtering with responsive table sizing

Line map:
- `11-130`: root screen shell, table sizing, and initial load
- `132-250`: explanatory header, toolbar filter menu, and dropdown controls
- `252-316`: table host, footer copy, and height resolution
- `318-408`: row/header rendering and sort-mode definition
- `410-549`: targets view model, resolved-target loading, fallback behavior, sorting, and bank filtering
- `551-610`: bundled fallback target dataset and number formatting

Primary interactions:
- `data/PinballDataCache.swift`
- `practice/PracticeStore.swift`
- `practice/ResolvedLeagueTargets.swift`
- `ui/AppFilterControls.swift`
- `ui/SharedTableUi.swift`

Findings:
- no dead code found after cleanup
- `follow-up`: missing or empty resolved-target data falls back to bundled targets with `errorMessage = nil`, so stale fallback benchmarks can present as a successful load with no freshness signal
- `follow-up`: `LPLTarget.rows` is a second embedded target dataset, so bundled fallback numbers can drift quietly from resolved league-target content over time
- `follow-up`: default `.location` sorting loses most of its meaning in fallback mode because bundled rows have no `areaOrder`, `group`, or `position`

Changes made in this pass:
- collapsed duplicate `sortDropdown` and `bankDropdown` branches that returned identical views in both navigation modes

### `SharedFullscreenChrome.swift`

Status: `reviewed`

Responsibility summary:
- provides the shared fullscreen stage container, transient fullscreen-chrome controller, and reusable fullscreen back-button/status-overlay components

Line map:
- `4-25`: fullscreen stage container
- `27-103`: chrome visibility controller and auto-hide timer logic
- `105-123`: fullscreen back button
- `126-157`: centered fullscreen status overlay

Primary interactions:
- `library/PlayfieldScreen.swift`
- `library/RulesheetScreen.swift`
- `practice/ScoreScannerView.swift`
- `practice/ScoreScannerCameraTestView.swift`
- `gameroom/GameRoomPresentationComponents.swift`

Findings:
- no dead code found
- `follow-up`: fullscreen chrome timing is stateful here, so callers have to keep pairing `resetOnAppear()` and `cleanupOnDisappear()` correctly if they reuse the controller across fullscreen surfaces

Changes made in this pass:
- none

### `SharedGestures.swift`

Status: `reviewed`

Responsibility summary:
- defines the shared edge-back gesture enabler and custom shake-motion detection/modifier used across app-level shake and fullscreen navigation surfaces

Line map:
- `6-13`: shake tuning constants
- `15-44`: interactive-pop enabler bridge
- `46-114`: shake observer and motion processing
- `116-149`: shake modifier and `View` extensions

Primary interactions:
- `app/ContentView.swift`
- `library/LibraryDetailScreen.swift`
- `library/PlayfieldScreen.swift`
- `library/RulesheetScreen.swift`
- `practice/PracticeGameSection.swift`
- `gameroom/GameRoomMachineView.swift`

Findings:
- no dead code found
- `follow-up`: `AppInteractivePopEnabler` forcibly sets `interactivePopGestureRecognizer.delegate = nil` on update/layout, which is a hidden navigation contract that will override any future custom delegate owner
- `follow-up`: shake detection samples `CMMotionManager` on the main queue at 30 Hz with hard-coded thresholds, so tuning and power/perf behavior are centralized here rather than obvious at the call sites

Changes made in this pass:
- none

### `SharedTableUi.swift`

Status: `reviewed`

Responsibility summary:
- houses the shared table/header/divider primitives, inline and panel status cards, simple metric grids, and the UIKit-backed clear-text field bridge used across the app

Line map:
- `4-53`: table layout helpers, divider styles, and header cell
- `55-130`: section title, card text, and metric grid primitives
- `133-235`: inline status messaging plus panel status/empty cards
- `237-304`: clear-text-field public surface and enum configuration
- `306-418`: `UITextField` bridge, configuration, and delegate wiring

Primary interactions:
- `library/LibraryListScreen.swift`
- `settings/SettingsHomeSections.swift`
- `settings/SettingsImportScreens.swift`
- `practice/PracticeGameSearchSheet.swift`
- `practice/PracticeIFPAProfileScreen.swift`
- `gameroom/GameRoomHomeComponents.swift`
- `gameroom/GameRoomSettingsComponents.swift`

Findings:
- no dead code found
- healthy shared primitive seam overall
- `follow-up`: `AppMetricItem.id = label` assumes labels stay unique within a grid, so duplicate labels would collide silently if this primitive gets reused more generically
- `follow-up`: `AppNativeClearTextFieldBridge.textFieldShouldReturn` delegates submit behavior entirely to callers and does not explicitly resign first responder, so keyboard-dismiss semantics are a hidden caller contract

Changes made in this pass:
- none

## Pass 016 summary

Safe cleanup changes made:
- removed dead `Standing.displayPlayer` from `StandingsScreen.swift`
- collapsed duplicate navigation/non-navigation dropdown branches in `TargetsScreen.swift`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. replace the duplicated `_ = showFullLPLLastNames` invalidation trick with a more explicit privacy-display dependency in standings and stats surfaces
2. decide whether partial ranking data in `StandingsScreen.swift` should really discard all CSV rank ordering instead of surfacing a degraded-data state
3. make `CSVScoreLoader.parse` report schema failures explicitly so malformed stats CSVs do not silently render as an empty table
4. make bundled-target fallback state explicit in `TargetsScreen.swift` so missing resolved targets do not look like a clean fresh load
5. audit `AppInteractivePopEnabler` before adding any custom interactive-pop delegate logic elsewhere in the app

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogLoader.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogSearchSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomHomeComponents.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomModels.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideImport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPresentationComponents.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomScreen.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStateCodec.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`

### `GameRoomCatalogLoader.swift`

Status: `reviewed`

Responsibility summary:
- loads the GameRoom machine catalog, normalizes grouped and variant machine identities, resolves slug imports, and builds fallback image candidate lists for owned machines

Line map:
- `4-24`: GameRoom catalog models
- `26-63`: loader lifecycle and reload entry points
- `65-181`: catalog lookup, variant resolution, slug lookup, and OPDB normalization for owned machines
- `188-240`: image candidate resolution
- `246-end`: catalog mapping, dedupe, variant/slug normalization, and helper utilities

Primary interactions:
- `gameroom/GameRoomScreen.swift`
- `gameroom/GameRoomHomeComponents.swift`
- `gameroom/GameRoomMachineView.swift`
- `gameroom/GameRoomSettingsComponents.swift`
- `gameroom/GameRoomStore.swift`

Findings:
- removed dead `gameRoomCatalogMatchesSearch(...)`
- removed unused manufacturer preload state and `loadManufacturers()` path; no GameRoom caller was reading `manufacturerOptions`, so that dead dependency could surface a catalog error even when the actual machine catalog loaded successfully
- `follow-up`: `variantOptionsByNormalizedCatalogGameID` silently overwrites later entries when multiple raw catalog IDs normalize to the same key
- `follow-up`: `slugMatches(from:)` is first-wins for every generated slug key, so later collisions are dropped silently
- `follow-up`: `dedupedGames(from:)` plus `preferredGame(in:)` is a major hidden contract: add/search surfaces only expose one preferred machine per catalog group, and that preference currently chooses earliest year before variant preference or image quality

Changes made in this pass:
- removed dead `gameRoomCatalogMatchesSearch(...)`
- removed unused manufacturer preload state and `loadManufacturers()` from `GameRoomCatalogLoader`

### `GameRoomCatalogSearchSupport.swift`

Status: `reviewed`

Responsibility summary:
- provides the shared tokenized search index, manufacturer suggestion helper, and machine-type filtering used by GameRoom add-machine flows

Line map:
- `3-19`: add-machine type filter enum
- `22-28`: indexed search entry model
- `30-39`: manufacturer suggestions
- `41-64`: catalog search indexing
- `66-99`: combined filtering and type classification

Primary interactions:
- `gameroom/GameRoomSettingsComponents.swift`
- shared search helpers from `library/`

Findings:
- no dead code found
- healthy shared search seam overall
- `follow-up`: `gameRoomSearchCategory(for:)` uses `opdbDisplay` for LCD but `opdbType` for EM and SS, so machine-type classification is asymmetric and hidden here rather than obvious at the UI layer

Changes made in this pass:
- none

### `GameRoomHomeComponents.swift`

Status: `reviewed`

Responsibility summary:
- renders the GameRoom home surface, selected-machine summary card, collection layouts, list/card machine tiles, and the shared GameRoom variant pill

Line map:
- `3-24`: home layout enum and top-level view state
- `26-99`: home screen composition and selection/navigation behavior
- `101-163`: selected machine summary card
- `165-239`: collection card and layout switch
- `241-439`: card/list machine rows
- `441-end`: variant pill and badge-label inference

Primary interactions:
- `gameroom/GameRoomScreen.swift`
- `gameroom/GameRoomCatalogLoader.swift`
- `gameroom/GameRoomStore.swift`
- `gameroom/GameRoomMachineView.swift`

Findings:
- no dead code found
- `follow-up`: home selection uses a hidden two-step tap contract, where the first tap selects a machine and only tapping the already-selected machine opens detail
- `follow-up`: the "Current Snapshot" metric grid is duplicated almost verbatim in `GameRoomMachineView.swift`, so summary drift risk is already real
- `follow-up`: `GameRoomVariantPill` truncates any longer variant label to seven characters, which is a display-only rule hidden in the shared pill itself

Changes made in this pass:
- none

### `GameRoomMachineView.swift`

Status: `reviewed`

Responsibility summary:
- owns the per-machine GameRoom detail surface, including summary, service/input sheets, media preview/edit flows, and embedded event log browsing

Line map:
- `3-60`: machine-local enums and view state
- `61-431`: main screen composition, sheet routing, media preview, and destructive actions
- `433-513`: summary section and recent media strip
- `515-610`: input section and button-to-sheet mapping
- `612-647`: attachment/event linking helpers
- `649-end`: embedded log section and selected log detail flow

Primary interactions:
- `gameroom/GameRoomStore.swift`
- `gameroom/GameRoomCatalogLoader.swift`
- `gameroom/GameRoomPresentationComponents.swift`
- `ui/SharedFullscreenChrome.swift`
- `ui/SharedGestures.swift`

Findings:
- no dead code found
- growth hotspot at 700+ lines with routing, event semantics, media behavior, and log presentation all mixed together
- `follow-up`: summary media silently caps at the most recent 12 attachments
- `follow-up`: the embedded log silently caps at 40 events and has no affordance to reach older history
- `follow-up`: media log rows open the attachment directly instead of selecting the log row, so the selected-log-detail interaction model changes based on event type

Changes made in this pass:
- none

### `GameRoomModels.swift`

Status: `reviewed`

Responsibility summary:
- defines the full persisted GameRoom domain schema: machine ownership, events, issues, attachments, reminder configs, import records, and top-level persisted state

Line map:
- `3-154`: GameRoom enums and persisted value domains
- `156-322`: area and owned-machine schema
- `324-347`: snapshot schema
- `349-519`: event, issue, attachment, and reminder config schema
- `521-end`: import record and top-level persisted state schema

Primary interactions:
- `gameroom/GameRoomStore.swift`
- `gameroom/GameRoomPresentationComponents.swift`
- `gameroom/GameRoomSettingsComponents.swift`
- `gameroom/GameRoomMachineView.swift`

Findings:
- no dead code safely removed because this file is the persistence/schema seam
- `follow-up`: several schema fields and enum cases are currently dormant from reachable UI flows: `purchasePrice`, `manufactureDate`, `thumbnailURI`, `MachineIssueStatus.monitoring`, `MachineIssueStatus.deferred`, `MachineEventType.ballsCleaned`, `MachineEventType.rubbersReplaced`, `MachineEventType.flipperServiced`, `MachineEventType.modRemoved`, and `MachineEventCategory.inspection`
- `follow-up`: `soldOrTradedDate` is modeled and shown in archive metadata, but current GameRoom mutation paths never stamp it
- `follow-up`: permissive decode defaults keep old or malformed saved data loading, but they also hide schema drift because missing data silently self-heals

Changes made in this pass:
- none

### `GameRoomPinsideImport.swift`

Status: `reviewed`

Responsibility summary:
- fetches and parses public Pinside collections, normalizes imported machine titles and variants, applies bundled slug/title corrections, and returns import-ready machine rows

Line map:
- `3-63`: title and variant normalization helpers
- `65-107`: imported machine model and public error domain
- `109-204`: import service, URL construction, HTML fetch, and page validation
- `214-360`: direct HTML parsing and Jina-based detailed parsing
- `363-442`: bundled group map loading and machine merge logic
- `445-end`: slug/title/date normalization helpers

Primary interactions:
- `gameroom/GameRoomSettingsComponents.swift`
- `SharedAppSupport/pinside_group_map.json`

Findings:
- no dead code found
- `follow-up`: import robustness depends on brittle HTML regexes plus the external `r.jina.ai` fallback path, so upstream markup or proxy changes can break matching unexpectedly
- `follow-up`: `loadGroupMap()` silently falls back to an empty map when the bundled JSON is missing or invalid, which degrades title quality without surfacing configuration drift
- `follow-up`: month/date normalization logic is duplicated again in the import review UI instead of being shared from this service

Changes made in this pass:
- none

### `GameRoomPresentationComponents.swift`

Status: `reviewed`

Responsibility summary:
- contains the GameRoom entry sheets, media import/edit surfaces, thumbnail and preview components, log detail card, and GameRoom-specific presentation helpers

Line map:
- `7-116`: service and play-count sheets
- `118-355`: issue logging sheet and issue media import/storage helpers
- `357-484`: issue resolution and ownership update sheets
- `486-695`: generic media entry sheet and duplicate media import/storage helpers
- `697-870`: transferable, thumbnail tiles, and media preview sheet
- `872-1042`: media edit sheet and log detail card
- `1044-end`: display-title helpers, sheet-style helpers, and event edit sheet

Primary interactions:
- `gameroom/GameRoomMachineView.swift`
- `ui/AppToolbarActions.swift`
- `ui/AppPresentationChrome.swift`
- `ui/AppTheme.swift`

Findings:
- no dead code found
- growth hotspot at 1100+ lines with repeated form, import, preview, and edit responsibilities
- `follow-up`: `GameRoomLogIssueSheet` and `GameRoomMediaEntrySheet` duplicate the same local photo/video import and `GameRoomMedia` storage logic
- `follow-up`: `GameRoomAttachmentPreviewSheet` constructs `AVPlayer(url:)` inside `body`, so playback state resets on view re-render
- `follow-up`: `gameRoomEntrySheetStyle()` and `gameRoomMediaSheetStyle()` are currently separate naming seams with identical behavior, which is fine for now but easy to let drift accidentally later

Changes made in this pass:
- none

### `GameRoomScreen.swift`

Status: `reviewed`

Responsibility summary:
- defines the top-level GameRoom navigation shell, owns the GameRoom store/catalog loader lifetimes, and boots data loading plus owned-machine OPDB migration

Line map:
- `3-26`: GameRoom navigation and settings enums
- `28-75`: top-level navigation shell and bootstrap task
- `77-end`: machine-view navigation helper

Primary interactions:
- `gameroom/GameRoomHomeComponents.swift`
- `gameroom/GameRoomSettingsComponents.swift`
- `gameroom/GameRoomMachineView.swift`
- `gameroom/GameRoomStore.swift`
- `gameroom/GameRoomCatalogLoader.swift`

Findings:
- no dead code found after cleanup
- `follow-up`: bootstrap still couples store load, catalog load, and OPDB migration to the screen `.task`, so data normalization runs from view presentation instead of a deeper lifecycle owner

Changes made in this pass:
- removed unused `PhotosUI`, `AVKit`, `UniformTypeIdentifiers`, and `UIKit` imports

### `GameRoomSettingsComponents.swift`

Status: `reviewed`

Responsibility summary:
- houses the full GameRoom settings workspace: section shell, Pinside import review, add/edit machine flows, venue and area editing, archive browsing, adaptive popover placement, and save-feedback overlay

Line map:
- `3-99`: settings shell and section routing
- `101-647`: Pinside import fetch, review, scoring, duplicate detection, and import commit flow
- `649-1343`: venue naming, add-machine search, area management, machine editing, variant selection, and archive filtering
- `1345-1460`: adaptive popover placement helper and viewport math
- `1462-end`: archive surface and floating save-feedback overlay

Primary interactions:
- `gameroom/GameRoomScreen.swift`
- `gameroom/GameRoomCatalogLoader.swift`
- `gameroom/GameRoomCatalogSearchSupport.swift`
- `gameroom/GameRoomPinsideImport.swift`
- `gameroom/GameRoomStore.swift`
- `gameroom/GameRoomMachineView.swift`

Findings:
- no dead code found
- major growth hotspot at 1600+ lines mixing settings shell, importer, search/indexing, edit forms, archive presentation, UIKit popover geometry, and transient feedback animation
- `follow-up`: import review re-implements `normalizedFirstOfMonth` locally, so purchase-date parsing rules can drift from `GameRoomPinsideImportService`
- `follow-up`: archive metadata reads `soldOrTradedDate`, but current edit/store write paths never stamp or clear that field
- `follow-up`: `GameRoomAdaptivePopoverModifier` depends on global `UIApplication` window geometry and safe-area math, so variant-picker behavior is coupled to UIKit/window assumptions rather than the SwiftUI call site

Changes made in this pass:
- none

### `GameRoomStateCodec.swift`

Status: `reviewed`

Responsibility summary:
- defines the canonical GameRoom JSON encoder/decoder settings and the load-from-defaults bridge for current and legacy storage keys

Line map:
- `3-14`: canonical encoder/decoder factories
- `16-25`: defaults loading and legacy key fallback

Primary interactions:
- `gameroom/GameRoomStore.swift`
- `UserDefaults`

Findings:
- no dead code found
- `follow-up`: `loadFromDefaults(...)` uses `try?` and returns `nil` on any decode failure, so corrupted or schema-broken saved state is treated the same as "no saved state" and the store silently resets to empty

Changes made in this pass:
- none

### `GameRoomStore.swift`

Status: `reviewed`

Responsibility summary:
- owns persisted GameRoom state, all GameRoom mutations, derived machine snapshots, due-task calculations, import dedupe checks, and the global save/recompute notification path

Line map:
- `5-40`: store bootstrap, save, and active/archive slices
- `42-166`: machine CRUD and event CRUD
- `221-346`: issue, attachment, area, and venue mutations
- `354-454`: import dedupe, import commit, and OPDB migration
- `457-end`: sort order, derived snapshots, reminder logic, save pipeline, and normalization helpers

Primary interactions:
- `gameroom/GameRoomScreen.swift`
- `gameroom/GameRoomHomeComponents.swift`
- `gameroom/GameRoomMachineView.swift`
- `gameroom/GameRoomSettingsComponents.swift`
- `gameroom/GameRoomStateCodec.swift`
- shared library-source notification plumbing

Findings:
- no dead code found
- `follow-up`: play-count and reminder logic depends on hidden store contracts: only `.custom` + `.custom` events with `playCountAtEvent` contribute to current plays, and date-based reminder configs with no history are considered immediately due
- `follow-up`: `effectiveReminderConfigs(for:)` injects implicit default reminder configs when none are stored, so due-task behavior depends on hidden defaults rather than persisted user state
- `follow-up`: every mutation funnels through `saveAndRecompute()`, which also calls `postPinballLibrarySourcesDidChange()`, making GameRoom a global library-source side-effect seam
- `follow-up`: `updateMachine(...)` can move a machine into `.sold` or `.traded`, but never stamps `soldOrTradedDate`, so archive metadata is structurally supported but functionally unwired

Changes made in this pass:
- none

## Pass 017 summary

Safe cleanup changes made:
- removed dead `gameRoomCatalogMatchesSearch(...)` from `GameRoomCatalogLoader.swift`
- removed unused manufacturer preload state and `loadManufacturers()` from `GameRoomCatalogLoader.swift`
- removed unused framework imports from `GameRoomScreen.swift`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. decide whether GameRoom should keep implicit default reminder configs or persist explicit reminder state so due-task behavior is not hidden inside `GameRoomStore.swift`
2. unify Pinside purchase-date normalization so `GameRoomPinsideImport.swift` and `GameRoomSettingsComponents.swift` cannot drift
3. define sold/traded/archive lifecycle behavior, including whether `soldOrTradedDate` should be stamped automatically when status changes
4. decide whether silent caps in `GameRoomMachineView.swift` for media (`12`) and log entries (`40`) are intentional enough to keep hidden
5. guard `GameRoomStateCodec.loadFromDefaults(...)` against silent state reset on decode failure
6. review whether GameRoom catalog dedupe should prefer earliest-year entries or a variant/image-first representative for parity with future Android behavior

Next files queued:
- `Pinball App 2/Pinball App 2/SharedAppSupport/pinside_group_map.json`
- `Pinball App 2/Pinball App 2/SharedAppSupport/app-intro/*.webp`
- `Pinball App 2/Pinball App 2/SharedAppSupport/shake-warnings/*.webp`
- `Pinball App 2/Pinball App 2/PinballPreload.bundle/preload-manifest.json`

### `SharedAppSupport/pinside_group_map.json`

Status: `reviewed`

Responsibility summary:
- provides the bundled slug-to-title correction map used during GameRoom Pinside import when direct collection parsing only yields slugs

Line map:
- `1`: root object start
- `2-338`: slug override entries
- `339`: object end

Primary interactions:
- `gameroom/GameRoomPinsideImport.swift`
- built app bundle root fallback and `SharedAppSupport/` source tree

Findings:
- no dead entries safely removed in this pass
- hidden data contract: the value `"~"` is a sentinel meaning "do not override, fall back to slug humanization", but that convention lives only in `resolvedTitle(for:groupMap:)` rather than in the JSON itself
- this is a hand-curated import quality seam, not just static data; mismapped or stale slugs will directly change import suggestions and duplicate-detection behavior
- bundle packaging currently flattens this file into the app bundle root, and the loader intentionally supports both root lookup and `SharedAppSupport/` source-tree lookup

Changes made in this pass:
- none

### `SharedAppSupport/app-intro/*.webp`

Status: `reviewed`

Responsibility summary:
- bundled intro-overlay artwork for the welcome deck, per-surface screenshots, and the professor spotlight avatar

Asset inventory:
- `launch-logo.webp`: welcome artwork, `2046x2046`
- `league-screenshot.webp`: intro screenshot, `1206x1809`
- `library-screenshot.webp`: intro screenshot, `1206x1809`
- `practice-screenshot.webp`: intro screenshot, `1206x1809`
- `gameroom-screenshot.webp`: intro screenshot, `1206x1809`
- `settings-screenshot.webp`: intro screenshot, `1206x1809`
- `professor-headshot.webp`: spotlight portrait, `512x512`

Primary interactions:
- `app/AppIntroOverlay.swift`
- `app/ContentView.swift`
- `settings/SettingsScreen.swift`

Findings:
- no unused intro assets found; all seven files are live
- hidden contract: `AppIntroCard.bundledArtworkFileName` and `artworkAspectRatio` hard-code both the filenames and the expected geometry, so replacing art with different aspect ratios will change layout behavior without any code diff
- hidden packaging contract: these assets are currently copied into the built app bundle root, and `AppIntroBundledArtProvider` supports both root lookup and `SharedAppSupport/app-intro` fallback
- `follow-up`: intro art is synchronously loaded from disk via `Data(contentsOf:)` and decoded with `UIImage(data:)` on first use; the in-memory cache avoids repeated work, but first presentation still pays a main-thread decode path

Changes made in this pass:
- none

### `SharedAppSupport/shake-warnings/*.webp`

Status: `reviewed`

Responsibility summary:
- bundled warning art for the professor shake/danger overlay states

Asset inventory:
- `professor-danger_1024.webp`: warning artwork, `1024x1024`
- `professor-danger-danger_1024.webp`: double-danger artwork, `1024x1024`
- `professor-tilt_1024.webp`: tilt artwork, `1024x1024`

Primary interactions:
- `app/AppShakeCoordinator.swift`
- shared bundle resource packaging

Findings:
- no unused shake-warning assets found; all three files are live
- hidden contract: warning level enums and filenames are tightly coupled in `AppShakeWarningLevel.bundledArtFileName`, so any rename becomes a runtime asset miss
- hidden packaging contract: like intro art, these files currently ship flattened at the app bundle root, with a secondary fallback to `SharedAppSupport/shake-warnings`
- `follow-up`: shake artwork is also loaded synchronously on demand, so large image replacement would directly affect first-warning presentation latency

Changes made in this pass:
- none

### `PinballPreload.bundle/preload-manifest.json`

Status: `reviewed`

Responsibility summary:
- declares the bundled preload resource list that `PinballDataCache` seeds into the on-device cache before remote refresh

Line map:
- `2`: preload schema version
- `3`: manifest generation timestamp (`2026-03-26T21:27:47Z`)
- `4-26`: bundled preload paths

Primary interactions:
- `data/PinballDataCache.swift`
- `PinballPreload.bundle/pinball/**`

Bundled payload coverage verified in this pass:
- `14` `data/` files
- `1` `rulesheets/` file
- `1` `gameinfo/` file
- `5` `images/` files
- bundle size on disk: about `8.6 MB`

Findings:
- no path drift found; every manifest path currently matches a real file in `PinballPreload.bundle/pinball/**`
- hidden contract: `seedBundledPreloadIntoCacheIfNeeded()` only consumes `paths`; `schemaVersion` and `generatedAt` are decoded but not used to gate or validate preload seeding today
- hidden failure mode: if any manifest-listed file is missing, preload seeding throws during `ensureLoaded()`, so manifest and bundle contents must stay perfectly in sync
- hidden freshness contract: the preload bundle is only a bootstrap subset, not a full offline mirror, but nothing in the manifest itself explains that scope

Changes made in this pass:
- none

## Pass 018 summary

Safe cleanup changes made:
- none

Verification:
- no additional build run; this pass was read-only apart from the review log, and the last code-affecting pass already built successfully

Open follow-up items from this pass:
1. document the `pinside_group_map.json` `"~"` sentinel explicitly somewhere near the source data or import code so future edits do not treat it like a literal title
2. decide whether app-intro and shake-warning art should keep relying on synchronous first-load decode paths
3. consider whether root-bundle resource flattening is intentional enough to document, since the loaders explicitly support both flattened and subdirectory packaging modes
4. decide whether `preload-manifest.json` should actively validate `schemaVersion` or use `generatedAt` for preload freshness/debugging
5. decide whether the preload manifest should describe its bootstrap-only scope so future parity work does not mistake it for a complete offline dataset

Next files queued:
- `Pinball App 2/Pinball App 2/Assets.xcassets/**`
- `Pinball App 2/Pinball App 2.xcodeproj/project.pbxproj`
- `Pinball App 2/Pinball App 2.xcodeproj/xcshareddata/xcschemes/**`

### `Assets.xcassets/Contents.json`

Status: `reviewed`

Responsibility summary:
- top-level asset catalog metadata for the iOS app asset namespace

Line map:
- `1-6`: catalog metadata

Primary interactions:
- Xcode asset catalog compilation
- `project.pbxproj`

Findings:
- no dead asset-catalog root metadata found
- healthy minimal root catalog

Changes made in this pass:
- none

### `Assets.xcassets/AccentColor.colorset/Contents.json`

Status: `reviewed`

Responsibility summary:
- defines the project-wide accent asset color used by the Xcode build setting `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`

Line map:
- `2-15`: universal sRGB accent color
- `16-20`: metadata

Primary interactions:
- `Pinball App 2.xcodeproj/project.pbxproj`
- system accent surfaces generated from the asset catalog

Findings:
- no dead color asset found
- hidden contract: this accent color affects the project-level asset setting, but most runtime UI branding comes from `ui/AppTheme.swift`, so changing `AccentColor` will not restyle the app the way a teammate might assume

Changes made in this pass:
- none

### `Assets.xcassets/LaunchBackground.colorset/Contents.json`

Status: `reviewed`

Responsibility summary:
- provides the generated launch-screen background color asset

Line map:
- `2-15`: universal sRGB launch background color
- `16-20`: metadata

Primary interactions:
- `Pinball App 2.xcodeproj/project.pbxproj`
- generated launch screen (`INFOPLIST_KEY_UILaunchScreen_UIColorName`)

Findings:
- no dead launch background asset found
- this asset is only tied to the generated launch screen, not the runtime app shell, so launch styling and in-app styling already have separate sources of truth

Changes made in this pass:
- none

### `Assets.xcassets/AppIcon.appiconset/Contents.json`

Status: `reviewed`

Responsibility summary:
- declares the primary, dark, and tinted app icon variants for iOS asset compilation

Line map:
- `2-32`: icon variant declarations
- `34-38`: metadata

Asset inventory:
- `AppIcon-1024.png`: `1024x1024`
- `AppIcon-1024-dark.png`: `1024x1024`
- `AppIcon-1024-tinted.png`: `1024x1024`

Primary interactions:
- `Pinball App 2.xcodeproj/project.pbxproj`
- iOS app icon compilation

Findings:
- no unused app icon variants found; all three are declared in the asset metadata
- hidden contract: icon appearance support now lives in asset metadata, not in any Swift code path, so icon regressions will bypass code review unless this asset set is reviewed directly

Changes made in this pass:
- none

### `Assets.xcassets/LaunchLogo.imageset/Contents.json`

Status: `reviewed`

Responsibility summary:
- provides the generated launch-screen logo image set in `1x`, `2x`, and `3x` PNG variants

Line map:
- `2-17`: image declarations
- `19-25`: metadata and rendering intent

Asset inventory:
- `LaunchLogo.png`: `682x682`
- `LaunchLogo@2x.png`: `1364x1364`
- `LaunchLogo@3x.png`: `2046x2046`

Primary interactions:
- `Pinball App 2.xcodeproj/project.pbxproj`
- generated launch screen (`INFOPLIST_KEY_UILaunchScreen_UIImageName`)

Findings:
- no unused launch logo scales found
- hidden duplication seam: this launch logo asset family appears to be the same branding source as `SharedAppSupport/app-intro/launch-logo.webp`, but the app now carries separate PNG and WebP pipelines for launch versus intro surfaces
- hidden contract: the launch screen uses this imageset only through generated Info.plist build settings, so there is no direct Swift call site to remind reviewers that changing launch art requires updating the asset catalog rather than `SharedAppSupport`

Changes made in this pass:
- none

### `Pinball App 2.xcodeproj/project.pbxproj`

Status: `reviewed`

Responsibility summary:
- defines the app and test targets, project-wide build settings, generated Info.plist keys, launch-screen asset wiring, and the Xcode filesystem-synchronized project structure

Line map:
- `1-35`: project headers and filesystem-synchronized root groups
- `37-121`: app/test target definitions and build phases
- `123-200`: project object and target dependency wiring
- `202-323`: project-level debug/release defaults
- `326-410`: app target debug/release settings
- `413-end`: test target settings and configuration lists

Primary interactions:
- `Assets.xcassets/**`
- `Pinball App 2/`
- `Pinball App 2Tests/`
- Xcode build system and generated Info.plist

Findings:
- no dead project configuration blocks found
- major hidden build-system contract: the project uses `PBXFileSystemSynchronizedRootGroup`, so source and resource inclusion is driven by on-disk folders while the sources/resources build phases stay visually empty in the pbxproj
- hidden configuration contract: launch screen, privacy strings, bundle display name, app icon, and accent color are all generated from build settings instead of a checked-in Info.plist
- `follow-up`: `ENABLE_PREVIEWS = YES` is enabled for both Debug and Release app configurations, which may be intentional but is not obvious without reading the project file
- `follow-up`: project-wide runtime assumptions such as `IPHONEOS_DEPLOYMENT_TARGET = 26.2`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` live here rather than near feature code

Changes made in this pass:
- none

### `Pinball App 2.xcodeproj/project.xcworkspace/contents.xcworkspacedata`

Status: `reviewed`

Responsibility summary:
- defines the minimal workspace shell pointing Xcode at the current project

Line map:
- `1-7`: workspace metadata and self reference

Primary interactions:
- Xcode workspace loading

Findings:
- no dead workspace metadata found
- healthy minimal workspace file

Changes made in this pass:
- none

### Local Xcode User State

Status: `context only`

Files observed:
- `Pinball App 2.xcodeproj/project.xcworkspace/xcuserdata/pillyliu.xcuserdatad/UserInterfaceState.xcuserstate`
- `Pinball App 2.xcodeproj/project.xcworkspace/xcuserdata/pillyliu.xcuserdatad/WorkspaceSettings.xcsettings`
- `Pinball App 2.xcodeproj/xcuserdata/pillyliu.xcuserdatad/xcschemes/xcschememanagement.plist`

Notes:
- these are local Xcode user-state files, not repo-tracked project artifacts in the current git view
- there are no shared scheme files under `xcshareddata/xcschemes/**` in this project
- the local `xcschememanagement.plist` still mentions `Pinball App Vision.xcscheme`, which does not appear in the project file; because this is local-only state, it is a context finding rather than a repo change target

Changes made in this pass:
- none

## Pass 019 summary

Safe cleanup changes made:
- none

Verification:
- no additional build run; this pass was read-only and project metadata findings did not change compiled code

Open follow-up items from this pass:
1. decide whether `AccentColor.colorset` should stay as-is or be documented as a system-only accent, since runtime branding mainly comes from `AppTheme.swift`
2. decide whether the duplicated launch-logo asset pipelines (`LaunchLogo.imageset` PNGs and `SharedAppSupport/app-intro/launch-logo.webp`) need a documented single source of truth
3. document the filesystem-synchronized Xcode project structure so empty build phases in `project.pbxproj` do not mislead future audits
4. confirm whether `ENABLE_PREVIEWS = YES` in Release is intentional
5. decide whether the absence of shared scheme files is fine for the team workflow or whether a shared scheme should be committed explicitly

Next files queued:
- `Pinball App 2Tests/**`
- repo-level iOS support docs that still influence the app runtime contract

### `Pinball App 2Tests/AppShakeCoordinatorTests.swift`

Status: `reviewed`

Responsibility summary:
- regression tests for shake motion constants, warning timing/art wiring, native-undo suppression, fallback escalation, and escalating haptics

Line map:
- `4-13`: motion tuning parity constants
- `15-37`: warning duration, haptic delay, and art-file-name assertions
- `39-48`: native-undo suppression path
- `50-64`: fallback escalation across repeated shakes
- `66-82`: native undo does not reset escalation progress
- `84-96`: haptic escalation sequence

Primary interactions:
- `Pinball App 2/Pinball App 2/app/AppShakeCoordinator.swift`
- `Pinball App 2/Pinball App 2/app/AppShakeCoordinator.swift` warning-level constants and resource names
- `Pinball App 2/Pinball App 2/SharedAppSupport/shake-warnings/*`

Findings:
- no dead tests found
- good parity guard: this file protects several of the hard-coded shake constants and warning-art filenames that would otherwise drift silently from Android
- coverage gap: the test target does not exercise bundled-art loading or the flattened-bundle versus `SharedAppSupport/shake-warnings` fallback lookup path, so packaging regressions would currently slip past XCTest

Changes made in this pass:
- none

### `Pinball App 2Tests/GameRoomPinsideImportTests.swift`

Status: `reviewed`

Responsibility summary:
- targeted regression coverage for canonical Pinside displayed-title normalization

Line map:
- `5-13`: anniversary variant should win over generic premium suffix
- `15-23`: normal premium variant should remain intact

Primary interactions:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideImport.swift`
- `Pinball App 2/Pinball App 2/SharedAppSupport/pinside_group_map.json`

Findings:
- no dead tests found
- real coverage gap: this file only protects two title-normalization cases even though the import path also depends on `pinside_group_map.json`, slug humanization, fallback variant inference, and multi-source scrape behavior
- hidden seam left unguarded: the `"~"` sentinel behavior in `pinside_group_map.json` still has no direct test coverage

Changes made in this pass:
- none

### `Pinball App 2Tests/PracticeQuickEntryDefaultsTests.swift`

Status: `reviewed`

Responsibility summary:
- regression coverage for quick-entry source defaults, video input defaults, rulesheet short-title labels, and merged video ordering

Line map:
- `5-16`: selected-game source should beat Avenue fallback
- `18-29`: mechanics entry should start from the all-games library filter
- `31-37`: video-entry default mode and option order
- `39-55`: rulesheet short-title labeling
- `57-113`: resolved catalog video ordering
- `115-132`: merged curated/catalog video reordering

Primary interactions:
- `Pinball App 2/Pinball App 2/practice/PracticeQuickEntryDefaults.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeVideo*` helpers
- `Pinball App 2/Pinball App 2/library/LibraryTypes.swift`

Findings:
- no dead tests found
- healthy targeted protection around quick-entry defaults and shared video ordering seams
- no direct test coverage yet for source-removal or import-refresh edge cases after an initial quick-entry source has already been persisted

Changes made in this pass:
- none

### `Pinball App 2Tests/PracticeStateCodecTests.swift`

Status: `reviewed`

Responsibility summary:
- migration-gate coverage for canonical millisecond timestamps and legacy reference-date timestamp fallback decoding

Line map:
- `5-15`: canonical `v4` millisecond fixture decode
- `17-28`: legacy reference-date fixture decode and unix-time sanity check
- `30-35`: source-tree-relative fixture loading helper

Primary interactions:
- `Pinball App 2/Pinball App 2/practice/PracticeStateCodec.swift`
- `Pinball App 2Tests/Fixtures/canonical_millis_v4.json`
- `Pinball App 2Tests/Fixtures/legacy_reference_date_v4.json`

Findings:
- no dead tests found
- this remains the key persisted-state migration gate for iOS
- hidden contract: fixture loading is tied to the source-tree layout via `#filePath`, so moving the test file or `Fixtures/` folder breaks coverage without any build-setting reminder
- follow-up: migration coverage is intentionally narrow and does not try to exercise every persisted field variant; future schema growth should keep regenerating representative fixtures rather than hand-waving compatibility

Changes made in this pass:
- none

### `Pinball App 2Tests/Fixtures/canonical_millis_v4.json`

Status: `reviewed`

Responsibility summary:
- canonical persisted-practice fixture using millisecond unix timestamps

Line map:
- `2`: schema version anchor
- `3-80`: representative persisted domains including study, video, score, journal, custom groups, sync, analytics, rulesheet/video resume, and summary notes
- `81-85`: practice settings sample

Primary interactions:
- `Pinball App 2Tests/PracticeStateCodecTests.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStateCodec.swift`

Findings:
- no dead fixture fields found
- healthy representative sample for the current `v4` millisecond strategy
- hidden limitation: the fixture intentionally covers only a small slice of the full Practice state shape, so newly added optional domains can drift unless the canonical fixture is refreshed when the schema evolves

Changes made in this pass:
- none

### `Pinball App 2Tests/Fixtures/legacy_reference_date_v4.json`

Status: `reviewed`

Responsibility summary:
- legacy persisted-practice fixture that keeps the fallback date-decoding path alive

Line map:
- `2`: schema version anchor
- `3-51`: legacy reference-date timestamps across study, score, journal, league, sync, analytics, and resume hints
- `52-55`: legacy practice settings sample

Primary interactions:
- `Pinball App 2Tests/PracticeStateCodecTests.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStateCodec.swift`

Findings:
- no dead fixture fields found
- valuable compatibility anchor for older saved data
- hidden limitation: like the canonical fixture, this one covers only a focused subset of Practice fields, so future fallback-decoding regressions outside these domains could still pass unnoticed

Changes made in this pass:
- none

### `Pinball App 2Tests/RulesheetLinkResolutionTests.swift`

Status: `reviewed`

Responsibility summary:
- regression coverage for local rulesheet-path preservation, PinProf chip labeling, and the bundled-only `Final Exam` exception

Line map:
- `5-44`: local rulesheet path should survive external-link sort order
- `46-57`: hosted PinProf resources should show `PinProf` chips
- `59-76`: bundled-only `G900001` resources should stay `Local`
- `78-99`: minimal `PinballGame` test-payload builder

Primary interactions:
- `Pinball App 2/Pinball App 2/library/RulesheetResourceResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryTypes.swift`
- `Pinball App 2/Pinball App 2/PinballPreload.bundle/pinball/**`

Findings:
- no dead tests found
- strong protection for the `PinProf: The Final Exam` bundled-only exception, which is one of the app’s easiest hidden resource-label seams to regress
- remaining gap: there is still no direct override-path test for rulesheet link resolution when explicit overrides and live hosted status interact at the same time

Changes made in this pass:
- none

### `Pinball App 2Tests/ScoreScannerServicesTests.swift`

Status: `reviewed`

Responsibility summary:
- service-level regression coverage for OCR normalization, candidate ranking, manual score formatting, stability locking, and preview-frame crop mapping

Line map:
- `5-192`: OCR parsing heuristics and manual score formatting
- `194-242`: stability service behavior and dominant-reading selection
- `244-270`: preview-to-frame crop mapping

Primary interactions:
- `Pinball App 2/Pinball App 2/practice/ScoreParsingService.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreStabilityService.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerFrameMapper.swift`

Findings:
- no dead tests found
- this is currently the strongest score-scanner regression surface in the repo; the low-level OCR/service heuristics are much better protected than the surrounding camera/view-model flow
- coverage gap: there are still no tests for `ScoreScannerViewModel` freeze, retake, throttling, or mixed queue/actor coordination, so the highest-risk scanner behavior remains largely unguarded by the test target

Changes made in this pass:
- none

### `README.md`

Status: `reviewed`

Responsibility summary:
- top-level repo contract for the current release line, shared support ownership, hosted runtime source, and release/test anchors

Line map:
- `1-8`: repo identity and platform roots
- `10-19`: current product shape and release line
- `21-33`: runtime/source-of-truth notes and shared support ownership
- `35-46`: release versioning and migration test gates

Primary interactions:
- `RELEASE_NOTES_3.4.9.md`
- `Pinball_App_Architecture_Blueprint_latest.md`
- `scripts/sync_shared_app_assets.sh`

Findings:
- no dead top-level contract notes found
- change made: clarified that `./scripts/sync_shared_app_assets.sh` refreshes the iOS launch-logo asset catalog files and Android intro drawables, not the full iOS intro-overlay image path
- hidden contract: this file is still acting as live runtime documentation, so version, hosted-source, and shared-support wording here can drift from project metadata if it is not reviewed alongside the code

Changes made in this pass:
- clarified the shared intro-asset sync note so it matches the actual script behavior

### `RELEASE_NOTES_3.4.9.md`

Status: `reviewed`

Responsibility summary:
- release-facing summary of the current product shape, hosted runtime model, shared support assets, and shipping workflow

Line map:
- `1-11`: release anchors
- `13-29`: product shape and core release state
- `31-44`: data/runtime model summary
- `46-63`: release workflow and doc pointers

Primary interactions:
- `README.md`
- `Pinball_App_Architecture_Blueprint_latest.md`
- `Pinball App 2/Pinball App 2/SharedAppSupport/*`

Findings:
- no dead release-note blocks found
- this document is more than marketing copy; it is also a live summary of the hosted runtime contract and app-owned bundled support assets
- follow-up: the iOS validation note still highlights `PracticeStateCodecTests` only, which understates the broader regression coverage now present in `Pinball App 2Tests`

Changes made in this pass:
- none

### `Pinball_App_Architecture_Blueprint_latest.md`

Status: `reviewed`

Responsibility summary:
- main architecture reference describing release scope, runtime contracts, feature inventory, data flow, testing/release gates, and parity expectations for both mobile apps

Line map:
- `1-40`: release snapshot, purpose, current product shape, and goals
- `52-167`: system overview, technology stack, runtime contracts, and source-of-truth posture
- `171-465`: C4 diagrams and shared-service structure
- `513-871`: screen and feature inventory
- `881-965`: interaction diagrams
- `969-1060`: data model, storage, and identity rules
- `1077-1169`: background behavior and navigation relationships
- `1173-1222`: testing, release, and hosted-data publication path
- `1226-1259`: platform adaptations and final architecture summary

Primary interactions:
- `README.md`
- `RELEASE_NOTES_3.4.9.md`
- `Pinball App 2/Pinball App 2/**`
- `Pinball App Android/app/src/main/**`

Findings:
- no dead major architecture sections found; this is still the repo’s most complete written runtime-contract reference
- change made: corrected stale footer release-version drift from `3.4.7` to `3.4.9`
- hidden drift: the testing section still frames iOS validation around `PracticeStateCodecTests` even though the current XCTest target now also covers shake handling, GameRoom Pinside parsing, quick-entry defaults, rulesheet resource resolution, and score-scanner services

Changes made in this pass:
- updated the final-summary release references from `3.4.7` to `3.4.9`

### `docs/ios_rulesheet_rotation_preservation.md`

Status: `reviewed`

Responsibility summary:
- deep implementation note explaining why the iOS `WKWebView` rulesheet reader preserves semantic reading position across rotation the way it does today

Line map:
- `1-35`: summary, scope, user-facing problem, and why the bug was difficult
- `37-83`: debugging findings that shaped the final fix
- `84-116`: failed and rejected approaches
- `117-198`: final restore strategy and implementation details
- `199-243`: validation expectations and unrelated console noise
- `244-261`: cleanup status and practical takeaway

Primary interactions:
- `Pinball App 2/Pinball App 2/library/RulesheetScreen.swift`
- rulesheet rotation/reflow behavior in `WKWebView`

Findings:
- no dead explanatory sections found; this doc still matters because it explains why the current `RulesheetScreen` restore machinery exists
- change made: updated the cleanup section to reflect that the temporary named debug channels from the investigation are already gone from the current codebase
- hidden contract: this doc is still effectively the only human-readable explanation for the current anchor-freeze/layout-settle generation-guard approach, so refactors to rulesheet rotation risk losing important intent if this note drifts again

Changes made in this pass:
- replaced the stale “remove debug logs later” note with current-state wording

### `scripts/sync_shared_app_assets.sh`

Status: `reviewed`

Responsibility summary:
- syncs `SharedAppSupport/app-intro/*` source assets into Android intro drawables and the iOS launch-logo asset catalog outputs

Line map:
- `1-58`: repo paths and small file/command helpers
- `60-69`: Android WebP conversion/copy path
- `71-85`: iOS PNG rendering helpers
- `87-118`: source intro-asset resolution and Android output refresh
- `120-128`: iOS `LaunchLogo.imageset` refresh and completion message

Primary interactions:
- `Pinball App 2/Pinball App 2/SharedAppSupport/app-intro/*`
- `Pinball App Android/app/src/main/res/drawable-nodpi/*`
- `Pinball App 2/Pinball App 2/Assets.xcassets/LaunchLogo.imageset/*`
- `README.md`

Findings:
- hidden scope contract: despite the broader name, this script only syncs `app-intro` assets, and on iOS it only regenerates `LaunchLogo.imageset`; the runtime intro overlay still loads bundled `SharedAppSupport/app-intro/*.webp` directly
- change made: moved the `cwebp` dependency check into the conversion branch so the script no longer hard-fails on machines where every current source asset is already `.webp`
- legacy-cleanup note: the Android output reset still deletes both historical `.png` and current `.webp` filenames before rewriting the current `.webp` outputs, which is intentional but easy to misread as an active dual-format pipeline

Changes made in this pass:
- made `cwebp` a lazy requirement instead of an unconditional startup dependency

## Pass 020 summary

Safe cleanup changes made:
- clarified `README.md` so the shared intro-asset sync note matches the actual iOS launch-logo plus Android drawable behavior
- corrected the stale `3.4.7` footer references in `Pinball_App_Architecture_Blueprint_latest.md`
- updated `docs/ios_rulesheet_rotation_preservation.md` so its cleanup note matches the current codebase
- made `scripts/sync_shared_app_assets.sh` require `cwebp` only when it actually needs to convert a non-WebP source asset

Verification:
- `bash -n '/Users/pillyliu/Documents/Codex/Pinball App/scripts/sync_shared_app_assets.sh'`
- no additional Xcode build run; this pass only changed docs plus a maintenance script and did not touch compiled app code

Open follow-up items from this pass:
1. add `AppShakeCoordinator` resource-loading tests so bundle-packaging regressions are not invisible to XCTest
2. expand `GameRoomPinsideImportTests` to cover `pinside_group_map.json` sentinel behavior, slug humanization, and other import fallbacks
3. add `ScoreScannerViewModel` freeze/retake/throttling tests to cover the mixed queue/actor scanner behavior that the service tests do not reach
4. decide whether `PracticeStateCodec` fixtures should be expanded as the schema evolves so more persisted fields are protected by migration tests
5. decide whether `RELEASE_NOTES_3.4.9.md` and `Pinball_App_Architecture_Blueprint_latest.md` should describe the broader current iOS test surface instead of highlighting only `PracticeStateCodecTests`
6. decide whether the stale `Pinball App 2Tests` target `MARKETING_VERSION = 3.0.0` in `project.pbxproj` should be normalized with the `3.4.9` release line
7. consider renaming or splitting `scripts/sync_shared_app_assets.sh` if the team wants its current app-intro-only scope to be more obvious

Next files queued:
- non-runtime repo docs under `docs/modernization/**`
- historical/local archive material under `archive/**`
- remaining maintenance scripts outside the active iOS runtime/support path

### `docs/modernization/README.md`

Status: `reviewed`

Responsibility summary:
- top-level contract for how the modernization docs are organized and how teams are supposed to use them

Line map:
- `1-5`: folder purpose and current framing
- `7-17`: document hierarchy
- `19-25`: workflow rules
- `27-33`: feature-folder inventory

Primary interactions:
- `docs/modernization/00_program_overview.md`
- `docs/modernization/01_workflow.md`
- `docs/modernization/features/**`

Findings:
- no dead top-level doc-index entries found
- this file explicitly says the modernization docs are no longer tied to the old `3.2` branch framing, which made it a useful drift detector for older feature/program docs that still used that language

Changes made in this pass:
- none

### `docs/modernization/00_program_overview.md`

Status: `reviewed`

Responsibility summary:
- program-level overview for the modernization/parity effort, including goals, product map, work order, and current phase notes

Line map:
- `3-8`: program naming and framing
- `9-38`: goals, definitions, and what the effort is or is not
- `39-63`: work order, priorities, and canonical baseline references
- `64-107`: product map and structural realities
- `108-122`: modernization work order and current phase shift

Primary interactions:
- `docs/modernization/README.md`
- `docs/modernization/04_audit_matrix.md`
- `docs/modernization/features/**`

Findings:
- change made: updated the stale `3.2 Modernization` naming block so the file now matches the newer “living modernization/parity maintenance” framing described in `README.md`
- hidden contract: this file still points teams at the historical GameRoom `3.1` source docs as the strongest written baseline, so those references still shape current cleanup decisions even though the broader program framing has moved on

Changes made in this pass:
- replaced the stale branch-era program naming block with current wording plus explicit historical references

### `docs/modernization/01_workflow.md`

Status: `reviewed`

Responsibility summary:
- defines the expected doc-first modernization workflow, change categories, and completion checks

Line map:
- `3-14`: mandatory sequence
- `15-20`: canonical implementation rule
- `21-31`: preferred task size and anti-patterns
- `32-42`: change categories
- `44-67`: parity-start, completion, and commit guidance

Primary interactions:
- `docs/modernization/features/*/{spec,parity,checklist,ledger}.md`

Findings:
- no dead workflow rules found
- this file still describes a clean doc-first discipline that matches the user’s requested review-first approach better than the current repo history often does
- hidden tension: the workflow discourages broad “cleanup,” but several other modernization docs have grown into broad append-only ledgers and audit matrices anyway

Changes made in this pass:
- none

### `docs/modernization/02_design_system.md`

Status: `reviewed`

Responsibility summary:
- shared design-system intent and a large dated progress log of cross-platform token/chrome adoption work

Line map:
- `3-39`: design intent, token families, component families, and platform-adaptation rules
- `56-82`: brand direction, near-term outputs, and current gap framing
- `84-223`: dated baseline-progress ledger across Android and iOS shared chrome adoption
- `224-229`: next design-system steps

Primary interactions:
- `Pinball App 2/Pinball App 2/ui/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/**`
- `docs/modernization/04_audit_matrix.md`

Findings:
- change made: updated the “current gap” section so it no longer contradicts the same file’s later claim that Android already has an explicit semantic token layer
- major doc growth hotspot: this file now mixes enduring design-system contract language with a very long dated implementation ledger, which makes it harder to tell current guidance from historical progress notes
- hidden contract: many cross-platform chrome decisions are documented here before they are visible anywhere else, so drift in this file can mislead future cleanup work even when the code itself is healthy

Changes made in this pass:
- refreshed the “current gap to close” wording so it matches the current token-layer reality on both platforms

### `docs/modernization/03_parity_rules.md`

Status: `reviewed`

Responsibility summary:
- high-level definition of parity, allowed differences, required docs, and drift-handling language

Line map:
- `3-13`: parity definition
- `14-29`: allowed and disallowed differences
- `30-45`: parity-checklist and canonical-source rules
- `46-65`: drift handling and completion language

Primary interactions:
- `docs/modernization/features/*/parity.md`
- `docs/modernization/features/*/ledger.md`

Findings:
- no dead parity-rule language found
- healthy concise guardrail file
- the GameRoom `3.1` reference remains intentional historical baseline context here, not stale current-state wording

Changes made in this pass:
- none

### `docs/modernization/04_audit_matrix.md`

Status: `reviewed`

Responsibility summary:
- high-level audit tracker covering feature status, shell/theme hotspots, file-level hotspots, and current work order

Line map:
- `3-13`: status vocabulary
- `14-23`: feature-summary table
- `24-33`: shell and theme hotspots
- `34-224`: large cross-platform file-level hotspot table
- `225-238`: current work order and audit-matrix maintenance notes

Primary interactions:
- `docs/modernization/00_program_overview.md`
- `docs/modernization/features/**`
- `Pinball App 2/Pinball App 2/**`
- `Pinball App Android/app/src/main/**`

Findings:
- no dead matrix sections found, but this is now a major maintenance hotspot: the file has become a very large mixed-status registry that can drift from both the codebase and the newer sequential review doc
- hidden overlap: several “in audit” or “stable” judgments here now coexist with deeper findings from the new iOS sequential review, so this matrix is better as a coarse planning map than as a precise current-health ledger
- follow-up: the current work order still reads like a modernization-program roadmap, not a true reflection of the current review-first cleanup campaign

Changes made in this pass:
- none

## Pass 021 summary

Safe cleanup changes made:
- updated `00_program_overview.md` so its name/framing block matches the newer modernization/parity-maintenance language instead of pretending the whole doc set is still branch-bound to `3.2`
- updated `02_design_system.md` so its “current gap” section matches the actual Android token-layer state documented later in the file

Verification:
- `rg -n "## 3\\.2 focus|during 3\\.2|codex/3\\.2-modernization|light custom semantic layer|Material color-scheme defaults" '/Users/pillyliu/Documents/Codex/Pinball App/docs/modernization'`
- result after the edits: only intentional historical references remained

Open follow-up items from this pass:
1. decide whether `02_design_system.md` should be split into a stable contract file plus a dated progress ledger
2. decide whether `04_audit_matrix.md` should be trimmed or regenerated from fresher review sources, because it is now large enough to drift silently
3. consider whether the modernization docs should explicitly reference the newer sequential iOS review doc so the two audit systems do not diverge

Next files queued:
- `docs/modernization/features/gameroom/*`
- `docs/modernization/features/league/*`
- `docs/modernization/features/library/*`
- `docs/modernization/features/practice/*`
- `docs/modernization/features/settings/*`

### `docs/modernization/features/gameroom/checklist.md`

Status: `reviewed`

Responsibility summary:
- concise completion checklist for GameRoom parity and modernization verification

Line map:
- `1-15`: checklist items

Primary interactions:
- `docs/modernization/features/gameroom/spec.md`
- `docs/modernization/features/gameroom/parity.md`
- `docs/modernization/features/gameroom/ledger.md`

Findings:
- no dead checklist items found
- checklist is still compact and aligned with the shipped GameRoom behavior surface

Changes made in this pass:
- none

### `docs/modernization/features/gameroom/ledger.md`

Status: `reviewed`

Responsibility summary:
- dated change ledger for GameRoom cleanup/parity work

Line map:
- `3-8`: historical branch/baseline notes
- `9-63`: dated structural, shared-chrome, and parity-cleanup log
- `65-69`: next audit targets

Primary interactions:
- `docs/modernization/features/gameroom/spec.md`
- `docs/modernization/features/gameroom/parity.md`
- `Pinball App 2/Pinball App 2/gameroom/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/**`

Findings:
- no dead historical entries found
- still useful as a dated record, but it is clearly historical/change-log oriented rather than a current-state contract

Changes made in this pass:
- none

### `docs/modernization/features/gameroom/parity.md`

Status: `reviewed`

Responsibility summary:
- declares the baseline GameRoom parity contract and allowed native differences

Line map:
- `3-5`: baseline statement
- `7-18`: must-match behaviors
- `19-24`: allowed native differences
- `26-30`: drift rule

Primary interactions:
- `docs/modernization/features/gameroom/spec.md`
- `docs/modernization/features/gameroom/ledger.md`

Findings:
- change made: replaced stale “during 3.2” wording in the drift rule with current modernization/parity-maintenance language

Changes made in this pass:
- normalized stale branch-phase wording in the drift rule

### `docs/modernization/features/gameroom/spec.md`

Status: `reviewed`

Responsibility summary:
- current GameRoom feature scope, structural baseline, and cleanup focus

Line map:
- `3-12`: status and canonical references
- `14-24`: scope summary
- `26-31`: focus area
- `33-43`: structural baseline

Primary interactions:
- `docs/modernization/features/gameroom/{parity,ledger,checklist}.md`
- `Pinball App 2/Pinball App 2/gameroom/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/**`

Findings:
- change made: replaced stale `3.2 focus` wording with `Current focus`
- change made: updated the closing baseline sentence so it refers to the current modernization phase instead of implying the doc is still bound to a `3.2` milestone

Changes made in this pass:
- normalized stale milestone wording in the active spec

### `docs/modernization/features/league/checklist.md`

Status: `reviewed`

Responsibility summary:
- concise parity checklist for League routes and nested About behavior

Line map:
- `1-8`: checklist items

Primary interactions:
- `docs/modernization/features/league/spec.md`
- `docs/modernization/features/league/parity.md`
- `docs/modernization/features/league/ledger.md`

Findings:
- no dead checklist items found
- healthy compact checklist

Changes made in this pass:
- none

### `docs/modernization/features/league/ledger.md`

Status: `reviewed`

Responsibility summary:
- dated League cleanup/parity ledger

Line map:
- `3-5`: shipped-baseline note
- `7-24`: route, preview, shared-chrome, and About-flow cleanup log
- `25-29`: next audit targets

Primary interactions:
- `docs/modernization/features/league/spec.md`
- `Pinball App 2/Pinball App 2/league/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/**`

Findings:
- no dead historical entries found
- ledger is still coherent and materially shorter than the Practice/Library ledgers, so it remains readable as a dated implementation record

Changes made in this pass:
- none

### `docs/modernization/features/league/parity.md`

Status: `reviewed`

Responsibility summary:
- minimal parity contract for League destination order and routing behavior

Line map:
- `3-8`: must-match items
- `10-13`: allowed native differences

Primary interactions:
- `docs/modernization/features/league/spec.md`

Findings:
- no dead parity rules found
- concise but very light; this file assumes the spec and ledger carry most of the real detail

Changes made in this pass:
- none

### `docs/modernization/features/league/spec.md`

Status: `reviewed`

Responsibility summary:
- League feature scope, current focus, and structural baseline across both platforms

Line map:
- `3-7`: status
- `8-15`: scope summary
- `17-24`: focus area
- `25-46`: structural baseline

Primary interactions:
- `docs/modernization/features/league/{parity,ledger,checklist}.md`
- `Pinball App 2/Pinball App 2/league/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/**`

Findings:
- change made: replaced stale `3.2 focus` wording with `Current focus`
- otherwise the written contract is still aligned with the current League structure we saw in code

Changes made in this pass:
- normalized the active focus heading

### `docs/modernization/features/library/checklist.md`

Status: `reviewed`

Responsibility summary:
- parity checklist for Library source behavior, resource fallback, V3 local asset naming, and GameRoom overlay behavior

Line map:
- `1-10`: checklist items

Primary interactions:
- `docs/modernization/features/library/spec.md`
- `docs/modernization/features/library/parity.md`
- `docs/modernization/features/library/ledger.md`

Findings:
- no dead checklist items found
- still reflects the resource-fallback and overlay seams we confirmed during code review

Changes made in this pass:
- none

### `docs/modernization/features/library/ledger.md`

Status: `reviewed`

Responsibility summary:
- dated Library modernization ledger covering CAF runtime contract shifts, seam extraction, and shared-chrome cleanup

Line map:
- `3-5`: early shared-integration note
- `7-87`: long dated cleanup/parity ledger
- `88-91`: next audit targets

Primary interactions:
- `docs/modernization/features/library/spec.md`
- `Pinball App 2/Pinball App 2/library/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/**`

Findings:
- no dead historical entries found
- major growth hotspot: this file now serves as an extensive change log and is much better at preserving implementation history than at surfacing current unresolved risks

Changes made in this pass:
- none

### `docs/modernization/features/library/parity.md`

Status: `reviewed`

Responsibility summary:
- parity contract for Library data loading, fallback behavior, GameRoom overlay integration, and CAF resource rules

Line map:
- `3-12`: must-match behaviors
- `13-18`: allowed native differences
- `19-30`: current parity baseline

Primary interactions:
- `docs/modernization/features/library/spec.md`
- `docs/modernization/features/library/ledger.md`

Findings:
- no dead parity sections found
- the file still captures the important CAF and fallback ladders accurately, but it under-describes newer secondary behavior like hosted live-status handling and fullscreen presentation chrome

Changes made in this pass:
- none

### `docs/modernization/features/library/spec.md`

Status: `reviewed`

Responsibility summary:
- current Library scope, CAF runtime contract, fallback rules, and hosted playfield behavior

Line map:
- `3-18`: status and scope summary
- `20-26`: focus area
- `27-47`: structural baseline and active CAF contract
- `48-70`: resource and hosted playfield contract

Primary interactions:
- `docs/modernization/features/library/{parity,ledger,checklist}.md`
- `Pinball App 2/Pinball App 2/library/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/**`

Findings:
- change made: replaced stale `3.2 focus` wording with `Current focus`
- the CAF contract and fallback ladders here still align well with the Library/runtime review findings

Changes made in this pass:
- normalized the active focus heading

### `docs/modernization/features/practice/checklist.md`

Status: `reviewed`

Responsibility summary:
- detailed parity checklist for Practice routes, route-vs-sheet modeling, workspace behavior, and cross-platform feature coverage

Line map:
- `1-25`: checklist items

Primary interactions:
- `docs/modernization/features/practice/spec.md`
- `docs/modernization/features/practice/parity.md`
- `docs/modernization/features/practice/ledger.md`

Findings:
- no dead checklist items found
- this is the strongest feature checklist in the modernization docs and still tracks the highest-risk Practice surface areas well

Changes made in this pass:
- none

### `docs/modernization/features/practice/ledger.md`

Status: `reviewed`

Responsibility summary:
- large dated ledger for Practice audit, route/state extraction, shared-chrome cleanup, and parity work

Line map:
- `3-5`: initial audit-priority note
- `7-244`: long dated doc/code progress ledger
- `245-253`: next audit targets

Primary interactions:
- `docs/modernization/features/practice/spec.md`
- `Pinball App 2/Pinball App 2/practice/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/**`

Findings:
- no dead historical entries found
- this is the biggest doc growth hotspot in the modernization folder; it preserves useful history, but it is now much closer to an append-only engineering diary than a quick source of current unresolved Practice risk

Changes made in this pass:
- none

### `docs/modernization/features/practice/parity.md`

Status: `reviewed`

Responsibility summary:
- current Practice parity contract for route inventory, high-risk areas, game-route behavior, and ownership-model goals

Line map:
- `3-12`: must-match behaviors
- `13-32`: required route inventory and route-model notes
- `33-60`: high-risk areas and game-route contract
- `61-81`: ownership parity target, risk note, and allowed native differences

Primary interactions:
- `docs/modernization/features/practice/spec.md`
- `docs/modernization/features/practice/ledger.md`

Findings:
- no dead parity sections found
- this file already reflected the newer pushed-route normalization better than the older spec did, which helped identify where the spec had gone stale

Changes made in this pass:
- none

### `docs/modernization/features/practice/spec.md`

Status: `reviewed`

Responsibility summary:
- main Practice modernization spec covering route inventory, architecture snapshot, route contract, ownership model, refactor sequence, and current findings

Line map:
- `3-21`: status and scope summary
- `23-90`: current route inventory and architecture snapshot
- `92-249`: route-by-route product contract
- `251-300`: structural divergence and ownership snapshot
- `301-406`: file-responsibility map
- `407-487`: target ownership model, implementation sequence, and refactor seams
- `488-509`: focus area and initial findings

Primary interactions:
- `docs/modernization/features/practice/{checklist,parity,ledger}.md`
- `Pinball App 2/Pinball App 2/practice/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/**`

Findings:
- change made: replaced stale `3.2 focus` wording with `Current focus`
- change made: corrected the stale `GroupEditor` contract so it now reflects the current pushed-route model on both platforms instead of claiming iOS still presents it as `PracticeSheet.groupEditor`
- change made: updated the structural-divergence and ownership-goal sections so they describe the current route-model reality instead of a pre-refactor state where iOS still lacked an explicit route seam
- despite those corrections, this remains the biggest single feature-spec maintenance hotspot in the repo because it mixes living contract, refactor roadmap, and landed-history notes in one large file

Changes made in this pass:
- normalized stale route-model and phase wording so the active Practice spec matches the current codebase better

### `docs/modernization/features/settings/checklist.md`

Status: `reviewed`

Responsibility summary:
- concise Settings parity checklist

Line map:
- `1-7`: checklist items

Primary interactions:
- `docs/modernization/features/settings/spec.md`
- `docs/modernization/features/settings/parity.md`
- `docs/modernization/features/settings/ledger.md`

Findings:
- no dead checklist items found
- compact and still aligned with the current Settings feature surface

Changes made in this pass:
- none

### `docs/modernization/features/settings/ledger.md`

Status: `reviewed`

Responsibility summary:
- dated Settings cleanup/parity ledger

Line map:
- `3-5`: initial audit note
- `7-42`: dated extraction/shared-chrome ledger
- `43-47`: next audit targets

Primary interactions:
- `docs/modernization/features/settings/spec.md`
- `Pinball App 2/Pinball App 2/settings/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/**`

Findings:
- no dead historical entries found
- still readable and materially smaller than the Practice/Library ledgers

Changes made in this pass:
- none

### `docs/modernization/features/settings/parity.md`

Status: `reviewed`

Responsibility summary:
- minimal Settings parity contract

Line map:
- `3-8`: must-match items
- `10-12`: allowed native differences

Primary interactions:
- `docs/modernization/features/settings/spec.md`

Findings:
- no dead parity sections found
- concise but sparse; it depends on the spec/ledger for almost all real behavior detail

Changes made in this pass:
- none

### `docs/modernization/features/settings/spec.md`

Status: `reviewed`

Responsibility summary:
- Settings feature scope and current cleanup focus

Line map:
- `3-13`: status and scope summary
- `15-20`: focus area

Primary interactions:
- `docs/modernization/features/settings/{parity,ledger,checklist}.md`
- `Pinball App 2/Pinball App 2/settings/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/**`

Findings:
- change made: replaced stale `3.2 focus` wording with `Current focus`
- otherwise the file remains a small, current summary rather than a bloated hotspot

Changes made in this pass:
- normalized the active focus heading

## Pass 022 summary

Safe cleanup changes made:
- normalized stale branch/milestone wording in the active GameRoom, League, Library, Settings, and Practice feature specs so they use `Current focus` instead of `3.2 focus`
- updated `features/gameroom/parity.md` so its drift rule refers to active modernization/parity maintenance instead of “during 3.2”
- corrected `features/practice/spec.md` so it matches the current pushed-route `GroupEditor` model and the newer explicit iOS route-state seam

Verification:
- `rg -n "## 3\\.2 focus|during 3\\.2|PracticeSheet\\.groupEditor|iOS still differs from Android because Android models more of the full product surface as one unified route layer|iOS should gain an explicit route-state seam" '/Users/pillyliu/Documents/Codex/Pinball App/docs/modernization'`
- result after the edits: no remaining matches

Open follow-up items from this pass:
1. decide whether the large feature ledgers, especially `features/practice/ledger.md` and `features/library/ledger.md`, should be split into dated history versus current unresolved-risk sections
2. revisit `04_audit_matrix.md` statuses against the richer per-feature findings now captured in this sequential review
3. decide whether the sparse parity/checklist files for League and Settings need a little more behavioral detail so they do not rely so heavily on companion ledgers/specs

Next files queued:
- historical/local archive material under `archive/**`
- remaining maintenance scripts outside the active iOS runtime/support path

## Pass 023: archive snapshots and remaining active root scripts

### `archive/README.md`

Status: `reviewed`

Responsibility summary:
- declares the archive as local-only historical context and explains why retired docs/scripts were moved out of the active workflow

Line map:
- `1-10`: archive scope and guardrails
- `11-31`: retired-doc archive rationale
- `32-52`: retired-script archive rationale
- `53-68`: doc-refresh snapshot rationale
- `70-83`: historical release-notes rationale

Primary interactions:
- `README.md`
- `Pinball_App_Architecture_Blueprint_latest.md`
- `docs/**`
- `archive/2026-03-25-retired-docs/**`
- `archive/2026-03-25-retired-scripts/**`

Findings:
- clearly establishes that archive material must not be treated as runtime, preload, or build input
- change prompted elsewhere in this pass: archive review exposed dead root-level GameRoom baseline references still pointing at pre-archive locations from active modernization docs

Changes made in this pass:
- none directly in this file

### `archive/2026-03-25-doc-refresh/modernization/features/library/spec.md`

Status: `reviewed`

Responsibility summary:
- preserved pre-refresh snapshot of the Library modernization spec

Line map:
- `1-18`: status and scope summary
- `20-25`: older milestone-specific focus language
- `27-45`: pre-refresh structural baseline
- `46-68`: older resource and hosted-playfield contract wording

Primary interactions:
- `docs/modernization/features/library/spec.md`
- `Pinball App 2/Pinball App 2/library/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/**`

Findings:
- intentionally stale snapshot: still uses `3.2 focus` wording and starter-bundle/v3-only framing that the live spec has since replaced
- useful historical context, but it should remain archive-only and not be referenced as the current library contract

Changes made in this pass:
- none

### `archive/2026-03-25-doc-refresh/modernization/features/library/parity.md`

Status: `reviewed`

Responsibility summary:
- preserved pre-refresh Library parity snapshot

Line map:
- `1-12`: must-match and native-difference bullets
- `19-30`: pre-refresh parity baseline

Primary interactions:
- `docs/modernization/features/library/parity.md`

Findings:
- intentionally stale snapshot: it still codifies the `v3 starter-pack resource naming contract`
- still useful as a history marker for the older local-asset contract, but not a live parity rule

Changes made in this pass:
- none

### `archive/2026-03-25-doc-refresh/modernization/features/library/ledger.md`

Status: `reviewed`

Responsibility summary:
- append-only historical ledger for an earlier Library refactor/parity phase

Line map:
- `3-82`: dated extraction and UI-shared-chrome history
- `83-85`: next-audit targets from that older checkpoint

Primary interactions:
- `docs/modernization/features/library/ledger.md`
- `Pinball App 2/Pinball App 2/library/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/**`

Findings:
- intentionally stale snapshot: it preserves older starter-pack and v3-only local-asset wording that no longer matches the active CAF preload/hosted path
- still valuable as landed-history reference, but it is not a reliable current-state ledger anymore

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/docs/android_intro_overlay_parity_spec.md`

Status: `reviewed`

Responsibility summary:
- retired Android parity target for the earlier intro overlay design

Line map:
- `1-50`: purpose, source-of-truth file list, and older design decisions
- `51-89`: runtime launch/dismiss behavior contract
- `90-160`: card content and asset inventory for the earlier intro deck

Primary interactions:
- `Pinball App 2/Pinball App 2/app/AppIntroOverlay.swift`
- `Pinball App 2/Pinball App 2/app/ContentView.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsHomeSections.swift`

Findings:
- intentionally stale snapshot: it documents old asset-catalog names like `LaunchLogo`, `IntroStudyScreenshot`, and `IntroAssessmentScreenshot` instead of the current bundled `app-intro` webp contract
- still useful because it records the intentional next-launch hidden shortcut behavior that remains in the shipped app

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/docs/ios_onboarding_tipkit_version_overlays.md`

Status: `reviewed`

Responsibility summary:
- retired iOS guidance note for onboarding, TipKit, and version overlays

Line map:
- `1-21`: purpose and recommendation summary
- `22-69`: three-layer onboarding model
- `70-160`: recommended startup intro rules and older card-count guidance

Primary interactions:
- `Pinball App 2/Pinball App 2/app/ContentView.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeRootView.swift`

Findings:
- intentionally stale snapshot: it still recommends `Skip`, `Back`, `Next`, and a five-card default, which no longer matches the shipped six-card intro overlay
- it also references `Pinball_App_Feature_Guide_3.4.7_2026-03-22.md`, which is now archived history rather than an active product contract

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/docs/ios_shake_warning_parity_spec.md`

Status: `reviewed`

Responsibility summary:
- retired detailed parity baseline for the earlier shake-warning feature packaging

Line map:
- `1-35`: feature summary and user-facing copy
- `36-84`: file ownership and older packaging assumptions
- `85-160`: app wiring, undo gating, and shake-detection baseline

Primary interactions:
- `Pinball App 2/Pinball App 2/app/AppShakeCoordinator.swift`
- `Pinball App 2/Pinball App 2/app/ContentView.swift`
- `Pinball App 2/Pinball App 2/ui/SharedGestures.swift`

Findings:
- intentionally stale snapshot: it still assumes a separate website/data repo, `shared/pinball`, and `PinballStarter.bundle` starter-pack copies as the active asset path
- archive placement is correct because the shipped app now owns these assets locally through `SharedAppSupport` and bundle-root lookups instead

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/ANDROID_OPDB_V3_ADAPTATION.md`

Status: `reviewed`

Responsibility summary:
- retired Android parity kickoff note for the older OPDB v3 adaptation phase

Line map:
- `1-20`: older iOS data-contract assumptions
- `22-39`: implemented behavior snapshot from that phase
- `40-66`: then-pending Android/shared follow-up
- `68-79`: shared UI notes

Primary interactions:
- `Pinball App 2/Pinball App 2/library/**`
- `Pinball App 2/Pinball App 2/settings/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/**`

Findings:
- intentionally stale snapshot: it still treats adding the Settings tab and porting imported-source persistence as future Android work
- useful only as historical parity context for the older OPDB/starter-pack transition

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/Legacy_Path_Retirement_Checklist_2026-02-27.md`

Status: `reviewed`

Responsibility summary:
- retired checklist of legacy migration branches that were candidates for later deletion

Line map:
- `1-24`: iOS deletion candidates
- `25-44`: Android deletion candidates
- `45-65`: keep rules and exit criteria

Primary interactions:
- `Pinball App 2/Pinball App 2/practice/**`
- `Pinball App 2/Pinball App 2/library/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/**`

Findings:
- still useful as a historical shortlist because several items line up with the current review, including legacy date decoding, practice-key aliasing, and `*_local_legacy` compatibility
- intentionally stale pathing: it still references older Android package paths under `com/pillyliu/pinballandroid/**`

Changes made in this pass:
- none

### `scripts/export_bob_rulesheet_urls.py`

Status: `reviewed`

Responsibility summary:
- standalone utility that fetches the Silverball Mania sitemap and emits a JSON rulesheet-URL snapshot

Line map:
- `13-31`: sitemap fetch and rulesheet URL extraction
- `34-41`: JSON payload shaping
- `44-63`: CLI entrypoint and optional file output

Primary interactions:
- `https://rules.silverballmania.com/sitemap.xml`
- optional local JSON output path passed by the operator

Findings:
- no in-repo call sites found, so this behaves like a manual/offline utility rather than an active app build dependency
- compact and self-contained; no dead branches stood out

Changes made in this pass:
- none

### `scripts/pinball_api_auth.py`

Status: `reviewed`

Responsibility summary:
- minimal helper for loading local `.env` style key/value pairs into process environment

Line map:
- `8-26`: path iteration, comment/blank filtering, and env injection rules

Primary interactions:
- local env files supplied by the operator
- `os.environ`

Findings:
- no in-repo call sites found, so this also behaves like a manual helper instead of a wired build/runtime dependency
- tiny and focused; no dead branches found

Changes made in this pass:
- none

### `scripts/pinball_api_clients.py`

Status: `reviewed`

Responsibility summary:
- standalone OPDB export client with retry logic for manual snapshot/export workflows

Line map:
- `12-19`: environment-backed client bootstrap
- `20-48`: export request, payload-shape validation, and retry behavior

Primary interactions:
- `os.environ`
- `https://opdb.org/api/export` or `OPDB_EXPORT_URL`

Findings:
- no in-repo call sites found, so this appears to be a manual utility rather than live app plumbing
- the constructor carried an unused `autoload_local_env` compatibility argument

Changes made in this pass:
- renamed the unused constructor argument to `_autoload_local_env` so the compatibility surface remains intact while making the non-use explicit

### `scripts/render_mermaid_blocks.py`

Status: `reviewed`

Responsibility summary:
- manual utility that renders Mermaid code fences from markdown into sequential PNG files

Line map:
- `12-17`: Mermaid fence extraction
- `19-38`: per-block `.mmd` staging and `mermaid-cli` rendering
- `41-66`: CLI entrypoint

Primary interactions:
- local markdown input files
- local rendered diagram output directory
- `npx @mermaid-js/mermaid-cli`

Findings:
- no in-repo call sites found, so this is manual documentation tooling, not an active build step
- tightly coupled with `render_architecture_pdf_upgraded.py` through the `diagram_XX.png` naming convention, even though that coupling is only implicit

Changes made in this pass:
- none

### `scripts/render_architecture_pdf.py`

Status: `reviewed`

Responsibility summary:
- older ReportLab-only markdown-to-PDF renderer for architecture docs

Line map:
- `23-107`: PDF typography/style setup
- `110-214`: simple markdown parsing into report elements
- `217-248`: footer rendering and PDF build
- `251-265`: CLI entrypoint

Primary interactions:
- local markdown source files
- local PDF output path
- `reportlab`

Findings:
- no in-repo call sites found, so this appears to be a manual documentation utility
- overlaps heavily with `render_architecture_pdf_upgraded.py`, which suggests maintained duplication until one renderer is explicitly retired

Changes made in this pass:
- none

### `scripts/render_architecture_pdf_upgraded.py`

Status: `reviewed`

Responsibility summary:
- more polished markdown-to-PDF renderer with inline markdown formatting, custom fonts, and Mermaid diagram image embedding

Line map:
- `24-53`: inline markdown rendering rules
- `56-216`: font registration and style setup
- `219-358`: markdown parsing plus Mermaid image placement
- `361-429`: header/footer rendering and PDF build
- `432-469`: CLI entrypoint

Primary interactions:
- local markdown source files
- diagram images produced by `scripts/render_mermaid_blocks.py`
- local PDF output path
- `reportlab`

Findings:
- no in-repo call sites found, so this is also manual documentation tooling
- likely supersedes the older renderer, but both remain live side-by-side with overlapping responsibility

Changes made in this pass:
- none

### `scripts/mermaid_print_theme.json`

Status: `reviewed`

Responsibility summary:
- Mermaid theme configuration for printable diagram rendering

Line map:
- `1-23`: theme variables
- `24-39`: diagram-type spacing/layout tweaks

Primary interactions:
- `scripts/render_mermaid_blocks.py`
- `npx @mermaid-js/mermaid-cli`

Findings:
- no in-repo call sites found beyond manual script usage, so this is supporting documentation tooling rather than app/runtime configuration
- the file is still logically live because it provides the visual contract for the Mermaid-render path

Changes made in this pass:
- none

## Pass 023 summary

Safe cleanup changes made:
- renamed the unused compatibility argument in `scripts/pinball_api_clients.py` to `_autoload_local_env` so the parameter remains backwards-compatible while no longer pretending to be active logic
- updated dead root-level GameRoom baseline references discovered during archive review so active docs now point at the archived locations:
  - `docs/modernization/00_program_overview.md`
  - `docs/modernization/features/gameroom/spec.md`

Verification:
- `python3 -m py_compile '/Users/pillyliu/Documents/Codex/Pinball App/scripts/pinball_api_clients.py'`
- `rg -n "GameRoom_3\\.1_Master_Plan|GameRoom_3\\.1_Parity_Journal|GameRoom_3\\.1_Android_Parity_Kickoff" '/Users/pillyliu/Documents/Codex/Pinball App/docs/modernization'`
- result after the doc cleanup: only archived-path references remain

Open follow-up items from this pass:
1. decide whether `scripts/render_architecture_pdf.py` should now be retired in favor of `scripts/render_architecture_pdf_upgraded.py`, since both are manual utilities with overlapping ownership
2. decide whether the remaining root `scripts/**` utilities should move under a clearer `tools/docs` or `tools/data` home so they are not mistaken for build/runtime wiring
3. continue the archive sweep through the larger retired root markdown documents and the archived retired helper scripts so the full archive inventory is reviewed sequentially

Next files queued:
- larger retired root documents under `archive/2026-03-25-retired-docs/root/*.md`
- archived retired helper scripts under `archive/2026-03-25-retired-scripts/scripts/*.py`

## Pass 024: larger archived GameRoom planning and parity docs

### `archive/2026-03-25-retired-docs/root/GameRoom_3.1_Android_Parity_Kickoff.md`

Status: `reviewed`

Responsibility summary:
- archived Android execution guide for porting the original iOS-first `GameRoom 3.1` feature set

Line map:
- `1-12`: source-of-truth references, branch, and goal
- `13-35`: parity contract for routes, tabs, and settings labels
- `36-48`: then-current Android status snapshot
- `49-235`: milestone-by-milestone Android rollout status and acceptance details
- `236-260`: iOS-to-Android file mapping
- `262-275`: QA-oriented immediate next steps

Primary interactions:
- `archive/2026-03-25-retired-docs/root/GameRoom_3.1_Master_Plan.md`
- `archive/2026-03-25-retired-docs/root/GameRoom_3.1_Parity_Journal.md`
- `Pinball App 2/Pinball App 2/gameroom/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/**`

Findings:
- intentionally stale snapshot: its source-of-truth pointers still reference the old root-level `GameRoom_3.1_*` paths because the document is preserved exactly as captured
- useful historical handoff because it records the specific Android milestone acceptance criteria and parity checkpoints that later collapsed into much smaller active GameRoom modernization docs
- strong sign that the old GameRoom parity work relied on a trio of living root docs rather than today’s slimmer `docs/modernization/features/gameroom/**` set

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/GameRoom_3.1_Master_Plan.md`

Status: `reviewed`

Responsibility summary:
- archived comprehensive planning contract for the original iOS-first GameRoom 3.1 rollout

Line map:
- `1-18`: document purpose, branch, and platform strategy
- `21-129`: version goal, IA, domain rules, home spec, and settings spec
- `133-260`: detailed edit-machines, machine-view, and logging scope
- `262-338`: import/data-model/performance contracts
- `341-460`: milestone roadmap, status snapshot, micro-decisions, Android parity rule, and deferred backlog

Primary interactions:
- `archive/2026-03-25-retired-docs/root/GameRoom_3.1_Parity_Journal.md`
- `Pinball App 2/Pinball App 2/gameroom/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/**`
- `Pinball App 2/Pinball App 2/library/**`

Findings:
- this is an archive-only master plan now, but it still explains many hidden GameRoom contracts that survived into the shipped feature: machine-instance archive semantics, area-level ordering, first-tap-select/second-tap-open, and input-sheet ownership
- it mixes durable product rules with point-in-time roadmap status, so it was inherently prone to staleness even before archiving
- the plan explicitly deferred variant-fidelity questions across GameRoom, Library, and Practice; that same unresolved seam still appears in the current review as a parity-risk area rather than a closed decision

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/GameRoom_3.1_Parity_Journal.md`

Status: `reviewed`

Responsibility summary:
- archived authoritative ledger for accepted iOS-first GameRoom behavior and later Android parity follow-up notes

Line map:
- `1-23`: purpose, branch, and parity rule
- `24-129`: canonical naming and confirmed product rules
- `130-210`: schema/data-model contract
- `211-498`: milestone outcomes for implemented iOS GameRoom behavior
- `499-551`: Android parity targets, guardrails, and open TODOs
- `553-735`: rolling Android parity notes and follow-up polish history

Primary interactions:
- `archive/2026-03-25-retired-docs/root/GameRoom_3.1_Master_Plan.md`
- `Pinball App 2/Pinball App 2/gameroom/**`
- `Pinball App 2/Pinball App 2/library/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/**`

Findings:
- highest-signal archive finding: this one file became both the accepted iOS contract and a rolling Android parity changelog, so it is extremely informative historically but also a textbook documentation growth hotspot
- it captures many cross-feature GameRoom/Library contracts that the current smaller GameRoom docs only summarize, especially GameRoom-backed Library hydration, source visibility, variant-aware media resolution, and Pinside import behavior
- the long `Android 3.1 Parity Notes (Latest)` tail shows why the old parity workflow was hard to keep tidy: final contract and iterative implementation drift notes were mixed together in one artifact

Changes made in this pass:
- none

## Pass 024 summary

Safe cleanup changes made:
- none

Verification:
- none; this slice was archival review and review-log updates only

Open follow-up items from this pass:
1. decide at the end of the full audit whether the active GameRoom modernization docs should borrow a compact “historical context” appendix so they do not need to rely on archived root docs for background
2. keep variant-fidelity and GameRoom-to-Library hydration behavior on the final triage list, because those seams were deferred in the archived master plan and still surface in current runtime code
3. continue the archive sweep with the remaining retired root docs and then the archived retired helper scripts

Next files queued:
- remaining retired root documents under `archive/2026-03-25-retired-docs/root/*.md`
- archived retired helper scripts under `archive/2026-03-25-retired-scripts/scripts/*.py`

## Pass 025: remaining archived root docs and generated print snapshots

### `archive/2026-03-25-retired-docs/root/PinProf_Guidance_Inventory_and_Strategy_2026-03-22.md`

Status: `reviewed`

Responsibility summary:
- archived strategy note for onboarding overlays, version callouts, and contextual tips across iOS and Android

Line map:
- `1-156`: current app inventory, guidance-relevant surfaces, and reusable behavior signals
- `197-269`: proposed three-layer guidance architecture and central coordinator
- `272-401`: overlay-worthiness rules and candidate overlay concepts
- `405-643`: TipKit candidates, Android guidance mapping, copy prompts, and next steps

Primary interactions:
- `Pinball App 2/Pinball App 2/app/ContentView.swift`
- `Pinball App 2/Pinball App 2/app/AppShakeCoordinator.swift`
- `Pinball App 2/Pinball App 2/practice/**`
- `Pinball App 2/Pinball App 2/library/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/**`

Findings:
- useful historical planning doc, but intentionally stale now that the shipped intro overlay and hidden next-launch shortcut have already been implemented
- it still recommends a centralized multi-layer guidance coordinator and TipKit rollout that the current app does not fully ship, so it should stay archive-only rather than be mistaken for current architecture
- it captures a valuable design principle that still holds: derive learning state from real behavior before adding more explicit booleans

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/Pinball_API_Compliance_Checklist_2026-02-27.md`

Status: `reviewed`

Responsibility summary:
- archived governance checklist for third-party data/API usage across OPDB, Pinball Map, Match Play, and IFPA

Line map:
- `1-18`: core provider-agnostic compliance rules
- `19-65`: provider-specific checklists
- `67-91`: data-model, rights, security, and operational checklist
- `93-107`: pre-launch and ongoing governance items

Primary interactions:
- upstream provider integrations and publish pipeline assumptions rather than app runtime files directly

Findings:
- this is not runtime behavior documentation; it is policy and operational guidance for the old publish/integration workflow
- intentionally stale in places because it still frames the app-facing contract around `pinball_library_v3.json` or a “versioned successor,” whereas current active docs now describe CAF-hosted layers more explicitly
- still useful as a compliance/governance baseline if provider integrations are revisited later

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/Pinball_App_Architecture_Blueprint.md`

Status: `reviewed`

Responsibility summary:
- archived February 27 architecture blueprint from the earlier four-domain/four-tab era

Line map:
- `1-44`: purpose, goals, and repo/runtime boundaries
- `45-111`: compact C4 views and high-level component map
- `112-210`: feature inventory, persistence model, and cache architecture
- `212-333`: interaction flows, cleanup plan, risks, and architecture decisions

Primary interactions:
- historical references to iOS and Android app structure
- historical references to older root-level architecture docs and print-layout PDFs

Findings:
- intentionally stale snapshot: it still describes the product as `League / Library / Practice / About`, references the older Android package path `com/pillyliu/pinballandroid`, and treats `pinball_library_v3.json` as the main remote library contract
- highest-signal archive note: this file is byte-for-byte identical to `Pinball_App_Architecture_Blueprint_2026-02-27.md`, so the archive preserves two exact copies of the same blueprint revision

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/Pinball_App_Architecture_Blueprint_2026-02-27.md`

Status: `reviewed`

Responsibility summary:
- dated copy of the same February 27 architecture blueprint revision

Line map:
- identical to `Pinball_App_Architecture_Blueprint.md`

Primary interactions:
- same as the sibling blueprint file above

Findings:
- exact duplicate of `Pinball_App_Architecture_Blueprint.md`
- archive duplication is harmless, but it is a good reminder that root-doc history had already started to sprawl before the archive cleanup

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/Pinball_App_Architecture_Blueprint_3.4.7_2026-03-22.md`

Status: `reviewed`

Responsibility summary:
- archived large release-era architecture blueprint for PinProf `3.4.7`

Line map:
- `1-126`: release snapshot, product summary, stack, and version anchors
- `128-405`: detailed C4 diagrams across features and shared services
- `407-1075`: screen inventory, interaction diagrams, data/storage model, navigation map, and testing/release flow
- `1083-1105`: intentional platform adaptations and architecture direction
- `1105-1114`: final summary

Primary interactions:
- `Pinball App 2/Pinball App 2/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/**`
- historical hosted data/runtime contract docs

Findings:
- archived transitional snapshot: it already reflects the five-tab product and GameRoom baseline, but it still describes the hosted contract in older pre-CAF terms compared with the next day’s revision
- superseded by the March 23 revision, which expanded the publish-chain and CAF runtime-contract details materially

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/Pinball_App_Architecture_Blueprint_3.4.7_2026-03-23.md`

Status: `reviewed`

Responsibility summary:
- archived expanded release-era architecture blueprint that captured the newer CAF/runtime-publish-chain framing

Line map:
- `1-160`: release snapshot, product goals, stack, CAF contract, and version anchors
- `164-504`: expanded C4 diagrams and shared-service views
- `505-1202`: screen inventory, interactions, data flow, navigation, and release operations
- `1212-1236`: platform adaptations and final architecture summary

Primary interactions:
- `Pinball App 2/Pinball App 2/**`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/**`
- historical publish-chain documentation around PinProf Admin and the website deploy bridge

Findings:
- this is effectively the last major archived blueprint before the active `Pinball_App_Architecture_Blueprint_latest.md`, and it is much closer to the current architecture language than the older March 22 version
- compared with the March 22 blueprint, it adds explicit CAF layer contracts, PinProf Admin publish-chain context, and newer hosted/runtime ownership language
- still intentionally stale now because it is frozen at `3.4.7` and older operational assumptions, but it remains one of the most informative archive references

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/Pinball_App_Feature_Guide_3.4.7_2026-03-22.md`

Status: `reviewed`

Responsibility summary:
- archived feature-and-experience guide used for guidance planning and video scripting

Line map:
- `1-94`: guide purpose, release scope, app story, and product-wide guidance implications
- `97-809`: feature-by-feature user-facing guide across League, Library, Practice, GameRoom, and Settings
- `829-978`: cross-tab journeys plus guidance and walkthrough-planning lens

Primary interactions:
- user-facing feature surfaces across all major app tabs
- the archived guidance/video-planning docs that were derived from this guide

Findings:
- intentionally stale snapshot: it is frozen to `3.4.7`, but it still does a good job describing the user-facing story that later intro/guidance planning built on
- useful because it separates product experience from implementation detail better than many of the older architecture docs
- it still references some now-evolved surfaces, like score-scanner discovery and earlier Group Editor affordances, so it should remain archive-only rather than be treated as exact current behavior

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/Pinball_App_Video_Walkthrough_Planning_2026-02-27.md`

Status: `reviewed`

Responsibility summary:
- archived walkthrough-planning document with feature ranking, screen order, and word-for-word narration scripts

Line map:
- `1-40`: core app story and feature-priority ranking
- `43-127`: detailed screen walkthrough order
- `131-330`: 1-, 3-, 5-, and 10-minute outline structures
- `331-485`: narration scripts
- `486-520`: recording plan and visual emphasis suggestions

Primary interactions:
- historical user-facing flow across the older app surface

Findings:
- intentionally stale snapshot: it still describes the root tabs as `League / Library / Practice / About`, which predates the GameRoom + Settings expansion
- useful historical artifact for product-story framing, but not a current walkthrough source

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/Practice_Journal_iOS_Canonical_Format.md`

Status: `reviewed`

Responsibility summary:
- archived iOS-first reference spec for canonical Practice persistence and journal semantics

Line map:
- `1-80`: scope, storage keys, serialization format, canonical game IDs, and top-level persisted state
- `81-243`: journal-linked models, enums, and write-path semantics
- `245-293`: summary rendering and edit/delete reconciliation rules
- `294-406`: example JSON plus Android parity recommendation

Primary interactions:
- `Pinball App 2/Pinball App 2/practice/PracticeStore.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStorePersistence.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStateCodec.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeIdentityKeying.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift`

Findings:
- historically important because it explains why string-rendered journal summaries were never meant to be the canonical stored form
- intentionally stale snapshot: it says Android was not yet identical and recommends migrating Android toward the iOS schema, which has since changed materially with later parity work
- still aligns with one current review theme: render-time summary strings are derived view data, not a safe schema boundary

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/RELEASE_NOTES_2.0.md`

Status: `reviewed`

Responsibility summary:
- archived release notes for the older iOS `2.0` milestone

Line map:
- `1-35`: league mini-view and rulesheet improvements
- `55-113`: Practice 2.0 structure/behavior summary
- `114-125`: stability/data-handling improvements and intended outcome

Primary interactions:
- historical iOS-only feature baseline for league mini-views, rulesheets, and Practice

Findings:
- intentionally stale release artifact from the pre-cross-platform `3.x` era
- still useful as a compact history marker for some older Practice and rulesheet behavior work, but not relevant to current active product contract

Changes made in this pass:
- none

### `archive/2026-03-25-retired-docs/root/*.pdf` generated print snapshots

Status: `reviewed`

Responsibility summary:
- archived print-layout PDF snapshots of older architecture, feature-guide, and walkthrough documents

Line map:
- generated artifact group rather than hand-maintained source files

Primary interactions:
- the retired markdown docs in the same folder
- the old render scripts under `scripts/render_architecture_pdf.py`, `scripts/render_architecture_pdf_upgraded.py`, and `scripts/render_mermaid_blocks.py`

Findings:
- these PDFs are generated historical snapshots, not source-of-truth docs
- archive placement is correct because they preserve presentation-ready copies without reintroducing stale root-level docs into the active workflow

Changes made in this pass:
- none

## Pass 025 summary

Safe cleanup changes made:
- none

Verification:
- `cmp -s '/Users/pillyliu/Documents/Codex/Pinball App/archive/2026-03-25-retired-docs/root/Pinball_App_Architecture_Blueprint.md' '/Users/pillyliu/Documents/Codex/Pinball App/archive/2026-03-25-retired-docs/root/Pinball_App_Architecture_Blueprint_2026-02-27.md'`
- result: exact duplicate archive copies

Open follow-up items from this pass:
1. if we ever want to reduce archive noise, the exact duplicate February 27 architecture blueprints are a clean archive-prune candidate
2. the archived Practice journal spec reinforces a current cleanup rule: summary strings should stay derived presentation, not turn into hidden persistence schema
3. continue with the archived retired helper scripts, which appear to be the last major unreviewed archive slice

Next files queued:
- archived retired helper scripts under `archive/2026-03-25-retired-scripts/scripts/*.py`

## Pass 026: archived retired helper scripts

### `archive/2026-03-25-retired-scripts/scripts/audit_rulesheet_links.py`

Status: `reviewed`

Responsibility summary:
- retired auditing utility that checked external rulesheet URLs for reachability/parse quality and preserved failure history by normalized URL

Line map:
- `22-157`: inventory shaping and URL normalization helpers
- `160-470`: provider-specific fetch and parse auditing logic
- `473-547`: history merge and summary shaping
- `550-675`: threaded audit execution and CLI entrypoint

Primary interactions:
- `archive/2026-03-25-retired-scripts/scripts/fetch_opdb_snapshot.py`
- starter-pack `opdb_catalog_v1.json` outputs for both iOS and Android
- external rulesheet providers such as Tilt Forums, Pinball Primer, Bob/Silverball Mania, and PAPA

Findings:
- clearly retired pipeline tooling: the only current in-repo references are in [archive/README.md](/Users/pillyliu/Documents/Codex/Pinball%20App/archive/README.md)
- hidden contract: it imports `normalize_rulesheet_url` from the sibling `fetch_opdb_snapshot.py`, so the old publish pipeline depended on shared URL-normalization heuristics across separate scripts
- the script preserves nuanced provider-specific parse heuristics and failure history, which is useful historical context if rulesheet auditing ever moves into a new upstream pipeline

Changes made in this pass:
- none

### `archive/2026-03-25-retired-scripts/scripts/build_external_rulesheet_resources.py`

Status: `reviewed`

Responsibility summary:
- retired build step that produced OPDB-group-keyed external rulesheet resources from a reference catalog plus live Bob sitemap data

Line map:
- `15-30`: workstation-specific roots and provider/source mapping
- `56-71`: reference-catalog resolution logic
- `74-139`: extraction of existing rulesheets plus optional live Bob sitemap enrichment
- `142-164`: CLI build/write flow

Primary interactions:
- `/Users/pillyliu/Documents/Codex/Pinball Scraper`
- `/Users/pillyliu/Documents/Codex/Pillyliu Pinball Website/shared/pinball/data/opdb_catalog_v1.json`
- iOS and Android starter-pack `opdb_catalog_v1.json`
- `https://rules.silverballmania.com/sitemap.xml`

Findings:
- strong evidence of the old workstation-local generation pipeline: it hardcodes absolute local paths to `Pinball Scraper`, the website repo, and starter-pack catalogs
- hidden contract: provider keys like `tf`, `pp`, `papa`, and `bob` were remapped into older source keys such as `tiltforums`, `pinball_primer`, `pinball_org`, and `bobs_guide`
- archive placement is correct because this logic belongs to upstream content generation, not the app repo runtime

Changes made in this pass:
- none

### `archive/2026-03-25-retired-scripts/scripts/build_library_seed_db.py`

Status: `reviewed`

Responsibility summary:
- retired generator that built the old SQLite seed database for iOS and Android starter packs from `pinball_library_v3.json` plus `opdb_catalog_v1.json`

Line map:
- `11-17`: starter-pack input/output paths
- `32-121`: catalog indexing and curated-override extraction
- `124-248`: built-in row/rulesheet/video resolution
- `251-391`: SQLite schema creation
- `394-538`: database write flow and dual-platform output

Primary interactions:
- iOS `PinballStarter.bundle/pinball/data`
- Android `assets/starter-pack/pinball/data`
- `pinball_library_v3.json`
- `opdb_catalog_v1.json`

Findings:
- highest-signal retired-script finding: this script is a concrete snapshot of the old app-owned starter-pack/seed-db generation pipeline that the archive README says has moved out of the app repo
- hidden contract: duplicate `library_entry_id` collisions were silently preserved by suffixing `--dupN`, which explains one historical path for deterministic but implicit duplicate handling
- it also preserved older override/resource rules around local rulesheets, local game info, and local playfield precedence that later became runtime seams in the app

Changes made in this pass:
- none

### `archive/2026-03-25-retired-scripts/scripts/build_local_asset_intake.py`

Status: `reviewed`

Responsibility summary:
- retired inventory/audit generator for website-shared versus starter-pack local rulesheet/playfield assets

Line map:
- `14-21`: website and starter-pack roots plus output locations
- `56-130`: path resolution, variant derivation, hashing, and bucket classification
- `133-225`: v3 inventory row aggregation and conflict detection
- `228-430`: coverage report generation across website, iOS, and Android asset pools
- `433-546`: markdown summary rendering and CLI flow

Primary interactions:
- `Pillyliu Pinball Website/shared/pinball`
- iOS `PinballStarter.bundle/pinball`
- Android `assets/starter-pack/pinball`
- `pinball_library_v3.json`

Findings:
- this script captures the older shared-website plus starter-pack asset parity workflow very explicitly
- hidden contract: it still audits both `*_local_practice` and `*_local_legacy` asset fields, which lines up with the current review’s remaining legacy-compatibility seams
- another strong sign of retired status: it writes mirrored reports back into website/iOS/Android data folders rather than feeding any live in-app path

Changes made in this pass:
- none

### `archive/2026-03-25-retired-scripts/scripts/build_matchplay_tutorial_enrichment.py`

Status: `reviewed`

Responsibility summary:
- retired generator that extracted Match Play tutorial videos from a reference catalog into an enrichment payload keyed by OPDB group

Line map:
- `13-20`: workstation-specific roots and reference catalogs
- `46-61`: best-reference-catalog resolution
- `64-103`: tutorial extraction and row shaping
- `106-127`: CLI flow

Primary interactions:
- `/Users/pillyliu/Documents/Codex/Pinball Scraper`
- website/shared and starter-pack `opdb_catalog_v1.json` sources

Findings:
- another small but clear upstream-generation helper rather than app runtime code
- hidden contract: it emits rows in the old `payload.entry.machineGroup.opdbId` shape, which ties it directly to the earlier Match Play enrichment pipeline consumed by `fetch_opdb_snapshot.py`

Changes made in this pass:
- none

### `archive/2026-03-25-retired-scripts/scripts/fetch_opdb_snapshot.py`

Status: `reviewed`

Responsibility summary:
- retired main catalog-generation script that fetched/normalized OPDB data, merged Match Play tutorial enrichment and external rulesheet resources, and wrote `opdb_catalog_v1.json` into both starter packs

Line map:
- `18-63`: roots, defaults, and provider/manufacturer constants
- `65-260`: normalization, provider labeling, rulesheet filtering, env loading, and OPDB fetch helpers
- `270-431`: manufacturer normalization, payload-shape handling, and manufacturer sort logic
- `450-687`: Match Play/external rulesheet enrichment plus catalog assembly
- `697-765`: CLI flow, recent-catalog reuse, fetch/build/write path

Primary interactions:
- `/Users/pillyliu/Documents/Codex/Pinball Scraper`
- retired sibling scripts and enrichment outputs
- iOS and Android starter-pack `opdb_catalog_v1.json`
- OPDB export API and groups export
- Match Play enrichment output
- external rulesheet enrichment output

Findings:
- this was the central retired app-side bridge helper in the old content pipeline
- highest-signal hidden contract: it encoded a large amount of provider-specific normalization and precedence logic, including manufacturer bucketing, rulesheet provider inference, manual rulesheet overrides, Match Play tutorial stitching, and recent-catalog reuse to avoid frequent exports
- it still carries a deprecated `--skip-bob-sitemap` flag, which is a good example of historical CLI drift that no longer matters because the script is archived

Changes made in this pass:
- none

## Pass 026 summary

Safe cleanup changes made:
- none

Verification:
- `rg -n "audit_rulesheet_links.py|build_external_rulesheet_resources.py|build_library_seed_db.py|build_local_asset_intake.py|build_matchplay_tutorial_enrichment.py|fetch_opdb_snapshot.py" '/Users/pillyliu/Documents/Codex/Pinball App'`
- result: these retired scripts are only referenced by [archive/README.md](/Users/pillyliu/Documents/Codex/Pinball%20App/archive/README.md)

Open follow-up items from this pass:
1. the archive review now confirms that the old app repo once owned content-generation, asset-parity, and starter-pack build logic locally; that history is useful context but should stay isolated from active app/runtime docs
2. if we ever rebuild an upstream content pipeline locally again, the most reusable historical pieces are the provider-normalization heuristics and audit logic from `fetch_opdb_snapshot.py` and `audit_rulesheet_links.py`
3. after this pass, the major archive inventory has been reviewed; the next cleanup focus can return to triaging the highest-signal runtime findings already accumulated in the main iOS audit

Next files queued:
- final end-of-audit triage and prioritization pass once the sequential review sweep is considered complete

## Pass 027: end-of-sweep triage board

### Fix now

1. `PinballDataCache` clear-cache race and checkpoint drift
   - iOS detached revalidation work can repopulate disk after a user clears cache, and the update-log checkpoint path is less defensive than Android when event ordering is not newest-first
   - primary files:
     - `Pinball App 2/Pinball App 2/data/PinballDataCache.swift`
     - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCache.kt`

2. Practice scanner concurrency ownership
   - `ScoreScannerViewModel` mixes queue-owned and actor-owned gating state around freeze/retake/throttling, which is the clearest current hidden-behavior risk in active runtime code
   - primary files:
     - `Pinball App 2/Pinball App 2/practice/ScoreScannerViewModel.swift`
     - `Pinball App 2Tests/ScoreScanner*`

3. GameRoom persisted-state corruption handling
   - `GameRoomStateCodec` currently treats decode failure like “no saved state,” so bad JSON would silently reset GameRoom to empty instead of surfacing corruption or fallback intent
   - primary files:
     - `Pinball App 2/Pinball App 2/gameroom/GameRoomStateCodec.swift`
     - `Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`

4. Practice dashboard staleness
   - `PracticeGroupDashboardSection` can preserve stale detail because the reload key tracks group metadata more than live practice/journal/score changes
   - primary files:
     - `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`
     - `Pinball App 2/Pinball App 2/practice/PracticeStore.swift`

5. League/About copy and loading cleanup
   - `AboutScreen` has stale league logistics copy and sync image loading on the main thread, so it is both a correctness and polish cleanup target
   - primary files:
     - `Pinball App 2/Pinball App 2/info/AboutScreen.swift`

### Ask first

1. GameRoom play-count and reminder semantics
   - current behavior is deterministic but hidden: only certain custom events affect play totals, default reminder configs are implicit, and every mutation emits a library-source change
   - primary files:
     - `Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`

2. Duplicate-resolution policy
   - `ResolvedLeagueMachineMappings`, `ResolvedLeagueTargets`, and some GameRoom/import paths silently overwrite duplicates; this may be acceptable or may need surfaced conflict handling depending on your preference
   - primary files:
     - `Pinball App 2/Pinball App 2/practice/ResolvedLeagueMachineMappings.swift`
     - `Pinball App 2/Pinball App 2/practice/ResolvedLeagueTargets.swift`
     - `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogLoader.swift`

3. Variant-fidelity boundaries
   - GameRoom, Library, and Practice still carry deferred variant-fidelity tradeoffs, especially where group identity collapses strategy/media onto non-exact variants
   - primary files:
     - `Pinball App 2/Pinball App 2/library/**`
     - `Pinball App 2/Pinball App 2/gameroom/**`
     - `Pinball App 2/Pinball App 2/practice/**`

4. IFPA scraping durability
   - `PracticeIFPAProfileScreen` uses brittle HTML scraping with regexes; fixing it may require product/API decisions rather than a pure cleanup
   - primary files:
     - `Pinball App 2/Pinball App 2/practice/PracticeIFPAProfileScreen.swift`

### Safe cleanup later

1. File-size and ownership hotspots
   - `PracticeGroupEditorComponents.swift`, `PracticeJournalSettingsSections.swift`, `GameRoomSettingsComponents.swift`, `GameRoomPresentationComponents.swift`, and several modernization ledgers are now concentration hotspots and should be split when we want maintainability wins

2. Hidden invalidation hacks
   - the duplicated `_ = showFullLPLLastNames` invalidation trick should become an explicit formatting dependency instead of a hidden refresh poke
   - primary files:
     - `Pinball App 2/Pinball App 2/league/**`
     - `Pinball App 2/Pinball App 2/practice/**`

3. Orphan/manual tooling cleanup
   - `ScoreScannerCameraTestView.swift` looks orphaned, and the root/archive PDF/render scripts contain overlapping manual tooling that could be reduced without touching runtime behavior

4. Doc growth cleanup
   - the active modernization ledgers/specs now mix current contract and long history; they should eventually split “current contract” from “historical log”

### Intentional keep

1. Hidden about-logo double tap
   - keep the hidden Settings double-tap that arms the next-launch intro overlay
   - primary file:
     - `Pinball App 2/Pinball App 2/settings/SettingsHomeSections.swift`

2. Archive history
   - keep the archived root docs and retired scripts as historical context, even though some are duplicate or stale, unless you explicitly want a second archive-prune pass later

## Pass 027 summary

Safe cleanup changes made:
- none

Verification:
- none; this pass is a synthesis/triage layer over the existing sequential review

Outcome:
- the sequential iOS-first sweep now has a prioritized endgame board without losing the underlying file-by-file audit history

Next files queued:
- targeted cleanup pass starting with the `Fix now` list above, or Android-side parity review if we want to begin the second half of the parity audit

## Pass 028: `PinballDataCache` fix-now cleanup

Primary files:
- `Pinball App 2/Pinball App 2/data/PinballDataCache.swift`
- `Pinball App 2/Pinball App 2Tests/PinballDataCacheTests.swift`
- Android reference only:
  - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCache.kt`

Changes made in this pass:
- added a `cacheGeneration` guard inside iOS `PinballDataCache` so detached manifest-resource revalidations and detached remote-image revalidations cannot write back to disk or index state after `clearAllCachedData()` or the legacy destructive reset path has advanced the cache generation
- upgraded in-flight revalidation bookkeeping from path-only/image-key-only sets to generation-tagged dictionaries so an old detached task cannot clear the in-flight marker for a newer revalidation of the same resource after a cache reset
- changed iOS update-log checkpointing to compute the newest `generatedAt` across the full event list instead of assuming `events.first` is newest
- added focused unit coverage for the checkpoint helper in `PinballDataCacheTests.swift` so the iOS behavior and Android parity contract are pinned to an explicit expectation

Behavioral outcome:
- clearing cache on iOS now prevents older detached revalidation work from silently repopulating `resources/` or `remote-images/` afterward
- iOS update-log scan progress now matches Android’s more defensive “newest event wins” behavior even if the server ever returns events out of order
- the fix intentionally covers both hosted manifest resources and remote image disk cache because both shared the same post-clear stale-write risk

Android parity notes:
1. Android already had the desired checkpoint behavior conceptually; no Android change is needed for the `events.first` drift because the Kotlin cache computes the newest timestamp defensively today.
2. Android still does not have the iOS-style cache-generation/write guard around stale detached revalidation writes after a clear/reset.
3. When Android cleanup starts, mirror the iOS `cacheGeneration` plus generation-tagged in-flight marker pattern unless there is a deliberate reason to keep Android’s current semantics.

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 072: GameRoom machine shell and sheet-router cleanup

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineView.swift`

Changes made in this pass:
- extracted the machine screen body into named sections for the hero image, machine header, subview picker, subview content, unavailable-state message, and delete-alert bindings
- moved the large `activeInputSheet` switch into a dedicated `inputSheetContent(for:machine:)` helper so the root body no longer mixes navigation chrome, alerts, and input-sheet routing inline

Behavioral outcome:
- no intended front-facing behavior changed
- the machine screen now reads as a route shell with explicit seams for screen chrome, subview routing, and sheet routing instead of one large inline body

Hidden contract surfaced in this pass:
1. `GameRoomMachineView` was acting as both the screen shell and the full machine-input sheet router
2. the sheet switch itself is still large because it owns many GameRoom event-entry contracts, but those contracts are now isolated behind one explicit helper instead of being visually buried in the root body
3. this was iOS-only structural cleanup, so there was no Android parity change in this pass

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 073: GameRoom machine summary/input panel cleanup

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineView.swift`

Changes made in this pass:
- extracted the machine summary view into named `snapshotSummaryPanel`, `recentMediaPanel`, and `mediaAttachmentTile` helpers
- extracted the machine input button groups into a shared `inputCategoryPanel` plus named grid-column helpers
- resolved a compile-only refactor slip during this pass by correcting the snapshot panel type to `OwnedMachineSnapshot` before final verification

Behavioral outcome:
- no intended front-facing behavior changed
- the summary and input subviews are easier to audit because the metrics panel, media panel, media tile behavior, and repeated input-grid scaffolding are now separated instead of interleaved

Hidden contract surfaced in this pass:
1. the summary tab is really two distinct concerns: current machine health snapshot and recent attached media
2. the input tab was using the same grid/button presentation contract for service, issue, and ownership/media actions even though that shared structure was hidden by repetition
3. this was iOS-only structural cleanup, so there was no Android parity change in this pass

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 074: Cross-platform GameRoom reminder-contract hardening

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomModels.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomStore.kt`

Changes made in this pass:
- moved the hidden “active inventory machine” rule into model-owned helpers on both platforms instead of repeating `active || loaned` checks inline in the GameRoom store
- moved the hidden play-log rule into model-owned event helpers on both platforms so the “only custom/custom events with a non-negative total count toward current plays” contract is explicit instead of being buried in store-private helpers
- moved reminder task-to-event mapping into model-owned task helpers on both platforms instead of keeping those switches inside the store
- changed effective reminder resolution on both platforms to merge persisted machine-specific reminder configs over the default reminder set instead of using an all-or-nothing fallback, so partial persisted config state no longer silently disables the missing default tasks

Behavioral outcome:
- no intended front-facing behavior changed for normal current app usage
- GameRoom still shows the same current-play and due-task values for machines that rely on the default reminder set
- if any machine ever has partial persisted reminder config state, the app now behaves defensively by preserving the missing default reminder tasks instead of silently dropping them

Hidden contract surfaced in this pass:
1. GameRoom’s play-count and reminder semantics were still real runtime rules, but they were spread across store-private helpers instead of living with the relevant model types
2. the old reminder resolution path treated “any saved config exists” as “the full reminder contract exists,” which meant partial config state could silently erase defaults even though there is no current UI that intentionally writes a complete custom reminder set
3. this was the cleanest remaining must-fix-adjacent hidden behavior seam after the earlier cache, scanner, restore-failure, and dashboard passes were closed

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 075: Cross-platform duplicate-collision warning policy

Primary files:
- `Pinball App 2/Pinball App 2/practice/ResolvedLeagueMachineMappings.swift`
- `Pinball App 2/Pinball App 2/practice/ResolvedLeagueTargets.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogLoader.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ResolvedLeagueMachineMappings.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ResolvedLeagueTargets.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogLoader.kt`

Changes made in this pass:
- added developer-visible duplicate warnings to the league machine-mapping parsers on both platforms when the same normalized machine key appears more than once
- added developer-visible duplicate warnings to the resolved league-target score maps on both platforms when the same `practiceIdentity` appears more than once
- added developer-visible duplicate warnings to the GameRoom slug-match loaders on both platforms when multiple catalog records claim the same normalized slug key
- preserved the existing deterministic fallback behavior for each path instead of changing winner selection rules in this pass:
  - league machine mappings still use later-row replacement
  - resolved league target scores still use later-row replacement
  - GameRoom slug matches still keep the first-seen slug owner

Behavioral outcome:
- no intended front-facing UI change
- ambiguous upstream data is no longer completely silent during development and QA
- runtime behavior stays stable because the existing winners are still used while the collisions are now surfaced in logs

Hidden contract surfaced in this pass:
1. duplicate-resolution was not one policy; it was several different silent policies spread across league and GameRoom loaders
2. the approved cleanup direction here is “warn and keep deterministic fallback,” not “hard fail the feature” and not “change every path to one new winner rule”
3. the catalog-group representative collapse inside `preferredGame(in:)` remains intentionally unchanged in this pass because it is tied to a broader variant-fidelity decision rather than a pure duplicate-key collision

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 076: Cross-platform Practice key fallback parity

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeIdentityKeying.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeIdentityKeying.kt`

Changes made in this pass:
- aligned the iOS Practice-side `canonicalPracticeKey` fallback with the existing library model contract so it now uses `practiceIdentity`, then `opdbGroupID`, then `slug`
- aligned the Android Practice-side `practiceKey` helper with the same fallback order so Practice state migration, dropdown dedupe, and lookup paths no longer skip `opdbGroupId`
- left the broader variant-grouping policy unchanged; this pass only fixes an internal parity mismatch in how existing grouped identities are derived

Behavioral outcome:
- no intended front-facing UI change for normal current data
- Practice is now more defensive when older or partially-enriched library rows rely on OPDB group identity instead of an explicit `practiceIdentity`
- iOS and Android now derive grouped Practice identities from the same fallback chain before any future variant-policy decision is made

Hidden contract surfaced in this pass:
1. both platforms already had a stronger library-level grouped-identity fallback, but the Practice feature layer was still using a weaker `practiceIdentity -> slug` shortcut in one of its main canonicalization paths
2. that meant Practice dropdown dedupe, state migration, and legacy-key recovery could disagree with the rest of the library model about which rows belong to the same grouped machine family
3. this is a safe parity correction, not the broader product decision about whether Practice history should remain grouped across nearby variants or eventually split them

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 077: Variant-fidelity policy decision recorded

Primary files:
- review only:
  - `docs/review/ios-sequential-code-review.md`

Decision recorded in this pass:
- Practice should continue grouping progress/history/dropdowns by machine family identity rather than splitting by exact variant
- Library and GameRoom should continue preserving more exact variant fidelity where that detail exists for ownership, import, media, and resource matching
- future cleanup work should treat this as an intentional cross-feature policy, not an accidental inconsistency

Behavioral outcome:
- no code change was required because the current app already mostly behaves this way
- the earlier `canonicalPracticeKey` fallback parity fix remains in place so both platforms group families consistently when `practiceIdentity` is absent
- variant-aware GameRoom and Library behavior remains intentionally unchanged

Hidden contract surfaced in this pass:
1. Practice, Library, and GameRoom do not share one universal variant rule; they have different roles, and the grouped Practice rule is now an explicit product decision rather than an unresolved cleanup question
2. future parity work should avoid “helpfully” splitting Practice stats/history by exact variant unless that migration is intentionally approved
3. the remaining work in this area is mostly naming, documentation, and future UI clarity, not a must-fix runtime bug

## Pass 078: Cross-platform IFPA last-good snapshot fallback

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeIFPAProfileScreen.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeIfpaProfileScreen.kt`

Changes made in this pass:
- added lightweight per-player last-good IFPA profile snapshot caching on both platforms, stored locally in app preferences rather than mixed into broader Practice persistence
- changed both screens to load any cached snapshot immediately for the current player before attempting the live IFPA HTML scrape
- changed both screens to keep showing the cached snapshot when a refresh fails, with an explicit “may be outdated” warning plus retry action instead of dropping straight to an empty error state
- kept the live scrape as the source of truth; successful refreshes still replace the cached snapshot
- fixed an adjacent iOS state-ownership bug in the same screen where the previous player’s loaded profile could survive an IFPA ID change because the screen state was not reset per-player

Behavioral outcome:
- front-facing IFPA content is unchanged when the live scrape succeeds
- when IFPA is temporarily unavailable or changes markup, the app now degrades more gracefully by showing the most recent saved public snapshot for that player instead of only an error card
- the fallback warning is intentionally explicit so stale data is not mistaken for a live refresh

Hidden contract surfaced in this pass:
1. both platforms were already relying on brittle live HTML scraping, but neither one had a last-good cache or soft-degradation path despite the feature being user-facing and network-dependent
2. the approved durability policy here is “live scrape first, cached snapshot fallback on failure,” not “treat cached data as authoritative forever” and not “remove the feature”
3. iOS and Android now share the same persistence boundary for this feature: local, screen-owned cache keyed by IFPA player ID

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 079: Cross-platform GameRoom hydration asset-policy split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryDataLoader.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`

Changes made in this pass:
- split the old one-size-fits-all GameRoom template matcher into two explicit paths on both platforms:
  - visual template matching for playfield/backglass-style assets and display-name fallback
  - content template matching for rulesheets, videos, and game-info-style assets
- removed the permissive title-only fallback from GameRoom overlay template hydration so borrowed assets stay anchored to OPDB identity/group matches instead of jumping across unrelated same-title rows
- kept image fallback permissive within the same group by continuing to prefer exact/nearby variant art when available, while still allowing group-level image fallback and keeping curated/template image overrides ahead of generic OPDB art
- changed rulesheet and video hydration to come only from OPDB-group / practice-identity scoped content matches rather than whichever visual template happened to win
- aligned `gameinfo` with the same group-scoped content template path so rules/content assets stay together instead of drifting with alias-specific imagery

Behavioral outcome:
- GameRoom-backed Library rows still get rich image fallback, including alias-specific overrides when available
- rulesheets and videos now follow the group-level machine identity rule you approved instead of piggybacking on the image matcher
- future alias mismatches should be limited to visuals within the same OPDB group, not strategy/content assets

Hidden contract surfaced in this pass:
1. the old shared matcher was quietly making one decision serve two different product needs: “which image looks best for this machine?” and “which rules/content belongs to this machine?”
2. your approved policy is now explicit in code and in the audit: visuals may be alias-sensitive within a group, but rulesheets/videos belong to the OPDB group / practice identity
3. the remaining cleanup in this seam is mostly naming and documentation, not another runtime parity bug

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 080: Live duplicate-conflict snapshot

Primary files:
- `docs/review/live-duplicate-conflict-report-2026-03-27.md`
- review only:
  - `Pinball App 2/Pinball App 2/practice/ResolvedLeagueMachineMappings.swift`
  - `Pinball App 2/Pinball App 2/practice/ResolvedLeagueTargets.swift`
  - `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogLoader.swift`
  - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ResolvedLeagueMachineMappings.kt`
  - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ResolvedLeagueTargets.kt`
  - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogLoader.kt`

Changes made in this pass:
- pulled the live hosted `lpl_machine_mappings_v1.json`, `lpl_targets_resolved_v1.json`, and `opdb_export.json` payloads on `2026-03-27`
- checked them against the app's current duplicate-warning rules instead of a looser “looks similar” heuristic
- recorded the concrete result in a dedicated report so duplicate cleanup can use real examples rather than guesses

Behavioral outcome:
- no runtime code changed
- the current live hosted data does not trigger any of the three duplicate-warning paths
- the only notable duplicate-like case in current live data is an intentional alias cluster in league mappings: `TMNT` plus `Teenage Mutant Ninja Turtles` both resolve to practice identity `Gd2Xb`
- that alias pair is extra-interesting because `LibraryGameLookup.machineAliases` already carries the same equivalence app-side, but the adjacent admin source repo still contains both raw machine-name forms across seasons, so the dual-row mapping is not an obvious delete

Hidden contract surfaced in this pass:
1. there is now a real distinction between duplicate conflicts and intentional alias coverage; current live data has the latter but not the former
2. the duplicate developer warnings are still worth keeping because they protect future data publishes even though the current snapshot is clean
3. if we decide to collapse intentional alias rows later, the `TMNT` / `Teenage Mutant Ninja Turtles` mapping pair is the first concrete case to review rather than an abstract policy discussion, but that choice belongs with the admin/source-data workflow because the raw league CSV still uses both names

Verification:
- live hosted data snapshot fetched successfully from `https://pillyliu.com/pinball/data/...` with browser-style request headers

## Pass 081: Architecture doc generation path cleanup

Primary files:
- `scripts/generate_architecture_blueprint.sh`
- `scripts/render_mermaid_blocks.py`
- `scripts/render_architecture_pdf_upgraded.py`
- `README.md`
- `archive/README.md`
- `archive/2026-03-27-retired-scripts/scripts/render_architecture_pdf.py`
- `.gitignore`

Changes made in this pass:
- archived the older `scripts/render_architecture_pdf.py` helper because it no longer supports the current Mermaid-heavy blueprint path and had no active references outside historical notes
- added one active wrapper script, `scripts/generate_architecture_blueprint.sh`, so the current blueprint export flow is explicit instead of spread across two manual Python steps
- made that wrapper self-bootstrap a local ignored virtualenv for `reportlab` so the PDF export no longer depends on whatever the machine Python happens to have installed
- documented the active blueprint source and generation command in `README.md`
- logged the newly archived renderer in `archive/README.md`
- removed the stale ignore entry for the older rendered-mermaid PDF filename that no longer matches the active output path

Behavioral outcome:
- repo docs now have one explicit active print-layout generation path for the architecture blueprint
- that path now works from a clean shell without requiring a manual global `reportlab` install first
- the old non-Mermaid renderer is preserved for local history under `archive/` instead of lingering beside the active tooling
- future blueprint refreshes can target `Pinball_App_Architecture_Blueprint_latest_print_layout.pdf` consistently from one command

Hidden contract surfaced in this pass:
1. the upgraded renderer and Mermaid block renderer were already the real active path, but the repo was still carrying an older alternate renderer without any explicit retirement step
2. that overlap made the doc-tooling contract look optional when it had effectively already converged on one path
3. this is repo maintenance only, not app runtime behavior, so there is no Android parity implementation to mirror

Verification:
- `bash -n '/Users/pillyliu/Documents/Codex/Pinball App/scripts/generate_architecture_blueprint.sh'`
- result: syntax check passed
- `./scripts/generate_architecture_blueprint.sh`
- result: generated `/Users/pillyliu/Documents/Codex/Pinball App/Pinball_App_Architecture_Blueprint_latest_print_layout.pdf`

## Pass 082: Source-side TMNT normalization decision

Primary files:
- admin source/workflow follow-up:
  - `../PinProf Admin/workspace/data/source/LPL_Stats.csv`
  - `../PinProf Admin/workspace/data/source/LPL_Targets.csv`
  - `../PinProf Admin/workspace/data/source/lpl_machine_mappings_v1.json`
  - `../PinProf Admin/workspace/data/published/lpl_targets_resolved_v1.json`
  - `../PinProf Admin/docs/LPL_LEAGUE_DATA_WORKFLOW.md`
- app-review record:
  - `docs/review/live-duplicate-conflict-report-2026-03-27.md`

Changes made in this pass:
- normalized all historical `TMNT` machine-name rows in the admin `LPL_Stats.csv` source to `Teenage Mutant Ninja Turtles`
- normalized the single `TMNT` row in admin `LPL_Targets.csv`
- removed the now-redundant `TMNT` row from admin `lpl_machine_mappings_v1.json`
- regenerated admin `lpl_targets_resolved_v1.json` so the published derived targets data matches the normalized source
- updated the admin `LPL_LEAGUE_DATA_WORKFLOW.md` machine-normalization rules so future stats intake must keep using `Teenage Mutant Ninja Turtles`
- updated the duplicate report to note that the source-side alias case has now been resolved locally and is only pending publish/deploy

Behavioral outcome:
- no app-runtime code changed in this repo
- the concrete duplicate-like league alias case is now resolved in the admin source data rather than left as an open cleanup question
- once the admin data is published, the live hosted duplicate snapshot should stop needing the `TMNT` alias row entirely

Hidden contract surfaced in this pass:
1. the earlier duplicate-like `TMNT` pair was not arbitrary noise; it existed because historical league source CSVs had never been fully backfilled to the full machine name
2. the right long-term fix was source normalization plus an intake rule, not just app-side alias tolerance
3. the app duplicate warnings remain valuable because they still guard future publishes even after this concrete alias case is cleaned up at the source
4. `../PinProf Admin/workspace/data/source/lpl_machine_mappings_v1.json` is currently a local untracked workspace source file, so its cleanup is real in the admin workspace but not yet backed by tracked repo history there

Verification:
- admin source counts after normalization:
  - `LPL_Stats.csv`: `TMNT=0`, `Teenage Mutant Ninja Turtles=466`
  - `LPL_Targets.csv`: `TMNT=0`, `Teenage Mutant Ninja Turtles=1`
  - `lpl_machine_mappings_v1.json`: `TMNT=0`, `Teenage Mutant Ninja Turtles=1`
- `python3 scripts/publish/build_lpl_targets_resolved.py`
- result: wrote updated `../PinProf Admin/workspace/data/published/lpl_targets_resolved_v1.json` with `39/39 matched`

## Pass 083: Publish and live TMNT verification

Primary files:
- admin publish path:
  - `../PinProf Admin/scripts/publish/rebuild-shared-pinball-payload.sh`
  - `../Pillyliu Pinball Website/deploy.sh`
- review record:
  - `docs/review/live-duplicate-conflict-report-2026-03-27.md`

Changes made in this pass:
- ran the real website deploy path so the normalized league source data and regenerated resolved targets were published to `pillyliu.com`
- rechecked the hosted league payloads directly after deploy and updated the duplicate report to reflect the live post-publish state

Behavioral outcome:
- the hosted league payloads now use `Teenage Mutant Ninja Turtles` consistently across stats, targets, machine mappings, and resolved targets
- the concrete duplicate-like alias case found earlier in the review is no longer present in the live hosted app data

Hidden contract surfaced in this pass:
1. the actual publish entrypoint is still the legacy website repo deploy script, which rebuilds from `PinProf Admin` first and only then syncs the live site
2. duplicate cleanup at the source is not really “done” until the hosted payloads are verified after deploy, because the apps read `pillyliu.com`, not the local admin workspace

Verification:
- hosted payload check on `2026-03-27` after deploy:
  - `LPL_Stats.csv`: `TMNT=0`, `Teenage Mutant Ninja Turtles=466`
  - `LPL_Targets.csv`: `TMNT=0`, `Teenage Mutant Ninja Turtles=1`
  - `lpl_machine_mappings_v1.json`: `TMNT=0`, `Teenage Mutant Ninja Turtles=1`
  - `lpl_targets_resolved_v1.json`: `TMNT=0`, `Teenage Mutant Ninja Turtles=1`
- deploy result: `Deploy complete.`

## Pass 071: GameRoom edit/archive chrome cleanup

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

Changes made in this pass:
- extracted the `GameRoomEditMachinesView` panel stack into a named `panelStack` section
- centralized the initial editor bootstrap work behind `handleAppear()`
- named the selected-machine variant list with `selectedMachineVariantOptions`
- extracted the archive screen row list and footer into `archiveListContent` and `archiveSummaryFooter`

Behavioral outcome:
- no intended front-facing behavior changed
- the remaining GameRoom settings root flow is easier to audit because disclosure layout, bootstrap behavior, selected-machine support data, archive rows, and archive summary are now explicit seams instead of inline body logic

Hidden contract surfaced in this pass:
1. the edit-machines screen was already doing two independent bootstrap tasks on appear: selection normalization and catalog-search indexing
2. the archive screen was simpler than it looked; most of the complexity was presentation glue, not archival business logic
3. this was iOS-only structural cleanup, so there was no Android parity change in this pass

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 069: GameRoom screen routing cleanup

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomScreen.swift`

Changes made in this pass:
- extracted the `NavigationStack` destination switch into a named `destination(for:)` helper
- extracted the initial GameRoom bootstrap task into `loadDataIfNeeded()`

Behavioral outcome:
- no intended front-facing behavior changed
- the GameRoom screen now reads more clearly as route wiring plus bootstrap flow instead of mixing both concerns inline

Hidden contract surfaced in this pass:
1. the screen itself is just the route shell; the real work is still delegated to the store, loader, and destination views
2. making the route/dataload seams explicit reduces the chance of subtle drift when GameRoom navigation evolves later
3. this was iOS-only structural cleanup, so there was no Android parity change in this pass

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 070: Practice settings card-stack cleanup

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`

Changes made in this pass:
- extracted the Practice settings card stack in `PracticeSettingsSectionView` into a named `settingsCards` section
- kept the two destructive alert flows attached at the root, but separated them from the card layout so the settings body no longer mixes layout and alert definitions inline

Behavioral outcome:
- no intended front-facing behavior changed
- the Practice settings screen is easier to audit because the card stack and destructive recovery prompts are now clearly separated concerns

Hidden contract surfaced in this pass:
1. the user-facing settings cards were already stable, but the destructive prompts were visually buried inside the same long body definition
2. the actual sensitive contract here is still the recovery/reset confirmation flow, which remains unchanged and explicitly isolated
3. this was iOS-only structural cleanup, so there was no Android parity change in this pass

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'platform=iOS Simulator,id=BC731628-5C08-40EB-8B42-A565A19086D9' -only-testing:'Pinball App 2Tests/PinballDataCacheTests' test`
- result: blocked by an unrelated pre-existing test-target compile failure in `Pinball App 2Tests/ScoreScannerServicesTests.swift` because those tests still call `ScoreParsingService.bestCandidate`, which no longer exists on the current app code

Open follow-up items from this pass:
1. if you want fully reproducible coverage for the clear-cache race itself, iOS still needs a test harness that can inject a stubbed `URLSession`/`URLProtocol` into `PinballDataCache`; today the new test coverage only locks down the checkpoint behavior
2. Android parity work should revisit the same clear-cache race, not just the update-log checkpoint logic
3. the next `Fix now` item remains `ScoreScannerViewModel` queue/actor ownership cleanup

## Pass 028 summary

Safe cleanup changes made:
- none; this pass was behavior-focused runtime cleanup

Verification:
- app build passed
- new targeted test intent was blocked by unrelated existing test-target API drift in `ScoreScannerServicesTests`

Outcome:
- the iOS half of `Fix now` item 1 is now implemented and logged with explicit Android follow-up guidance

Next files queued:
- `Pinball App 2/Pinball App 2/practice/ScoreScannerViewModel.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerView.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerServices.swift`

## Pass 029: scanner queue-ownership cleanup

Primary files:
- `Pinball App 2/Pinball App 2/practice/ScoreScannerViewModel.swift`
- Android reference reviewed for parity direction:
  - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerController.kt`

Changes made in this pass:
- made `captureQueue` the explicit owner for iOS live-scanner gate state that had been mixed across direct access and queued access, especially `processingPaused`, `isProcessingFrame`, `lastOCRTime`, and `latestSnapshot`
- changed `retake()` to synchronously reset capture-owned gating state before the main-thread UI reset so retake no longer leaves a timing window where one more OCR callback can observe partially reset state
- changed `freeze(...)` to mark `processingPaused` on `captureQueue` before continuing with crop/preview work so the live frame gate sees the pause immediately
- collapsed `handleCapturedFrame(...)` into a single capture-queue gate entry point (`beginLiveProcessing`) plus a matching completion path (`finishLiveProcessing`) so live throttling, pause checks, and “one OCR at a time” decisions all share one serialization seam
- updated `preferredFreezeReading()` to read `latestSnapshot` through `captureQueue` instead of reaching across that state directly

Behavioral outcome:
- iOS freeze/retake/live-OCR transitions now have one clear owner for the control flags that decide whether another frame should process
- the most likely “weird one-off” outcomes from the old mixed access pattern are reduced: a frame slipping through right after freeze, retake racing one last OCR pass, or stale snapshot state participating in preferred-freeze selection
- this is intentionally a structural ownership cleanup, not a scanner UX rewrite

Android parity notes:
1. Android does have a live scanner counterpart in `ScoreScannerController.kt`, so this is not hypothetical future parity work.
2. The Android controller still spreads scanner gate state across `@Volatile` fields, Compose state, and coroutine callbacks, so the right parity direction is “single owner for gating state,” not “copy the old iOS mixed-access pattern.”
3. When Android cleanup starts, use the same principle as this iOS pass: one serialization seam should own pause/throttle/in-flight gating for freeze and retake.

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Open follow-up items from this pass:
1. the scanner test target is still blocked by unrelated pre-existing API drift in `ScoreScannerServicesTests.swift`, so this ownership cleanup does not yet have direct automated regression coverage
2. Android scanner parity should get its own focused audit pass before implementation because its current controller also carries mixed-state risk
3. the next `Fix now` items remain `GameRoomStateCodec` corruption handling, Practice dashboard staleness, and `AboutScreen` cleanup

## Pass 029 summary

Safe cleanup changes made:
- none; this pass was concurrency-ownership cleanup in active runtime code

Verification:
- app build passed

Outcome:
- iOS `ScoreScannerViewModel` now has a clearer single-owner state seam for live OCR gating, with explicit Android parity guidance recorded

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStateCodec.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`

## Pass 108: Settings import/search and source-persistence cleanup

Primary files:
- `Pinball App 2/Pinball App 2/settings/SettingsImportScreens.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsDataIntegration.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsImportScreens.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsDataIntegration.kt`

Changes made in this pass:
- centralized iOS venue-search state transitions behind `performVenueSearch(...)` so text-query search and current-location search no longer duplicate `hasSearched`, `lastSearchContext`, `searchResults`, `errorMessage`, and `isSearching` updates
- added shared iOS helpers for venue-provider ID normalization and imported-source persistence/update so manufacturer, venue, tournament, and refresh flows no longer each reimplement the same upsert/snapshot boilerplate
- mirrored the same structural cleanup on Android with `performVenueSearch(...)`, `persistSettingsSource(...)`, `updateSettingsSource(...)`, `publishSettingsSourceMutation(...)`, and a shared venue provider-ID helper
- normalized Settings venue import to use one effective search-context rule on both platforms instead of repeating inline `lastSearchContext` fallback logic

Behavioral outcome:
- no intended front-facing behavior change
- Settings search/import results, source creation, and refresh behavior stay the same on iOS and Android

Outdated or conflicting code resolved in this pass:
1. the venue-import/search path had grown two parallel search-state machines per platform; that duplication is now collapsed into one owner per platform
2. Settings source persistence had near-identical manufacturer/venue/tournament/add/refresh logic, which made provider-ID normalization and future source-state changes easy to drift

Outdated or conflicting code surfaced but intentionally left for review:
1. venue import still does not have a dedicated importing state on iOS
2. Android venue import still reuses the generic `searching` state for import progress
3. those are front-facing loading-state changes, so they are logged for a separate UX decision instead of being silently changed during cleanup

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest`
- result: `BUILD SUCCESSFUL`

## Pass 108 summary

Safe cleanup changes made:
- removed duplicated Settings search/import state handling
- removed duplicated Settings source upsert/update plumbing

Outcome:
- the Settings import flow now has clearer internal ownership and less hidden parity drift risk, while the visible import-progress UX seam is explicitly logged for later review instead of being changed implicitly

## Pass 109: Settings refresh and tournament-import helper cleanup

Primary files:
- `Pinball App 2/Pinball App 2/settings/SettingsScreen.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsImportScreens.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsScreenState.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsImportScreens.kt`

Changes made in this pass:
- centralized iOS Settings source refresh error handling behind `performSourceRefresh(...)` so venue/tournament refresh paths no longer duplicate the same guard, publish, and error plumbing
- centralized Android Settings source mutation completion and refresh handling behind `completeSourceMutation(...)` and `refreshImportedSource(...)`
- pulled tournament import fetch/validation/error mapping behind dedicated helpers on iOS and Android instead of leaving the “fetch, reject empty OPDB machine list, map error message” flow inline inside each button action
- added explicit `canImportTournament` state on iOS and Android so the tournament-import button uses one named enablement rule instead of repeating the raw expression

Behavioral outcome:
- no intended front-facing behavior change
- tournament import still behaves the same: invalid IDs stay blocked, empty Match Play arena lists still show the same error, and successful imports still return to Settings home

Outdated or conflicting code resolved in this pass:
1. Settings refresh paths had started drifting into venue-specific and tournament-specific controller copies on both platforms; the shared helpers now keep that logic in one place per platform
2. tournament import validation for “no OPDB-linked arenas” was an inline hidden contract in each screen; it is now named and explicit

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest`
- result: `BUILD SUCCESSFUL`

## Pass 109 summary

Safe cleanup changes made:
- removed duplicated Settings refresh plumbing
- removed duplicated tournament import fetch/validation plumbing

Outcome:
- the remaining Settings import flow reads more like explicit state ownership and less like repeated controller glue, with current UX behavior preserved

## Pass 100: Library file-ownership rename cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryExtractionSupport.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySourceStores.kt`

Changes made in this pass:
- renamed the stale iOS extraction helper file from `LibraryCatalogStore.swift` to `LibraryExtractionSupport.swift` so the filename matches its current job after the earlier Library extraction work
- renamed the stale Android source/import persistence file from `LibraryCatalogStore.kt` to `LibrarySourceStores.kt` because it no longer owns catalog storage and had become a misleading file anchor during review

Behavioral outcome:
- no runtime behavior change
- the Library architecture is easier to audit because file names now match current ownership boundaries instead of earlier pre-extraction responsibilities

Hidden contract surfaced in this pass:
1. Xcode was still compiling the renamed iOS file cleanly without a visible `project.pbxproj` edit, which confirms this project is currently relying on filesystem-synced group behavior for many Library file moves
2. the old `LibraryCatalogStore` name had become actively misleading on both platforms: on iOS it only wrapped extraction/filtering, while on Android it owned source-state and imported-source persistence

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest`
- result: `BUILD SUCCESSFUL`

## Pass 101: iOS Library domain/view-model ownership split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryViewModel.swift`
- `Pinball App 2/Pinball App 2/library/LibrarySourceModels.swift`
- `Pinball App 2/Pinball App 2/library/LibrarySearchSupport.swift`

Changes made in this pass:
- renamed `LibraryDomain.swift` to `LibraryViewModel.swift` because the surviving file content was entirely the `PinballLibraryViewModel`
- moved `PinballLibrarySourceType`, `PinballLibrarySource`, and `PinballLibrarySortOption` into `LibrarySourceModels.swift`
- moved the shared search-token/search-match helpers into `LibrarySearchSupport.swift`

Behavioral outcome:
- no intended runtime behavior change
- the remaining iOS Library domain layer now has clearer ownership boundaries: source models, search helpers, and the view model no longer hide inside one vaguely named file

Outdated or conflicting code surfaced:
1. `LibraryViewModel.swift` still persists preferred source selection in two places: the raw `preferred-library-source-id` `UserDefaults` key and `PinballLibrarySourceStateStore.selectedSourceID`
2. that duplicate persistence is a stale contract from the older Library state model. It is currently harmless, but it is hidden duplication and a future cleanup candidate once we decide whether the raw defaults key should be retired entirely
3. the raw `preferred-library-source-id` key is not Library-local yet; `PracticeQuickEntrySheet.swift` and `PracticeStoreDataLoaders.swift` still read it, so retiring it will need a coordinated Library/Practice cleanup instead of a one-file change

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 102: Android Library source-store split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySourceStateStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryImportedSourcesStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySourceStoreSupport.kt`

Changes made in this pass:
- split `LibrarySourceStores.kt` into dedicated files for source-state persistence, imported-source persistence, and shared store-support helpers/events
- kept the seeded default source data with `ImportedSourcesStore`, since those defaults are only used when imported sources are first bootstrapped
- moved the shared `LibrarySourceEvents` flow plus JSON/map normalization helpers into `LibrarySourceStoreSupport.kt`

Behavioral outcome:
- no intended Android runtime behavior change
- Android now mirrors the iOS Library ownership shape more closely: source-state persistence and imported-source persistence are no longer hidden inside the same broad file

Outdated or conflicting code surfaced:
1. Android still keeps both the seeded-default source lists and imported-source persistence in one file, which is acceptable now but still a minor ownership hotspot if the seeded-source catalog grows further
2. the bigger stale seam is no longer hidden: the old combined `LibrarySourceStores.kt` file had become a catch-all for unrelated responsibilities

Verification:
- `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest`
- result: `BUILD SUCCESSFUL`

## Pass 102 summary

Safe cleanup changes made:
- renamed stale Library support files to match current responsibilities
- split the iOS Library domain/view-model layer into dedicated source-model, search-support, and view-model files
- split Android Library source persistence into dedicated state-store, imported-source-store, and shared-support files

Verification:
- iOS app build passed
- Android compile plus unit tests passed

Outcome:
- the Library cleanup now has much clearer file ownership on both platforms, and the remaining outdated seam worth fixing next is the duplicate preferred-source persistence in `LibraryViewModel.swift`

## Pass 103: Shared preferred Library source ownership cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/LibrarySourceStateStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryViewModel.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreDataLoaders.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeQuickEntrySheet.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryBrowsingState.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeLibraryIntegration.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeQuickEntrySheet.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeKeys.kt`

Changes made in this pass:
- made the Library source-state store the single live owner of the preferred Library source on iOS
- added `PinballLibrarySourceStateStore.setSelectedSourceID(_:)` so iOS Library and Practice stop hand-editing `selectedSourceID`
- removed iOS reads and writes to the old raw `preferred-library-source-id` key from `LibraryViewModel.swift`, `PracticeStoreDataLoaders.swift`, and `PracticeQuickEntrySheet.swift`
- made the Android Library source-state store the single live owner of preferred Library source selection as well
- removed Android Library/Practice reads and writes of `KEY_PREFERRED_LIBRARY_SOURCE_ID`
- simplified Android `PracticeLibraryIntegration` so it no longer needs injected raw preference closures just to mirror source selection state
- simplified Android `resolveLibrarySelection(...)` so it now resolves from source-state plus in-memory current selection, not a second saved-source channel

Behavioral outcome:
- no intended front-facing behavior change
- Library and Practice still remember the last chosen Library source across the same flows as before
- the hidden split-brain contract is gone: Library and Practice no longer keep a second raw preference key in parallel with source-state selection

Outdated or conflicting code resolved in this pass:
1. the older `preferred-library-source-id` raw key path is no longer part of live selection flow
2. repo-wide search after the change found no remaining live references to `preferred-library-source-id`, `KEY_PREFERRED_LIBRARY_SOURCE_ID`, or the old iOS defaults-key constants
3. that means any future reappearance of this key would now be a fresh stale seam, not a tolerated legacy contract

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest`
- result: `BUILD SUCCESSFUL`

## Pass 103 summary

Safe cleanup changes made:
- removed the shared raw preferred-source key path and made Library source-state the only live owner of preferred source selection on both platforms

Verification:
- iOS app build passed
- Android compile plus unit tests passed

Outcome:
- the preferred Library source seam is now explicit and single-owned, and the next cleanup work can move on to other stale Library/Practice contracts instead of carrying this duplicate persistence path

## Pass 104: Shared preferred Library source resolution cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/LibrarySelectionSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryViewModel.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreDataLoaders.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryBrowsingState.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeLibrarySourceSelection.kt`

Changes made in this pass:
- added a shared iOS `resolvePreferredLibrarySource(...)` helper so Library and Practice stop carrying separate “pick saved source else current source else first source” logic
- updated iOS `LibraryViewModel` and `PracticeStoreDataLoaders` to use the shared resolver instead of duplicating the fallback chain locally
- updated Android `PracticeLibrarySourceSelection.kt` to delegate its preferred-source resolution to the shared Library browsing helper instead of keeping a parallel Practice-specific copy
- kept the resolution order the same on both platforms: saved source first, then current/default source, then first available source

Behavioral outcome:
- no intended front-facing behavior change
- Library and Practice now stay aligned by construction when deciding which source should be active after a load

Outdated or conflicting code resolved in this pass:
1. preferred-source choice no longer depends on near-duplicate resolver copies in Library and Practice
2. any future change to preferred-source fallback order now has one obvious place per platform instead of hidden drift between features

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest`
- result: `BUILD SUCCESSFUL`

## Pass 104 summary

Safe cleanup changes made:
- centralized preferred Library source resolution so Library and Practice share one rule on both platforms

Verification:
- iOS app build passed
- Android compile plus unit tests passed

Outcome:
- preferred source persistence and preferred source resolution are now separate but both explicit, which removes another hidden Library/Practice state seam

## Pass 105: Library source identity and removal-state parity cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/LibrarySourceIdentity.swift`
- `Pinball App 2/Pinball App 2/library/LibrarySourceStateStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryImportedSourcesStore.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySourceIdentity.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySourceStateStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryImportedSourcesStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`

Changes made in this pass:
- renamed the stale internal “built-in venue alias” naming on both platforms to “legacy Library source alias” so the code matches the new seeded-imported-source model
- renamed Android’s `BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID` to `GAME_ROOM_LIBRARY_SOURCE_ID` so the GameRoom synthetic source no longer pretends to be part of a retired built-in-source system
- added `removeSourcePreferences(...)` helpers to both source-state stores
- switched imported-source removal to use those helpers instead of each store manually editing part of the state payload
- tightened Android source-state mutation helpers so `setSelectedSort(...)` and `setSelectedBank(...)` stop loading state twice before saving

Behavioral outcome:
- no intended front-facing behavior change
- removing a Library source now clears all associated selection/sort/bank preference state consistently on both platforms

Outdated or conflicting code resolved in this pass:
1. iOS source removal had been leaving behind stale `selectedSortBySource` and `selectedBankBySource` entries for deleted sources, while Android already cleared them; that parity mismatch is now gone
2. the remaining “built-in source” wording in live code is reduced to actual seed-db schema fields and historical docs, not active source-identity helpers

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest`
- result: `BUILD SUCCESSFUL`

## Pass 105 summary

Safe cleanup changes made:
- renamed stale source-identity helpers to match the post-built-in-source model
- aligned deleted-source preference cleanup between iOS and Android
- simplified Android source-state writes to use one loaded snapshot per mutation

Outcome:
- source identity and source removal behavior now read like the model the app actually uses today, and stale deleted-source preferences no longer linger on iOS

## Pass 106: Android Settings source-management ownership cleanup

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsScreenState.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsScreen.kt`

Changes made in this pass:
- moved Android Settings source-management actions out of `SettingsScreen.kt` inline closures and into `SettingsScreenState`
- gave the state object explicit methods for enable/pin, add manufacturer/venue/tournament, delete source, and refresh source
- kept route transitions and error handling in one owner instead of scattering them across the screen composable

Behavioral outcome:
- no intended front-facing behavior change
- Android Settings source management is now much closer to the iOS `SettingsViewModel` ownership model

Outdated or conflicting code resolved in this pass:
1. Android Settings had turned into a mixed screen/controller file with source mutation logic inline in the composable tree
2. that made it easier for route changes, error messages, and source-change notifications to drift across action paths; centralizing them in `SettingsScreenState` removes that hidden maintenance seam

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest`
- result: `BUILD SUCCESSFUL`

## Pass 106 summary

Safe cleanup changes made:
- moved Android Settings source-mutation logic behind named state methods instead of inline composable closures

Outcome:
- the Android Settings screen now reads more like UI and less like a controller bucket, which makes future parity cleanup with iOS much safer

## Pass 107: iOS Settings source-management ownership cleanup

Primary files:
- `Pinball App 2/Pinball App 2/settings/SettingsScreen.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsHomeSections.swift`

Changes made in this pass:
- centralized iOS Settings source-mutation success handling behind shared `publishSourceSnapshot(...)` and `reloadSourceState(...)` helpers in `SettingsViewModel`
- added a unified iOS `refreshSource(...)` entrypoint so the Settings UI no longer branches between venue/tournament refresh logic inline
- replaced the old Settings source-row display model with `SettingsManagedSourceItem`, which keeps the underlying `PinballImportedSourceRecord` attached to the row instead of forcing the row to look the record back up by ID later
- extracted dedicated private Settings views for the Library add-button strip and managed source table/rows so `SettingsHomeSections.swift` reads more like layout plus explicit actions
- added `syncSourceStateWithoutNotification()` so a failed “pin source” attempt now updates local toggle state without broadcasting a fake source-change notification

Behavioral outcome:
- no intended front-facing behavior change
- the Settings source table still shows the same rows, actions, and toggles as before

Outdated or conflicting code resolved in this pass:
1. iOS Settings source rows used to build a display-only row model, then re-query `viewModel.importedSources` by ID just to refresh the source; that hidden lookup seam is gone
2. a failed iOS pin attempt used to post `pinballLibrarySourcesDidChange` even though no source state changed, which could trigger unnecessary Settings/Library refresh churn; that false notification is now gone
3. iOS Settings now matches the Android direction more closely: source mutations are owned by state/model methods rather than scattered through view closures

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 107 summary

Safe cleanup changes made:
- cleaned up iOS Settings source-management ownership and removed a stale source-row relookup path
- stopped failed iOS pin attempts from emitting a false source-change notification

Verification:
- iOS app build passed

Outcome:
- iOS Settings source-management now has clearer ownership, fewer hidden lookups, and less accidental refresh churn

## Pass 096: Seeded default Library sources and built-in-source retirement

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryBuiltInSources.swift`
- `Pinball App 2/Pinball App 2/library/LibraryImportedSourcesStore.swift`
- `Pinball App 2/Pinball App 2/library/LibrarySourceStateStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryGame.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsScreen.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsHomeSections.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryBuiltInSources.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsHomeSections.kt`

Changes made in this pass:
- retired the active built-in-source default path on both platforms; fresh installs now seed imported Library sources instead of pretending venues are special built-ins
- added five first-run default sources on both platforms:
  - `The Avenue Cafe` (`venue--pm-8760`)
  - `Electric Bat Arcade` (`venue--pm-10819`)
  - `Stern` (`manufacturer-12`)
  - `Jersey Jack Pinball` (`manufacturer-74`)
  - `Spooky Pinball` (`manufacturer-95`)
- made those seeded defaults persist the first time they materialize, instead of disappearing on the next launch once source-state storage exists
- set fresh-install source state to `enabled + pinned + selected` in the requested order, with Avenue first, so Library is not empty and the visible Library source filter shows the intended starting set
- kept the seeding gate strict: if a user already has persisted imported sources or persisted Library source state, the new defaults do not get injected into that existing setup
- removed the Settings “Built-in venue” table split on both platforms; the Library settings UI now manages all sources through the imported-source model
- replaced the stale iOS `PinballGame` decode fallback from `"The Avenue Cafe"` to `"Unknown Source"` so malformed payloads no longer inherit an old single-venue assumption
- bundled the Avenue and Electric Bat machine-id snapshots directly into the first-run seed data so both default venues populate immediately without needing a first-refresh network round trip

Behavioral outcome:
- a truly fresh install now starts with a populated Library instead of an empty source list
- the initial visible Library source strip now opens on the user’s home venue first, then Electric Bat Arcade, then the three requested manufacturer sources
- existing users keep their current Library source setup untouched

Concrete data snapshot used:
- Avenue machine IDs were seeded from Pinball Map venue `8760`
- Electric Bat machine IDs were seeded from Pinball Map venue `10819`
- both venue snapshots were pulled on March 28, 2026 so the first-run defaults reflect current known machine lists at implementation time

Outdated/conflicting code surfaced in this pass:
1. `LibraryBuiltInSources.swift` and `LibraryBuiltInSources.kt` are now stale internal names. The active behavior is no longer “built-in sources”; the files mainly hold canonical source IDs, legacy alias migration, and GameRoom/Avenue shared IDs.
2. legacy Avenue/RLM migration helpers still exist for old saved-state repair, which is fine operationally, but the internal naming is now ahead-of-time cleanup debt rather than a live product model.

Recommended follow-up:
1. rename the `LibraryBuiltInSources` files to something neutral like `LibrarySourceIDs` once the current cleanup batch settles
2. if Electric Bat should display the full Pinball Map venue name (`Electric Bat Arcade / Yucca Tap Room`) instead of the shorter `Electric Bat Arcade`, make that a deliberate label choice later rather than inheriting it accidentally from provider data

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

Next files queued:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDataLoader.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`

## Pass 097: Rename built-in-source support file to source-identity support

Primary files:
- `Pinball App 2/Pinball App 2/library/LibrarySourceIdentity.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySourceIdentity.kt`

Changes made in this pass:
- renamed the stale `LibraryBuiltInSources.*` support files to `LibrarySourceIdentity.*` on both platforms
- kept behavior unchanged; this was a naming cleanup only

Why this rename:
- the files no longer define active built-in Library sources
- they now mainly hold canonical source IDs, legacy alias migration, and source-ID helper logic
- `LibrarySourceIdentity` matches the current responsibility much better than `LibraryBuiltInSources`

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 090: Library source/import store extraction

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`
- `Pinball App 2/Pinball App 2/library/LibrarySourceStateStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryImportedSourcesStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogModels.swift`

Changes made in this pass:
- moved library source-state persistence, migration, notification posting, and shared dictionary normalization helpers out of `LibraryCatalogStore.swift` into `LibrarySourceStateStore.swift`
- moved imported-source persistence, normalization, merge behavior, and provider inference out of `LibraryCatalogStore.swift` into `LibraryImportedSourcesStore.swift`
- moved the catalog-facing payload/model types into `LibraryCatalogModels.swift` so `LibraryCatalogStore.swift` no longer has to own both storage infrastructure and domain models in the same file
- kept the runtime behavior unchanged; this pass only changed file ownership and helper placement

Behavioral outcome:
- no intended UI or data-contract changes
- `LibraryCatalogStore.swift` is now more focused on legacy payload decode plus merge/resolution flow instead of also owning unrelated persistence infrastructure

Notes surfaced in this pass:
1. the earlier monolithic file had become the hidden owner for source-state storage, imported-source storage, normalized payload models, OPDB decode support, CAF support, and merge logic all at once
2. splitting out the storage seams makes later Android follow-through much safer because the iOS log now shows which concerns were runtime behavior and which were only local organization
3. this was iOS-only structural cleanup; no Android parity patch was needed because no product behavior changed

## Pass 091: Library catalog decoder and venue-support extraction

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogOPDBDecoding.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogVenueSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogModels.swift`

Changes made in this pass:
- moved the OPDB export decode path, synthetic PinProf Labs machine support, practice-identity curation decode, manufacturer option decode, and practice-catalog game decode into `LibraryCatalogOPDBDecoding.swift`
- moved public playfield override parsing, venue metadata overlay parsing, imported venue metadata resolution, CAF asset decode/grouping, and CAF library payload/extraction builders into `LibraryCatalogVenueSupport.swift`
- removed the duplicated type and helper blocks from `LibraryCatalogStore.swift`, leaving it focused on legacy payload decode plus merged and normalized catalog resolution
- replaced the local duplicate legacy source parsing helpers with the shared `libraryParseSourceType(...)` and `libraryInferSources(...)` helpers already used elsewhere in the Library layer
- surfaced one real file-split seam during rebuild: `buildCAFLibraryExtraction(...)` still depended on `legacyCatalogExtraction(...)` being file-private, so that helper was promoted to shared module scope to preserve behavior after the extraction

Behavioral outcome:
- no intended front-facing changes
- the Library catalog pipeline is now split by responsibility:
  - `LibraryCatalogStore.swift`: legacy payload decode and merge orchestration
  - `LibraryCatalogOPDBDecoding.swift`: OPDB/source-derived catalog decode support
  - `LibraryCatalogVenueSupport.swift`: public override, venue overlay, and CAF support

Notes surfaced in this pass:
1. the old store file had dead drift risk because shared helpers like source parsing and optional-string normalization were being duplicated in parallel with the rest of the Library layer
2. the first rebuild failure after the extraction was a useful hidden-contract find, not a logic regression: CAF extraction was still coupled to a private helper only because everything used to live in one file
3. this remains iOS-only structural cleanup; Android cleanup can mirror the file-boundary ideas later, but there was no parity behavior change to apply immediately

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Next files queued:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDomain.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDataLoader.swift`

## Pass 092: Library GameRoom augmentation extraction

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryDataLoader.swift`
- `Pinball App 2/Pinball App 2/library/LibraryGameRoomAugmentation.swift`

Changes made in this pass:
- moved the full GameRoom-to-Library augmentation path out of `LibraryDataLoader.swift` into `LibraryGameRoomAugmentation.swift`, including:
  - persisted GameRoom venue/machine load
  - GameRoom machine sorting
  - OPDB media index build and media preference scoring
  - content/visual template matching
  - GameRoom row synthesis back into `PinballGame`
- removed the unused `GameRoomOPDBCatalogRoot` decode shell that was still sitting at the top of `LibraryDataLoader.swift` with no call sites
- left the async hosted-data loading entrypoints in `LibraryDataLoader.swift`, so that file now focuses more clearly on “load hosted payloads, then augment” instead of also owning the entire GameRoom augmentation implementation

Behavioral outcome:
- no intended front-facing behavior changes
- GameRoom augmentation is now isolated behind its own file boundary, which makes later parity review and manual QA much easier

Notes surfaced in this pass:
1. `LibraryDataLoader.swift` had become a second monolith after `LibraryCatalogStore.swift`, with hosted CAF loading and GameRoom augmentation logic mixed together even though they are different concerns
2. the unused `GameRoomOPDBCatalogRoot` type was safe dead code; all active augmentation logic uses the decoded OPDB catalog machine records instead
3. this was still iOS-only structural cleanup, so there was no Android parity patch to apply immediately

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Next files queued:
- `Pinball App 2/Pinball App 2/library/LibraryDomain.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDataLoader.swift`

## Pass 093: Library grouped-identity stale-contract fixes

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogVenueSupport.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`

Changes made in this pass:
- fixed iOS curated-override lookup so `catalogCuratedOverride(...)` now checks candidate keys in explicit fallback order `opdbID -> practiceIdentity -> opdbGroupID` instead of silently ignoring the `opdbGroupID` parameter it already accepted
- fixed iOS normalized catalog resolution so grouped OPDB/practice-identity machines are resolved via `Dictionary(grouping: ...)` plus `catalogPreferredGroupDefaultMachine`, instead of assuming a single machine per `practiceIdentity`
- hardened iOS normalized override lookup by replacing `Dictionary(uniqueKeysWithValues: ...)` with `dictionaryPreservingLastValue(...)`, so duplicate override keys no longer carry a hidden crash seam
- mirrored the override fallback-order fix on Android in `LibraryDataLoader.kt`, including the merged-library helper path so Android now also honors exact `opdbId`, then `practiceIdentity`, then `opdbGroupId`

Behavioral outcome:
- Library image/playfield override fallback now matches the intended grouped-data model more closely on both platforms: exact machine override first, then canonical practice identity, then shared OPDB group
- normalized catalog payloads no longer rely on the stale “one machine forever per practice identity” assumption when choosing the default machine representative for source memberships
- no intended front-facing UI flow changed, but this was a real runtime data-resolution correction rather than pure file cleanup

Outdated/conflicting code surfaced in this pass:
1. `LibraryCatalogVenueSupport.swift` had an obviously stale signature/body mismatch: `catalogCuratedOverride(...)` already accepted `opdbGroupID`, but the function never actually used it.
2. `LibraryCatalogStore.swift` still used `Dictionary(uniqueKeysWithValues: machines.map { ($0.practiceIdentity, $0) })`, which conflicts with the newer grouped OPDB model where many variants can share one practice identity.
3. the Android Library loader had already drifted from the iOS fallback order by not considering `opdbGroupId` in one override path and by skipping exact `opdbId` in another merged-library path.

What still needs attention later if this area changes again:
1. if normalized catalog payloads ever begin shipping duplicate override rows intentionally, we may want warning logs here instead of silent last-write preservation
2. Android Library cleanup can still mirror the iOS file-boundary refactors later, but the runtime fallback behavior is now back in sync

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 094: PinballGame model extraction and stale fallback note

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryDomain.swift`
- `Pinball App 2/Pinball App 2/library/LibraryGame.swift`

Changes made in this pass:
- moved the full `PinballGame` model, nested rulesheet/video helpers, and manufacturer-card abbreviation helper out of `LibraryDomain.swift` into a dedicated `LibraryGame.swift`
- removed the now-unused `SwiftUI` import from `LibraryDomain.swift`, leaving that file more focused on Library browsing/view-model concerns instead of also owning the entire Library row model
- kept the moved code behaviorally identical; this was file-boundary cleanup only

Behavioral outcome:
- no intended front-facing behavior changes
- the Library layer now has a clearer separation between the browsing/view-model surface and the decoded game model surface, which makes later cleanup in `LibraryDomain.swift` less risky

Outdated/conflicting code surfaced in this pass:
1. `LibraryGame.swift` still defaults a missing decoded source name to `"The Avenue Cafe"`, which looks like a stale single-venue-era fallback rather than a generic Library-safe default.
2. I did not change that fallback in this pass because it can affect visible source naming when malformed or partial payloads are decoded, so it should be treated as an explicit follow-up decision instead of an invisible cleanup.

What needs fixing later:
1. decide whether missing decoded source names should fall back to a neutral value like the canonical source ID, a generic `"Library"` label, or some other non-Avenue placeholder
2. once that policy is chosen, mirror the same fallback rule in Android `LibraryDomain.kt` / `LibraryDataLoader.kt` so malformed-payload behavior stays aligned

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 099: Active Library extraction rename

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogModels.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogVenueSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDataLoader.swift`
- `Pinball App 2/Pinball App 2/library/LibraryGameRoomAugmentation.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDomain.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryHostedData.kt`

Changes made in this pass:
- renamed the active extracted Library result model from `LegacyCatalogExtraction` to `LibraryExtraction` on both platforms
- renamed the small extraction helper from `legacyCatalogExtraction(...)` to `libraryExtraction(...)`
- updated the active iOS and Android Library loading / CAF build / GameRoom augmentation paths to use the new name consistently

Behavioral outcome:
- no intended front-facing behavior changes
- the active Library architecture now reads closer to reality in code: current extraction helpers no longer carry a `Legacy` label after the runtime legacy merge path was removed in Pass 098

Outdated/conflicting code surfaced in this pass:
1. `LibraryCatalogStore.swift` is now doubly stale in naming: it is neither a catalog store nor a legacy pipeline owner. It is effectively just a tiny extraction/filter helper file.
2. Android still has a broader stale naming seam in `LibraryCatalogStore.kt`, which now mostly owns source-state and imported-source persistence rather than catalog storage. I left that for a later structural cleanup pass because it is file-organization cleanup, not behavior risk.

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest`
- result: `BUILD SUCCESSFUL`

## Pass 098: Dead legacy Library merge-path removal

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogVenueSupport.swift`
- removed `Pinball App 2/Pinball App 2/library/LibraryCatalogMergeResolution.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`
- `Pinball App Android/app/src/test/java/com/pillyliu/pinprofandroid/library/LibraryDataLoaderParityTest.kt`

Changes made in this pass:
- removed the now-unused iOS legacy decode wrappers from `LibraryCatalogStore.swift`, including:
  - `decodeLibraryPayloadWithState(...)`
  - `decodeMergedLibraryPayloadWithState(...)`
  - `decodeLegacyLibraryPayload(...)`
  - the private legacy payload structs that only fed those wrappers
- removed the fully dead iOS merge-resolution file `LibraryCatalogMergeResolution.swift`; the active Library runtime already goes through the CAF/OPDB path in `LibraryDataLoader.swift` and `LibraryCatalogVenueSupport.swift`
- removed the now-unused iOS venue-support leftovers that only existed for the dead merged path:
  - `PublicLibraryOverridesRoot`
  - `PublicLibraryPlayfieldOverrideRecord`
  - `parsePublicLibraryOverrides(...)`
  - `parseVenueMetadataOverlays(...)`
  - `applyPublicPlayfieldOverrides(...)`
  - `emptyVenueMetadataOverlayIndex()`
- removed the Android pre-CAF merged-catalog leftovers from `LibraryDataLoader.kt`, including the dead normalized-root parser path, dead legacy merge helpers, dead public-override parsing, and dead JSON array decoders that only existed to support that path
- removed the stale Android parity test that was still directly exercising `resolveLegacyGame(...)`; after the CAF-only cleanup, that test was the only remaining caller keeping dead production code alive

Behavioral outcome:
- no intended front-facing behavior changes
- both platforms are now more honest about the active Library architecture: hosted CAF/OPDB data plus imported sources, rather than a mixed live/runtime path plus a second dead legacy merge engine

Outdated/conflicting code surfaced in this pass:
1. `LibraryCatalogStore.swift` is now only a very small extraction/filter helper file, so its filename no longer matches its remaining job. It should likely be renamed in a later cleanup pass.
2. the Android stale legacy merge path had already become “test-only code.” Keeping it would have meant preserving dead runtime behavior just to satisfy a unit test, which is exactly the kind of hidden cleanup drag this review is meant to remove.

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest`
- result: `BUILD SUCCESSFUL`

## Pass 095: Library catalog merge-resolution extraction

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogMergeResolution.swift`

Changes made in this pass:
- moved the merged-library and normalized-catalog runtime resolution helpers out of `LibraryCatalogStore.swift` into `LibraryCatalogMergeResolution.swift`
- moved the legacy-game resolution helpers with them, including:
  - legacy curated-override synthesis
  - preferred legacy playfield/name inference
  - legacy machine matching against grouped OPDB data
  - normalized source-membership game synthesis
- left `LibraryCatalogStore.swift` with the decode/orchestration entrypoints plus legacy payload parsing, which is a much closer match to the file’s actual role

Behavioral outcome:
- no intended front-facing behavior changes
- the Library catalog pipeline is now easier to reason about in three layers:
  - decode/orchestration in `LibraryCatalogStore.swift`
  - merge and normalized resolution in `LibraryCatalogMergeResolution.swift`
  - OPDB / venue / CAF support in the already-extracted support files

Outdated/conflicting code surfaced in this pass:
1. `LibraryCatalogStore.swift` had effectively become a second monolithic merge engine even after the earlier file splits, which made it harder to see where decode stopped and data policy began.
2. the still-active stale follow-up from Pass 094 remains relevant here: `PinballGame` decode fallback still hard-codes `"The Avenue Cafe"` for missing source names, which is old single-venue behavior living inside the broader Library pipeline.

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 088: Library markdown/image parsing helper cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdown.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownParsing.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownRegex.swift`

Changes made in this pass:
- kept the earlier shared regex helper extraction and extended it with a shared `MarkdownImageParsing.firstImage(...)` path so the native markdown renderer and the markdown parser stop maintaining separate regex patterns for markdown/html image detection
- updated `MarkdownImageDescriptor.first(...)` and `NativeMarkdownParser.parseStandaloneImage(...)` to consume that shared image parser instead of carrying duplicate inline regex handling
- kept the earlier catalog rulesheet source-kind centralization in `LibraryCatalogResolution` as part of the same Library support cleanup wave, so rulesheet-source label/rank mapping and markdown image parsing now both have explicit single owners instead of nearby duplicated logic

Behavioral outcome:
- no intended UI, parser, or Library rulesheet-resolution behavior changed
- Library markdown support is easier to audit because the renderer and parser now derive image matches from the same helper instead of relying on duplicated regex branches that could drift

Hidden contract surfaced in this pass:
1. markdown image detection was already effectively a shared contract between the renderer and parser, but the contract only existed as duplicated regex snippets in two files
2. the rulesheet-source label/rank mapping and markdown image detection were both “small duplicated seams” that were easy to overlook individually but together represented the same long-term drift risk inside Library support code
3. this remains iOS-only structural cleanup inside Library support files; there was no Android parity patch in this pass

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 089: Rulesheet pipeline decomposition

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetScreen.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetHTMLDocument.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetModels.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetRemoteLoading.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetWebViewSupport.swift`

Changes made in this pass:
- moved rulesheet render models and remote-source/provider mapping out of `RulesheetScreen.swift` into `RulesheetModels.swift`
- moved the remote rulesheet fetch/cache/source-cleanup stack out of `RulesheetScreen.swift` into `RulesheetRemoteLoading.swift`, including Tilt Forums payload handling, legacy HTML cleanup, attribution generation, and the application-support cache actor
- moved the shared web-view bridge/configuration layer out of `RulesheetScreen.swift` into `RulesheetWebViewSupport.swift`, including the custom tracking web view, message-handler configuration, transparent appearance helper, and the large fragment/viewport JavaScript bridge
- moved the large HTML document builder out of `RulesheetScreen.swift` into `RulesheetHTMLDocument.swift` so the screen/renderer file no longer owns the HTML/CSS/JS template itself

Behavioral outcome:
- no intended rulesheet UI, source-selection, remote-loading, or viewport-restore behavior changed
- `RulesheetScreen.swift` is materially less monolithic: the screen/renderer layer now reads as screen orchestration, while models, remote loading, HTML document generation, and web bridge support each have their own files

Hidden contract surfaced in this pass:
1. `RulesheetScreen.swift` had grown into four different subsystems at once: SwiftUI screen chrome, renderer lifecycle, remote content loading, and JS/web-view bridge support
2. that coupling made it harder to reason about which edits were “UI cleanup” versus “content pipeline” versus “web bridge” changes, increasing the chance of accidental behavior drift during future cleanup
3. this is still iOS-only structural decomposition; there was no Android parity patch in this pass because Android does not share this WebKit-based rulesheet pipeline

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Next files queued:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDomain.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetScreen.swift`

## Pass 080: shared practice-identity model review before commit

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeIdentityKeying.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeIdentityKeying.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreLeagueOps.kt`
- `Pinball App Android/app/src/test/java/com/pillyliu/pinprofandroid/practice/PracticeLeagueImportTest.kt`

Changes reviewed in this pass:
- verified the new shared practice-identity structure is intentionally moving canonical Practice keys to `practiceIdentity -> opdbId -> ""` instead of the old `practiceIdentity -> opdbGroup -> slug` fallback
- confirmed the concrete Android regression was not runtime behavior but a stale unit test that still expected league-imported scores to store under the old slug for exact `opdbId` matches
- updated the Android unit expectation so an exact `opdbId` match now records under the canonical Practice key `GYWBZ-MW9B0`, matching the current model
- explicitly did not keep or reintroduce backward-compatibility slug/group fallback in app code after user confirmation that old local Practice/GameRoom state can be updated separately if needed

Behavioral outcome:
- the current branch now treats the new canonical Practice key model as authoritative
- exact `opdbId` league-import matches continue to work, but they now persist against the canonical Practice key rather than an old slug alias
- no compatibility shim remains for old slug-based or shared-group-based Practice keys; any required migration for local saved state should be handled as data maintenance, not runtime lookup behavior

Review finding resolved in this pass:
1. Android unit coverage still encoded the pre-curation slug assumption for exact `opdbId` league imports, which made the suite fail even though the runtime behavior matched the new canonical identity design

Verification:
- `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest`
- result: `BUILD SUCCESSFUL`
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Operational note:
1. if old local Practice or GameRoom state still holds slug/group keys from before the current curation model, update or regenerate that local data rather than broadening runtime lookup behavior again.

## Pass 081: Library list view decomposition

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryListScreen.swift`

Changes made in this pass:
- replaced the large computed menu-section fragments with dedicated private view types for source, sort, and bank filters
- replaced the large inline content/grid/card rendering chain with dedicated private views for the empty state, grouped/flat content, grid, card, overlay, and load-more footer
- kept the screen’s data flow inside `LibraryScreen`, but made the visual sections explicit so future cleanup can touch one area at a time without reopening the full file

Behavioral outcome:
- no intended UI or copy change
- the Library list screen now reads more like a view tree and less like a sequence of computed `some View` fragments

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 082: Library detail resource section decomposition

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryDetailComponents.swift`

Changes made in this pass:
- extracted the summary card’s inline rulesheet and playfield routing into dedicated private resource-row/chip views
- centralized rulesheet chip routing/logging so local, embedded, and external rulesheet destinations no longer duplicate their `NavigationLink` and activity-log wiring
- corrected a compile-only type reference slip during the refactor by using `LibraryPlayfieldOption` instead of a non-existent nested `PinballGame.PlayfieldOption`

Behavioral outcome:
- no intended UI or copy change
- the Library detail summary card’s resource behavior is now easier to audit because rulesheet/playfield resource decisions are isolated in named view types

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 084: Manual QA checkpoint after cleanup/publish

Primary surfaces exercised:
- Android emulator runtime
  - `GameRoom`
  - `Practice`
  - `PracticeIfpaProfileScreen`
  - `Settings`
- iOS simulator runtime
  - app launch / current-root sanity check

Changes made in this pass:
- no code changes; this was a manual validation pass

Android QA performed:
- installed the current debug build with `./gradlew :app:installDebug`
- launched `com.pillyliu.pinballandroid/com.pillyliu.pinprofandroid.MainActivity`
- captured UI trees and screenshots for:
  - League home
  - GameRoom home
  - GameRoom settings
  - Practice home
  - IFPA profile
  - IFPA profile after forced offline relaunch
  - Settings

Results:
1. GameRoom home loaded existing collection data successfully.
2. switching the selected tracked machine from `Godzilla` to `King Kong: Myth of Terror Island LE` updated the summary card correctly without stale snapshot text carrying over from the previous machine.
3. entering `GameRoom Settings > Edit` and expanding `Edit Machines` showed a machine editor bound to `Godzilla` even though `King Kong` was the selected machine on the GameRoom home screen.
4. that looked suspicious at first, but code review confirmed it is currently intentional, not stale-draft leakage:
   - Android keeps a separate `selectedEditMachineID` state in `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`
   - iOS keeps a separate `selectedMachineID` inside `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
   - both settings editors default to the first available machine when their local editor selection is empty, rather than mirroring the home-screen selected machine
5. Practice home loaded normally and the clickable player-name entry still opens the IFPA profile.
6. the IFPA live profile loaded successfully while online.
7. after disabling network, force-stopping the app, relaunching, and reopening the same player profile, the app showed the cached last-good IFPA snapshot with explicit stale-state copy and the refresh failure reason:
   - the warning message included the cached timestamp (`Mar 28, 2026 9:41 AM` in this run)
   - the stale snapshot content remained visible below the warning
   - this validates the intended offline fallback behavior from the IFPA durability pass
8. the first Settings viewport loaded normally after network re-enable; the LPL last-name privacy toggle was not revalidated in this pass because it was not in the initial visible viewport and I stopped before doing deeper scroll traversal there.

iOS QA performed:
- launched `com.pillyliu.Pinball-App-2` on the booted simulator with `xcrun simctl launch booted`
- captured a simulator screenshot after launch
- checked the recent process log for app-specific launch errors

iOS results:
1. the app launched successfully on the booted simulator.
2. the captured screen reopened into the existing Library/GameRoom-style state instead of crashing on launch.
3. the short recent `PinProf` log sample did not show an app-specific error or crash during this launch.
4. deep interactive iOS flow QA was not attempted in this pass because this environment does not expose the richer simulator interaction tooling that would make that reliable.

Behavioral takeaway:
- the highest-confidence runtime validation from this pass is the IFPA cached-fallback path on Android; it behaved exactly as intended
- the GameRoom editor-selection mismatch is currently a product/design choice, not a regression from the stale-selection cleanup
- no new crash or obvious broken-flow regression was surfaced in the exercised Android or iOS launch paths

Open follow-up from this pass:
1. if we want the GameRoom settings editor to mirror the currently selected home-screen machine, that is now a separate product decision rather than a bug fix
2. the LPL privacy-toggle visibility path in Settings still deserves one explicit manual pass later
3. score-scanner freeze/retake still needs hands-on device/simulator QA with camera input; I did not validate that flow here

## Pass 085: Rulesheet screen shell and viewport-restore cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetScreen.swift`

Changes made in this pass:
- extracted the top-level rulesheet fullscreen shell into dedicated private views for status routing, progress-pill chrome, portrait top gradient, and fullscreen back-button chrome instead of keeping those branches inline in `RulesheetScreen.body`
- centralized the repeated “viewport restore is finished, clear tracking state and resume capture” logic inside `RulesheetRenderer.Coordinator` behind named helpers so the success and timeout branches no longer duplicate the same reset sequence inline
- centralized shared rulesheet `WKWebViewConfiguration` setup so the embedded renderer and external fallback path no longer rebuild the same chrome/message-bridge wiring separately
- centralized shared transparent web-view appearance setup behind a small `WKWebView` helper so the embedded renderer and external fallback path no longer hand-apply the same background styling separately

Behavioral outcome:
- no intended UI, copy, or rulesheet-navigation behavior changed
- `RulesheetScreen` now reads more like a composed screen shell with explicit chrome pieces, and the riskiest viewport-restore path is easier to audit because its completion/reset behavior has a named owner

Hidden contract surfaced in this pass:
1. the viewport-restore logic already relied on two subtly different “restore is done” branches, but that contract was buried inside long nested scheduling code instead of being visible as one explicit cleanup step
2. the rulesheet screen is still a major file, but the top-level chrome and restore-finish behavior are now better isolated for future cleanup without touching the deeper HTML/JS bridge logic
3. this is iOS-only structural cleanup inside the local rulesheet screen; there is no Android parity patch for this pass

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 086: Library hydration and remote-image helper cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryDataLoader.swift`
- `Pinball App 2/Pinball App 2/library/PlayfieldScreen.swift`

Changes made in this pass:
- introduced a shared `GameRoomMatchContext` in `LibraryDataLoader` so Library hydration no longer recalculates the same normalized GameRoom identity inputs separately for OPDB media, visual templates, and content templates
- updated the visual/content/media template-selection helpers to consume that shared match context instead of each rebuilding their own `catalogID` / `catalogGroupID` / `canonicalPracticeIdentity` fallback ladder
- introduced a shared `RemoteUIImageRepository` in `PlayfieldScreen` so the fallback image view and fullscreen hosted-image loader now share one cache-aware image decode path and one retry policy instead of duplicating remote fetch/decode/cache wiring

Behavioral outcome:
- no intended UI, copy, or hydration-policy changes
- Library GameRoom hydration is easier to audit because the identity inputs are now explicit in one helper type
- Library image loading is easier to reason about because the fallback preview and fullscreen image flow now share one fetch/cache contract

Hidden contract surfaced in this pass:
1. `LibraryDataLoader` was already relying on one implicit normalized identity bundle for GameRoom hydration, but that bundle was being recomputed ad hoc in each helper instead of carried explicitly as one match context
2. `PlayfieldScreen` had two separate remote-image loading paths with the same cache/decode responsibilities, which made later loader cleanup harder than it needed to be
3. this was iOS-only structural cleanup inside Library support code; there was no Android parity patch in this pass

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 087: Library playfield candidate-group cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryResourceResolution.swift`

Changes made in this pass:
- introduced a shared `LibraryPlayfieldCandidateGroup` helper so `resolvedPlayfieldCandidates(...)` and `resolvedPlayfieldOptions(...)` no longer rebuild the same playfield-source grouping and deduplication logic separately
- centralized the “PinProf first, otherwise local fallback, then OPDB” grouping contract behind one helper instead of keeping that fallback order duplicated between the button-target path and the option-list path

Behavioral outcome:
- no intended UI or resource-resolution change
- the playfield resolution path is easier to audit because the primary candidate list and the presented option list now derive from the same grouped source data

Hidden contract surfaced in this pass:
1. playfield resolution already had one implicit grouped-source order, but it was duplicated in two nearby functions instead of being expressed as one explicit helper
2. this is still iOS-only Library support cleanup, so there was no Android parity patch in this pass

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 067: GameRoom import helper extraction

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

Changes made in this pass:
- extracted the Pinside import match/review heuristics inside `GameRoomImportSettingsView` into a dedicated local `ImportMatcher` helper
- moved hidden helper rules for duplicate detection, review gating, variant option merging, date normalization, display-label generation, and suggestion scoring out of the view body / free-floating method cluster
- updated the review section wiring and fetch path to call the matcher explicitly instead of relying on a long tail of same-file private methods

Behavioral outcome:
- no intended front-facing behavior changed
- the import review flow still computes the same suggestions, duplicate warnings, review filtering, and normalized purchase dates, but the contracts are now easier to follow and safer to mirror on Android later if needed

Hidden contract surfaced in this pass:
1. `GameRoomImportSettingsView` had already grown into a mini import engine, but the matching rules were buried between UI helpers and fetch/import control flow
2. the important import contracts are now grouped behind one explicit local owner instead of being spread across the view file as unrelated-looking methods
3. this was structural cleanup only, so there was no Android patch in this pass

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 068: GameRoom settings chrome cleanup

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`

Changes made in this pass:
- extracted the root GameRoom settings picker/error/save-feedback chrome in `GameRoomSettingsView` into named internal sections and helpers
- extracted the section switch in `GameRoomSettingsSectionCard` into explicit `sectionContent`
- removed the unnecessary `nonisolated(unsafe)` marker from the dashboard date formatter in `PracticeGroupDashboardSection`

Behavioral outcome:
- no intended front-facing behavior changed
- the GameRoom settings root is easier to audit because the picker bar, error banner, section content, and floating save overlay are now clearly separated
- the dashboard formatter cleanup removes an avoidable compiler warning without changing formatting behavior

Hidden contract surfaced in this pass:
1. the root GameRoom settings screen was still carrying UI chrome and section-routing behavior inline, which made the file look more coupled than it really was
2. the `nonisolated(unsafe)` formatter marker had become stale after the earlier dashboard refactor; the current isolation model no longer needed the unsafe escape hatch
3. this was iOS-only structural cleanup, so there was no Android parity change in this pass

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 057: Journal editor and GameRoom sync decomposition

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

Changes made in this pass:
- split the `PracticeJournalEntryEditorSheet` form into named internal sections so game selection, entry-specific fields, validation, and shared editor structure are no longer buried in one large body
- replaced the journal-entry save switch with per-entry helper builders plus a shared `persist` path, so score, note, study, and video entry mutation rules are easier to audit without changing editor behavior
- separated `GameRoomSettingsComponents` selection sync into explicit venue-name draft syncing versus selected-machine validation, which removes another hidden side-effect seam from the settings screen lifecycle
- kept this pass intentionally internal-only; no copy, routing, feature flags, or visible product behavior were intentionally changed

Behavioral outcome:
- the two largest remaining iOS hotspot files are easier to audit line by line because the hidden save/update rules now have names and isolated seams
- future Android parity work is less likely to drift because the journal editor and GameRoom selection contracts are no longer embedded in long inline closures

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`

## Pass 058: Practice group dashboard view decomposition

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`

Changes made in this pass:
- extracted the selected-group dashboard panel into dedicated private views for the group card and snapshot rows instead of keeping the full detail layout inline in the parent body
- centralized the inline date-editor presentation contract with named `present`, `dismiss`, and `Binding` helpers so the start/end popover state is no longer duplicated inline in the group list rows
- moved date and task-progress formatting into a small shared formatting helper so dashboard rows and headers use the same explicit formatting path

Behavioral outcome:
- no intended front-facing change; this was a structural SwiftUI cleanup so the dashboard view reads as layout plus named seams instead of nested imperative branching
- the old “dashboard reload looks stale” finding still does not reproduce from static review; this pass only made the current reload and date-popover ownership easier to inspect

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Notes surfaced during the pass:
- the project’s default `MainActor` isolation means shared non-view format helpers need explicit `nonisolated` annotations when they are used from synchronous view contexts outside the owning view
- the dashboard snapshot model type is `GroupProgressSnapshot`; the refactor briefly exposed that hidden type-name contract during build validation and then corrected it

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

## Pass 059: Practice settings card extraction

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`

Changes made in this pass:
- replaced the remaining large computed settings-card fragments with dedicated private card views for profile, IFPA, league import, and recovery settings
- introduced a shared `PracticeSettingsCard` wrapper so panel chrome is explicit and not re-declared across each section
- pulled destructive-prompt triggers into named methods in the owning view, keeping the alert presentation state in one place while moving the visible card content into smaller view types

Behavioral outcome:
- no intended front-facing change; this pass only clarified settings ownership and reduced the amount of inline UI/business wiring in the Practice settings screen
- the gated LPL full-last-name display behavior, league import button enablement, and destructive reset prompts are unchanged; they are simply expressed through smaller dedicated views now

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`

## Pass 060: GameRoom import review decomposition

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

Changes made in this pass:
- split the `GameRoomImportSettingsView` body into nested source, review, and row-editor subviews so the Pinside import flow no longer keeps fetch controls, review filtering, and per-row matching logic inline in one large body
- moved the per-row purchase-date normalization, match selection, and variant selection behavior into a dedicated row view with named helpers instead of anonymous inline closures
- added an explicit `canFetchCollection` gate and `fetchCollectionIfPossible()` helper so the source-entry contract is named once and reused by both submit and button actions

Behavioral outcome:
- no intended front-facing change; this pass only made the import review flow easier to audit and reduced the amount of hidden mutable row logic embedded directly in the parent view body
- the duplicate-warning, suggestion ranking, match selection, and import execution rules are unchanged

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Notes surfaced during the pass:
- the import review row only ever selects from the current suggestion set, so extracting a dedicated row editor made that “selected match comes from suggestions” contract much more obvious

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`

## Pass 061: GameRoom name and area panel extraction

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

Changes made in this pass:
- extracted the GameRoom name editor into a dedicated nested panel view instead of leaving the venue-name form inline in `GameRoomEditMachinesView`
- extracted the area-management form and area rows into dedicated nested views, and moved save/delete feedback into named helper methods on the owning view
- kept the existing save/delete behavior intact while removing another layer of inline mutation and feedback wiring from the large edit-machines screen

Behavioral outcome:
- no intended front-facing change; the GameRoom edit screen still saves names, edits areas, and deletes areas the same way, but the write paths are now easier to inspect and mirror later if Android cleanup reaches the same seam
- the large `GameRoomEditMachinesView` remains a hotspot, but this pass reduced the amount of nested imperative logic inside the area-management section

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`

## Pass 062: GameRoom machine editor decomposition

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

Changes made in this pass:
- extracted the remaining machine-edit section into dedicated nested views for machine-management, machine selection, and machine editor fields instead of keeping selection menus, draft bindings, and destructive actions inline in `GameRoomEditMachinesView`
- moved machine save/archive actions behind named helper methods on the owning view so the feedback side effects are explicit and not duplicated in button closures
- kept the machine draft bindings in the owner while making the editor UI consume those bindings through smaller dedicated views

Behavioral outcome:
- no intended front-facing change; the edit-machines panel still selects machines, edits area/status/metadata, saves, archives, and deletes exactly as before
- the hidden contract around “selected machine drives all current draft fields” is now easier to inspect because the machine editor is isolated from the rest of the GameRoom settings panels

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`

## Pass 063: GameRoom add-machine search decomposition

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

Changes made in this pass:
- extracted the add-machine search flow into dedicated nested views for the main search panel, advanced filters, result rows, and the variant-picker popover
- named the add-machine filter-clearing and manufacturer-suggestion visibility rules so those search-state contracts are no longer embedded in long inline branches
- kept the pending variant picker wired through explicit callbacks instead of ad hoc inline closures in each catalog result row

Behavioral outcome:
- no intended front-facing change; the add-machine panel still searches the indexed catalog, shows manufacturer suggestions, applies advanced filters, and prompts for a variant when needed
- the hidden contract around “only the currently pending catalog row owns the variant popover” is much clearer after the extraction

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Notes surfaced during the pass:
- the refactor briefly exposed a missing type-selection callback in the advanced-filter subview; that was corrected immediately and verified in the final green build

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

## Pass 064: Practice journal list decomposition

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`

Changes made in this pass:
- extracted the Practice journal bulk-edit action bar, list panel, day header, and row rendering into dedicated private views instead of keeping all list behavior inline in `PracticeJournalSectionView`
- moved journal row tap/selection behavior into a named row helper so the edit-mode selection contract is explicit and isolated from the parent view
- kept the swipe-to-edit/delete behavior attached only to editable entries while making that rule easier to see from the new dedicated row view

Behavioral outcome:
- no intended front-facing change; journal filtering, selection, edit/delete actions, row transitions, and swipe actions should behave exactly as before
- the hidden contract around “editing mode turns taps into selection toggles only for editable entries” is now expressed directly in the row helper rather than in a long inline gesture block

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

## Pass 065: GameRoom archive row decomposition

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

Changes made in this pass:
- extracted the archive filter control and archive machine row into dedicated nested views instead of keeping the archive picker and row-open behavior inline in `GameRoomArchiveSettingsView`
- moved the archive row open action into a named helper on the row view so the transition-source contract is easier to trace

Behavioral outcome:
- no intended front-facing change; archive filtering, archive-row transition sources, and machine opening behavior are unchanged
- this pass mainly reduced one more untouched section of the large GameRoom settings file and made the archive-row metadata contract more explicit

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

## Pass 066: Practice journal editor section extraction

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`

Changes made in this pass:
- extracted the journal entry editor form into dedicated private section views for game selection, score editing, note editing, study progress, video progress, unsupported-entry messaging, and validation display
- introduced shared private views for the note editor and progress controls so those editor widgets are no longer embedded as computed fragments inside the sheet
- kept the actual save/normalization logic in the owning sheet, but moved the visible editor form layout into smaller explicit view types

Behavioral outcome:
- no intended front-facing change; the journal entry editor should still present the same fields, validation states, and action-specific layouts as before
- the separation between editor UI sections and save/mutation logic is now much clearer, which should help future parity work if Android ever needs the same cleanup

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

## Pass 056: Hotspot section decomposition round

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

Changes made in this pass:
- split the iOS Practice settings card into named internal sections (`profileSettingsCard`, `ifpaSettingsCard`, `leagueImportSettingsCard`, `recoverySettingsCard`) plus a shared `settingsCard` wrapper so the file no longer hides four distinct settings surfaces inside one long body
- split the iOS GameRoom machine editor into named internal sections (`machineSelectionRow`, `machineEditorFields`, `machineAreaAndStatusRow`, `machineNumericFields`, `machineMetadataFields`, `machineActionRow`) so the active machine-edit path is easier to follow and compare against Android
- kept the new helpers strictly structural; they reuse the same actions and bindings instead of changing field meaning, copy, or user flow

Behavioral outcome:
- no intended front-facing behavior change; this pass is about making the two largest remaining SwiftUI hotspots easier to audit and safer to keep in parity
- the next cleanup passes can now target smaller named seams instead of re-entering giant view bodies every time

Notes surfaced in this pass:
1. `PracticeJournalSettingsSections.swift` is still doing multiple jobs, but the settings half is now much easier to scan separately from the journal-entry editor half
2. `GameRoomSettingsComponents.swift` still owns too much overall, but the machine editor now has explicit subregions instead of one monolithic inline form block
3. this pass was iOS-only internal refactoring, so no Android parity patch was needed

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 056 summary

Safe cleanup changes made:
- decomposed the remaining large Practice settings and GameRoom machine-editor bodies into named internal sections

Verification:
- iOS build passed

Outcome:
- the hottest remaining iOS cleanup files are more reviewable now without changing what the user sees

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`

## Pass 055: Android scanner analyzer-state ownership cleanup

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerController.kt`

Changes made in this pass:
- replaced the loose lock-protected analyzer gate fields in `ScoreScannerController` with an explicit `AnalyzerState` owner object plus small helper methods for requesting freeze, beginning frame analysis, finishing frame analysis, and updating the latest snapshot
- moved the OCR throttle, pending-freeze, processing, fallback-timestamp, and snapshot bookkeeping onto those helpers so the Android scanner no longer spreads the gate-state contract across many direct field reads and writes
- kept the visible scanner behavior the same while making the parity intent explicit: one owned analyzer-state seam now governs freeze/retake/throttle flow just like the iOS cleanup aimed for

Behavioral outcome:
- Android scanner state ownership is now easier to reason about, because the freeze/throttle/snapshot gate rules are centralized instead of scattered through the controller
- this closes the most important Android follow-through from the earlier iOS `ScoreScannerViewModel` cleanup and reduces the chance of future one-off race regressions during scanner maintenance

Notes surfaced in this pass:
1. this was primarily a parity-and-maintainability cleanup; it is designed to preserve current runtime behavior while making the hidden gating contract explicit
2. the remaining scanner validation should still be manual in emulator/device, since your real workflow is interaction-based rather than test-driven

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 188: Android catalog variant and media support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogResolution.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogVariantLabelSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogVariantSelectionSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryMediaResolutionSupport.kt`

Changes made in this pass:
- split Android catalog variant labeling out of `LibraryCatalogResolution.kt` into `LibraryCatalogVariantLabelSupport.kt`
- split preferred-machine and variant-selection policy out of `LibraryCatalogResolution.kt` into `LibraryCatalogVariantSelectionSupport.kt`
- split rulesheet/video merge, dedupe, and sort helpers out of `LibraryCatalogResolution.kt` into `LibraryMediaResolutionSupport.kt`
- left `LibraryCatalogResolution.kt` focused on imported-game assembly instead of also carrying variant heuristics and media merge policy

Hidden seam surfaced and reduced:
1. Android catalog resolution was still combining three distinct responsibilities in one file:
   - imported game construction
   - variant/title heuristics
   - rulesheet/video link merge and sort policy
2. the split now mirrors the cleaned iOS Library structure more closely and makes the remaining Android hotspots easier to reason about

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 185: Android Library domain support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDomain.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySearchSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryRulesheetSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryGamePresentationSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryYouTubeSupport.kt`

Changes made in this pass:
- split the old Android `LibraryDomain.kt` catch-all into narrower support files for:
  - search tokenization and query matching
  - rulesheet links, remote-source typing, and video reference models
  - `PinballGame` presentation helpers, grouping, and sort rules
  - YouTube launch and metadata loading
- left `LibraryDomain.kt` focused on the actual shared Library domain models instead of also owning generic helper behavior

Hidden seam surfaced and reduced:
1. `LibraryDomain.kt` had become Android Library’s generic utility bucket, mixing models with search, rulesheet metadata, UI-facing game helpers, and remote video loading
2. after the split, the remaining hotspots are the real runtime files rather than a broad “domain” catch-all

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 186: Android imported-source store split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryImportedSourcesStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryImportedSourceModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryImportedSourceNormalizationSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySeededImportedSources.kt`

Changes made in this pass:
- moved imported-source record and provider models out of the store file
- moved imported-source normalization and duplicate-merge policy out of the store file
- moved seeded default imported-source payloads and bundled venue machine IDs out of the store file
- left `LibraryImportedSourcesStore.kt` focused on persistence, load/save/upsert/remove, and first-run default seeding

Hidden seam surfaced and reduced:
1. the Android imported-source store was still mixing persistence, normalization policy, and large seeded data payloads in one file
2. the split now mirrors the iOS cleanup shape more closely and makes future default-source or normalization changes easier to audit in isolation

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 187: Android Library selection policy split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryBrowsingState.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySelectionSupport.kt`

Changes made in this pass:
- moved preferred-source and source-selection resolution policy out of `LibraryBrowsingState.kt`
- moved default-sort and default-year-direction rules into `LibrarySelectionSupport.kt`
- left `LibraryBrowsingState.kt` focused on derived browse-state data for the current source/query/sort/bank combination

Hidden seam surfaced and reduced:
1. `LibraryBrowsingState.kt` still mixed derived visible-state computation with selected-source resolution policy
2. separating those concerns makes the Android Library browse-state file closer to the iOS cleanup shape and reduces the risk of selection-policy changes quietly affecting unrelated derived list behavior

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 055 summary

Safe cleanup changes made:
- centralized Android scanner analyzer gate state behind explicit helper methods and one owned state object

Verification:
- Android Kotlin compile passed

Outcome:
- the active scanner runtime seam now reads much closer across iOS and Android, which should help keep future parity cleanup from drifting

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`

## Pass 054: Explicit settings action guards

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`

Changes made in this pass:
- extracted `saveVenueNameDraft()` and `deleteMachine(_:)` in the iOS GameRoom settings editor so those actions stop carrying their full write/update behavior inline inside button closures
- removed the old manual post-delete machine reselection from the iOS delete button and let the newer selection-normalization path own that responsibility instead
- added explicit `hasSelectedLeaguePlayer` and `canConfirmResetPracticeLog` helpers in the iOS Practice settings card so the import/reset gating rules are named instead of being hidden inside long `.disabled(...)` expressions

Behavioral outcome:
- no intended feature change; the same settings actions still work, but the remaining guard logic is easier to audit because the inline button bodies no longer hide state-reset rules
- the iOS GameRoom delete path now leans on the same centralized selection-state normalization introduced in Pass 052 instead of manually poking selection from the button action itself

Notes surfaced in this pass:
1. this was iOS-only internal cleanup; no Android parity patch was needed because it did not change the user-facing contract
2. `PracticeJournalSettingsSections.swift` and `GameRoomSettingsComponents.swift` are still growth hotspots, but more of their behavior is now named and centralized instead of being spread across view modifiers and inline closures

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 054 summary

Safe cleanup changes made:
- named the remaining inline import/reset/settings guard rules in Practice
- centralized one more venue/delete action path in iOS GameRoom settings

Verification:
- iOS build passed

Outcome:
- the remaining hotspot settings code is a little less “hidden in closures,” which should help keep the Android follow-through honest later

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`

## Pass 051: Practice journal save normalization helpers

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`

Changes made in this pass:
- added shared text-normalization helpers inside `PracticeJournalEntryEditorSheet` so score, tournament, note, and video-entry save paths stop repeating their own trim and newline-cleanup logic
- added a shared `currentStudyProgressPercent` helper so the study/video editor branches derive their saved progress value from one source of truth instead of duplicating the rounded-percent calculation
- updated the journal editor save branches to use those helpers for validation and persisted values without changing the supported entry types or the visible UI

Behavioral outcome:
- Practice journal edit saves now normalize single-line and multiline draft text consistently across score, note, study, and video entries
- this reduces drift risk inside a growth hotspot without changing what entry types are editable or how the editor looks

Notes surfaced in this pass:
1. this was an internal iOS save-path cleanup only; no Android parity patch was needed because it did not change the feature contract
2. `PracticeJournalSettingsSections.swift` still remains a hotspot because it owns editor UI, validation, settings, and part of the LPL privacy formatting path in one file

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 051 summary

Safe cleanup changes made:
- centralized repeated journal-entry save normalization and progress-percent derivation in the Practice journal editor

Verification:
- iOS build passed

Outcome:
- Practice journal edits now follow one normalization path instead of several copy-pasted ones

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeSettingsSection.kt`

## Pass 052: GameRoom selection-state normalization

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

Changes made in this pass:
- replaced the old `seedSelectionIfNeeded()` flow with `syncMachineSelectionState()` so the edit panel now normalizes invalid machine selections instead of only filling in an empty one
- taught `syncDraftFromSelection()` to clear the edit draft when no selected machine remains, instead of silently keeping the last machine's area/group/variant/ownership values alive in state
- added a dedicated `clearMachineDraft()` helper so empty-state cleanup is explicit and reusable

Behavioral outcome:
- if the selected GameRoom machine disappears because it was deleted or the machine list changes underneath the editor, the iOS edit panel now resets cleanly instead of leaving stale machine details in the draft fields
- iOS now matches the Android edit-screen contract more closely here; Android already had a selection-reset effect when the chosen machine ID stopped existing

Notes surfaced in this pass:
1. this was a real hidden-behavior seam: the old iOS path only healed `nil` selections, not stale selections pointing at removed machines
2. no Android patch was needed for this pass because `GameRoomScreen.kt` already resets `selectedEditMachineID` when the backing machine list no longer contains it

Verification:
- `xcodebuild -project '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 052 summary

Safe cleanup changes made:
- normalized invalid GameRoom machine selections and explicit empty-state draft clearing in the iOS editor panel

Verification:
- iOS build passed

Outcome:
- deleting or otherwise losing the selected GameRoom machine no longer leaves stale editor values parked in memory on iOS

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`

## Pass 053: Android GameRoom empty-selection parity follow-through

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`

Changes made in this pass:
- updated the Android edit-machine draft sync effect so it now clears area/group/position/status/variant/ownership draft state when no selected edit machine remains
- kept the existing Android invalid-selection reset behavior in place, but closed the last gap so the empty-state contract now matches the iOS cleanup from Pass 052 instead of leaving stale draft text parked in memory

Behavioral outcome:
- Android and iOS now both fully clear GameRoom edit drafts when the selected machine disappears and no replacement machine is available
- this removes one more hidden parity seam from the GameRoom settings editor path

Notes surfaced in this pass:
1. while checking the next Practice dashboard fix item, the current iOS dashboard route appears to already key reloads off `store.derivedDataRevision`, which means the older “dashboard detail can stay stale after live progress changes” finding is likely no longer active in the current code
2. that dashboard item should still be validated in simulator/emulator if it behaves strangely, but it no longer looks like a clear code-path bug from static review alone

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 053 summary

Safe cleanup changes made:
- aligned Android GameRoom edit-draft clearing with the new iOS empty-selection behavior

Verification:
- Android Kotlin compile passed

Outcome:
- the GameRoom edit panel now converges across platforms when the selected machine vanishes

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`

## Pass 046: Practice journal cache trim and GameRoom machine-save dedup

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeStoreJournalHelpers.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

Changes made in this pass:
- removed the unused `items` field from `CachedPracticeJournalPayload`; the current Practice journal cache path only reads grouped `sections`
- removed the old unused `journalItems`, `recentJournalEntries`, `allJournalEntries`, and `clearJournalLog` helper surface from the same Practice journal helper file
- consolidated the duplicated Save/Archive `store.updateMachine(...)` argument list in `GameRoomEditMachinesView` behind a single `persistMachineEdits(for:status:)` helper

Behavioral outcome:
- no user-facing behavior changed; this was dead Practice journal cache surface plus internal deduplication of the GameRoom machine-edit write path
- the GameRoom settings screen now has one authoritative place for machine field persistence, which reduces the chance that Save and Archive drift apart during later edits

Notes surfaced in this pass:
1. the dead Practice journal helper surface appears to be leftover from an older “raw journal item list” flow; current routing and rendering only consume grouped day sections
2. Android did not need a parity patch here: there is no matching cached-journal payload object on Android, and the GameRoom change was internal iOS helper dedup rather than a product-behavior change
3. `PracticeJournalSettingsSections.swift` and `GameRoomSettingsComponents.swift` are still legitimate growth hotspots even after this trim; this pass only removed one dead seam and one duplicated write seam

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 046 summary

Safe cleanup changes made:
- removed dead cached Practice journal payload surface on iOS
- centralized duplicated GameRoom machine Save/Archive persistence on iOS

Verification:
- iOS build passed

Outcome:
- the Practice journal cache carries only live data now, and the GameRoom settings editor has a single persistence seam for machine field updates

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeSettingsSection.kt`

## Pass 047: Practice journal editor shared control cleanup

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`

Changes made in this pass:
- extracted the repeated study-progress UI block in `PracticeJournalEntryEditorSheet` into a shared `progressTrackingFields` helper
- extracted the repeated optional note editor styling into a shared `styledNoteEditor(text:)` helper and reused it for both note entries and study/video entries
- moved the draft-state initialization logic out of the `.onAppear` closure into a dedicated `seedDraftState()` helper

Behavioral outcome:
- no user-facing behavior changed; the editor still shows the same controls for score, note, study, and video journal actions
- the journal editor now has one shared styling seam for note editors and one shared seam for progress controls, which reduces the chance of accidental drift across supported entry types

Notes surfaced in this pass:
1. this file still mixes multiple responsibilities: journal list rendering, settings/profile panels, and entry editing live together
2. Android did not need a parity patch for this pass because the cleanup was internal SwiftUI deduplication within the iOS journal editor sheet

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 047 summary

Safe cleanup changes made:
- shared repeated progress controls and note-editor styling inside the iOS Practice journal editor

Verification:
- iOS build passed

Outcome:
- the journal editor is a little less brittle, with fewer duplicated UI/styling blocks to keep in sync

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeSettingsSection.kt`

## Pass 050: Cross-platform GameRoom area-order contract alignment

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`

Changes made in this pass:
- changed iOS `GameRoomStore.upsertArea` to clamp `areaOrder` to `>= 1` instead of `>= 0`
- changed Android `GameRoomStore.upsertArea` to clamp `areaOrder` to `>= 1` instead of `>= 0`
- changed Android GameRoom settings area-order draft defaults and reset/save fallbacks from `"0"` / `0` to `"1"` / `1`

Behavioral outcome:
- new and edited GameRoom areas now use the same minimum valid order on both platforms
- the UI and store contract now agree that area order starts at `1`, removing the earlier mismatch where the iOS settings UI prevented `0` but the underlying stores still allowed it

Notes surfaced in this pass:
1. this is a real parity cleanup, not just internal deduplication; both platforms previously carried the same hidden store-level `0` allowance
2. legacy persisted area records with `0` can still exist until they are edited or otherwise rewritten; this pass fixes new writes and edits going forward

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 050 summary

Safe cleanup changes made:
- aligned the GameRoom area-order minimum contract across iOS and Android

Verification:
- iOS build passed
- Android Kotlin compile passed

Outcome:
- GameRoom area ordering now has a cleaner parity-safe rule: `1` is the minimum everywhere in the active edit/write path

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeSettingsSection.kt`

## Pass 049: Practice journal editability rule centralization

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeModels.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift`

Changes made in this pass:
- added `JournalActionType.supportsEditing` as the single source of truth for whether a Practice journal action is editable
- updated `PracticeJournalItem.isEditablePracticeEntry` to use that shared enum property
- updated `PracticeStore.canEditJournalEntry(_:)` to use the same shared enum property instead of carrying its own duplicate switch

Behavioral outcome:
- no user-facing behavior changed; the same Practice journal actions remain editable
- the journal list UI and the store/editor gate now share one editability rule, so those paths cannot silently diverge during future cleanup

Notes surfaced in this pass:
1. Android already has the cleaner ownership split here through `PracticeJournalIntegration.canEdit(...)` and `PracticeStore.canEditJournalEntry(...)`, so this was iOS parity catch-up rather than a new Android change
2. this is the kind of low-visibility contract that can create “row looks editable but editor refuses” style bugs if duplicated across multiple layers

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 049 summary

Safe cleanup changes made:
- centralized the Practice journal editability rule on iOS

Verification:
- iOS build passed

Outcome:
- Practice journal editability now has one source of truth on iOS, matching the cleaner Android ownership pattern

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeSettingsSection.kt`

## Pass 048: GameRoom area-editor state dedup

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

Changes made in this pass:
- extracted the area save/reset flow into `saveAreaDraft()` and `clearAreaDraft()`
- extracted the area edit-seeding flow into `editArea(_:)`
- extracted the area delete-side-effects flow into `deleteArea(_:)`

Behavioral outcome:
- no user-facing behavior changed; the GameRoom area editor still supports add, edit, and delete in the same places
- the area editor now has one shared draft-state contract instead of resetting/seeding those fields inline across multiple button handlers

Notes surfaced in this pass:
1. this is iOS-only internal cleanup; Android did not need a parity patch because there is no matching SwiftUI area-draft state machine there
2. there is still a small hidden contract mismatch worth keeping in the review log: the GameRoom settings UI clamps area order to `>= 1`, while `GameRoomStore.upsertArea` still technically accepts `0`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 048 summary

Safe cleanup changes made:
- centralized GameRoom area-editor draft state handling on iOS

Verification:
- iOS build passed

Outcome:
- GameRoom area editing is a little easier to reason about, with fewer inline state-reset branches

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeSettingsSection.kt`

## Pass 044: dead Practice insights name-formatting plumbing

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeInsightsSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeInsightsContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeScreenContexts.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeScreenRouteContent.swift`

Changes made in this pass:
- removed the unused `redactName` closure from the Practice insights view/context plumbing
- removed the matching pass-through closures from the route-content and screen-context builders

Behavioral outcome:
- no runtime behavior changed; this was dead wiring that was never read by the rendered insights UI
- the Practice insights context is slightly smaller and easier to reason about because it no longer advertises a formatting dependency the view does not use

Notes surfaced in this pass:
1. this was pure iOS cleanup; the Android insights implementation does not have an equivalent dead `redactName` plumbing chain
2. the unused closure likely survived an earlier refactor where player-name formatting moved into the view itself

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 044 summary

Safe cleanup changes made:
- removed dead Practice insights name-formatting closure plumbing on iOS

Verification:
- iOS build passed

Outcome:
- Practice insights routing/context code no longer carries an unused formatting dependency

Next files queued:
- `Pinball App 2/Pinball App 2/stats/StatsScreen.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/stats/StatsScreen.kt`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`

## Pass 045: cross-platform stats-card player label normalization

Primary files:
- `Pinball App 2/Pinball App 2/stats/StatsScreen.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/stats/StatsScreen.kt`

Changes made in this pass:
- replaced the stats card’s preformatted `highPlayer` / `lowPlayer` strings with raw player-plus-optional-season structs on both platforms
- moved the final display formatting into the rendered stats-card views so the active privacy toggle is applied at the last step instead of being baked into the computed stat result
- removed the old “store a string like `Player (S24)` and then substring/format it again in the UI” pattern on both iOS and Android

Behavioral outcome:
- the machine stats card now has a cleaner contract: stat computation owns score math and raw source identity, while the UI owns display formatting
- this keeps iOS and Android aligned on the same structure and removes one more hidden/defaults-driven formatting seam from the stats feature

Notes surfaced in this pass:
1. Android had the same conceptual debt as iOS here, even though it already passed the privacy flag explicitly in more places
2. this is a structural cleanup, not a user-facing feature change; high/low labels still show the same names and season suffixes as before

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 045 summary

Safe cleanup changes made:
- normalized stats-card player label data on iOS and Android so display formatting happens in the UI instead of the stat result model

Verification:
- iOS build passed
- Android Kotlin compile passed

Outcome:
- stats-card name formatting now has a cleaner parity-safe ownership split across both platforms

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeSettingsSection.kt`

## Pass 041: Cross-platform performance trace prefix cleanup

Primary files:
- `Pinball App 2/Pinball App 2/app/PinballPerformanceTrace.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/PinballPerformanceTrace.kt`

Changes made in this pass:
- renamed the human-readable performance log prefix from `practice_perf` to `pinball_perf` on both iOS and Android
- kept the signpost/trace section names unchanged; this pass only corrected the emitted log text so it matches the helper’s actual usage outside the Practice feature

Behavioral outcome:
- hosted library warmup and other non-Practice timing points no longer emit misleading `practice_perf` log lines
- Android observability now stays aligned with iOS instead of carrying the same misleading prefix drift

Notes surfaced in this pass:
1. this was a cross-platform observability debt item, not a runtime feature bug; the value is making future profiling and parity review easier to read correctly
2. the shared helper is now semantically named for the app shell instead of one feature area, which reduces the chance that Android-specific cleanup later assumes these logs are Practice-only

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 041 summary

Safe cleanup changes made:
- aligned the generic performance trace helper’s log prefix across iOS and Android

Verification:
- iOS build passed
- Android Kotlin compile passed

Outcome:
- profiling output is clearer and no longer falsely labeled as Practice-only work

Next files queued:
- `Pinball App 2/Pinball App 2/app/AppShakeCoordinator.swift`
- `Pinball App 2/Pinball App 2/league/LeaguePreviewSections.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeInsightsSection.swift`

## Pass 042: iOS shake-warning art loading cleanup

Primary files:
- `Pinball App 2/Pinball App 2/app/AppShakeCoordinator.swift`

Changes made in this pass:
- replaced the shake-warning art view’s eager bundled image read with a memory-backed async loader so the overlay no longer does `Data(contentsOf:)` on the main path
- removed the duplicate “read once in init, then read again in `.task`” behavior by letting the view seed from memory cache only and perform a single async load when needed
- moved the fallback image path onto the same async loading flow and cached its bytes as well, so the placeholder fallback does not re-read disk repeatedly

Behavioral outcome:
- the shake overlay still presents the same images and fallback behavior, but it now avoids hidden main-thread file I/O and repeated bundle reads when warning levels are shown
- Android did not need a code mirror for this pass because `AppShakeWarning.kt` already loads the bundled warning art via `produceState` on `Dispatchers.IO`

Notes surfaced in this pass:
1. the earlier review note about “loads warning artwork twice per presentation path and does sync image reads on the main actor” is now resolved on iOS
2. this stays intentionally scoped to asset loading only; warning level timing, haptics, and overlay semantics are unchanged

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 042 summary

Safe cleanup changes made:
- made iOS shake-warning art loading async and memory-aware without changing visible warning behavior

Verification:
- iOS build passed
- Android Kotlin compile passed

Outcome:
- the iOS shake overlay no longer hides duplicate synchronous asset reads behind view initialization

Next files queued:
- `Pinball App 2/Pinball App 2/league/LeaguePreviewSections.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeInsightsSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`

## Pass 043: explicit LPL name-privacy dependency cleanup

Primary files:
- `Pinball App 2/Pinball App 2/data/SharedCSV.swift`
- `Pinball App 2/Pinball App 2/league/LeaguePreviewSections.swift`
- `Pinball App 2/Pinball App 2/league/LeagueCardPreviews.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeInsightsSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/standings/StandingsScreen.swift`
- `Pinball App 2/Pinball App 2/stats/StatsScreen.swift`

Changes made in this pass:
- extended `formatLPLPlayerNameForDisplay` so views can pass `showFullLastNames` explicitly instead of relying on the formatter to read `UserDefaults` behind the scenes
- removed every current `_ = showFullLPLLastNames` invalidation poke and replaced those call sites with explicit `showFullLastNames: showFullLPLLastNames`
- kept the formatter’s `UserDefaults` fallback for non-view and legacy call sites that do not currently thread the privacy flag explicitly

Behavioral outcome:
- the LPL full-last-name toggle now participates in SwiftUI view updates as a real input instead of a hidden “touch this state so the body refreshes” dependency
- Android did not need a matching code change because its `formatLplPlayerNameForDisplay` already takes `showFullLastName` explicitly and Compose already observes the preference state

Notes surfaced in this pass:
1. this resolves one of the review’s “hidden invalidation hacks” items in the active league/practice/stats surfaces without changing the actual privacy rules
2. keeping the formatter fallback in place avoids forcing a huge signature-threading refactor through store/viewmodel code that does not need live UI invalidation today

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- Android parity review:
  - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/LplNamePrivacy.kt`
  - result: no code change needed because Android already uses explicit `showFullLastName`

## Pass 043 summary

Safe cleanup changes made:
- replaced hidden LPL name-privacy refresh pokes with explicit formatting inputs on iOS

Verification:
- iOS build passed
- Android source review confirmed parity already existed

Outcome:
- league, standings, stats, and practice views no longer rely on dummy state reads to refresh redacted-name formatting

Next files queued:
- `Pinball App 2/Pinball App 2/stats/StatsScreen.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`

## Pass 035: Android parity mirror for GameRoom restore failures

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomStateCodec.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomRouteContent.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`

Changes made in this pass:
- added Android-side `GameRoomStateCodec.LoadResult` so GameRoom restore now distinguishes missing save data, successfully loaded save data, and unreadable/corrupt save data instead of collapsing all decode failures into `empty`
- made Android GameRoom restore fall back from unreadable current save data to readable legacy save data, with the same “needs resave” / recovery-notice behavior used on iOS
- stopped the Android library overlay loader from silently decoding partial GameRoom overlay state from unreadable raw JSON; it now follows the same restore contract as the GameRoom store
- surfaced `store.lastErrorMessage` in the Android GameRoom home and settings routes so restore failures and recovery notices are visible instead of staying hidden in store state
- cleared stale GameRoom error banners on successful Android save, matching the iOS behavior

Behavioral outcome:
- Android no longer silently resets GameRoom to an empty state when the saved JSON is unreadable
- if the current Android save is bad but the legacy save still decodes, GameRoom recovers from legacy and tells the user that it did so
- the Android library overlay now stays aligned with the same persisted-state restore rules as the Android GameRoom feature itself

Hidden contract surfaced in this pass:
1. Android had already grown a `lastErrorMessage` state on `GameRoomStore`, but before this pass only save failures ever set it and no GameRoom route actually rendered it
2. Android library extraction was still operating on the old nullable `decode(raw)` contract, so fixing the store alone would have left the public library overlay on a different restore path
3. this is the direct Android parity mirror of the iOS GameRoom restore fix, and it keeps the platform behavior aligned before deeper Android cleanup starts

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

Manual validation note:
1. I did not run the Android emulator through a corrupted-save scenario in this pass; verification here is compile success plus the code-path alignment with the iOS fix.

## Pass 035 summary

Safe cleanup changes made:
- removed the now-unused partial GameRoom overlay raw-decoder path from Android library loading

Verification:
- Android debug Kotlin compile passed

Outcome:
- Android GameRoom now follows the same explicit restore/failure semantics as iOS instead of quietly treating unreadable saved state like a normal empty room

Next files queued:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/info/AboutScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCache.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerController.kt`

## Pass 036: Android mirror for refreshed LPL About copy

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/info/AboutScreen.kt`

Changes made in this pass:
- mirrored the iOS About-screen wording refresh onto Android so the Android LPL page no longer hard-codes `Season 24` or the old top-8 Smackdown finals description
- kept the existing Android layout and local drawable path unchanged, since Android was already using a bundled drawable resource rather than doing synchronous file I/O in the composable body
- added the same “check the website or Facebook group for schedule changes” guidance used on iOS

Behavioral outcome:
- Android now presents the same evergreen, source-backed league description as iOS
- the cross-platform league info surfaces are back in sync on the content that had visibly drifted

Hidden contract surfaced in this pass:
1. the stale LPL About copy was a true cross-platform drift issue, not an iOS-only artifact
2. Android’s About screen was structurally healthier than iOS on the image-loading side because it already used `painterResource`, so only the copy needed mirroring here

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

Manual validation note:
1. I did not run the Android emulator through the About screen in this pass; verification here is copy review plus clean Kotlin compile.

## Pass 036 summary

Safe cleanup changes made:
- refreshed stale Android LPL logistics copy to match the corrected iOS wording

Verification:
- Android debug Kotlin compile passed

Outcome:
- iOS and Android now match again on the LPL About-page content that had drifted over time

Next files queued:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCache.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerController.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/info/AboutScreen.kt` note complete; no further Android image-loading parity work needed there right now

## Pass 037: Android parity mirror for cache-clear stale revalidation writes

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCache.kt`

Changes made in this pass:
- added an Android cache-generation token so in-flight fetches started before a cache clear can no longer write files or missing markers back into the cache after the clear finishes
- wrapped Android `clearAllCachedData()` in the cache mutex and advanced the generation inside that critical section so cache reset and revalidation write paths now coordinate explicitly
- kept Android’s existing “newest event wins” update-log checkpoint logic intact, since that part was already more defensive than the old iOS implementation

Behavioral outcome:
- Android cache clears are now protected against the same stale background revalidation write-back issue that iOS had
- the Android cache no longer has a hidden path where a background refresh can repopulate disk immediately after the user clears cached data

Hidden contract surfaced in this pass:
1. Android’s cache checkpointing was already using the newest update-log event, so the real parity gap was the stale write-after-clear race rather than timestamp ordering
2. background revalidation and explicit clear were previously coordinated only by convention, not by a shared generation boundary

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

Manual validation note:
1. I did not run a device/emulator cache-clear race manually in this pass; verification here is compile success plus the explicit generation guard in the write path.

## Pass 037 summary

Safe cleanup changes made:
- none; this was a targeted cache behavior fix

Verification:
- Android debug Kotlin compile passed

Outcome:
- Android cache clear behavior now matches the guarded iOS behavior instead of leaving a stale background write path behind

Next files queued:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerController.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGroupDashboardSection.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`

## Pass 039: Android parity mirror for scanner gate-state ownership

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerController.kt`

Changes made in this pass:
- introduced a dedicated analyzer-state lock in the Android scanner controller so frame-gating fields now have one explicit synchronization boundary across the camera executor and main-coroutine OCR/freeze flow
- moved Android access for `processingPaused`, `isProcessingFrame`, `lastOcrTimeMs`, `lastLiveBitmapFallbackTimeMs`, pending freeze requests, and `latestSnapshot` behind that shared lock instead of relying on mixed ad hoc cross-thread reads and writes
- added a separate internal frozen gate so the camera analyzer no longer depends on reading Compose UI state directly to know whether frame processing should stop

Behavioral outcome:
- Android scanner freeze/retake/live-OCR gating is less likely to race between the analyzer thread and the main coroutine path
- the Android scanner now follows the same “single coordinated owner for gate state” direction as the iOS scanner fix, without rewriting the whole controller architecture

Hidden contract surfaced in this pass:
1. Android did not have the same exact queue structure as iOS, but it did have the same class of hidden risk: analyzer gating fields were split across camera-executor access and main-coroutine mutation
2. Android’s group dashboard does not need the iOS reload-token patch because `PracticeGroupDashboardSection.kt` computes directly from `PracticeStore` during Compose recomposition instead of storing a separate async-loaded dashboard detail snapshot

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

Manual validation note:
1. I did not run an emulator freeze/retake interaction pass in this step; verification here is compile success plus the state-ownership cleanup above.

## Pass 039 summary

Safe cleanup changes made:
- none; this was a targeted scanner concurrency fix

Verification:
- Android debug Kotlin compile passed

Outcome:
- Android scanner gate-state ownership is now tighter, and Android dashboard parity is confirmed without needing an extra dashboard patch

Next files queued:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGroupDashboardSection.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeSelectedGroupDashboardCard.kt`

## Pass 040: Android dashboard parity confirmation

Primary files reviewed:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGroupDashboardSection.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeSelectedGroupDashboardCard.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeHomeSection.kt`

Changes made in this pass:
- none

Behavioral outcome:
- confirmed that Android does not need the iOS `derivedDataRevision` / reload-token fix for group dashboard refresh

Hidden contract surfaced in this pass:
1. Android group dashboard values are computed directly from `PracticeStore` inside Compose recomposition (`groupDashboardScore`, `groupProgress`, `selectedGroup`) rather than loaded into a separate remembered async dashboard-detail state
2. because there is no Android equivalent of iOS `loadedDashboardDetail`, the stale-dashboard bug fixed on iOS does not currently exist in the same form on Android

Verification:
- no code changes in this pass

Outcome:
- Android dashboard behavior is intentionally kept as-is, and the parity log now records why there was no mirror patch here

## Pass 038: About copy rollback per user direction

Primary files:
- `Pinball App 2/Pinball App 2/info/AboutScreen.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/info/AboutScreen.kt`

Changes made in this pass:
- reverted the LPL About-page body copy on both iOS and Android back to the prior user-authored wording
- kept the non-copy iOS logo-loading cleanup in place, since that change was about bundled image I/O rather than league messaging

Behavioral outcome:
- both platforms are back to the original About-page text the user intentionally wrote
- iOS still retains the async bundled-logo loading fix from the earlier cleanup pass

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

Outcome:
- the About-copy refresh is no longer active; only the non-copy technical cleanup remains

## Pass 034: About screen copy drift and bundled logo loading

Primary files:
- `Pinball App 2/Pinball App 2/info/AboutScreen.swift`

Changes made in this pass:
- replaced the synchronous `Data(contentsOf:)` logo decode in `LPLLogoView` with an async bundled-art loader that resolves the bundled WebP off the main thread and then updates the view state
- kept the bundled-logo contract flexible by supporting both flattened bundle lookup and `info/` subdirectory lookup
- rewrote the most time-sensitive LPL copy to remove the hard-coded current-season sentence and the stale Smackdown finals description, while keeping the same overall layout and link structure
- added an explicit “check the website or Facebook group for current schedule changes” note so the screen stays useful even when the season calendar changes

Behavioral outcome:
- the About screen no longer does synchronous bundled image file I/O from the view body
- the LPL description is now more evergreen while still reflecting the current public league rules and Smackdown format as of March 27, 2026

Hidden contract surfaced in this pass:
1. both iOS and Android had drifted in the same way: they hard-coded `Season 24` plus the old “top 8 around 9:30 pm” Smackdown copy directly in the app UI
2. that kind of date-specific league copy ages faster than normal feature text, so parity is better served by evergreen wording plus a live-source pointer than by baking the current season number into shipped UI
3. Android has a matching stale page in `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/info/AboutScreen.kt`, so this is now an explicit parity follow-up rather than an iOS-only cleanup

Source verification:
- verified against `https://www.lansingpinleague.com/` on March 27, 2026
- the public site still lists Season 24 beginning January 13, 2026 and describes Tuesday Night Smackdown as two qualifying attempts on a random game with a top-4 playoff after league play

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Manual validation note:
1. I did not run the simulator through the About screen manually in this pass; verification here is source review plus clean build.

## Pass 034 summary

Safe cleanup changes made:
- removed main-thread bundled logo loading from the About screen
- replaced time-sensitive league copy with source-backed evergreen wording

Verification:
- iOS simulator build passed

Outcome:
- the iOS About screen is no longer carrying known stale LPL logistics copy, and the Android mirror target is explicitly identified

Next files queued:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomStateCodec.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/info/AboutScreen.kt`

## Pass 033: Practice group dashboard reload invalidation

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeStore.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeScreenContexts.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeScreenRouteContent.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`

Changes made in this pass:
- added a lightweight `derivedDataRevision` counter to `PracticeStore` and advanced it from `invalidateDerivedCaches()` so store-driven derived-data invalidation has an explicit revision token instead of being invisible to route-level task keys
- threaded that revision through the group-dashboard route context into `PracticeGroupDashboardSectionView`
- expanded the selected-group dashboard task key so the async dashboard-detail reload reruns when derived practice data changes, not just when the selected group metadata changes

Behavioral outcome:
- the selected group dashboard no longer keeps stale locally cached detail after score-entry, journal, or rulesheet-progress changes that do not alter the group id or date metadata
- iOS now keeps the dashboard detail view aligned with the same store invalidation events that already clear the backing cached dashboard-detail store data

Hidden contract surfaced in this pass:
1. the dashboard screen was already invalidating `cachedGroupDashboardDetails`, but the view kept its own `loadedDashboardDetail` state behind a `.task(id:)` key that only changed for group metadata edits
2. that meant normal practice activity could invalidate the store cache without ever causing the view task to rerun, so the UI quietly displayed stale dashboard detail until some unrelated navigation or group edit happened
3. Android does not currently have the same hidden seam because `PracticeGroupDashboardSection.kt` computes directly from `PracticeStore` during Compose recomposition instead of holding a separate async-loaded dashboard snapshot; parity guidance is to preserve that direct-store model or add an equivalent revision-trigger if Android later introduces local dashboard caching

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

Manual validation note:
1. I did not run a simulator interaction pass for this change; verification here is compile/build plus the code-path review above.

## Pass 033 summary

Safe cleanup changes made:
- none; this was a targeted behavior fix

Verification:
- iOS simulator build passed

Outcome:
- selected-group dashboard detail now refreshes when underlying practice progress changes instead of waiting for a separate group-metadata change

Next files queued:
- `Pinball App 2/Pinball App 2/info/AboutScreen.swift`

## Pass 032: GameRoom persisted-state corruption handling

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStateCodec.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomHomeComponents.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- compatibility call-site updated because it shared the same old contract:
  - `Pinball App 2/Pinball App 2/library/LibraryDataLoader.swift`
- Android reference reviewed for parity:
  - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomStore.kt`
  - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`

Changes made in this pass:
- replaced the old optional-return GameRoom restore helper with an explicit `LoadResult` that distinguishes missing state, successful restore, recoverable restore from legacy state, and unreadable persisted data
- taught iOS GameRoom restore to fall back to the legacy save if the current save blob is unreadable and the legacy blob still decodes
- changed `GameRoomStore.loadState()` so unreadable persisted data is no longer treated as “no save existed”; the store now surfaces a restore error message instead of silently resetting
- cleared stale GameRoom error state on successful save so a previous restore/save error does not linger after a later good write
- exposed the restore error banner in both the GameRoom home surface and GameRoom settings surface so the persistence problem is visible without needing logs
- updated `LibraryDataLoader` because it also consumed the old optional GameRoom restore contract when building the GameRoom-backed library source

Behavioral outcome:
- unreadable iOS GameRoom saved JSON no longer silently masquerades as an empty collection
- if the current save is bad but the legacy save is still readable, iOS now recovers from the legacy blob and migrates forward instead of dropping straight to empty state
- the GameRoom-backed library source now follows the same explicit missing-vs-failed-vs-loaded contract as the main GameRoom store

Hidden contract surfaced in this pass:
1. `LibraryDataLoader` was depending on the same silent optional restore behavior as `GameRoomStore`, so changing the codec immediately exposed a second hidden consumer of the old contract.
2. iOS had no visible UI seam for `GameRoomStore.lastErrorMessage`, which is why save/load persistence problems could exist without any in-app signal.

Android parity notes:
1. Android GameRoom still has the old behavior today: `GameRoomStore.loadState()` treats `GameRoomStateCodec.decode(raw)` returning `null` the same as “no saved state,” then proceeds with `GameRoomPersistedState.empty`.
2. Android `LibraryDataLoader.kt` also reads GameRoom state directly, so the same hidden-contract cleanup will be needed there when Android parity work starts.
3. The right parity target is the iOS behavior after this pass: explicit missing vs unreadable state, plus visible restore failure instead of silent empty reset.

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 032 summary

Safe cleanup changes made:
- none; this pass was active persistence-behavior cleanup plus visible error surfacing

Verification:
- app build passed

Outcome:
- iOS GameRoom no longer silently hides persisted-state corruption, and the library integration now matches the new explicit restore contract

Next files queued:
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardContext.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStore.swift`

## Pass 031: App Store release-history helper

Primary files:
- `Pinball App 2/fastlane/Fastfile`
- `Pinball App 2/fastlane/README.md`

Changes made in this pass:
- added a read-only `release_history` fastlane lane so recent App Store Connect `What's New` text and promotional text can be fetched on demand before drafting the next release
- added reusable App Store Connect helpers for bundle-id resolution, Spaceship app lookup, and client-side release-history collection so future metadata tooling does not need to duplicate the same ASC setup logic
- kept the new history lane explicitly separate from `upload_build` and `submit_review`; it does not upload, mutate metadata, or submit anything
- documented the new lane in the auto-generated fastlane README

Behavioral outcome:
- iOS release-prep can now pull prior release copy from App Store Connect without going through the web UI
- this gives a concrete source for “what did we say last time?” when drafting new release notes and promo text for review

Notes surfaced in this pass:
1. App Store Connect accepted the API-key read path for version localizations, but not a server-side `sort` parameter on that request shape; the helper now sorts version strings client-side instead.
2. the lane defaults to `locale:en-US` and `limit:8`, with optional `version_number` filtering when we only want one release.
3. this is a drafting helper only; it does not change runtime app behavior and does not have an Android parity equivalent.

Verification:
- `bundle exec ruby -c 'fastlane/Fastfile'`
- result: `Syntax OK`
- `bundle exec fastlane lanes`
- result: fastlane listed the new `release_history` lane
- `bundle exec fastlane ios release_history limit:5 locale:en-US`
- result: `fastlane.tools finished successfully` and printed the recent `What's New` plus promotional text entries for versions including `3.4.9`, `3.4.8`, and `3.4.7`

Operational notes for future use:
1. use `bundle exec fastlane ios release_history` to see the recent release-copy baseline before drafting a new release
2. use `bundle exec fastlane ios release_history version_number:3.4.9` when we only want one specific version
3. after reviewing that history, I can draft new copy into `fastlane/metadata/en-US/release_notes.txt` and `fastlane/metadata/en-US/promotional_text.txt` for your approval before any submission step

## Pass 031 summary

Safe cleanup changes made:
- added a read-only App Store Connect history helper to the iOS fastlane layer

Verification:
- fastlane syntax passed
- lane discovery passed
- live App Store Connect history lookup passed

Outcome:
- release-note drafting can now start from real App Store Connect history instead of memory or manual web lookup

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStateCodec.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`

## Pass 030: iOS fastlane release-flow alignment

Primary files:
- `Pinball App 2/fastlane/Fastfile`
- `Pinball App 2/fastlane/README.md`
- `Pinball App 2/Pinball App 2.xcodeproj/xcshareddata/xcschemes/PinProf.xcscheme`
- local machine only:
  - `Pinball App 2/fastlane/.env.default`

Changes made in this pass:
- reshaped iOS fastlane around the actual manual iOS release workflow instead of the stale “always run the narrow test lane, then beta/release” flow
- kept the old `beta` and `release` lane names as compatibility aliases, but made the intended paths explicit with new `upload_build` and `submit_review` lanes
- changed `build` to be a local archive/export lane that does not mutate build numbers unless explicitly asked, while `upload_build` defaults to incrementing the build number unless `increment_build:false` is passed
- added fastlane helpers for current project version/build lookup, optional version/build mutation, optional test execution, and App Store Connect API key reuse so the lane behavior is centralized instead of repeated
- added metadata helpers so `submit_review` can use either passed-in `release_notes` / `promotional_text` text or persisted files under `fastlane/metadata/<locale>/...`, with `en-US` as the default locale
- made `submit_review` pick the latest uploaded TestFlight/App Store Connect build for the requested version when `build_number` is omitted, instead of forcing manual build-number lookup every time
- regenerated the auto-generated fastlane README so the public lane list now documents `upload_build` and `submit_review`
- restored a shared `PinProf.xcscheme` to the repo under `xcshareddata/xcschemes`; before this pass, fastlane/gym archive behavior depended on local user scheme state even though plain `xcodebuild` still worked
- hardened the local fastlane secret env file permissions from world-readable to owner-only so the existing App Store Connect credentials stay local but are not casually readable by other users on the machine

Behavioral outcome:
- iOS now has a repeatable fastlane path for “archive and upload a build” and a separate repeatable path for “update promo text / release notes, select a build, and submit for review”
- the fastlane archive path no longer relies on hidden local Xcode scheme state; the missing shared scheme was a real hidden release-tooling contract that would have broken on another machine or a clean environment
- release metadata submission is now explicit and scriptable instead of being limited to a binary-only upload path that skipped metadata entirely

Hidden contract surfaced in this pass:
1. the project already behaved as if `PinProf` were a shared scheme, but the actual `.xcscheme` file was missing from source control while `xcschememanagement.plist` still referenced it as shared
2. that mismatch is why plain local `xcodebuild` continued to work but `gym` initially failed; the fastlane path exposed tooling drift that manual organizer uploads had been masking
3. this is iOS delivery tooling only, not runtime parity logic, so there is no Android feature-parity implementation to mirror here; the parity note is simply to keep release automation concerns separate from product behavior cleanup

Verification:
- `bundle exec ruby -c 'fastlane/Fastfile'`
- result: `Syntax OK`
- `bundle exec fastlane lanes`
- result: fastlane listed the new `upload_build` and `submit_review` lanes plus the compatibility aliases
- `bundle exec fastlane ios build increment_build:false run_tests:false`
- result: `fastlane.tools finished successfully` and exported `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/PinProf.ipa`

Operational notes for future use:
1. `upload_build` is the closest match to the current manual “update build, archive, upload” flow.
2. `submit_review` is the closest match to the current App Store Connect “set promo text/release notes, choose build, submit for review” flow.
3. if you want manual control over the release text, use `fastlane/metadata/en-US/release_notes.txt` and `fastlane/metadata/en-US/promotional_text.txt`; if you want me to drive it conversationally, I can pass those values directly when running `submit_review`.
4. optional test execution still exists via `run_tests:true`, but it is no longer a forced prerequisite for every archive/upload lane because that did not match the real workflow.

## Pass 030 summary

Safe cleanup changes made:
- added repo-owned shared scheme metadata for `PinProf`
- aligned iOS fastlane lanes to the real manual release process without changing app runtime behavior

Verification:
- fastlane syntax passed
- lane discovery passed
- local archive/export via fastlane passed

Outcome:
- iOS release automation is now in a usable state for future Codex-driven uploads and review submission, and the hidden scheme-state dependency is explicitly logged

Next files queued:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStateCodec.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardSection.swift`

## Pass 110: iOS Library selection/state parity extraction

Primary files:
- `Pinball App 2/Pinball App 2/library/LibrarySourceStateStore.swift`
- `Pinball App 2/Pinball App 2/library/LibrarySelectionSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryPayloadParsing.swift`
- `Pinball App 2/Pinball App 2/library/LibraryViewModel.swift`

Changes made in this pass:
- added iOS source-state store setters for selected Library sort and selected bank so the selection-persistence contract now matches Android's cleaner store surface
- extracted Library selection restoration and default-sort resolution into `LibrarySelectionSupport.swift` instead of leaving that logic inline in `PinballLibraryViewModel`
- switched `PinballLibraryBrowsingState.sortOptions` to the new shared `librarySortOptions(...)` helper instead of keeping a duplicated switch

Hidden seams surfaced and fixed:
1. the first extraction pass still carried Android leftovers (`ParsedLibraryData`, `sourceID`, and an assumed free `sortOptionsForSource` helper); those stale names were corrected immediately during the pass
2. before this pass, iOS had a cleaner runtime result but a worse ownership story than Android because view-model selection restore, default sort selection, and persistence fallback were still split across multiple files

Behavioral outcome:
- no intended front-facing behavior changed
- iOS now uses the same overall ownership shape as Android for preferred-source restore, sort selection, and bank restore

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 111: iOS Library screen/layout and state-ownership cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryListScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryViewModel.swift`
- `Pinball App 2/Pinball App 2/library/LibraryPayloadParsing.swift`

Changes made in this pass:
- extracted Library grid sizing into `LibraryScreenLayoutMetrics` so the screen no longer spreads viewport math across a long run of inline computed properties
- pulled Library initial-load, source-refresh, viewport update, and deep-link consumption behind named helpers instead of leaving them as duplicated inline closures
- removed the last dead default-sort wrapper methods from `PinballLibraryBrowsingState` after the shared selection helpers landed
- changed `PinballLibraryViewModel` to keep one live `PinballLibrarySourceState` snapshot instead of rereading `PinballLibrarySourceStateStore.load()` every time browsing state is computed

Hidden seams surfaced and fixed:
1. iOS Library browsing was still hitting persisted source state from computed view state, which was a stale ownership pattern after the newer selection-support split
2. Library deep-link handling was still duplicated across `LibraryScreen.swift` and `LibraryListScreen.swift`; the list extension no longer owns that navigation mutation path
3. the first layout extraction briefly failed the build because the new metrics type was scoped too narrowly for the list extension; that compile-only slip was corrected during the pass

Behavioral outcome:
- no intended front-facing behavior changed
- Library screen layout, source refresh, and selection persistence now have clearer ownership boundaries on iOS

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 112: iOS Settings import-screen ownership cleanup

Primary files:
- `Pinball App 2/Pinball App 2/settings/SettingsImportScreens.swift`

Changes made in this pass:
- split the venue import screen into dedicated controls/status/results cards instead of keeping all search UI, status rendering, and result rows inline inside `AddVenueScreen`
- split the tournament import screen into a dedicated import card so the view body no longer mixes route shell, provider chrome, form controls, and status rendering in one block
- introduced a tiny `SettingsImportStatusContent` value type so venue import status routing is explicit rather than embedded in a long `if / else if / else if` chain

Hidden seams surfaced and kept in view:
1. venue import still has no dedicated importing state on iOS; only search and locate states are explicit. That is still logged as a visible UX decision and was not silently changed here
2. manufacturer bucketing still relies on the hard-coded top-20 classic heuristic from earlier review passes. This pass did not change that product rule

Behavioral outcome:
- no intended front-facing behavior changed
- the Settings import screens are easier to audit and less likely to hide future behavior changes inside giant inline SwiftUI bodies

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 112 summary

Safe cleanup changes made:
- aligned iOS Library selection/state ownership with the newer Android shape
- removed stale dead Library browsing helpers
- decomposed the large iOS Settings import screens into clearer private cards and status helpers

Key findings surfaced:
1. iOS Library browsing had one outdated store-ownership seam left; it is now fixed
2. venue import still lacks a dedicated importing state on iOS, but that remains an intentional visible-behavior decision to discuss before changing

Next files queued:
- `Pinball App 2/Pinball App 2/settings/SettingsHomeSections.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDetailComponents.swift`
- `Pinball App 2/Pinball App 2/library/LibraryListScreen.swift`

## Pass 113: Settings self-refresh suppression parity fix

Primary files:
- `Pinball App 2/Pinball App 2/settings/SettingsScreen.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsScreenState.kt`

Changes made in this pass:
- added local source-change refresh suppression on both platforms so the Settings screen no longer does a full reload immediately after its own source mutation already applied a fresh local snapshot
- kept the global source-change notifications/events in place so Library, Practice, and other screens still react normally
- extended the same suppression to the hosted-data refresh path because Settings already applies the refreshed snapshot locally before broadcasting the cross-screen update event

Hidden seam surfaced and fixed:
1. Settings was carrying a redundant self-refresh loop on both iOS and Android: local add/remove/toggle/refresh actions updated state, then the screen reloaded itself again when its own global source-change event came back through
2. on iOS that meant unnecessary `loadSettingsDataSnapshot()` churn after local source edits; on Android it meant unnecessary `reload()` work after `LibrarySourceEvents.notifyChanged()`

Behavioral outcome:
- no intended front-facing behavior changed
- other screens still receive the global Library source-change event
- the active Settings screen simply stops refetching itself when it already has the up-to-date local snapshot

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest`
- result: both passed

## Pass 114: iOS Settings home-section cleanup

Primary files:
- `Pinball App 2/Pinball App 2/settings/SettingsHomeSections.swift`

Changes made in this pass:
- extracted shared section-status content for the top loading/error card plus the hosted refresh and cache inline statuses
- collapsed repeated game-count subtitle formatting for manufacturer, venue, and tournament source rows behind one helper

Hidden seams surfaced:
1. the Settings home screen was still repeating near-identical status-routing logic in three places
2. this was not a behavior bug, but it was a maintenance hotspot because tiny copy or loading-state changes had to be kept in sync manually

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 115: iOS Library detail/list cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryDetailComponents.swift`
- `Pinball App 2/Pinball App 2/library/LibraryListScreen.swift`

Changes made in this pass:
- extracted the Library detail video grid and video tile into dedicated private views so `LibraryDetailVideosCard` no longer mixes launch-panel selection, grid-column routing, tile rendering, and tap logging inline
- extracted `LibraryGameScrollContent` so grouped and ungrouped Library list layouts stop duplicating the same `ScrollView`, grid, and load-more footer wiring

Hidden seams surfaced:
1. Library detail video rendering had become another small inline SwiftUI hotspot; layout selection, logging, and tile styling were all packed into one body block
2. Library list grouped and ungrouped modes were sharing almost all of their structure but still duplicating the scroll container and footer plumbing

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 115 summary

Safe cleanup changes made:
- removed a real cross-platform redundant Settings self-refresh loop
- cleaned up repeated Settings status-routing helpers
- decomposed Library detail video rendering and Library list scroll content

Key findings surfaced:
1. the Settings self-refresh loop was a real hidden behavior issue and is now fixed on both platforms
2. no new front-facing behavior changes were made in this batch

Next files queued:
- `Pinball App 2/Pinball App 2/settings/SettingsHomeSections.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDetailComponents.swift`
- `Pinball App 2/Pinball App 2/library/LibraryResourceResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogResolution.swift`

## Pass 116: Library rulesheet parity cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryResourceResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDetailComponents.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetModels.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeVideoComponents.swift`

Changes made in this pass:
- fixed the iOS imported-rulesheet merge path so it now matches Android when a local curated rulesheet exists:
  - local/PinProf markdown-style rulesheet links are suppressed from the merged external link list
  - a local rulesheet path is suppressed if the merged external links include a Tilt Forums rulesheet
- fixed the iOS runtime Library/Practice rulesheet display path so it now suppresses local/PinProf duplicate links the same way Android already did when a local rulesheet resource exists
- split iOS rulesheet link ownership into:
  - `orderedRulesheetLinks` for raw sorted link ordering
  - `displayedRulesheetLinks` for the filtered links actually surfaced in Library/Practice UI and preferred external rulesheet resolution
- cleaned up the actor-isolation seams introduced by the new iOS rulesheet helpers so the final iOS build is warning-free again

Hidden seams surfaced and fixed:
1. iOS and Android had drifted on rulesheet suppression behavior:
   - Android already hid local/PinProf markdown links when a bundled/local rulesheet existed
   - Android also dropped the local rulesheet file path when a Tilt Forums rulesheet link was present
   - iOS was still surfacing both paths at once in some cases
2. iOS was overloading `orderedRulesheetLinks` to mean both "sorted raw links" and "links we actually display", which made the suppression behavior hard to reason about

Behavioral outcome:
- intended cross-platform parity is improved
- users should no longer see duplicate local/PinProf rulesheet chips alongside the local rulesheet resource on iOS
- no Android behavior change was needed in this pass because Android already matched the desired behavior

Stale-source sweep notes:
1. no additional live built-in-source loading path was found in Library after the default-source seeding change
2. `LibraryCatalogModels.swift` still decodes `is_builtin` for payload/schema compatibility only
3. `LibraryGame.swift` still falls back malformed/missing source names to `"Unknown Source"`; that is now the only visible old-source fallback left in the Library model path from this sweep

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`

## Pass 381: Shared UI theme-token consistency pass

Primary files:
- `Pinball App 2/Pinball App 2/ui/AppTheme.swift`
- `Pinball App 2/Pinball App 2/ui/AppContentChrome.swift`
- `Pinball App 2/Pinball App 2/ui/AppSurfaceModifiers.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/PinballDesignTokens.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/PinballTheme.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppButtonChrome.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppContentChrome.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppScreenSurface.kt`

Changes made in this pass:
- added shared status-chrome tokens on both platforms for:
  - inline status spacing
  - panel accent sizing
  - status-card and empty-card padding
  - refresh-row spacing
  - success-banner spacing and padding
- added shared atmosphere tokens on both platforms for the two background glow layers
- updated iOS shared content and background chrome to read from those tokens instead of local literals
- added Android theme parity for `brandOnGold` and updated the primary button to use theme-provided foreground ink instead of a private hardcoded color
- updated Android shared content and screen-surface chrome to read from the new token sets instead of local literals

Hidden seam surfaced and reduced:
1. shared chrome across iOS and Android was visually similar but still carrying separate hardcoded spacing and glow values in the leaf UI files
2. the new token layer makes those values part of the intentional design system instead of untracked local constants, which should make future parity review much easier

Behavioral outcome:
- no intended front-facing behavior changed
- primary action button ink, success banners, status cards, empty cards, refresh rows, and atmosphere backgrounds now read more clearly from the shared theme layer on both platforms

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`

## Pass 382: iOS Pinball data-cache runtime support split

Primary files:
- `Pinball App 2/Pinball App 2/data/PinballDataCache.swift`
- `Pinball App 2/Pinball App 2/data/PinballDataCacheRuntimeSupport.swift`

Changes made in this pass:
- moved the remaining runtime text/binary cache path out of the main iOS cache coordinator:
  - manifest-backed data load entrypoints
  - remote-update detection
  - background revalidate scheduling
  - text fetch/decode
  - binary fetch with stale fallback
  - missing-resource marking and fetched-resource persistence
- left `PinballDataCache.swift` focused on:
  - public cache entrypoints
  - remote-image cache handling
  - metadata/bootstrap coordination
  - local storage helpers

Hidden seam surfaced and reduced:
1. even after the bootstrap, metadata, and storage splits, the iOS cache coordinator was still mixing two different runtime responsibilities:
   - public cache API routing
   - the lower-level fetch/revalidate/writeback flow
2. the new runtime support file isolates the fetch/stale-fallback policy so future hosted-data changes can touch network coordination without reopening the full cache actor body

Behavioral outcome:
- no intended front-facing behavior changed
- `PinballDataCache.swift` now reads more clearly as the runtime coordinator shell instead of also carrying the whole network fetch pipeline inline

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`

## Pass 383: Android Pinball data-cache runtime support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCache.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCacheRuntimeSupport.kt`

Changes made in this pass:
- moved the matching Android runtime cache path out of the main cache object:
  - byte fetch with stale fallback
  - background revalidate launch
  - passthrough-or-cached text/bytes helpers
  - manifest-backed image-model resolution
- kept thin member wrappers in `PinballDataCache.kt` so the rest of the app still calls the same public API surface while the heavier runtime flow lives in one support layer

Hidden seam surfaced and reduced:
1. the Android cache object had reached the same late-stage shape as iOS, where the remaining weight was mostly the runtime fetch/revalidate path rather than bootstrap or metadata logic
2. using a support file plus thin wrappers preserves the current call sites while making the runtime path easier to compare against iOS 1:1

Behavioral outcome:
- no intended front-facing behavior changed
- `PinballDataCache.kt` now reads more clearly as the cache API shell plus state host instead of also carrying the entire fetch/revalidate implementation inline

Verification:
- `./gradlew :app:compileDebugKotlin`

## Late-stage paired polish plan

Tracking rule for the remaining work:
- prefer paired iOS/Android passes whenever the seam exists on both platforms
- keep the scope as close to 1:1 as practical, but preserve platform-specific idioms when the UI or runtime model is genuinely different
- treat QA, automation, and performance review as first-class cleanup work, not just code splitting

Remaining paired passes worth doing:

1. Shared UI and theme consistency pass
- iOS:
  - `Pinball App 2/Pinball App 2/ui/AppTheme.swift`
- Android:
  - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppContentChrome.kt`
  - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppScreenSurface.kt`
- Goal:
  - tighten spacing, section chrome, surface hierarchy, and shared copy/empty-state consistency

2. Cache and hosted-asset validation pass
- iOS:
  - `Pinball App 2/Pinball App 2/data/PinballDataCache.swift`
  - `Pinball App 2/Pinball App 2/data/PinballDataCacheMetadataSupport.swift`
  - `Pinball App 2/Pinball App 2/data/PinballDataCacheBootstrapSupport.swift`
- Android:
  - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCache.kt`
  - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCacheMetadataSupport.kt`
  - `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCacheBootstrapSupport.kt`
- Goal:
  - verify preload seeding, hosted image fetches, rulesheet loads, refresh behavior, and stale-data fallback behavior

3. Paired smoke and UI automation pass
- iOS:
  - League previews -> Stats / Standings / Targets
  - Library filters / game detail / rulesheet
  - Practice quick entry / scanner entry point
  - GameRoom settings / import / edit / archive
  - Settings home / import screens
- Android:
  - same feature path coverage as iOS
- Goal:
  - turn the manual late-stage regression checklist into repeatable simulator/emulator coverage where practical

4. Perf-focused follow-up only if QA reveals a real issue
- iOS:
  - runtime fetch / revalidate path in `PinballDataCache.swift`
- Android:
  - runtime fetch / revalidate path in `PinballDataCache.kt`
- Goal:
  - only do more cache/runtime refactoring if an actual hot path, redundant work pattern, or flaky refresh behavior shows up in testing
- result: both passed

## Pass 378: Practice journal-linking support split

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeStoreJournalMutationSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreJournalLinkingSupport.swift`

Changes made in this pass:
- moved the journal-to-entry linking helpers out of `PracticeStoreJournalMutationSupport.swift`:
  - score log matching
  - study-event matching
  - video progress matching
  - note entry matching
  - journal-action task mapping
  - study-event reconcile/update behavior
- left `PracticeStoreJournalMutationSupport.swift` focused on the two mutation entrypoints:
  - `updateJournalEntry(...)`
  - `deleteJournalEntry(...)`

Hidden seam surfaced and reduced:
1. the journal mutation file was still mixing edit/delete orchestration with all of the identity-matching policy for score, note, study, and video records
2. the new support file makes that journal-linking policy reviewable in one place, without reopening the mutation entrypoints themselves

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`

## Pass 379: Android Pinside slug and title support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPinsideParsingSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPinsideSlugSupport.kt`

Changes made in this pass:
- moved the slug/title helper layer out of `GameRoomPinsideParsingSupport.kt`:
  - Cloudflare challenge-page detection
  - collection slug extraction
  - slug-to-title resolution via group-map fallback
  - slug-based variant inference
  - humanized fallback title generation
- updated the parsing file to call the extracted helpers directly, so it now reads more like the actual collection/detail parser and merge coordinator

Hidden seam surfaced and reduced:
1. `GameRoomPinsideParsingSupport.kt` was still mixing collection/detail parsing with a second layer of slug/title normalization policy
2. the new support file isolates that slug policy so future import cleanup can change normalization without reopening the parser loops

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`

## Pass 380: Pinball data-cache bootstrap support split

Primary files:
- `Pinball App 2/Pinball App 2/data/PinballDataCache.swift`
- `Pinball App 2/Pinball App 2/data/PinballDataCacheBootstrapSupport.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCache.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCacheBootstrapSupport.kt`

Changes made in this pass:
- moved cache bootstrap/preload responsibilities out of the main data-cache coordinators on both platforms:
  - cache-root creation
  - legacy cache purge marker handling
  - bundled preload seeding
  - saved-index bootstrap loading on iOS
- left the main cache files focused more tightly on the public cache API, fetch/revalidate coordination, and metadata refresh

Hidden seam surfaced and reduced:
1. the data-cache files were still mixing startup/bootstrap responsibilities with the actual runtime cache API and network revalidation flow
2. the new bootstrap support files isolate the one-time load/reset/preload policy so future cache work can touch startup behavior without reopening the runtime fetch path

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`

## Pass 377: Pinball data-cache metadata support split

Primary files:
- `Pinball App 2/Pinball App 2/data/PinballDataCache.swift`
- `Pinball App 2/Pinball App 2/data/PinballDataCacheMetadataSupport.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCache.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCacheMetadataSupport.kt`

Changes made in this pass:
- moved manifest/update-log fetch and removed-path application support out of the main data-cache files on both platforms
- left the platform cache objects focused on:
  - cache coordination
  - resource fetch/revalidate flow
  - disk cache entry reads and writes
- kept the current preload/storage split intact and added one narrower metadata-refresh support layer on top of it

Hidden seam surfaced and reduced:
1. both cache files were still mixing two different responsibilities:
   - long-lived cache coordination/state
   - one-shot metadata refresh parsing and removed-path bookkeeping
2. that made the main cache files heavier than they needed to be, especially since the same manifest/update-log contract exists on both platforms

Notable follow-up surfaced while verifying:
1. the iOS target uses default main-actor isolation broadly enough that plain support helpers in app code need explicit `nonisolated` handling when called from inside an actor
2. `ScoreScannerSessionSupport.swift` still emits a non-blocking `switch must be exhaustive` warning during iOS builds; that warning predates this cache split and is outside this pass

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 118: Hosted library cache stale-first revalidation parity

Primary files:
- `Pinball App 2/Pinball App 2/data/PinballDataCache.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCache.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryHostedData.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryScreenStateSupport.kt`

Changes made in this pass:
- changed both cache coordinators so hosted text payloads and allow-missing markers return stale cached results immediately, then trigger background revalidation instead of blocking first paint
- kept first-load blocking only for the true no-cache case
- moved Android library extraction work fully onto `Dispatchers.IO`
- parallelized Android hosted Library sidecar loads so first render no longer serially waits through every hosted payload

Hidden seams surfaced and fixed:
1. the cache-runtime split left both platforms still treating stale hosted text as a synchronous fetch boundary, which was acceptable for explicit refreshes but wrong for Library and Practice hydration
2. Android Library compounded that by loading hosted sidecars serially on the route path, so stale or slow network checks could trap the tab on `Loading library…` despite valid cached payloads already being on disk

Behavioral outcome:
- Library and Practice now paint from stale hosted cache immediately when data exists
- Android Library no longer hangs on `Loading library…` when the hosted sidecars are already cached but revalidation is slow
- stale revalidation still happens in the background so the cache can refresh without blocking first paint

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- Android emulator QA: Library now renders catalog content instead of staying on the loading screen

## Pass 119: Android remote rulesheet fallback hardening

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetExternalWebSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetScreenSupport.kt`

Changes made in this pass:
- introduced `RulesheetLoadResult` so the Android rulesheet route can distinguish between embedded HTML content and an external-web fallback URL
- added timeout-bounded remote embedded rulesheet loading on a separate thread boundary instead of waiting indefinitely on blocking `HttpURLConnection` work
- degraded Android remote rulesheet failures into `ExternalRulesheetWebView` instead of leaving the screen on a permanent loading spinner
- limited progress and resume UI to the embedded-render path only

Hidden seams surfaced and fixed:
1. Android remote rulesheet loading had no failure escape hatch while iOS already degraded to an external web fallback, so the two platforms had drifted on a real user-facing failure mode
2. coroutine timeouts were not enough because the blocking remote rulesheet loader did not reliably cooperate with cancellation, so the timeout had to be enforced outside the loader thread itself

Behavioral outcome:
- Android Library remote rulesheets now open a usable external web fallback when embedded loading stalls or fails
- the viewer no longer stays stuck on `Loading rulesheet…` indefinitely for remote rulesheet sources

Verification:
- `./gradlew :app:compileDebugKotlin`
- Android emulator QA: opening the `TF` rulesheet now reaches a `WebView` route instead of staying on the loading spinner

## Pass 120: Hosted playfield viewer fallback parity

Primary files:
- `Pinball App 2/Pinball App 2/library/HostedImageCandidateSupport.swift`
- `Pinball App 2/Pinball App 2/library/HostedImageScreen.swift`
- `Pinball App 2/Pinball App 2/library/RemoteUIImageSupport.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/HostedImageCandidateSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/HostedImageRequestSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/HostedImageScreenSupport.kt`

Changes made in this pass:
- added paired hosted-image candidate prioritization so fullscreen playfield viewers prefer the faster `_1400` and `_700` PinProf candidates ahead of slower original or external candidates
- added iOS candidate timeout advancement and final timeout failure handling so the hosted-image viewer can move past stalled candidates instead of waiting forever
- made Android fullscreen playfield requests stop blocking on cache-model resolution before the image request even starts
- added Android fullscreen hosted-image failure UI with an `Open Original URL` escape hatch instead of leaving the screen on a permanent loading overlay
- hardened the iOS loader against cancellation so candidate-advance tasks do not leave stale failure state behind

Hidden seams surfaced and fixed:
1. fullscreen hosted-image QA showed the cache/runtime work had fixed Library hydration, but the playfield viewer could still hang behind slow or stalled image candidates
2. iOS and Android had drifted on the failure mode: iOS already had a real failure state for hosted images, while Android could stay on `Loading image…` indefinitely with no recovery path

Behavioral outcome:
- iOS fullscreen playfields still load successfully after the candidate-ordering and timeout changes
- Android fullscreen playfields now either load or degrade to a clear failure state with an external-open option instead of hanging forever
- both platforms now use the same high-level candidate-ordering rule for hosted playfield images

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- iOS simulator QA: Library detail -> `PinProf` playfield still renders the fullscreen playfield image
- Android emulator QA: Library detail -> `PinProf` playfield now reaches `Could not load image.` plus `Open Original URL` instead of staying on `Loading image…`

## Pass 118: Hosted library cache stale-first revalidation parity

Primary files:
- `Pinball App 2/Pinball App 2/data/PinballDataCache.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCache.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryHostedData.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryScreenStateSupport.kt`

Changes made in this pass:
- changed both cache coordinators so stale hosted text returns immediately when cached data exists, while background revalidation is scheduled instead of blocking first paint
- changed allow-missing cache markers on both platforms to follow the same stale-first rule: return the current missing result immediately and refresh in the background when the record is old
- moved Android Library extraction work onto the IO dispatcher and loaded hosted Library sidecar payloads in parallel so the screen no longer owns a long serial hydration chain
- kept one Android screen-level performance trace around the full Library load path and removed the temporary per-asset investigation traces once the root cause was confirmed

Hidden seams surfaced and fixed:
1. the paired cache runtime cleanup had left both platforms with a stricter freshness policy than the app actually wants for first-paint Library and Practice hydration
2. Android surfaced the bug more obviously because stale hosted Library payloads forced a network path before the Library screen could render anything, leaving the tab stuck on `Loading library...`
3. the root issue was not corrupt hosted payload data; the cached OPDB export and sidecar assets were present and valid, but the stale-first behavior contract was missing from the runtime coordinators

Behavioral outcome:
- Library now renders immediately from cached hosted payloads on both platforms even when those payloads are older than the freshness window
- background refresh still happens, but stale cache age no longer blocks the first visible Library state
- no intended front-facing cache policy changed for true cache misses; those still fetch live data

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- Android emulator QA: Library tab now opens into real content instead of staying on `Loading library...`
- iOS simulator QA: Library tab still opens into real content after the paired cache behavior change

## Pass 363: iOS Settings home section split

Primary files:
- `Pinball App 2/Pinball App 2/settings/SettingsHomeSections.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsHomeAppearanceSupport.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsHomeLibrarySupport.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsHomeHostedDataSupport.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsHomePrivacyAboutSupport.swift`

Changes made in this pass:
- moved appearance controls out of `SettingsHomeSections.swift`
- moved Library source management UI and delete-confirm flow into `SettingsHomeLibrarySupport.swift`
- moved hosted-data refresh/cache controls into `SettingsHomeHostedDataSupport.swift`
- moved privacy/about cards into `SettingsHomePrivacyAboutSupport.swift`
- left `SettingsHomeSections.swift` focused on screen-level status assembly and section orchestration

Hidden seam surfaced and fixed:
1. the extracted iOS section views still needed the shared section-status helpers from `SettingsHomeSections.swift`
2. widening those helpers from file-private ownership to module-local reuse kept the screen shell small without duplicating status-card code

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 364: Android Settings home section split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsHomeSections.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsHomeAppearanceSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsHomeLibrarySupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsHomeHostedDataSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsHomePrivacyAboutSupport.kt`

Changes made in this pass:
- moved appearance controls out of `SettingsHomeSections.kt`
- moved Library source add/manage UI and delete-confirm flow into `SettingsHomeLibrarySupport.kt`
- moved hosted-data refresh/cache controls into `SettingsHomeHostedDataSupport.kt`
- moved privacy/about cards into `SettingsHomePrivacyAboutSupport.kt`
- left `SettingsHomeSections.kt` as the LazyColumn shell and screen-status coordinator

Hidden seam surfaced and fixed:
1. the first Android split imported the wrong `weight` symbol in `SettingsHomeLibrarySupport.kt`, which resolved to an internal layout property instead of the normal RowScope modifier
2. removing that explicit import restored the repo's existing Compose pattern and brought the extracted Library section back to a clean compile

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 367: iOS shake-warning support split

Primary files:
- `Pinball App 2/Pinball App 2/app/AppShakeCoordinator.swift`
- `Pinball App 2/Pinball App 2/app/AppShakeWarningModels.swift`
- `Pinball App 2/Pinball App 2/app/AppShakeWarningHaptics.swift`
- `Pinball App 2/Pinball App 2/app/AppShakeWarningOverlaySupport.swift`

Changes made in this pass:
- moved shake-warning models out of `AppShakeCoordinator.swift`
- moved Core Haptics and UIKit fallback playback into `AppShakeWarningHaptics.swift`
- moved overlay layout, professor artwork loading, fallback art, and subtitle font support into `AppShakeWarningOverlaySupport.swift`
- left `AppShakeCoordinator.swift` as the undo-aware coordinator and overlay-state host

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 368: Android shake-warning support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/AppShakeWarning.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/AppShakeWarningModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/AppShakeMotionSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/AppShakeWarningOverlaySupport.kt`

Changes made in this pass:
- moved shake-warning models, motion tuning, and vibration effect policy out of `AppShakeWarning.kt`
- moved accelerometer/linear-acceleration observation and lifecycle-aware motion effect support into `AppShakeMotionSupport.kt`
- moved overlay host, warning card UI, professor art loading, and fallback placeholder UI into `AppShakeWarningOverlaySupport.kt`
- left `AppShakeWarning.kt` as the overlay-state coordinator and haptics service host

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 369: iOS league preview surface split

Primary files:
- `Pinball App 2/Pinball App 2/league/LeaguePreviewSections.swift`
- `Pinball App 2/Pinball App 2/league/LeagueTargetsPreview.swift`
- `Pinball App 2/Pinball App 2/league/LeagueStandingsPreview.swift`
- `Pinball App 2/Pinball App 2/league/LeagueStatsPreview.swift`

Changes made in this pass:
- moved the targets mini-preview out of `LeaguePreviewSections.swift` into `LeagueTargetsPreview.swift`
- moved the standings mini-preview out of `LeaguePreviewSections.swift` into `LeagueStandingsPreview.swift`
- moved the stats mini-preview out of `LeaguePreviewSections.swift` into `LeagueStatsPreview.swift`
- deleted the stale mixed `LeaguePreviewSections.swift` bucket once the three leaf surfaces had real homes

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 370: Android league preview surface and shell split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeagueMiniPreviews.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeagueStatsMiniPreview.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeagueStandingsMiniPreview.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeagueTargetsMiniPreview.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeaguePreviewFormattingSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeagueShellContent.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeagueShellCardSupport.kt`

Changes made in this pass:
- moved the stats, standings, and targets mini-preview composables out of `LeagueMiniPreviews.kt` into dedicated support files
- moved the shared rank-color and number-formatting helpers into `LeaguePreviewFormattingSupport.kt`
- moved the destination-card and about-footer composition out of `LeagueShellContent.kt` into `LeagueShellCardSupport.kt`
- left `LeagueShellContent.kt` as the layout shell that chooses portrait versus landscape composition
- deleted the stale mixed `LeagueMiniPreviews.kt` file once the support files were in place

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 371: iOS league preview parsing split

Primary files:
- `Pinball App 2/Pinball App 2/league/LeaguePreviewParsing.swift`
- `Pinball App 2/Pinball App 2/league/LeaguePreviewParsingSupport.swift`
- `Pinball App 2/Pinball App 2/league/LeagueStandingsPreviewSupport.swift`
- `Pinball App 2/Pinball App 2/league/LeagueStatsPreviewSupport.swift`
- `Pinball App 2/Pinball App 2/league/LeagueNextBankSupport.swift`

Changes made in this pass:
- moved shared parsed-row and helper functions out of `LeaguePreviewParsing.swift` into `LeaguePreviewParsingSupport.swift`
- moved standings payload/build/CSV parsing into `LeagueStandingsPreviewSupport.swift`
- moved stats payload/build/CSV parsing into `LeagueStatsPreviewSupport.swift`
- moved next-bank resolution into `LeagueNextBankSupport.swift`
- deleted the stale mixed `LeaguePreviewParsing.swift` file once the narrower support files existed

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 372: Android league preview parsing split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeaguePreviewParsing.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeaguePreviewParsingSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeagueStandingsPreviewSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeagueStatsPreviewSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeagueNextBankSupport.kt`

Changes made in this pass:
- moved shared name-matching, season coercion, sort-value, and around-you window helpers out of `LeaguePreviewParsing.kt` into `LeaguePreviewParsingSupport.kt`
- moved standings preview build/CSV parsing into `LeagueStandingsPreviewSupport.kt`
- moved stats preview build/CSV parsing into `LeagueStatsPreviewSupport.kt`
- moved next-bank resolution into `LeagueNextBankSupport.kt`
- removed the dead target-row parsing and library-merge helpers while splitting, because they were no longer used anywhere in the Android league loader path
- deleted the stale mixed `LeaguePreviewParsing.kt` file once the narrower support files existed

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 373: iOS data-cache storage support split

Primary files:
- `Pinball App 2/Pinball App 2/data/PinballDataCache.swift`
- `Pinball App 2/Pinball App 2/data/PinballDataCacheStorageSupport.swift`

Changes made in this pass:
- moved preload-manifest models, cache manifest/update-log models, and cache-index models out of `PinballDataCache.swift`
- moved the bundled preload/path hashing and index read/write helpers into `PinballDataCacheStorageSupport.swift`
- rewired `PinballDataCache.swift` to consume those helpers while keeping the actor as the fetch/revalidate coordinator
- left remote image revalidation and network fetch policy in the main cache file

Hidden seam surfaced and fixed:
1. moving the cache models out of the actor file required renaming the generic nested `Manifest`, `UpdateLog`, and `CacheIndex` types to explicit cache-prefixed models so the support file could own them cleanly
2. the first rewrite also left one stale inline index-load path in the actor; routing that through the shared helper kept the split consistent and the build clean

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 374: Android data-cache storage support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCache.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data/PinballDataCacheStorageSupport.kt`

Changes made in this pass:
- moved preload asset constants, cache-root/resource/index path helpers, SHA-256 helpers, and JSON index read/write helpers out of `PinballDataCache.kt`
- moved bundled preload manifest/path loading into `PinballDataCacheStorageSupport.kt`
- rewired `PinballDataCache.kt` to use the shared storage helpers while keeping the object focused on fetch/revalidate and network/cache policy
- cleaned a stale unused import while trimming the main file

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 375: iOS practice entry mutation support split

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreStudyEntrySupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreEntryLoggingSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreEntrySettingsSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreJournalMutationSupport.swift`

Changes made in this pass:
- deleted the stale mixed `PracticeStoreEntryMutations.swift` bucket once the narrower mutation files existed
- moved study progress lookup and task/video progress logging into `PracticeStoreStudyEntrySupport.swift`
- moved score/note/browse journaling into `PracticeStoreEntryLoggingSupport.swift`
- moved practice settings, analytics settings, state reset, and imported-league purge into `PracticeStoreEntrySettingsSupport.swift`
- moved journal edit/delete behavior and the score/video/note/study reconciliation helpers into `PracticeStoreJournalMutationSupport.swift`

Hidden seam surfaced and fixed:
1. the journal edit/delete path looked like a generic mutation bucket at first, but it actually depends on one private cluster of nearest-match and study-reconcile helpers
2. keeping that reconciliation logic together in `PracticeStoreJournalMutationSupport.swift` avoided creating cross-file private-helper drift while still deleting the catch-all file

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 376: Android Pinside import support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPinsideImport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPinsideImportModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPinsideUrlSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPinsideNetworkSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPinsideParsingSupport.kt`

Changes made in this pass:
- moved imported-machine/result models and import error/message mapping out of `GameRoomPinsideImport.kt`
- moved collection URL normalization/building into `GameRoomPinsideUrlSupport.kt`
- moved direct/Jina fetch and collection-page validation into `GameRoomPinsideNetworkSupport.kt`
- moved basic/detailed machine parsing and merge logic into `GameRoomPinsideParsingSupport.kt`
- rewired `GameRoomPinsideImport.kt` so the service now reads as the fallback/coordinator layer plus group-map loading

Hidden seam surfaced and fixed:
1. the parser already depended on shared helpers in the wider GameRoom package for displayed-title normalization and purchase-date normalization
2. reusing `canonicalPinsideDisplayedTitle(...)` and `normalizeFirstOfMonthMs(...)` in the new support files avoided creating duplicate Pinside normalization paths during the split

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 365: iOS intro overlay support split

Primary files:
- `Pinball App 2/Pinball App 2/app/AppIntroOverlay.swift`
- `Pinball App 2/Pinball App 2/app/AppIntroModels.swift`
- `Pinball App 2/Pinball App 2/app/AppIntroArtworkSupport.swift`
- `Pinball App 2/Pinball App 2/app/AppIntroViewSupport.swift`

Changes made in this pass:
- moved intro card models, theme values, and typography helpers out of `AppIntroOverlay.swift`
- moved artwork loading, screenshot/welcome art, and professor spotlight support into `AppIntroArtworkSupport.swift`
- moved backdrop, deck page, card shell, copy column, quote rendering, and page indicators into `AppIntroViewSupport.swift`
- left `AppIntroOverlay.swift` as the modal overlay shell and dismiss/paging coordinator

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 366: Android intro overlay support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/AppIntroOverlay.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/AppIntroModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/AppIntroArtworkSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/AppIntroViewSupport.kt`

Changes made in this pass:
- moved intro card models, theme values, typography, and accent resolution out of `AppIntroOverlay.kt`
- moved screenshot/welcome artwork and professor spotlight support into `AppIntroArtworkSupport.kt`
- moved backdrop, deck page, card shell, quote rendering, and page indicators into `AppIntroViewSupport.kt`
- left `AppIntroOverlay.kt` as the overlay host and pager/dismiss coordinator

Hidden seam surfaced and fixed:
1. the first Android support-file cut carried an explicit `matchParentSize` import that did not belong in this codebase and missed the shell file's `statusBarsPadding` import
2. removing the stray import and restoring the normal layout import brought the extracted overlay back to a clean compile without reopening the shell file

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 347: iOS shared content and table chrome split

Primary files:
- `Pinball App 2/Pinball App 2/ui/SharedTableUi.swift`
- `Pinball App 2/Pinball App 2/ui/AppContentChrome.swift`
- `Pinball App 2/Pinball App 2/ui/AppTableChrome.swift`

Changes made in this pass:
- moved table layout, divider, and header-cell helpers out of `SharedTableUi.swift` into `AppTableChrome.swift`
- moved reusable content chrome out of `SharedTableUi.swift` into `AppContentChrome.swift`:
  - section/card titles
  - inline title-with-variant label and UIKit bridge
  - metric grid
  - inline/panel status and empty-state cards
- left `SharedTableUi.swift` focused on the native clear-text field bridge

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 348: Android shared content chrome split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppContentChrome.kt`

Changes made in this pass:
- moved reusable content chrome out of `CommonUi.kt` into `AppContentChrome.kt`:
  - section/card titles
  - metric grid
  - empty/status surfaces
  - refresh row
  - passive/tinted status chips
  - metric pill and three-column legend header
- left `CommonUi.kt` focused on app shell, route/header structure, gestures, controls, and button primitives

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 349: iOS button and filter chrome cleanup

Primary files:
- `Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`
- `Pinball App 2/Pinball App 2/ui/AppButtonStyles.swift`
- `Pinball App 2/Pinball App 2/ui/AppContentChrome.swift`

Changes made in this pass:
- moved generic button-press feedback and reusable button styles out of `AppFilterControls.swift` into `AppButtonStyles.swift`
- moved generic content-status chrome out of `AppFilterControls.swift` into `AppContentChrome.swift`:
  - inline link action
  - refresh status row
  - passive/tinted status chips
  - metric pill
  - success banner
- left `AppFilterControls.swift` focused on toolbar, menu-label, and filter-control presentation

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 350: shared resource pill chrome split

Primary files:
- `Pinball App 2/Pinball App 2/ui/AppResourceChrome.swift`
- `Pinball App 2/Pinball App 2/ui/AppResourcePillChrome.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppResourceChrome.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppResourcePillSupport.kt`

Changes made in this pass:
- moved reusable resource pill, badge, wrap-layout, and inline-text-with-pill infrastructure into dedicated support files on both platforms
- left the remaining resource chrome files focused on:
  - overlay titles and subtitles
  - reading-progress chrome
  - media preview placeholders
  - video-tile chrome

Hidden seam surfaced and fixed:
1. Android `AppResourceChrome.kt` initially kept too many now-unused imports after the split
2. the support split stayed intact; only the surviving file imports were tightened enough to rebuild cleanly

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 351: iOS inline-title chrome split

Primary files:
- `Pinball App 2/Pinball App 2/ui/AppContentChrome.swift`
- `Pinball App 2/Pinball App 2/ui/AppInlineTitleChrome.swift`

Changes made in this pass:
- moved the UIKit-backed inline title-with-variant bridge out of `AppContentChrome.swift` into `AppInlineTitleChrome.swift`
- moved the supporting appearance model, UILabel subclass, and string/font helpers with it
- left `AppContentChrome.swift` focused on SwiftUI-native metric, status, and panel content chrome

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 352: Android app surface chrome split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppSurfaceChrome.kt`

Changes made in this pass:
- moved the shared app surface shell out of `CommonUi.kt` into `AppSurfaceChrome.kt`:
  - composition-local bottom-bar visibility
  - background and route-screen shell
  - keyboard-dismiss background gesture
  - back/header icon buttons
  - screen header
- left `CommonUi.kt` focused on controls, swipe actions, inline actions, and remaining generic UI widgets

Hidden seam surfaced and fixed:
1. the first cut trimmed `CommonUi.kt` imports too aggressively, which surfaced as unresolved references during the Android compile
2. restoring the remaining imports kept the file boundary intact without undoing the split

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 353: Android info chrome split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppContentChrome.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppInfoChrome.kt`

Changes made in this pass:
- moved shared info/title chrome out of `AppContentChrome.kt` into `AppInfoChrome.kt`:
  - section title
  - card heading/title surfaces
  - metric grid
  - empty label
- left `AppContentChrome.kt` focused on status cards, banners, refresh chrome, and other feedback surfaces

Hidden seam surfaced and fixed:
1. the first Android cut trimmed `AppContentChrome.kt` imports too aggressively after the move
2. restoring only the still-needed layout/background imports kept the split intact without re-mixing the title chrome

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 354: Android inline pill text support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppResourcePillSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppInlinePillTextSupport.kt`

Changes made in this pass:
- moved the inline title-with-pill layout machinery out of `AppResourcePillSupport.kt` into `AppInlinePillTextSupport.kt`
- moved the supporting candidate, measurement, truncation, and fit-resolution helpers with it
- left `AppResourcePillSupport.kt` focused on resource-row and pill presentation instead of also owning custom text layout math

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 355: iOS surface modifier split

Primary files:
- `Pinball App 2/Pinball App 2/ui/AppTheme.swift`
- `Pinball App 2/Pinball App 2/ui/AppSurfaceModifiers.swift`

Changes made in this pass:
- moved the shared app background and reusable view modifiers out of `AppTheme.swift` into `AppSurfaceModifiers.swift`:
  - `AppBackground`
  - readable-width and panel/control/list style modifiers
  - keyboard-dismiss tap gesture helper
- left `AppTheme.swift` focused on theme tokens, semantic colors, and layout constants

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 356: iOS info chrome split

Primary files:
- `Pinball App 2/Pinball App 2/ui/AppContentChrome.swift`
- `Pinball App 2/Pinball App 2/ui/AppInfoChrome.swift`

Changes made in this pass:
- moved shared info/title chrome out of `AppContentChrome.swift` into `AppInfoChrome.swift`:
  - section title
  - card headings/titles
  - title-with-variant card wrapper
  - metric grid item/model
- left `AppContentChrome.swift` focused on status, refresh, and feedback surfaces

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 357: shared status pill chrome split

Primary files:
- `Pinball App 2/Pinball App 2/ui/AppContentChrome.swift`
- `Pinball App 2/Pinball App 2/ui/AppStatusPillChrome.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppContentChrome.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppStatusPillSupport.kt`

Changes made in this pass:
- moved reusable status-pill and metric-pill chrome out of the generic content files into dedicated shared-UI support files on both platforms
- moved Android's reusable three-column legend header with the pill helpers so the content file no longer owns compact legend layout logic
- left the remaining content chrome files focused on inline status messaging, success banners, panel cards, and refresh-state presentation

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 358: Android shared button and selection chrome split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppButtonChrome.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppSelectionChrome.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppToggleControls.kt`

Changes made in this pass:
- moved Android toggle controls out of `CommonUi.kt` into `AppToggleControls.kt`:
  - switch colors and wrapper
  - checkbox colors and wrapper
- moved reusable button/action chrome out of `CommonUi.kt` into `AppButtonChrome.kt`:
  - external-link button
  - inline/text actions
  - top-bar dropdown trigger
  - primary/secondary/destructive buttons
- moved row/pill selection chrome out of `CommonUi.kt` into `AppSelectionChrome.kt`
- left `CommonUi.kt` focused on:
  - card container/control card
  - swipe actions
  - inset filter header

Hidden seam surfaced and fixed:
1. the first Android cut missed one `clip` import in the new selection file and the surviving `Icons` import in `CommonUi.kt`
2. tightening only those imports kept the split intact without re-mixing the controls

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 359: Android route edge-swipe migration

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppSurfaceChrome.kt`

Changes made in this pass:
- moved the `iosEdgeSwipeBack` modifier out of `CommonUi.kt` into `AppSurfaceChrome.kt`
- colocated the back-swipe gesture with the route/surface shell that consumes it
- left `CommonUi.kt` free of route-navigation gesture ownership

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 360: Android screen surface split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppSurfaceChrome.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppScreenSurface.kt`

Changes made in this pass:
- moved the shared Android screen shell out of `AppSurfaceChrome.kt` into `AppScreenSurface.kt`:
  - bottom-bar composition local
  - `AppScreen` and `AppRouteScreen`
  - edge-swipe back gesture
  - keyboard-dismiss background tap gesture
  - atmosphere background
- left `AppSurfaceChrome.kt` focused on back/header/icon chrome

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 361: Android inline action chrome split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppButtonChrome.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppInlineActionChrome.kt`

Changes made in this pass:
- moved inline action surfaces out of `AppButtonChrome.kt` into `AppInlineActionChrome.kt`:
  - inline action chip
  - text action
  - inline link action
  - top-bar dropdown trigger
- left `AppButtonChrome.kt` focused on button-style surfaces:
  - external-link button
  - primary/secondary/destructive buttons

Hidden seam surfaced and fixed:
1. the first cut of `AppInlineActionChrome.kt` missed the `dp` unit import
2. removing an unnecessary explicit `weight` import restored the normal RowScope-based layout usage

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 362: iOS display and layout token split

Primary files:
- `Pinball App 2/Pinball App 2/ui/AppTheme.swift`
- `Pinball App 2/Pinball App 2/ui/AppDisplayMode.swift`
- `Pinball App 2/Pinball App 2/ui/AppLayoutTokens.swift`

Changes made in this pass:
- moved `AppDisplayMode` out of `AppTheme.swift` into `AppDisplayMode.swift`
- moved `AppSpacing`, `AppRadii`, and `AppLayout` out of `AppTheme.swift` into `AppLayoutTokens.swift`
- left `AppTheme.swift` focused on semantic colors, token structs, and the central theme/color bridge

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 341: iOS standings support split

Primary files:
- `Pinball App 2/Pinball App 2/standings/StandingsScreen.swift`
- `Pinball App 2/Pinball App 2/standings/StandingsModels.swift`
- `Pinball App 2/Pinball App 2/standings/StandingsDataSupport.swift`
- `Pinball App 2/Pinball App 2/standings/StandingsViewModel.swift`
- `Pinball App 2/Pinball App 2/standings/StandingsViewSupport.swift`

Changes made in this pass:
- moved standings row models out of `StandingsScreen.swift`
- moved CSV parsing and formatting helpers out of `StandingsScreen.swift`
- moved the standings loader/state object out to `StandingsViewModel.swift`
- moved row/header view helpers out to `StandingsViewSupport.swift`
- left `StandingsScreen.swift` as the screen shell and filter/presentation coordinator

Hidden seam surfaced and fixed:
1. the extracted `StandingsViewModel.swift` kept `@Published` state but initially lost its `Combine` import during the split
2. adding that import restored the expected observable-object boundary without changing behavior

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 342: iOS targets support split

Primary files:
- `Pinball App 2/Pinball App 2/targets/TargetsScreen.swift`
- `Pinball App 2/Pinball App 2/targets/TargetsModels.swift`
- `Pinball App 2/Pinball App 2/targets/TargetsViewModel.swift`
- `Pinball App 2/Pinball App 2/targets/TargetsViewSupport.swift`

Changes made in this pass:
- moved target rows, sort mode, and formatting helpers out of `TargetsScreen.swift`
- moved target load/sort/filter state out to `TargetsViewModel.swift`
- moved row/header leaf views out to `TargetsViewSupport.swift`
- left `TargetsScreen.swift` as the route shell and explanatory chrome

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 343: Android standings support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/standings/StandingsScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/standings/StandingsModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/standings/StandingsDataSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/standings/StandingsViewSupport.kt`

Changes made in this pass:
- moved standings row models out of `StandingsScreen.kt`
- moved CSV parsing, season coercion, and formatting helpers out of `StandingsScreen.kt`
- moved header/row leaf views out of `StandingsScreen.kt`
- left `StandingsScreen.kt` as the Compose screen shell and refresh/filter coordinator

Hidden seam surfaced and fixed:
1. one call site still referenced the old `StandingRow(...)` name after the view split
2. that was updated to `StandingsRow(...)` so the screen keeps using the extracted leaf view without duplicating the row implementation

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 344: Android targets support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/targets/TargetsScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/targets/TargetsModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/targets/TargetsDataSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/targets/TargetsViewSupport.kt`

Changes made in this pass:
- moved target models and bundled LPL target rows out of `TargetsScreen.kt`
- moved resolved-target loading and sort policy out of `TargetsScreen.kt`
- moved filter controls and table leaf views out of `TargetsScreen.kt`
- left `TargetsScreen.kt` as the screen shell and state coordinator

Hidden seam surfaced and fixed:
1. the first support-file cut carried an invalid Material import that did not belong in the extracted dropdown/view helper file
2. removing that import restored the build without broadening the screen file again

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 345: iOS settings import support split

Primary files:
- `Pinball App 2/Pinball App 2/settings/SettingsImportScreens.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsManufacturerSupport.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsVenueImportSupport.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsTournamentImportSupport.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsImportSharedViews.swift`

Changes made in this pass:
- moved manufacturer bucket/filter support out of `SettingsImportScreens.swift`
- moved venue search status, venue controls, venue results, and location-request plumbing into `SettingsVenueImportSupport.swift`
- moved tournament import error handling and card UI into `SettingsTournamentImportSupport.swift`
- moved provider caption and import-result row UI into `SettingsImportSharedViews.swift`
- left `SettingsImportScreens.swift` focused on the three screen shells and their async orchestration

Hidden seam surfaced and fixed:
1. `SettingsImportScreens.swift` still directly accessed `coordinate.latitude` and `coordinate.longitude` after the location requester moved out
2. restoring the `CoreLocation` import in the screen file kept the split clean without dragging the requester back into the screen file

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 346: Android settings import support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsImportScreens.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsManufacturerSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsImportHtmlSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsVenueImportSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsTournamentImportSupport.kt`

Changes made in this pass:
- moved manufacturer bucket/filter support out of `SettingsImportScreens.kt`
- moved linked HTML/provider-caption rendering out of `SettingsImportScreens.kt`
- moved venue search card, venue result card, and current-location resolution into `SettingsVenueImportSupport.kt`
- moved tournament import parsing, error types, and card UI into `SettingsTournamentImportSupport.kt`
- left `SettingsImportScreens.kt` focused on screen-level state, permission flow, and async orchestration

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 337: iOS Stats support split

Primary files:
- `Pinball App 2/Pinball App 2/stats/StatsScreen.swift`
- `Pinball App 2/Pinball App 2/stats/StatsModels.swift`
- `Pinball App 2/Pinball App 2/stats/StatsDataSupport.swift`
- `Pinball App 2/Pinball App 2/stats/StatsViewModel.swift`
- `Pinball App 2/Pinball App 2/stats/StatsViewSupport.swift`
- `Pinball App 2/Pinball App 2/stats/StatsFormattingSupport.swift`

Changes made in this pass:
- moved stats row/result models out of `StatsScreen.swift`
- moved CSV load/parse logic into `StatsDataSupport.swift`
- moved refresh/filter/state coordination into `StatsViewModel.swift`
- moved table row and machine-stats leaf views into `StatsViewSupport.swift`
- moved score/points/season formatting helpers into `StatsFormattingSupport.swift`
- left `StatsScreen.swift` focused on layout, filter chrome, and route shell responsibilities

Hidden seam surfaced and reduced:
1. `StatsScreen.swift` was still acting as screen shell, view model, CSV loader, statistics engine, and leaf view bucket all at once
2. the file boundary now matches those layers, so future stats work can change data loading or UI presentation without reopening the entire screen

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 338: iOS IFPA profile support split

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeIFPAProfileScreen.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeIFPAProfileModels.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeIFPAProfileCacheSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeIFPAProfileRemoteSupport.swift`

Changes made in this pass:
- moved IFPA profile models out of the screen file
- moved cached snapshot persistence into `PracticeIFPAProfileCacheSupport.swift`
- moved HTML fetch/parse logic into `PracticeIFPAProfileRemoteSupport.swift`
- left `PracticeIFPAProfileScreen.swift` focused on load state, stale-cache fallback, and screen composition

Hidden seam surfaced and reduced:
1. the IFPA profile screen was still carrying its own network parser and cache codec, which made a UI change require rereading scraping and persistence code
2. those support layers now live separately, so the remaining league-tab UI can be reviewed without reopening HTML parsing internals

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 339: Android Stats support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/stats/StatsScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/stats/StatsModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/stats/StatsDataSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/stats/StatsComputationSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/stats/StatsScreenSupport.kt`

Changes made in this pass:
- moved stats models into `StatsModels.kt`
- moved CSV fetch/parse and season sorting into `StatsDataSupport.kt`
- moved stats computation and display-format helpers into `StatsComputationSupport.kt`
- moved table and machine-stats composables into `StatsScreenSupport.kt`
- left `StatsScreen.kt` as the filter/state/shell coordinator

Hidden seam surfaced and reduced:
1. `StatsScreen.kt` was mixing Compose shell logic with raw CSV handling, statistics math, and all leaf table/panel UI
2. the screen now reads more like a coordinator, and the parser/math code can evolve independently of the layout shell

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 340: Android IFPA profile support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeIfpaProfileScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeIfpaProfileModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeIfpaProfileCacheSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeIfpaProfileRemoteSupport.kt`

Changes made in this pass:
- moved IFPA models and cached-at formatting into `PracticeIfpaProfileModels.kt`
- moved shared-preferences cache and JSON encoding into `PracticeIfpaProfileCacheSupport.kt`
- moved public profile fetch and HTML parsing into `PracticeIfpaProfileRemoteSupport.kt`
- left `PracticeIfpaProfileScreen.kt` focused on load/retry flow and the profile UI surface

Hidden seam surfaced and reduced:
1. the Android IFPA profile screen was still carrying network scraping, cache storage, and JSON serialization inside the UI file
2. separating those layers makes the remaining league-tab UI easier to reason about and keeps parser/cache churn out of the composable shell

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 334: Android PracticeStore load-coordinator cleanup

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreLoadCoordinatorSupport.kt`

Changes made in this pass:
- moved the remaining Android PracticeStore load-state flags and library/catalog hydration helpers out of `PracticeStore.kt` into `PracticeStoreLoadCoordinatorSupport.kt`
- made `PracticeStore.kt` delegate:
  - initial library load
  - full-library hydration
  - search-catalog hydration
  - league-catalog hydration
  - bank-template hydration
  - league-target hydration
  - bootstrap/home-snapshot visibility flags
- kept `PracticeStore.kt` as the state host and mutation coordinator while the new support file owns the last mixed loading bucket

Hidden seams surfaced and fixed:
1. the final Android PracticeStore cleanup debt was no longer business logic; it was the remaining coupling between:
   - load flags
   - hydration side effects
   - home-bootstrap snapshot refreshes
2. that coupling made `PracticeStore.kt` read like both a state host and a loader implementation at the same time, even though the loading policy had already been narrowed by the earlier support files

Behavioral outcome:
- no intended front-facing behavior changed
- `PracticeStore.kt` dropped from `909` lines to `880`
- the remaining file now reads much more clearly as a coordinator/state owner instead of a mixed lifecycle bucket

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 335: Cross-platform scanner controller cleanup

Primary files:
- `Pinball App 2/Pinball App 2/practice/ScoreScannerViewModel.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerCameraLifecycleSupport.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerFreezeFlowSupport.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerController.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerCameraBindingSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerFrameAnalysisSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerAnalyzerStateSupport.kt`

Changes made in this pass:
- split the remaining iOS scanner camera lifecycle out of `ScoreScannerViewModel.swift` into `ScoreScannerCameraLifecycleSupport.swift`
- split the remaining iOS freeze/final-pass/live-frame orchestration out of `ScoreScannerViewModel.swift` into `ScoreScannerFreezeFlowSupport.swift`
- split the remaining Android scanner camera binding and teardown out of `ScoreScannerController.kt` into `ScoreScannerCameraBindingSupport.kt`
- split the remaining Android frame analysis/freeze flow out of `ScoreScannerController.kt` into `ScoreScannerFrameAnalysisSupport.kt`
- split Android analyzer lock-state helpers into `ScoreScannerAnalyzerStateSupport.kt`

Hidden seams surfaced and fixed:
1. both scanner coordinators were already heavily decomposed, but the final leftover buckets still mixed:
   - camera lifecycle
   - analyzer lock state
   - live OCR processing
   - freeze/final-pass handling
2. the iOS split surfaced one stale access seam: `videoOutputDelegate` was still `private` from the single-file layout and had to be widened to the coordinator scope used by the new camera lifecycle support
3. the Android split surfaced one compile-only support seam: `dispose()` moved with camera binding and needed the explicit coroutine `cancel` import in the new file

Behavioral outcome:
- no intended front-facing scanner behavior changed
- `ScoreScannerViewModel.swift` dropped from `454` lines to `162`
- `ScoreScannerController.kt` dropped from `563` lines to `158`
- the remaining shell files now read like actual scanner coordinators instead of mixed camera/analyzer buckets

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 336: iOS league remote cache support cleanup

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeStoreLeagueHelpers.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeLeagueRemoteLoadSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeLeagueImportedScoreRepairSupport.swift`

Changes made in this pass:
- moved the remote league payload cache/load helpers out of `PracticeStoreLeagueHelpers.swift` into `PracticeLeagueRemoteLoadSupport.swift`
- moved duplicate imported-score detection and repair helpers out of `PracticeStoreLeagueHelpers.swift` into `PracticeLeagueImportedScoreRepairSupport.swift`

Hidden seams surfaced and fixed:
1. the remaining iOS league helper bucket was no longer one concern; it mixed:
   - player/profile orchestration
   - resume/note helpers
   - remote payload cache loading
   - imported score repair policy
2. the score repair logic and remote cache logic were both real support layers, but leaving them together made the main helper file look much larger and less cohesive than it really was

Behavioral outcome:
- no intended front-facing behavior changed
- `PracticeStoreLeagueHelpers.swift` dropped from `383` lines to `226`
- the remaining file is now primarily league/profile orchestration plus practice-facing note/resume helpers

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 316: iOS league helper support split

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeStoreLeagueHelpers.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeLeagueNameSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeLeagueCSVSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeLeagueGameResolutionSupport.swift`

Changes made in this pass:
- split human-name normalization and approved IFPA matching helpers out of the main league helper file
- split league CSV row / IFPA player parsing and player-list derivation into dedicated CSV support
- split league game-resolution, OPDB-group extraction, and target-score matching into dedicated resolution support

Hidden seams surfaced and fixed:
1. `PracticeStoreLeagueHelpers.swift` was still mixing player identity policy, CSV payload parsing, cache-backed loading, and game-resolution heuristics in one file
2. the extracted helpers still need to remain shared with `PracticeStoreLeagueOps.swift`, so `normalizeHumanName(...)` and approved-player matching stayed as shared module helpers rather than file-private closures

Behavioral outcome:
- no intended front-facing behavior changed
- league import, head-to-head matching, and IFPA identity lookup kept the same behavior while the main helper file became much more focused on cache-backed load flows

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`

## Pass 317: iOS score parsing normalization split

Primary files:
- `Pinball App 2/Pinball App 2/practice/ScoreParsingService.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreParsingOCRNormalizationSupport.swift`

Changes made in this pass:
- trimmed `ScoreParsingService.swift` back to its public score-formatting and candidate-entry points
- moved OCR normalization, digit-like rescue logic, grouped zero-confusion rescue variants, and run-quality scoring into dedicated support

Hidden seams surfaced and fixed:
1. the extracted OCR helpers initially kept wider visibility than their moved private score structs allowed, which caused a compile-only access-control failure
2. that seam was fixed by tightening the normalization helpers back to private support-level functions while leaving only the candidate-entry points shared

Behavioral outcome:
- no intended front-facing behavior changed
- the OCR candidate ranking and rescue heuristics stayed the same while the public service file became much smaller and easier to audit

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed after the visibility fix

## Pass 318: Android score parsing normalization parity split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerParsingService.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerParsingNormalizationSupport.kt`

Changes made in this pass:
- mirrored the iOS score-parser cleanup by trimming the Android service file back to public formatting / candidate entry points
- moved candidate construction, OCR normalization, grouped rescue variants, and run-quality heuristics into a Kotlin support file with top-level helpers

Hidden seams surfaced and fixed:
1. Android was already farther along on league helper cleanup, so the true 1:1 parity seam for this batch was the score-scanner parsing bucket rather than the league integration files
2. the Android mirror used top-level support helpers instead of object extensions so the public API could stay unchanged without introducing artificial object state

Behavioral outcome:
- no intended front-facing behavior changed
- Android score scanner parsing now has a cleaner ownership split that matches the iOS cleanup direction

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 319: iOS scanner reading and image support split

Primary files:
- `Pinball App 2/Pinball App 2/practice/ScoreScannerViewModel.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerReadingSupport.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerImageSupport.swift`

Changes made in this pass:
- moved score-scanner reading shaping out of the main view-model file:
  - locked-reading derivation from stability snapshots
  - displayed-reading fallback selection
  - candidate-to-reading conversion
  - OCR candidate boundary filtering
- moved preview/image helpers out of the main view-model file:
  - target crop resolution
  - CIImage -> preview UIImage rendering
  - frozen-image OCR conversion

Hidden seams surfaced and fixed:
1. `ScoreScannerViewModel.swift` was still mixing camera/session state ownership with a set of fully pure score-display and image-prep helpers
2. the split kept buffered freeze-frame policy in the main view model on purpose, because that logic still depends on local capture state and buffered image lifetime rules rather than just pure transforms

Behavioral outcome:
- no intended front-facing behavior changed
- `ScoreScannerViewModel.swift` dropped from `648` lines to `584` while keeping camera/session ownership intact

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 320: Android scanner controller reading and preview support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerController.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerReadingSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerPreviewSupport.kt`

Changes made in this pass:
- moved score-scanner reading helpers out of the controller:
  - filtered candidate selection
  - locked/displayed reading shaping
  - candidate-to-reading conversion
  - live bitmap fallback decision policy
  - merged live-analysis ranking
- moved preview capture / geometry helpers out of the controller:
  - preview crop bitmap extraction
  - oriented frame-size calculation

Hidden seams surfaced and fixed:
1. the first controller split left two stale helper references behind in the live-analysis and freeze-candidate paths, which caused a temporary compile-only seam
2. those leftovers were cleaned immediately, and the controller now calls only the extracted support helpers for its pure preview and reading logic

Behavioral outcome:
- no intended front-facing behavior changed
- `ScoreScannerController.kt` dropped from `658` lines to `563` while staying the stateful camera/orchestration owner

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 321: iOS scanner view shell/support split

Primary files:
- `Pinball App 2/Pinball App 2/practice/ScoreScannerView.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerViewSupport.swift`

Changes made in this pass:
- rewrote `ScoreScannerView.swift` into a route/state shell that now mostly owns:
  - `ScoreScannerViewModel` wiring
  - viewport-size stabilization state
  - keyboard-dismiss handling
  - camera permission overlay routing
- moved the scanner UI surfaces into dedicated support:
  - close pill
  - header
  - live reading panel
  - zoom/freeze controls
  - camera overlay card
  - frozen preview
  - keyboard observer
  - target overlay
  - viewport-size helper functions

Hidden seams surfaced and reduced:
1. `ScoreScannerView.swift` was still mixing screen lifecycle and state with all of the scanner-specific UI leaf surfaces, which made every scanner tweak reopen one big file
2. the shell rewrite kept `dismissKeyboard()` and `useReading()` in the route file intentionally, because those are still direct screen actions rather than reusable UI leaves

Behavioral outcome:
- no intended front-facing behavior changed
- `ScoreScannerView.swift` dropped from `491` lines to `156`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 322: Android scanner dialog shell/support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerDialog.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/ScoreScannerDialogSupport.kt`

Changes made in this pass:
- rewrote `ScoreScannerDialog.kt` into a dialog shell that now mostly owns:
  - permission request and camera binding effects
  - preview-mapping updates
  - soft-input/window handling
  - haptic transition handling
  - fullscreen status overlay routing
- moved scanner Compose surfaces into one support file:
  - camera preview
  - close pill
  - target stage and candidate highlights
  - header
  - live reading panel
  - zoom/freeze controls
  - confirmation sheet
  - manual entry field
  - `Rect` -> `RectF` helper

Hidden seams surfaced and fixed:
1. the first shell rewrite left one predictable Compose seam behind in the target-stage height modifier path, which was fixed immediately before the rebuild
2. the dialog shell now reads as route/effects code instead of a combined route, effects, and large-UI-surface bucket

Behavioral outcome:
- no intended front-facing behavior changed
- `ScoreScannerDialog.kt` dropped from `661` lines to `271`

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 323: iOS scanner freeze-buffer support split

Primary files:
- `Pinball App 2/Pinball App 2/practice/ScoreScannerViewModel.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerFreezeBufferSupport.swift`

Changes made in this pass:
- moved the buffered freeze-frame model and pure helper policy out of `ScoreScannerViewModel.swift` into `ScoreScannerFreezeBufferSupport.swift`
- extracted dedicated helpers for:
  - deciding whether a candidate should replace an existing buffered frame
  - building a buffered freeze-frame from a preview image and candidate
  - pruning stale buffered frames by lifetime
  - updating the buffered-frame map with capped retention
- trimmed `ScoreScannerViewModel.swift` so it now keeps the live scanner state/orchestration while delegating pure buffer retention rules to support helpers

Hidden seams surfaced and fixed:
1. the first extraction briefly rebuilt a synthetic candidate while updating buffered frames, which would have made the support layer harder to trust
2. that was corrected immediately so the support file now compares buffered-frame values directly instead of manufacturing placeholder candidates

Behavioral outcome:
- no intended front-facing behavior changed
- `ScoreScannerViewModel.swift` dropped from `584` lines to `538`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 324: Android PracticeStore league state support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreLeagueStateSupport.kt`

Changes made in this pass:
- moved pure league-state helpers out of `PracticeStore.kt` into `PracticeStoreLeagueStateSupport.kt`
- extracted dedicated support for:
  - updating canonical state when the selected league player changes
  - updating canonical state after a successful CSV import
  - deciding whether auto-import should run based on throttle, remote freshness, and repair/version state
  - purging imported league scores and related journal entries from canonical state
- kept `PracticeStore.kt` responsible for store orchestration and side effects while the new support file owns the pure canonical-state transitions

Hidden seams surfaced and fixed:
1. the first pass left a duplicated tail from the old purge path in `PracticeStore.kt`, which would have caused dead repeated save/recompute code to linger in the store
2. that duplicate tail was removed immediately, and the purge path now goes through a single pure state transformation before the normal refresh/save flow

Behavioral outcome:
- no intended front-facing behavior changed
- `PracticeStore.kt` remains the main Android Practice coordinator, but the league import/update rules are now isolated in one support file

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 325: iOS scanner session support split

Primary files:
- `Pinball App 2/Pinball App 2/practice/ScoreScannerViewModel.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerSessionSupport.swift`

Changes made in this pass:
- moved camera authorization routing and AVCapture session/device setup out of `ScoreScannerViewModel.swift` into `ScoreScannerSessionSupport.swift`
- extracted dedicated support for:
  - mapping authorization status to scanner routing/state
  - configuring the AVCapture session input/output
  - configuring autofocus, exposure, and initial zoom bounds
  - returning the device/default zoom/max zoom bundle needed by the view model
- trimmed `ScoreScannerViewModel.swift` so it now reads more like scanner state/orchestration, while the support file owns the camera setup plumbing

Hidden seams surfaced and fixed:
1. the first view-model rewrite briefly treated `.notDetermined` like a routed authorization case, which would have broken the existing request-access flow
2. that mismatch was fixed immediately so the permission request remains in the view model, while the new support file only owns the already-known authorization and session setup paths

Behavioral outcome:
- no intended front-facing behavior changed
- `ScoreScannerViewModel.swift` dropped from `538` lines to `494`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 326: Android PracticeStore persisted-state support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStorePersistedStateSupport.kt`

Changes made in this pass:
- moved pure persisted-state application helpers out of `PracticeStore.kt` into `PracticeStorePersistedStateSupport.kt`
- extracted dedicated support for:
  - applying parsed persisted payloads to canonical/runtime store state
  - projecting canonical state back into runtime state for refresh paths
  - applying restored home-bootstrap snapshot payloads back into store-owned state
- kept `PracticeStore.kt` responsible for orchestration, persistence side effects, and UI-facing mutation entry points while the new support file owns the pure state-shape transforms

Hidden seams surfaced and reduced:
1. the store still had the same canonical/runtime/application shape repeated in several places:
   - parsed persisted state load
   - migrated loaded state
   - canonical refresh
   - home bootstrap restore
2. those repeated transforms now go through one support layer instead of drifting independently inside the store

Behavioral outcome:
- no intended front-facing behavior changed
- `PracticeStore.kt` remains the main Android Practice coordinator, but the persisted-state application path is now isolated in a dedicated support file

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 327: Android PracticeStore reference-load support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreReferenceLoadSupport.kt`

Changes made in this pass:
- moved stored-reference bootstrap/load decision support out of `PracticeStore.kt` into `PracticeStoreReferenceLoadSupport.kt`
- extracted dedicated support for:
  - computing whether stored references require bank-template games
  - computing whether stored references require search-catalog games
  - computing whether stored references require full-library scope
  - deciding whether an initial load still needs a canonical-state rewrite/save
- simplified `loadIfNeeded()` so it now reads more like a bootstrap coordinator instead of repeating three separate stored-reference wrapper paths

Hidden seams surfaced and reduced:
1. the store was recomputing stored reference IDs through three private wrapper methods just to answer one bootstrap question: what extra data still needs loading
2. those decisions now share one support layer and one reference-ID assembly path, which makes the bootstrap contract easier to audit and less likely to drift

Behavioral outcome:
- no intended front-facing behavior changed
- `PracticeStore.kt` dropped from `937` lines to `914`

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 328: iOS scanner capture-plumbing support split

Primary files:
- `Pinball App 2/Pinball App 2/practice/ScoreScannerViewModel.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerSessionSupport.swift`

Changes made in this pass:
- moved the remaining capture-session plumbing out of `ScoreScannerViewModel.swift` into `ScoreScannerSessionSupport.swift`
- extracted dedicated support for:
  - applying portrait rotation to the preview connection
  - converting captured pixel buffers into portrait-oriented `CIImage` frames
  - the `AVCaptureVideoDataOutputSampleBufferDelegate` bridge used to hand frames back into the view model
- left `ScoreScannerViewModel.swift` focused on scanner state, live OCR orchestration, and freeze/retake behavior

Hidden seams surfaced and reduced:
1. after the earlier session setup split, the view model still had a leftover pocket of low-level capture plumbing that belonged with the session helpers rather than the scanner state owner
2. this pass finished that boundary so the session support file now owns both setup and frame-delivery plumbing instead of splitting those concerns between files

Behavioral outcome:
- no intended front-facing behavior changed
- `ScoreScannerViewModel.swift` dropped from `494` lines to `460`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 329: iOS scanner live-processing support split

Primary files:
- `Pinball App 2/Pinball App 2/practice/ScoreScannerViewModel.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerLiveProcessingSupport.swift`

Changes made in this pass:
- moved the remaining pure live-processing helpers out of `ScoreScannerViewModel.swift` into `ScoreScannerLiveProcessingSupport.swift`
- extracted dedicated support for:
  - preferred freeze-reading selection from live candidate vs snapshot state
  - buffered freeze-frame pruning and replacement decisions
  - buffered freeze preview lookup
  - live-processing start state for OCR cadence, target cropping, and processing gate checks
- kept the view model responsible for OCR orchestration, freeze/retake flow, and capture-queue ownership while the support file now owns the reusable live-processing rules

Hidden seams surfaced and fixed:
1. the first helper rewrite briefly computed updated buffered-frame state outside the capture-queue-owned path, which would have weakened the queue ownership boundary
2. that was corrected immediately so the extracted buffer update still runs against the capture-queue-owned state before assignment

Behavioral outcome:
- no intended front-facing behavior changed
- `ScoreScannerViewModel.swift` kept the same high-level coordinator role, with more of the live-processing rule set now living in one dedicated support file

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 330: Android PracticeStore home-bootstrap snapshot support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreBootstrapSupport.kt`

Changes made in this pass:
- moved home-bootstrap snapshot assembly glue out of `PracticeStore.kt` into `PracticeStoreBootstrapSupport.kt`
- extracted dedicated support for:
  - building the store-specific home bootstrap snapshot from current runtime state
  - resolving the resume candidate into the lookup set used for the bootstrap snapshot
  - saving the assembled bootstrap snapshot in one support call instead of rebuilding that wiring inside the store
- trimmed `PracticeStore.kt` so it no longer owns the small bundle of resume-slug lookup plus snapshot assembly code

Hidden seams surfaced and reduced:
1. the store was still hand-wiring the same home-bootstrap pieces each time it saved a snapshot:
   - current visible games
   - combined lookup games
   - resume candidate lookup
   - snapshot assembly
2. that bundle now lives in the bootstrap support file beside the existing restore/build helpers, which makes the snapshot contract easier to reason about in one place

Behavioral outcome:
- no intended front-facing behavior changed
- `PracticeStore.kt` dropped from `914` lines to `906`

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 331: Android PracticeStore persistence-state assembly split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStorePersistenceStateSupport.kt`

Changes made in this pass:
- moved runtime-state and shadow-state save-payload assembly out of `PracticeStore.kt` into `PracticeStorePersistenceStateSupport.kt`
- extracted dedicated support for:
  - building the runtime `PracticePersistedState` from current store-owned values
  - building the canonical shadow state used during persistence saves
  - returning the paired runtime/shadow save payload as one support object
- removed the now-redundant `runtimeStateSnapshot()` wrapper from the store and routed its remaining callers through the new support helpers instead

Hidden seams surfaced and reduced:
1. the store was still assembling the same persistence shape in two places:
   - migration-time runtime snapshot building
   - normal save-state runtime/shadow payload building
2. those save-payload details now live in one support layer instead of being repeated inline inside the coordinator

Behavioral outcome:
- no intended front-facing behavior changed
- this pass was more about consolidating persistence-shape ownership than raw file shrink, and `PracticeStore.kt` now reads more like the coordinator over those save-payload helpers

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 332: Android PracticeStore library-state support cleanup

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreLibraryStateSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeLibraryIntegration.kt`

Changes made in this pass:
- expanded `PracticeStoreLibraryStateSupport.kt` so both loaded library state and selected-source application go through one shared support layer
- rewrote `setPreferredLibrarySource(...)` in `PracticeStore.kt` to use the shared library-state support instead of building its own source-selection state inline
- updated `applyLibraryState(...)` to use the support-owned persisted selected-source value
- removed the now-dead `PracticeLibraryIntegration.applySelectedSource(...)` wrapper after the store stopped calling it

Hidden seams surfaced and reduced:
1. the store and library integration were both owning pieces of the same source-selection contract:
   - selected source normalization
   - visible-game filtering
   - persisted selected-source updates
2. this pass moved the store-facing state shape into one support layer and removed the stale integration wrapper so that contract is no longer split across two places

Behavioral outcome:
- no intended front-facing behavior changed
- this pass was primarily about removing one stale wrapper and centralizing library-state mutation support rather than chasing a large line-count drop

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 333: iOS scanner display-state support split

Primary files:
- `Pinball App 2/Pinball App 2/practice/ScoreScannerViewModel.swift`
- `Pinball App 2/Pinball App 2/practice/ScoreScannerDisplayStateSupport.swift`

Changes made in this pass:
- moved the repeated live display-state assembly out of `ScoreScannerViewModel.swift` into `ScoreScannerDisplayStateSupport.swift`
- extracted dedicated support for:
  - computing the live scanner display state from filtered OCR analysis plus stability snapshot
  - computing the fallback display state after OCR failure when only the stability snapshot remains
- updated the view model so both the normal OCR path and the failure path use the same support-owned display state shape instead of rebuilding those UI values inline

Hidden seams surfaced and reduced:
1. the scanner view model was still rebuilding the same UI-facing values in two nearby paths:
   - normal live OCR processing
   - OCR failure fallback processing
2. those display-state rules now live in one support file instead of drifting inside the coordinator

Behavioral outcome:
- no intended front-facing behavior changed
- `ScoreScannerViewModel.swift` dropped from `460` lines to `454`

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 314-315: Practice journal list/editor split

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalListSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalEntryEditorSheet.swift`

Changes made in these passes:
- split the iOS Practice journal file into dedicated layers:
  - `PracticeJournalListSupport.swift` now owns the journal action bar, list panel, day header, row rendering, and static editable row chrome
  - `PracticeJournalEntryEditorSheet.swift` now owns the full journal-entry editing sheet plus its draft seeding, normalization, validation, and persistence routing
- trimmed `PracticeJournalSettingsSections.swift` back to the journal item models, grouped-section helper, and the high-level `PracticeJournalSectionView` coordinator

Hidden seams surfaced and fixed:
1. `PracticeJournalSettingsSections.swift` was still acting like two unrelated files fused together:
   - the journal list/filter surface
   - the full editor-sheet workflow
2. the row chrome and swipe-edit behavior had also become a second hidden bucket inside that same file, even though it is a reusable list concern rather than journal-screen orchestration

Behavioral outcome:
- no intended front-facing behavior changed
- `PracticeJournalSettingsSections.swift` dropped from `573` lines to `102`, and the remaining journal list/editor behavior now lives in dedicated support files instead of one mixed surface file

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 312-313: Practice group editor and Android store load/runtime cleanup

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeGroupEditorComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupEditorSectionSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupEditorActionSupport.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreLoadSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreRuntimeSupport.kt`

Changes made in these passes:
- split the iOS Practice group editor into dedicated section/chrome views:
  - `PracticeGroupEditorSectionSupport.swift` now owns the name, template, title, and settings sections plus the inline date and title-delete popovers
  - `PracticeGroupEditorComponents.swift` is trimmed back toward state ownership, lifecycle wiring, and coordination
- moved iOS group-editor save/template/date helpers out of the screen file:
  - `PracticeGroupEditorActionSupport.swift` now owns template-default normalization, save validation/persistence, bank-template application, duplicate-template application, and the shared editor date formatter
- split the Android Practice store’s async load/persistence scaffolding out of `PracticeStore.kt`:
  - `PracticeStoreLoadSupport.kt` now owns the initial library + persisted-state bootstrap load plus the search/league/bank catalog loaders
  - `PracticeStoreRuntimeSupport.kt` now owns the runtime-state application shape and canonical shadow-state assembly used during saves
- trimmed `PracticeStore.kt` back toward being the state host and domain orchestrator instead of also carrying every async-load and runtime-shape helper inline

Hidden seams surfaced and fixed:
1. `PracticeGroupEditorComponents.swift` was still mixing four different responsibilities in one SwiftUI file:
   - section UI
   - popover chrome
   - save validation/persistence
   - template application policy
2. Android `PracticeStore.kt` was still bundling async library/catalog loaders and runtime shadow-state assembly inline even after the earlier bootstrap and reference-support splits, which left the bottom half of the store acting like a generic persistence bucket

Behavioral outcome:
- no intended front-facing behavior changed
- `PracticeGroupEditorComponents.swift` dropped from `694` lines to `337`
- `PracticeStore.kt` dropped from `957` lines to `943` in this pass, with the more important change being that the load/runtime scaffolding now lives in dedicated support files

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 307: Practice group editor support split

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeGroupEditorComponents.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupEditorSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGroupSelectionSupport.swift`

Changes made in this pass:
- split the iOS Practice group editor support bucket into:
  - `PracticeGroupEditorSupport.swift` for:
    - `GroupProgressWheel`
    - group template/date enums
    - adaptive popover placement support shared with the dashboard/editor surfaces
  - `PracticeGroupSelectionSupport.swift` for:
    - `GroupGameSelectionScreen`
    - selected-title drag/drop reorder delegates
- trimmed `PracticeGroupEditorComponents.swift` back toward the editor screen itself instead of also owning the group picker and generic popover utility

Hidden seams surfaced and fixed:
1. `PracticeGroupEditorComponents.swift` had become another mixed bucket: editor screen, game selection screen, reorder delegates, and adaptive popover infrastructure were all coexisting in one file
2. the adaptive popover helper is not editor-only; moving it into dedicated support makes its reuse by Practice dashboard/editor routes more explicit

Behavioral outcome:
- no intended front-facing behavior changed
- the group editor file now reads more like the actual editor flow instead of a general Practice utility file

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 300-304: Android GameRoom end-state cleanup

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreenSettingsRouteSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreenSettingsContentSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomEnumModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomInventoryModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomRecordModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomUiComponents.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomVariantPresentationSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomUiFormattingSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPinsideImport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPinsideTitleSupport.kt`

Changes made in these passes:
- split the Android settings-route host into:
  - a smaller route shell in `GameRoomScreenSettingsRouteSupport.kt`
  - dedicated route content builders in `GameRoomScreenSettingsContentSupport.kt` for:
    - Pinside import fetch/update/import flow
    - edit-settings context assembly
- retired the old all-in-one `GameRoomModels.kt` bucket and split Android GameRoom models into:
  - `GameRoomEnumModels.kt`
  - `GameRoomInventoryModels.kt`
  - `GameRoomRecordModels.kt`
- split shared GameRoom UI concerns so `GameRoomUiComponents.kt` now focuses on the machine card/list surfaces, while:
  - `GameRoomVariantPresentationSupport.kt` owns variant pills and manufacturer/variant dropdowns
  - `GameRoomUiFormattingSupport.kt` owns location/meta/date/attention formatting helpers
- split Pinside title and variant normalization out of `GameRoomPinsideImport.kt` into `GameRoomPinsideTitleSupport.kt`

Hidden seams surfaced and fixed:
1. the Android settings-route host still owned both async import fetch/error policy and the full edit-settings context assembly, which made it a second controller bucket after the screen split
2. Android GameRoom was still carrying the old monolithic model file even after iOS had already proven the enum/inventory/record split
3. the shared UI file had become a mixed bucket for machine cards, dropdowns, variant rendering, meta formatting, and date helpers; that made it harder to tell what was real screen chrome versus generic support

Behavioral outcome:
- no intended front-facing behavior changed
- Android GameRoom is now in checkpoint territory rather than ongoing monolith cleanup
- the biggest remaining Android GameRoom files are now mostly intentional coordinators or parser-heavy files rather than generic buckets

Current Android GameRoom end-state:
1. `GameRoomPinsideImport.kt` is still the largest remaining Android GameRoom file, but it is now mostly one service with page/network/parser policy rather than a generic shared bucket
2. `GameRoomScreen.kt`, `GameRoomStore.kt`, `GameRoomMachineRoute.kt`, and `GameRoomRouteContent.kt` are still medium-large, but they now read as coordinators/routes instead of mixed policy hosts

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed after the settings-route, model, UI, and Pinside support splits

## Pass 308-309: Practice quick-entry and store reference support cleanup

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeQuickEntrySheet.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeQuickEntryModeFields.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeQuickEntrySaveLogic.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeEntryFieldSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeScoreFormatting.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreReferenceSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreLibraryStateSupport.kt`

Changes made in these passes:
- split iOS Practice quick-entry into real support layers:
  - `PracticeQuickEntryModeFields.swift` now owns the activity-specific form body
  - `PracticeQuickEntrySaveLogic.swift` now owns the activity save/validation path
  - `PracticeEntryFieldSupport.swift` now owns the shared text-editor and percent-slider chrome used by Practice entry sheets
  - `PracticeScoreFormatting.swift` now owns the shared comma formatter instead of leaving separate copies in quick-entry and the regular score sheet
- trimmed `PracticeQuickEntrySheet.swift` back toward selection, lifecycle, and save routing instead of also owning every mode-specific field and save branch
- moved the Android PracticeStore stored-reference and load-decision helpers out of `PracticeStore.kt`
- moved the trivial Practice library-state application shape into `PracticeStoreLibraryStateSupport.kt` so `PracticeStore.kt` reads more like orchestration than raw shape assembly

Hidden seams surfaced and fixed:
1. iOS Practice quick-entry and the regular score-entry sheet were both carrying their own score comma-formatters and entry-field chrome, which had become a stale duplication seam
2. Android `PracticeStore.kt` still carried stored-reference scanning and load-decision policy inline even after the earlier Practice bootstrap split, so the bottom of the file was still acting like a generic helper bucket

Behavioral outcome:
- no intended front-facing behavior changed
- iOS quick-entry now matches the same mode-fields/save-logic decomposition pattern Android already used
- Android PracticeStore now has clearer boundaries between orchestration and stored-reference/load-decision helpers

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 310-311: Practice game-entry file split and Android quick-entry selection support

Primary files:
- `Pinball App 2/Pinball App 2/practice/GameScoreEntrySheet.swift`
- `Pinball App 2/Pinball App 2/practice/GameNoteEntrySheet.swift`
- `Pinball App 2/Pinball App 2/practice/GameTaskEntrySheet.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameEntrySheets.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeQuickEntrySheet.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeQuickEntrySelectionSupport.kt`

Changes made in these passes:
- split the old iOS `PracticeGameEntrySheets.swift` catch-all file into three dedicated screens:
  - `GameScoreEntrySheet.swift`
  - `GameNoteEntrySheet.swift`
  - `GameTaskEntrySheet.swift`
- deleted the stale combined file once its contents had been moved into dedicated screen files
- updated the iOS task-entry screen to use the shared Practice entry-field helpers and the shared category-label helper rather than carrying another local copy of that UI support
- moved Android quick-entry library/game/activity dropdown rendering plus the initial quick-entry key/source resolution helpers into `PracticeQuickEntrySelectionSupport.kt`
- trimmed `PracticeQuickEntrySheet.kt` back toward state, effect, and save orchestration instead of also rendering every selection field inline

Hidden seams surfaced and fixed:
1. `PracticeGameEntrySheets.swift` had become a misleading file name because it was really three separate screens sharing only a few small helpers
2. Android `PracticeQuickEntrySheet.kt` was still a mixed dialog shell plus selection-surface renderer even after the earlier mode-fields/save-logic cleanup, so the next truthful split was the selection layer

Behavioral outcome:
- no intended front-facing behavior changed
- iOS game entry screens and Android quick-entry selection now read like dedicated files rather than leftover combined buckets

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 305-306: Practice journal/settings and bootstrap support cleanup

Primary files:
- `Pinball App 2/Pinball App 2/practice/PracticeJournalSettingsSections.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeJournalEntryEditorSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeSettingsSupport.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreBootstrapSupport.kt`

Changes made in these passes:
- split the iOS Practice journal/settings bucket by concern:
  - `PracticeJournalEntryEditorSupport.swift` now owns the journal entry editor leaf sections plus shared progress/note/score-format helpers
  - `PracticeSettingsSupport.swift` now owns the Practice settings cards and destructive-confirmation prompts
  - `PracticeJournalSettingsSections.swift` is trimmed back toward journal list + editor flow rather than also being the settings surface file
- split Android Practice home-bootstrap snapshot restore/build logic out of `PracticeStore.kt` into `PracticeStoreBootstrapSupport.kt`
  - snapshot restore now returns an explicit payload instead of rewriting store state inline
  - snapshot save/build and lookup-game assembly now live in one support layer with explicit inputs/outputs

Hidden seams surfaced and fixed:
1. `PracticeJournalSettingsSections.swift` had quietly become two unrelated files fused together: journal editing/list UI and the Practice settings screen
2. `PracticeStore.kt` was still carrying home-bootstrap persistence/rehydration policy inline even though the Android Practice package already had strong decomposition everywhere else

Behavioral outcome:
- no intended front-facing behavior changed
- iOS Practice journal/settings support and Android Practice bootstrap logic now read more like dedicated support layers instead of leftover buckets

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 299: Android GameRoom screen state grouping split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreenStateSupport.kt`

Changes made in this pass:
- grouped the screen’s raw `rememberSaveable` and `remember` state into named state holders for:
  - navigation state
  - presentation/input draft state
  - settings/import/edit draft state
- moved `GameRoomRoute` into the same support file so screen-level route and draft state now live together instead of being declared inline at the top of `GameRoomScreen.kt`

Hidden seams surfaced and fixed:
1. `GameRoomScreen.kt` was still acting like a giant draft bucket even after the earlier route and effect splits
2. making the state ownership explicit through named state groups clarifies that the screen is coordinating three domains of local UI state, rather than one undifferentiated mass of saved values

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 298: Android GameRoom screen selection and draft-sync split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreenSelectionSupport.kt`

Changes made in this pass:
- moved the screen’s derived machine-selection state and sync `LaunchedEffect` rules out of `GameRoomScreen.kt`
- introduced a dedicated support file that now owns:
  - initial store/catalog load
  - selected machine and selected edit-machine fallback selection
  - edit-machine draft synchronization
  - venue-name draft seeding
  - input-sheet date reset and issue-draft attachment reset

Hidden seams surfaced and fixed:
1. `GameRoomScreen.kt` was still the single place where several unrelated selection and draft-reset policies were silently coupled
2. keeping those sync rules in one support file makes it clearer that the screen owns the raw state while the helper owns how that state is synchronized with store changes and active sheet transitions

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 297: Android GameRoom home and machine route bridge split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreenRouteBridgeSupport.kt`

Changes made in this pass:
- moved the Home route context assembly out of `GameRoomScreen.kt`
- moved the Machine route callback bridge out of `GameRoomScreen.kt`
- left the screen route switch reading more like:
  - choose route
  - hand off to route host
  - keep shared screen state local

Hidden seams surfaced and fixed:
1. the remaining Home and Machine route branches were still mixing route selection with a lot of callback and draft-state wiring
2. putting that bridge code in one dedicated support file makes it easier to keep the screen as a navigator instead of a grab-bag of route-specific callback glue

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 296: Android GameRoom settings-route host split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreenSettingsRouteSupport.kt`

Changes made in this pass:
- moved the full Settings route assembly out of `GameRoomScreen.kt`
- introduced a dedicated settings-route host that owns:
  - import fetch/update/import callbacks
  - edit-settings context assembly
  - archive route wiring
- left `GameRoomScreen.kt` more focused on top-level route switching and shared screen state

Hidden seams surfaced and fixed:
1. the Settings route branch was still the single biggest inline coordinator inside the screen even after the earlier media and presentation-context splits
2. import, edit, and archive callbacks were tightly interleaved in the screen branch, so giving them one route host makes that section easier to change without reopening unrelated route wiring

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 292: Android GameRoom store mutation split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomStoreInventorySupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomStoreRecordSupport.kt`

Changes made in this pass:
- moved pure machine, area, venue, and import state transitions out of `GameRoomStore.kt`
- moved pure event, attachment, and issue state transitions out of `GameRoomStore.kt`
- left `GameRoomStore.kt` as the observable state host that loads, saves, recomputes snapshots, and delegates mutations to the pure helpers

Hidden seams surfaced and fixed:
1. `openIssue(...)` and `resolveIssue(...)` were previously performing nested `addEvent(...)` calls that triggered repeated save/recompute behavior inside the store; the new pure state path now performs those linked issue-event updates in one state transition before the normal save/recompute
2. machine and import mutations were repeating the same string normalization and copy patterns inline, which made the store harder to audit and easier to drift from future callers

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 293: Android GameRoom catalog machine-resolution split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogLoader.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogMachineResolutionSupport.kt`

Changes made in this pass:
- moved exact OPDB resolution, normalized catalog-game lookup, image candidate assembly, and preferred art selection out of `GameRoomCatalogLoader.kt`
- introduced a small catalog-resolution context so the loader can hand its indexed catalog data to pure machine-resolution helpers

Hidden seams surfaced and fixed:
1. `GameRoomCatalogLoader.kt` was still mixing hosted-data load/index responsibilities with exact-machine and art-selection policy
2. the exact-machine and art-selection logic depended on several parallel maps and lists, so making that dependency explicit through the resolution context reduces the chance of future one-off lookups drifting from the indexed source of truth

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 286: Android GameRoom screen action helper split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreenActionSupport.kt`

Changes made in this pass:
- moved import-row mutation helpers out of `GameRoomScreen.kt`
- moved the import execution path out of `GameRoomScreen.kt`
- moved edited-machine save/archive behavior out of `GameRoomScreen.kt`

Hidden seams surfaced and fixed:
1. the screen file was mixing route composition with import-row state mutation and machine persistence behavior
2. after the split, the import and edit flows are easier to reuse without reopening the full screen shell

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 287: Android GameRoom media launcher split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreenMediaSupport.kt`

Changes made in this pass:
- moved pending media picker handling into a dedicated screen-media support file
- moved issue draft attachment pickers into the same support layer
- grouped the launcher return values behind `GameRoomMediaLaunchers`

Hidden seams surfaced and fixed:
1. the initial extraction used the wrong launcher type import; switching to `androidx.activity.compose.ManagedActivityResultLauncher` fixed the resulting bad type inference at the call sites
2. that compile seam confirmed the screen was previously relying on a lot of inline compose-specific wiring that is now isolated

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 288: Android GameRoom screen settings and media surface split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomEditSettingsPanels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomAddMachineSettingsSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomEditMachinesSettingsSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPresentationComponents.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomMediaPresentationSupport.kt`

Changes made in this pass:
- moved the add-machine search/filter/results surface out of `GameRoomEditSettingsPanels.kt`
- moved area and machine editor cards into their own support file
- moved media grid and fullscreen media preview out of `GameRoomPresentationComponents.kt`

Hidden seams surfaced and fixed:
1. the extraction surfaced a stale duplicate `GameRoomAreaSettingsCard(...)`, which was removed so there is now one truthful owner for that card
2. the trimmed presentation/log file still needed `background` and `clickable`, which made the old accidental coupling explicit and easy to fix

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 289: Android GameRoom input-sheet form split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPresentationHost.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomInputSheetFormSupport.kt`

Changes made in this pass:
- moved the full input-sheet form body and issue-attachment draft row out of `GameRoomPresentationHost.kt`
- left `GameRoomPresentationHost.kt` as a smaller multiplexer and modal shell over the active presentation routes

Hidden seams surfaced and fixed:
1. the new form support file needed its own `dp` import for spacing rows after the extraction
2. that was a clean compile-only seam and confirmed the form body is now truly independent of the presentation host shell

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 294: Android GameRoom catalog indexing split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogLoader.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogIndexingSupport.kt`

Changes made in this pass:
- moved the raw OPDB-to-GameRoom catalog indexing build-out of `GameRoomCatalogLoader.kt`
- introduced `GameRoomLoadedCatalogData` so the loader now fetches hosted payloads and assigns indexed results instead of owning the full indexing procedure inline

Hidden seams surfaced and fixed:
1. `GameRoomCatalogLoader.kt` was still mixing hosted payload fetch with all of the manufacturer, variant, slug, and machine-record indexing logic
2. that made it harder to reason about whether future cleanup changed loading behavior or only changed indexing behavior, so the new support file separates those responsibilities cleanly

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 295: Android GameRoom dead constructor dependency cleanup

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogLoader.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/PinballShell.kt`

Changes made in this pass:
- removed the unused `Context` constructor dependency from `GameRoomCatalogLoader`
- updated the Android GameRoom call sites to construct the loader without threading through an application context it never used

Hidden seams surfaced and fixed:
1. the loader had been carrying dead API surface that suggested it needed runtime Android services even though it only used hosted preload/cache helpers
2. leaving that constructor parameter in place would make future tests and refactors look more coupled to Android app state than they really are

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 290: Android GameRoom screen presentation context split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreenPresentationSupport.kt`

Changes made in this pass:
- moved the bottom presentation-context assembly out of `GameRoomScreen.kt`
- introduced dedicated builders for:
  - input-sheet presentation context
  - edit-event presentation context
  - attachment preview and edit presentation context
- left `GameRoomScreen.kt` more clearly focused on route, screen state, and section wiring

Hidden seams surfaced and fixed:
1. the pending-media launch path was still tightly coupled to the selected machine and active sheet dismissal sequence, so the new support file now owns that transition explicitly instead of leaving it inline at the bottom of the screen
2. attachment preview and edit state were previously computed inside the screen from raw attachment arrays, so the support split made that hidden dependency explicit and localized it to one place

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 291: Android GameRoom input-sheet concern split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomInputSheetFormSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomIssueInputSheetFormSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomMaintenanceInputSheetFormSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomMachineEventInputSheetFormSupport.kt`

Changes made in this pass:
- split the mixed input-sheet body into dedicated concern files for:
  - issue and resolve-issue forms
  - maintenance and pitch forms
  - ownership, mod, replacement, play-count, and media forms
- left `GameRoomInputSheetFormSupport.kt` as a small router plus the shared cancel/save action row

Hidden seams surfaced and fixed:
1. the old form file was still acting like a second presentation host by owning unrelated issue, maintenance, and media form behavior in one place
2. after the split, the issue attachment draft row is now owned by the issue form support file, which keeps issue-only draft behavior from drifting back into the shared router

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 276: Android GameRoom import review support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomSettingsSections.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomImportReviewSupport.kt`

Changes made in this pass:
- moved the import-review filter, row card, and review-list UI out of `GameRoomSettingsSections.kt`
- left `GameRoomSettingsSections.kt` focused on the settings-section shells and their high-level routing

Hidden seams surfaced and fixed:
1. the extracted import review UI initially depended on imports that were previously inherited from the old file
2. those imports are now explicit in the new support file so future cleanup passes can change that surface without reopening the section shell

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 277: Android GameRoom settings card split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomSettingsSections.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomEditSettingsPanels.kt`

Changes made in this pass:
- moved the venue name, add-machine, area management, and edit-machines cards out of `GameRoomSettingsSections.kt`
- left `GameRoomEditSettingsSection` reading more like a coordinator over named settings panels

Hidden seams surfaced and fixed:
1. the old extraction briefly carried a malformed archive-section `Text(...)` tail and stale segmented-button imports
2. those compile-only seams were corrected immediately, which was useful confirmation that the file boundary was real rather than accidental

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 278: Android GameRoom screen model split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreenModels.kt`

Changes made in this pass:
- moved the screen-owned enums and small data records out of `GameRoomScreen.kt`:
  - route-adjacent section filters
  - subview/layout selections
  - input-sheet identifiers
  - import review drafts
  - issue attachment drafts
- kept `GameRoomRoute` local to the screen because it still only matters inside the top-level route shell

Hidden seams surfaced and fixed:
1. the split made the distinction clearer between reusable screen models and the one remaining route-local enum
2. no visibility widening was needed beyond what the file move actually required

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 279: Android GameRoom input save/reset split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPresentationHost.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomInputSheetSaveSupport.kt`

Changes made in this pass:
- moved the input-sheet save path and draft reset path out of `GameRoomPresentationHost.kt`
- left the host file focused on sheet rendering instead of also carrying every event/issue/media mutation case inline

Hidden seams surfaced and fixed:
1. this split exposed that the save/reset path was effectively a controller layer living inside a presentation file
2. moving it out reduced the risk of future UI-only changes accidentally reopening persistence logic

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 280: Android GameRoom event and attachment sheet split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPresentationHost.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPresentationSheetSupport.kt`

Changes made in this pass:
- moved the edit-event sheet and attachment preview/edit sheet out of `GameRoomPresentationHost.kt`
- left `GameRoomPresentationHost.kt` as a smaller multiplexer over the currently active presentation routes

Hidden seams surfaced and fixed:
1. the presentation host briefly lost `FontWeight` because the input-sheet title still uses it after the extraction
2. restoring only that import kept the split clean without widening any behavior or state boundaries

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 281: Android GameRoom catalog loader model and helper split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogLoader.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogVariantSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogArtSupport.kt`

Changes made in this pass:
- moved catalog-facing data classes out of the loader file
- moved variant normalization and catalog-name parsing out of the loader file
- moved slug-key assembly, hosted URL resolution, and art ranking helpers out of the loader file
- left `GameRoomCatalogLoader.kt` reading more like the actual async extraction and lookup coordinator

Hidden seams surfaced and fixed:
1. the old loader was mixing raw hosted decode orchestration with pure variant/art helper policy
2. after the split, future catalog-policy changes can happen without reopening the load-state plumbing

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 282: Android GameRoom snapshot and reminder support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomStoreSnapshotSupport.kt`

Changes made in this pass:
- moved machine ordering, snapshot recomputation, reminder due-count logic, and play-count helper math out of `GameRoomStore.kt`
- left `GameRoomStore.kt` more clearly responsible for persisted state ownership and mutation entry points

Hidden seams surfaced and fixed:
1. the old store mixed persistence and domain math so tightly that even read-only snapshot policy changes reopened the storage host
2. the new support file makes the snapshot/reminder layer explicit and easier to verify independently in later cleanup or tests

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`

## Pass 271: GameRoom shared media import support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaPickerImportSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueLoggingSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaEntrySupport.swift`

Changes made in this pass:
- moved shared media-picker state, import error messages, imported-file persistence, and imported-caption helpers into `GameRoomMediaPickerImportSupport.swift`
- updated the issue logging and media entry sheets to use the shared import state instead of carrying their own near-duplicate import lifecycle fields

Hidden seam surfaced and reduced:
1. the extracted picker helper initially failed to compile because `PhotosPickerItem` was only visible in the original view files' broader UI import context
2. the shared helper now imports the same SwiftUI overlay context explicitly, so the type boundary is no longer relying on where the code happened to live before the split

Behavioral outcome:
- no intended front-facing behavior changed
- issue logging and media entry still use the same picker/import flow, but now share one import-state contract

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 272: GameRoom issue and media draft-state split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueLoggingStateSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaEntryStateSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueLoggingSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaEntrySupport.swift`

Changes made in this pass:
- grouped issue logging sheet state into `GameRoomIssueLogDraft`
- grouped media entry sheet state into `GameRoomMediaEntryDraft` and `GameRoomMediaEntryField`
- moved attachment append/delete and normalized caption/notes helpers into the dedicated draft-state files

Hidden seam surfaced and reduced:
1. both sheets were still relying on clusters of loose `@State` values even after earlier GameRoom support splits
2. those draft contracts now live outside the route views, which makes future issue/media edits less likely to drift across separate state variables

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 273: GameRoom edit-machines shell split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinesView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinesShellSupport.swift`

Changes made in this pass:
- moved the edit-machines panel composition out of `GameRoomEditMachinesView.swift` into `GameRoomEditMachinesShellSupport.swift`
- left `GameRoomEditMachinesView.swift` focused on:
  - owned state
  - lifecycle watchers
  - derived selections/indexes
  - save/archive/delete orchestration

Hidden seam surfaced and reduced:
1. `GameRoomEditMachinesView.swift` was still mixing route lifecycle with four panel-builder surfaces, even after the earlier action/state splits
2. the shell split exposed one old call-site type mismatch around `machineMenuLabel`, which is now explicit instead of being hidden inside the inline panel builder

Behavioral outcome:
- no intended front-facing behavior changed
- the edit-machines flow still uses the same panel stack, bindings, and save callbacks

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 241: GameRoom shared text normalization and media-path cleanup

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomTextNormalizationSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaImportSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEventEntrySupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueEntrySupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineView.swift`

Changes made in this pass:
- moved the shared blank-string trimming helper out of `GameRoomMediaImportSupport.swift` into `GameRoomTextNormalizationSupport.swift`
- updated event-entry, issue-entry, and event-edit sheets to call `gameRoomNormalizedOptional(...)` directly instead of carrying repeated local wrappers
- updated `GameRoomMachineView.swift` to use the shared `gameRoomResolvedMediaURL(...)` helper instead of maintaining its own attachment URI parsing

Hidden seams surfaced and fixed:
1. `gameRoomNormalizedOptional(...)` was already a cross-surface helper, but it lived in a file named as if it only belonged to media import
2. `GameRoomMachineView.swift` still had its own attachment URI resolver even though the media-entry/media-preview surfaces were already using the shared resolver

Behavioral outcome:
- no intended front-facing behavior changed
- GameRoom text normalization and attachment URI parsing now come from one shared support path

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 270: GameRoom Pinside collection parser split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideCollectionParsingSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideDocumentSupport.swift`

Changes made in this pass:
- moved the lightweight Pinside collection-page parser into `GameRoomPinsideCollectionParsingSupport.swift`
- left `GameRoomPinsideDocumentSupport.swift` focused on:
  - detailed markdown/document parsing
  - purchase-date normalization
  - primary/fallback merge behavior

Hidden seams surfaced and reduced:
1. `GameRoomPinsideDocumentSupport.swift` was still mixing two parsing modes:
   - the lightweight collection-page slug extractor
   - the detailed document parser and merge path
2. after the split, the remaining document-support file reads like one parsing mode instead of an accidental umbrella for all Pinside parsing

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 268: GameRoom catalog image candidate support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogMachineResolutionSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogImageCandidateSupport.swift`

Changes made in this pass:
- moved GameRoom catalog artwork candidate assembly into `GameRoomCatalogImageCandidateSupport.swift`
- left `GameRoomCatalogMachineResolutionSupport.swift` focused on:
  - exact OPDB resolution
  - normalized catalog-game lookup
- widened the shared catalog lookup helpers so both support files can reuse:
  - grouped catalog lookup by game ID
  - exact OPDB catalog lookup

Hidden seams surfaced and reduced:
1. `GameRoomCatalogMachineResolutionSupport.swift` was still mixing two different policies:
   - exact machine identity resolution
   - image candidate fallback ordering
2. separating those policies makes later artwork-ranking cleanup possible without reopening the exact OPDB matching path

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 269: GameRoom machine editor form split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinePanelsSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineEditorFieldsSupport.swift`

Changes made in this pass:
- moved the full machine editor form into `GameRoomMachineEditorFieldsSupport.swift`
- left `GameRoomEditMachinePanelsSupport.swift` focused on the machine-management shell:
  - empty-state routing
  - machine selector row
  - conditional presentation of the editor form

Hidden seams surfaced and reduced:
1. `GameRoomEditMachinePanelsSupport.swift` was still carrying both the management-panel shell and the full machine editor form
2. after the split, the file boundary matches the UI hierarchy more closely, so later editor-form cleanup will not require reopening the management shell

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 262: GameRoom settings support stale-name split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomAdaptivePopoverSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSaveFeedbackOverlaySupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsSupport.swift`

Changes made in this pass:
- split the old `GameRoomSettingsSupport.swift` bucket into:
  - `GameRoomAdaptivePopoverSupport.swift`
  - `GameRoomSaveFeedbackOverlaySupport.swift`
- deleted the stale `GameRoomSettingsSupport.swift` file after those two unrelated concerns were separated

Hidden seams surfaced and reduced:
1. `GameRoomSettingsSupport.swift` had become a misleading bucket that no longer represented “settings support” as a single concern
2. after the split, the adaptive popover geometry path and the floating save-feedback overlay stopped sharing one stale filename just because they happened to live near the settings screen

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 263: GameRoom machine input support stale-name split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineMaintenanceInputSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineCustomEventInputSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineServiceInputSupport.swift`

Changes made in this pass:
- split the old `GameRoomMachineServiceInputSupport.swift` file into:
  - `GameRoomMachineMaintenanceInputSupport.swift` for the recurring maintenance sheets
  - `GameRoomMachineCustomEventInputSupport.swift` for install-mod, replace-part, and log-plays entry
- deleted the stale `GameRoomMachineServiceInputSupport.swift` file after those sheets were separated

Hidden seams surfaced and reduced:
1. the old file name had gone stale because it owned both service-entry sheets and custom event-entry sheets
2. separating the two groups makes later maintenance-entry cleanup possible without reopening the custom event path, and vice versa

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 264: GameRoom catalog variant label support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogVariantSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogVariantLabelSupport.swift`

Changes made in this pass:
- moved pure catalog variant normalization and label-selection helpers into `GameRoomCatalogVariantLabelSupport.swift`
- left `GameRoomCatalogVariantSupport.swift` focused on assembled catalog game records, deduping, variant-option maps, and preferred-record selection

Hidden seams surfaced and reduced:
1. `GameRoomCatalogVariantSupport.swift` was still carrying two different concerns:
   - variant-label normalization and comparison rules
   - actual catalog-game assembly and selection policy
2. splitting the pure label helpers out made the support boundary much closer to the actual “variant label vs catalog resolution” contract

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 265: GameRoom edit-machines state consolidation

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinesView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachineStateSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachineActionSupport.swift`

Changes made in this pass:
- introduced `GameRoomEditMachinesViewState` so the edit-machines screen carries one top-level state object instead of a long list of loose `@State` properties
- added `GameRoomEditMachinePanelExpansionState` to group the disclosure-panel expansion flags
- made `GameRoomAreaDraftState` writable so the area editor can bind directly into the grouped state
- updated `GameRoomEditMachinesView.swift` to read and write:
  - filters
  - machine selection
  - area draft
  - machine draft
  - venue name draft
  - disclosure expansion state
  - pending variant picker
  - catalog search index
  through the one `viewState` object

Hidden seams surfaced and fixed:
1. `GameRoomEditMachinesView.swift` was still acting like a state bucket even after earlier action and selection splits
2. the first consolidation pass briefly left one stale `onChange(of: selectedMachineID)` watcher behind from the pre-consolidation layout; that compile-only seam was fixed immediately before the final green build

Behavioral outcome:
- no intended front-facing behavior changed
- `GameRoomEditMachinesView.swift` dropped from 333 lines to 321 while the edit-machine coordinator state became much easier to audit as one object

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 266: GameRoom import review row split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomImportReviewSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomImportReviewRowSupport.swift`

Changes made in this pass:
- moved the import review row card, purchase-date binding, duplicate-warning display, match-selection menu, variant-selection menu, and confidence badge into `GameRoomImportReviewRowSupport.swift`
- left `GameRoomImportReviewSupport.swift` focused on the review section shell:
  - filter control
  - filtered-row loop
  - import action button

Hidden seams surfaced and reduced:
1. `GameRoomImportReviewSupport.swift` was still acting as both the review-section coordinator and the full row-entry surface
2. after the split, the file boundary now matches that UI hierarchy much more closely, which makes later review-row cleanup possible without reopening the section shell

Behavioral outcome:
- no intended front-facing behavior changed
- `GameRoomImportReviewSupport.swift` dropped from 163 lines to 45

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 267: GameRoom variant presentation support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachinePresentationSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomVariantPresentationSupport.swift`

Changes made in this pass:
- moved the GameRoom variant pill and variant-badge labeling helpers into `GameRoomVariantPresentationSupport.swift`
- left `GameRoomMachinePresentationSupport.swift` focused on:
  - attention/status color
  - location/meta line formatting
  - snapshot metric assembly

Hidden seams surfaced and reduced:
1. `GameRoomMachinePresentationSupport.swift` was still mixing two different presentation layers:
   - machine status/location/metric formatting
   - reusable variant pill and badge presentation
2. separating the variant-specific path makes the machine presentation support file read more like a status/meta helper bucket instead of a mixed visual grab bag

Behavioral outcome:
- no intended front-facing behavior changed
- `GameRoomMachinePresentationSupport.swift` dropped from 178 lines to 81

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 257: GameRoom import review support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomImportSettingsSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomImportReviewSupport.swift`

Changes made in this pass:
- moved the review section and per-row review card UI into `GameRoomImportReviewSupport.swift`
- left `GameRoomImportSettingsSupport.swift` focused on the source-input fetch section

Hidden seams surfaced and reduced:
1. `GameRoomImportSettingsSupport.swift` was still carrying both sides of the import flow:
   - source fetch/input
   - review-and-correct matches
2. those now live in separate files that match the two-step import workflow, which makes import UI maintenance less likely to reopen the fetch step when only review-row behavior changes

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 258: GameRoom media thumbnail support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaThumbnailSupport.swift`

Changes made in this pass:
- moved the attachment square tile and image/video thumbnail loaders into `GameRoomMediaThumbnailSupport.swift`
- left `GameRoomMediaSupport.swift` focused on the preview sheet and media edit sheet

Hidden seams surfaced and reduced:
1. `GameRoomMediaSupport.swift` was still mixing three layers:
   - thumbnail tile rendering
   - asynchronous image/video thumbnail loading
   - full preview and edit sheet presentation
2. thumbnail generation now lives in one dedicated support file, so later media-sheet edits will not have to reopen the thumbnail loading path

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 259: GameRoom edit-machine action support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinesView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachineActionSupport.swift`

Changes made in this pass:
- moved edit-machine selection syncing, area-draft defaults, and catalog search-index rebuilding into `GameRoomEditMachineActionSupport.swift`
- moved add-machine selection and duplicate-detection policy into `GameRoomEditMachineActionSupport.swift`
- moved edited-machine resolution and persisted machine-update wiring into `GameRoomEditMachineActionSupport.swift`
- left `GameRoomEditMachinesView.swift` focused on panel routing, bindings, and save/archive/delete triggers

Hidden seams surfaced and reduced:
1. `GameRoomEditMachinesView.swift` was still mixing three layers at once:
   - panel-shell composition
   - derived selection/catalog state
   - add/edit mutation policy
2. after the split, the view file stopped carrying most of the business-logic helpers directly, which makes it much easier to tell which behavior belongs to the coordinator and which behavior belongs to GameRoom edit policy

Behavioral outcome:
- no intended front-facing behavior changed
- `GameRoomEditMachinesView.swift` dropped from 383 lines to 333 while keeping the same add/edit machine behavior

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 260: GameRoom machine route and content split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineContentSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineRouteSupport.swift`

Changes made in this pass:
- moved the machine scroll content, summary/input/log routing, and machine-detail composition into `GameRoomMachineContentSupport.swift`
- moved route-level machine lookup, optional-alert bindings, and attachment open-target policy into `GameRoomMachineRouteSupport.swift`
- left `GameRoomMachineView.swift` focused on the route shell:
  - sheets
  - alerts
  - navigation destination
  - attachment-preview/fullscreen state

Hidden seams surfaced and fixed:
1. `GameRoomMachineView.swift` was still acting as both the route shell and the full machine-detail surface even after earlier machine-support splits
2. the first extraction pass briefly introduced a mismatched delimiter in the input-sheet route; that compile-only break was fixed immediately before the final green build

Behavioral outcome:
- no intended front-facing behavior changed
- `GameRoomMachineView.swift` dropped from 218 lines to 140 and now reads like an actual route shell instead of a mixed content/router file

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 261: GameRoom machine summary and input surface split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineSummarySupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineInputPanelSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachinePanelsSupport.swift`

Changes made in this pass:
- moved the machine snapshot/media summary surface into `GameRoomMachineSummarySupport.swift`
- moved the service/issue/ownership input surface into `GameRoomMachineInputPanelSupport.swift`
- deleted the stale combined `GameRoomMachinePanelsSupport.swift` file after its two surfaces were separated

Hidden seams surfaced and reduced:
1. after the route/content split, `GameRoomMachinePanelsSupport.swift` had become a misleading bucket that still owned two unrelated surfaces:
   - the read-only snapshot/media summary
   - the action-launch input panel
2. splitting those surfaces finished the machine-detail decomposition and removed one more misleading “miscellaneous panels” file from GameRoom

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 255: GameRoom persistence model split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPersistenceModels.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomReminderConfig.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomImportRecord.swift`

Changes made in this pass:
- moved `MachineReminderConfig` into `GameRoomReminderConfig.swift`
- moved `MachineImportRecord` into `GameRoomImportRecord.swift`
- left `GameRoomPersistenceModels.swift` focused on the top-level `GameRoomPersistedState` shape

Hidden seams surfaced and reduced:
1. `GameRoomPersistenceModels.swift` was still mixing three separate persistence layers:
   - per-machine reminder configuration
   - import history records
   - the top-level persisted state container
2. those model boundaries now match the actual persistence contracts, which should make future schema review less likely to reopen unrelated record types

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 256: GameRoom reminder snapshot support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStoreSnapshotSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomReminderSnapshotSupport.swift`

Changes made in this pass:
- moved reminder due-count, play-count baseline, latest-event, and effective-reminder-config helpers into `GameRoomReminderSnapshotSupport.swift`
- moved small machine-event and issue query helpers into the same support file
- left `GameRoomStoreSnapshotSupport.swift` focused on:
  - active/archive inventory views
  - snapshot recompute orchestration
  - machine sort policy

Hidden seams surfaced and reduced:
1. `GameRoomStoreSnapshotSupport.swift` was still mixing snapshot orchestration with the lower-level reminder policy that computes due maintenance counts
2. the reminder/play-count logic is now reviewable in one place without reopening the higher-level snapshot assembly path every time a maintenance badge or attention-state rule is touched

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 254: GameRoom add-machine filter and result support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomAddMachineSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomAddMachineFiltersSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomAddMachineResultSupport.swift`

Changes made in this pass:
- moved the advanced manufacturer/year/type filter disclosure UI into `GameRoomAddMachineFiltersSupport.swift`
- moved the catalog result row and variant-picker popover into `GameRoomAddMachineResultSupport.swift`
- left `GameRoomAddMachineSupport.swift` focused on the add-machine panel shell, status line, and result list routing

Hidden seams surfaced and reduced:
1. `GameRoomAddMachineSupport.swift` was still carrying three separate layers:
   - the add-machine panel shell
   - advanced filter controls
   - the result-row and variant-picker leaf UI
2. separating those layers makes the add-machine flow easier to scan without reopening the filter chrome every time the result-row behavior changes

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 253: GameRoom home selection and collection chrome support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomHomeComponents.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomHomeSelectionSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachinePresentationSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCollectionChromeSupport.swift`

Changes made in this pass:
- moved GameRoom home selected-machine lookup, selection syncing, and transition-source selection into `GameRoomHomeSelectionSupport.swift`
- left `GameRoomHomeComponents.swift` focused on the actual home screen shell and route wiring
- moved collection artwork chrome and attention-indicator views out of `GameRoomMachinePresentationSupport.swift` into `GameRoomCollectionChromeSupport.swift`
- left `GameRoomMachinePresentationSupport.swift` focused on display helpers:
  - location/meta text
  - status styling
  - variant badges
  - snapshot metric assembly

Hidden seams surfaced and reduced:
1. `GameRoomHomeComponents.swift` was still mixing the top-level home screen layout with the small-but-important selection/transition policy that decides which machine the home card opens
2. `GameRoomMachinePresentationSupport.swift` had drifted into a misleading file boundary by still owning collection-specific artwork chrome even after the collection rows moved into their own support file

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 251: GameRoom Pinside page support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideDocumentSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPinsidePageSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideImport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideImportServiceSupport.swift`

Changes made in this pass:
- moved Pinside collection-page validation and Cloudflare challenge detection into `GameRoomPinsidePageSupport.swift`
- moved slug extraction and bundled Pinside group-map resource loading into `GameRoomPinsidePageSupport.swift`
- left `GameRoomPinsideDocumentSupport.swift` focused on machine parsing and fallback merge behavior
- kept `GameRoomPinsideImport.swift` as the thin actor entry point and `GameRoomPinsideImportServiceSupport.swift` as the fetch/network helper layer

Hidden seams surfaced and reduced:
1. `GameRoomPinsideDocumentSupport.swift` was still mixing three different layers:
   - raw page sanity checks and Cloudflare detection
   - document-to-machine parsing
   - bundled resource lookup for the fallback title map
2. the page-validation/resource layer now lives in one support file, which makes future Pinside parser work less likely to reopen the fetch and bundle-loading rules at the same time

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 252: GameRoom home collection support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomHomeCollectionSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSelectedSummarySupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCollectionRowSupport.swift`

Changes made in this pass:
- moved the selected-machine summary card into `GameRoomSelectedSummarySupport.swift`
- moved the collection tile and list-row views into `GameRoomCollectionRowSupport.swift`
- left `GameRoomHomeCollectionSupport.swift` focused on the collection card container and its layout toggle

Hidden seams surfaced and reduced:
1. `GameRoomHomeCollectionSupport.swift` was still carrying three distinct home-surface layers at once:
   - the selected-machine summary card
   - the collection container and layout switcher
   - the leaf tile/list row views
2. those boundaries now match the actual home-screen composition, which makes later GameRoom home polish less likely to reopen unrelated summary-card or row-presentation code

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 244: GameRoom sheet chrome and issue attachment support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSheetChromeSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEventEditSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueAttachmentSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEventEntrySupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueEntrySupport.swift`

Changes made in this pass:
- moved the shared GameRoom sheet chrome helpers into `GameRoomSheetChromeSupport.swift`
- moved `GameRoomEventEditSheet` into `GameRoomEventEditSupport.swift`
- moved issue attachment draft/list/button leaf views into `GameRoomIssueAttachmentSupport.swift`
- trimmed `GameRoomIssueEntrySupport.swift` back to issue form state, picker routing, and save/import actions

Hidden seams surfaced and fixed:
1. the initial attachment-button split briefly failed because the new button row was passed immediate function calls instead of closures
2. after correcting that wiring, the split compiled cleanly and the attachment UI responsibility now lives in a file that matches its actual job

Behavioral outcome:
- no intended front-facing behavior changed
- issue attachment rows/buttons and sheet chrome are now reusable support instead of inline event/issue-file baggage

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 245: GameRoom presentation text-normalization cleanup

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPresentationComponents.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomTextNormalizationSupport.swift`

Changes made in this pass:
- updated `GameRoomLogDetailCard` to use `gameRoomNormalizedOptional(...)` instead of keeping its own blank-string trimming helper

Hidden seam surfaced and fixed:
1. the presentation layer was still carrying a private normalization path even after shared GameRoom text support existed

Behavioral outcome:
- no intended front-facing behavior changed
- GameRoom entry, issue, media, and presentation surfaces now share one text-normalization rule

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 246: GameRoom edit-machines panel shell split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinePanelStackSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinesView.swift`

Changes made in this pass:
- moved the disclosure/panel stack shell into `GameRoomEditMachinePanelStackSupport.swift`
- trimmed `GameRoomEditMachinesView.swift` down to state ownership, lifecycle hooks, panel data, and edit actions

Hidden seams surfaced and reduced:
1. `GameRoomEditMachinesView.swift` was still mixing top-level shell composition with the actual edit/add/search logic
2. separating the disclosure shell makes the remaining `GameRoomEditMachinesView` work more obviously about state and actions, not panel chrome

Behavioral outcome:
- no intended front-facing behavior changed
- `GameRoomEditMachinesView.swift` dropped from 415 lines to 392

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 247: GameRoom event and issue entry support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomServiceEventEntrySupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomOwnershipEventEntrySupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueLoggingSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueResolutionSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueSubsystemSupport.swift`
- removed stale shell: `Pinball App 2/Pinball App 2/gameroom/GameRoomRecordModels.swift`

Changes made in this pass:
- split service/play-count entry sheets out of the old mixed event-entry file into `GameRoomServiceEventEntrySupport.swift`
- split ownership and part/mod entry sheets into `GameRoomOwnershipEventEntrySupport.swift`
- split issue logging, issue resolution, and subsystem display-title formatting into:
  - `GameRoomIssueLoggingSupport.swift`
  - `GameRoomIssueResolutionSupport.swift`
  - `GameRoomIssueSubsystemSupport.swift`
- deleted the stale `GameRoomRecordModels.swift` shell after the snapshot/event/issue/attachment record types had already moved into dedicated files

Hidden seams surfaced and reduced:
1. the old event and issue entry buckets were still just holding multiple unrelated sheet flows because they happened to be created in the same earlier cleanup pass
2. `GameRoomRecordModels.swift` had become a misleading empty file after the record-type split, which would have looked like unfinished model debt on later passes

Behavioral outcome:
- no intended front-facing behavior changed
- event, ownership, issue, and issue-resolution flows now live in files that match their actual responsibilities

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 248: GameRoom catalog model and machine-resolution support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogLoader.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogModels.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogMachineResolutionSupport.swift`

Changes made in this pass:
- moved `GameRoomCatalogGame` and `GameRoomCatalogSlugMatch` out of `GameRoomCatalogLoader.swift` into `GameRoomCatalogModels.swift`
- moved exact-OPDB resolution, normalized catalog-game lookup, and image-candidate assembly into `GameRoomCatalogMachineResolutionSupport.swift`
- trimmed `GameRoomCatalogLoader.swift` down to the hosted-data load/reload pipeline, lookup entry points, and published loader state

Hidden seams surfaced and reduced:
1. `GameRoomCatalogLoader.swift` was still mixing three layers:
   - catalog data model types
   - async hosted-data loading and index construction
   - exact-machine normalization and artwork-candidate policy
2. the exact-OPDB and image fallback rules are now reviewable without reopening the async loader flow every time a GameRoom media issue comes up

Behavioral outcome:
- no intended front-facing behavior changed
- `GameRoomCatalogLoader.swift` dropped from 266 lines to 147

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 249: GameRoom machine route helper cleanup

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineRouteSupport.swift`

Changes made in this pass:
- moved machine-route helper queries out of `GameRoomMachineView.swift` into `GameRoomMachineRouteSupport.swift`:
  - recent attachments
  - open-issue detection
  - linked attachment lookup
  - linked event lookup
  - per-machine event sorting
- removed the stale `logRowHeights` state from `GameRoomMachineView.swift` after log-row measurement had already moved into `GameRoomMachineLogSupport.swift`

Hidden seams surfaced and reduced:
1. `GameRoomMachineView.swift` was still carrying small store-state query helpers that only remained there because the machine route and the underlying panels used to live in one file
2. the unused `logRowHeights` state was stale hidden state left behind after the log-height measurement logic moved into `GameRoomMachineLogSupport.swift`

Behavioral outcome:
- no intended front-facing behavior changed
- `GameRoomMachineView.swift` dropped from 222 lines to 218 and no longer carries stale log-measurement state

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 250: GameRoom edit-machine selection and import scoring support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachineSelectionSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinesView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomImportMatcherScoringSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomImportDateParsingSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomImportScoringSupport.swift`

Changes made in this pass:
- moved edit-machine selection helpers into `GameRoomEditMachineSelectionSupport.swift`:
  - selected-machine validation
  - venue-name draft sync
  - machine-menu label formatting
  - indexed manufacturer extraction
- trimmed `GameRoomEditMachinesView.swift` to use those helpers instead of carrying small local wrappers
- split `GameRoomImportMatcherScoringSupport.swift` into:
  - `GameRoomImportDateParsingSupport.swift` for purchase-date normalization
  - `GameRoomImportScoringSupport.swift` for text/token/manufacturer/year scoring helpers
- left `GameRoomImportMatcherScoringSupport.swift` focused on:
  - match labels
  - ranked suggestion assembly
  - confidence mapping

Hidden seams surfaced and reduced:
1. `GameRoomImportMatcherScoringSupport.swift` had drifted into a misleading file name because it still owned date parsing alongside actual scoring policy
2. `GameRoomEditMachinesView.swift` was still carrying several small support helpers that belonged with the edit-machine selection/search contract rather than the view lifecycle itself

Behavioral outcome:
- no intended front-facing behavior changed
- `GameRoomImportMatcherScoringSupport.swift` dropped from 194 lines to 63
- `GameRoomEditMachinesView.swift` dropped from 392 lines to 383

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 243: GameRoom machine input-sheet routing split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineServiceInputSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineIssueInputSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineOwnershipMediaInputSupport.swift`

Changes made in this pass:
- moved service-entry sheet routing out of `GameRoomMachineSupport.swift` into `GameRoomMachineServiceInputSupport.swift`
- moved issue open/resolve sheet routing into `GameRoomMachineIssueInputSupport.swift`
- moved ownership-update and add-media sheet routing into `GameRoomMachineOwnershipMediaInputSupport.swift`
- trimmed `GameRoomMachineSupport.swift` down to the input-sheet enum and the top-level switch router

Hidden seams surfaced and reduced:
1. `GameRoomMachineSupport.swift` had become a catch-all for every machine input flow even though the flows already grouped naturally by:
   - service and maintenance
   - issue tracking
   - ownership and media
2. the old file boundary made simple changes to one sheet category reopen unrelated categories in the same file

Behavioral outcome:
- no intended front-facing behavior changed
- `GameRoomMachineSupport.swift` dropped from 284 lines to 57

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 242: GameRoom area and machine-selection support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomAreaManagementSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineSelectionSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinePanelsSupport.swift`

Changes made in this pass:
- moved venue-name and area-management panels into `GameRoomAreaManagementSupport.swift`
- moved machine menu-group and variant-selection row support into `GameRoomMachineSelectionSupport.swift`
- trimmed `GameRoomEditMachinePanelsSupport.swift` down to the actual edit/mutation panel wiring

Hidden seams surfaced and reduced:
1. `GameRoomEditMachinePanelsSupport.swift` was carrying three separate concerns at once:
   - venue and area settings
   - machine/variant selection chrome
   - machine editor fields and actions
2. the file now aligns more closely with the edit-machine flow boundaries, which should make the remaining `GameRoomEditMachinesView.swift` cleanup easier

Behavioral outcome:
- no intended front-facing behavior changed
- `GameRoomEditMachinePanelsSupport.swift` dropped from 312 lines to 172

Remaining notable seam after this pass:
1. `GameRoomMachineView.swift` still owns attachment-link lookup and event/log routing helpers that probably want a dedicated support file in a later pass

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 232: GameRoom machine view shell support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineViewSupport.swift`

Changes made in this pass:
- moved the GameRoom machine screen shell views out of `GameRoomMachineView.swift`:
  - `GameRoomMachineFullscreenPhotoItem`
  - `GameRoomMachineSubview`
  - `GameRoomMachineHeroSection`
  - `GameRoomMachineHeaderSection`
  - `GameRoomMachineSubviewPicker`
  - `GameRoomMachineUnavailableMessage`
- left `GameRoomMachineView.swift` focused on route state, sheets/alerts, and subview routing

Hidden seam surfaced and reduced:
1. `GameRoomMachineView.swift` was still mixing machine-screen navigation/sheet state with static presentation shells for hero/header/subview chrome
2. those shell views now live in one support file, so future GameRoom machine cleanup can review route behavior separately from display composition

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 239: GameRoom catalog variant and slug support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogLoader.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogVariantSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogSlugSupport.swift`

Changes made in this pass:
- split the old `GameRoomCatalogLoaderSupport.swift` bucket into:
  - `GameRoomCatalogVariantSupport.swift` for:
    - catalog game construction
    - variant parsing and ranking
    - preferred-game selection
    - variant-option normalization
    - normalized catalog identity helpers
  - `GameRoomCatalogSlugSupport.swift` for:
    - slug-key generation
    - duplicate slug collision logging
    - slug normalization and suffix stripping
    - hosted/local URL resolution
- left `GameRoomCatalogLoader.swift` focused on hosted data loading, indexing, and public lookup APIs

Hidden seam surfaced and reduced:
1. the old support file was still mixing two separate policy layers:
   - machine/variant identity rules
   - slug matching and hosted-path resolution
2. those rules now live in separate support files, so future cleanup can review variant policy without reopening slug collision handling and vice versa

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 240: GameRoom Pinside title and document support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideImport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideTitleSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideDocumentSupport.swift`

Changes made in this pass:
- split the old `GameRoomPinsideParsingSupport.swift` bucket into:
  - `GameRoomPinsideTitleSupport.swift` for:
    - displayed-title normalization
    - variant derivation from title/slug
    - group-map title fallback resolution
  - `GameRoomPinsideDocumentSupport.swift` for:
    - page validation and Cloudflare challenge detection
    - basic HTML slug scraping
    - detailed Jina markdown parsing
    - fallback merge behavior
    - bundled group-map loading
    - purchase-month normalization
- left `GameRoomPinsideImport.swift` focused on network/orchestration behavior

Compile-only seam fixed during the split:
1. `parsePinsideDisplayedTitle(...)` was still `private` from the old single-file layout, so the document parser could not call it after the split
2. the helper was widened just enough for the new sibling support file and the final build passed

Hidden seam surfaced and reduced:
1. the old parser file was still mixing page validation, fallback merge policy, title normalization, slug-derived variant logic, and bundled group-map loading in one place
2. the new file boundary now matches those responsibilities more closely:
   - title/variant resolution
   - document parsing and fallback merge

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- first run failed with the private helper visibility seam above
- final result after the visibility fix: passed

## Pass 237: GameRoom store inventory support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStoreInventorySupport.swift`

Changes made in this pass:
- moved GameRoom inventory and venue mutations out of `GameRoomStore.swift`:
  - `area(for:)`
  - `addOwnedMachine(...)`
  - `updateMachine(...)`
  - `deleteMachine(...)`
  - `upsertArea(...)`
  - `deleteArea(...)`
  - `updateVenueName(...)`
- left `GameRoomStore.swift` focused on published state ownership, load/save behavior, and shared recompute/persistence helpers

Hidden seam surfaced and reduced:
1. `GameRoomStore.swift` was still mixing state host responsibilities with the full inventory/area mutation surface
2. `deleteMachine(...)` was also directly mutating `snapshots` before the authoritative `saveAndRecompute()` path recalculated them, which was redundant hidden state churn
3. inventory and venue mutations now live in one extension file, and the redundant pre-recompute snapshot mutation is gone

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 238: GameRoom store record support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStoreRecordSupport.swift`

Changes made in this pass:
- moved GameRoom event/issue/attachment mutation APIs out of `GameRoomStore.swift`:
  - `updateEvent(...)`
  - `deleteEvent(...)`
  - `addEvent(...)`
  - `openIssue(...)`
  - `resolveIssue(...)`
  - `addAttachment(...)`
  - `updateAttachment(...)`
  - `deleteAttachmentAndLinkedEvent(...)`
- left `GameRoomStore.swift` as the state/persistence host and kept record mutation behavior unchanged

Hidden seam surfaced and reduced:
1. `GameRoomStore.swift` had become a second catch-all bucket for all GameRoom record mutation paths on top of already owning load/save state
2. record mutations now live in one dedicated extension file, which makes future GameRoom record cleanup easier to review without reopening persistence/loading code

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 233: GameRoom edit-machine selection support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinesView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachineSelectionSupport.swift`

Changes made in this pass:
- moved the pure selection/filter helpers out of `GameRoomEditMachinesView.swift`:
  - machine menu grouping
  - selected machine lookup
  - manufacturer suggestion visibility
  - search-filter detection
  - current variant label formatting
  - add-machine result metadata
  - parsed optional int/string helpers
  - variant option and distinct-variant helpers
- left `GameRoomEditMachinesView.swift` focused on owned state and user-triggered mutations

Hidden seam surfaced and reduced:
1. `GameRoomEditMachinesView.swift` still carried a large block of pure helper logic that did not need access to view state
2. moving those helpers out makes the remaining file easier to treat as a view-state coordinator instead of a second utility bucket

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 234: GameRoom enum, inventory, and record model split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEnumModels.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomInventoryModels.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomRecordModels.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomModels.swift`

Changes made in this pass:
- moved GameRoom enums out of the old catch-all `GameRoomModels.swift` into `GameRoomEnumModels.swift`
- moved `GameRoomArea` and `OwnedMachine` into `GameRoomInventoryModels.swift`
- completed the earlier record/history move by keeping:
  - `OwnedMachineSnapshot`
  - `MachineEvent`
  - `MachineIssue`
  - `MachineAttachment`
  in `GameRoomRecordModels.swift`
- removed the stale `GameRoomModels.swift` bucket entirely once it no longer owned a coherent set of types

Hidden seam surfaced and reduced:
1. after the earlier persistence and record splits, `GameRoomModels.swift` had become a misleading leftover bucket instead of a real model boundary
2. the GameRoom model layer now has clearer ownership:
   - enum/taxonomy types
   - inventory/domain types
   - record/history types
   - persistence/import types

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 235: GameRoom edit-machine draft state support cleanup

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinesView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachineStateSupport.swift`

Changes made in this pass:
- grouped the add-machine filter fields into `GameRoomAddMachineFilters`
- grouped the edit-machine draft fields into `GameRoomMachineEditDraft`
- grouped the pending variant-picker state into `GameRoomPendingVariantPicker`
- updated `GameRoomEditMachinesView.swift` to bind panel inputs through those state objects instead of carrying a long loose list of `@State` fields

Hidden seam surfaced and reduced:
1. `GameRoomEditMachinesView.swift` was still acting like a bag of unrelated state slots, which made it harder to see which fields belonged to the add-machine flow versus the edit-machine flow
2. the view state now mirrors the actual UI contracts more clearly:
   - add-machine filters
   - edit-machine draft
   - pending variant picker

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 236: GameRoom home collection chrome support cleanup

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomHomeCollectionSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachinePresentationSupport.swift`

Changes made in this pass:
- moved shared collection-card artwork chrome into `GameRoomCollectionArtworkChrome`
- moved shared attention-state dot rendering into `GameRoomAttentionIndicator`
- moved shared snapshot metric assembly into `gameRoomSnapshotMetrics(...)`
- added `gameRoomVariantBadgeLabel(for:)` so the home tile/list views stop duplicating the same badge lookup
- kept the mini-card and list-row-specific layout/content separate while removing the repeated image-overlay and attention-color scaffolding

Hidden seam surfaced and reduced:
1. the home tile card and list row were carrying near-duplicate artwork background, selection stroke, attention-state color, and variant-badge logic
2. those shared display rules now live in one presentation layer instead of drifting between two home collection surfaces

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 217: GameRoom machine input and summary support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineSupport.swift`

Changes made in this pass:
- moved the machine input-sheet routing and the summary/input tab content out of `GameRoomMachineView.swift`
- introduced `GameRoomMachineInputSheet`, `GameRoomMachineInputSheetContent`, `GameRoomMachineSummaryContent`, and `GameRoomMachineInputContent` as dedicated machine-view support types
- left `GameRoomMachineView.swift` focused on shell state, tab selection, attachment routing, and navigation presentation

Hidden seam surfaced and reduced:
1. the machine screen previously mixed three layers in one file:
   - screen shell and navigation state
   - machine summary rendering
   - service / issue / ownership / media input sheet routing
2. those responsibilities now have clearer seams, so future GameRoom passes can adjust machine logging or input behavior without reopening the whole machine screen shell

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 218: GameRoom machine log support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineLogSupport.swift`

Changes made in this pass:
- moved the embedded machine log list, row-height preference plumbing, log detail routing, and swipe actions out of `GameRoomMachineView.swift`
- introduced `GameRoomMachineLogContent` as the dedicated log-tab surface for machine history, media-open routing, and event edit/delete actions

Hidden seam surfaced and reduced:
1. the machine screen was still carrying the last large inline list-management bucket after the summary/input split
2. the log tab now owns its own detail-card selection and measured embedded-list sizing instead of relying on `GameRoomMachineView.swift` to coordinate that view-specific plumbing

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 219: GameRoom edit-machines view extraction

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinesView.swift`

Changes made in this pass:
- moved `GameRoomEditMachinesView` wholesale out of `GameRoomSettingsComponents.swift`
- kept `GameRoomSettingsComponents.swift` as the lightweight settings root and section switcher
- moved the embedded name, area, machine editor, add-machine search, and variant-picker support views with the extracted machine editor file

Hidden seam surfaced and reduced:
1. `GameRoomSettingsComponents.swift` had stopped being a settings shell and had effectively become the entire GameRoom machine editor implementation
2. after the extraction, the settings root is back to one clear job: load the catalog, choose the section, and route to the matching settings surface

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 220: GameRoom event entry support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPresentationComponents.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEventEntrySupport.swift`

Changes made in this pass:
- moved the shared service / play-count / ownership / part-or-mod entry sheets out of `GameRoomPresentationComponents.swift`
- moved `GameRoomEventEditSheet` and the shared sheet-style helpers into `GameRoomEventEntrySupport.swift`
- left `GameRoomPresentationComponents.swift` focused on read-side log detail presentation and event-title display helpers

Hidden seam surfaced and reduced:
1. the presentation file was still carrying a full set of edit-sheet forms even after issue/media support moved out
2. the remaining file boundary now better matches the real split between read-side presentation and edit-side event-entry surfaces

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 221: GameRoom import support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomImportSettingsView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomImportSettingsSupport.swift`

Changes made in this pass:
- moved the import review filter, import draft row model, import matcher, source-entry section, review section, and review row card out of `GameRoomImportSettingsView.swift`
- left `GameRoomImportSettingsView.swift` focused on fetch/import shell state, result messaging, and store mutations

Hidden seam surfaced and reduced:
1. the import screen had become another mixed-responsibility bucket with view shell state, matching heuristics, row models, and review UI all interleaved
2. the matcher and review UI now live together in one support file, which makes future Pinside matching and import-review cleanup more localized

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 222: GameRoom issue entry support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueEntrySupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaSupport.swift`

Changes made in this pass:
- moved the issue logging and issue resolution sheets out of the mixed issue/media bucket into `GameRoomIssueEntrySupport.swift`
- left the old media file focused on media entry preview/edit support instead of issue entry forms

Hidden seam surfaced and reduced:
1. the old issue/media support file had silently become two unrelated form systems:
   - issue logging / issue resolution
   - media import / preview / edit
2. the extraction exposed one real file-boundary seam: `MovieTransferable` was still scoped to the old mixed file, so it was widened just enough for the new issue-entry sheet to keep using the same media import path

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 223: GameRoom home collection and presentation support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomHomeComponents.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomHomeCollectionSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachinePresentationSupport.swift`

Changes made in this pass:
- moved the selected-machine summary card and the full collection card surfaces out of `GameRoomHomeComponents.swift`
- moved shared GameRoom machine presentation helpers out of the home file:
  - location text
  - machine meta line
  - machine status label/color
  - variant pill
  - variant badge labeling
- left `GameRoomHomeComponents.swift` focused on home-screen state, selection seeding, and navigation routing

Hidden seam surfaced and reduced:
1. `GameRoomHomeComponents.swift` was still acting as three different layers:
   - home-screen shell state
   - collection card/list rendering
   - shared machine presentation helpers reused by the machine detail screen
2. the shared machine presentation contract now lives in one explicit support file instead of being hidden inside the home screen file

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 224: GameRoom edit-machine panel support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinesView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomEditMachinePanelsSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomAddMachineSupport.swift`

Changes made in this pass:
- moved the venue-name, area-management, machine-selection, and machine-editor panels out of `GameRoomEditMachinesView.swift`
- moved the add-machine search, advanced filters, result row, and variant-picker popover out of `GameRoomEditMachinesView.swift`
- renamed the extracted support views with explicit `GameRoom...` prefixes so the file boundary is obvious and the editor shell no longer relies on ambiguous nested helper names

Hidden seam surfaced and reduced:
1. even after the initial machine-editor extraction, `GameRoomEditMachinesView.swift` was still carrying most of the actual edit UI leaf views inline
2. the remaining file is now much closer to what it should be: state, derivations, selection syncing, and store mutations

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 225: GameRoom import matching support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomImportSettingsSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomImportMatchingSupport.swift`

Changes made in this pass:
- moved the Pinside import review filter, draft-row model, and import matcher out of `GameRoomImportSettingsSupport.swift`
- left `GameRoomImportSettingsSupport.swift` focused on source-entry and review UI sections

Hidden seam surfaced and reduced:
1. the earlier import support split still mixed two separate concerns in one file:
   - matching heuristics and normalization policy
   - review UI sections and row cards
2. matching policy now lives in its own support file, which makes future import-tuning or parity review easier without reopening the UI surfaces

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 226: GameRoom shared media import support and media-file rename

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaImportSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaEntrySupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMediaSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueEntrySupport.swift`

Changes made in this pass:
- moved shared GameRoom media import/storage helpers into `GameRoomMediaImportSupport.swift`
- moved the add-photo/add-video sheet into `GameRoomMediaEntrySupport.swift`
- renamed the stale `GameRoomIssueAndMediaSupport.swift` file to `GameRoomMediaSupport.swift`
- updated the issue-entry path to reuse the same shared media import/storage helpers instead of keeping a second copy of that logic

Hidden seams surfaced and reduced:
1. the old file name had become misleading after issue entry moved out; the file no longer represented issue support at all
2. the issue-entry sheet and media-entry sheet were both maintaining their own copies of:
   - imported media storage
   - imported video copy logic
   - string normalization helpers
3. those helpers now live in one shared GameRoom media support layer instead of drifting separately

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 227: GameRoom persistence model and decoding support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomModels.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPersistenceModels.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomDecodingSupport.swift`

Changes made in this pass:
- moved persistence-heavy GameRoom model types out of `GameRoomModels.swift`:
  - `MachineReminderConfig`
  - `MachineImportRecord`
  - `GameRoomPersistedState`
- moved shared decode helpers out of `GameRoomModels.swift` into `GameRoomDecodingSupport.swift`:
  - trimmed string decoding
  - UUID decoding
  - enum decoding
  - safe date decoding
- left `GameRoomModels.swift` focused more tightly on the domain enums and user-facing GameRoom entities

Hidden seam surfaced and fixed:
1. `GameRoomModels.swift` was still carrying both the gameplay/domain types and the persistence/decode infrastructure that only exists to make saved-state migration resilient
2. the first extraction surfaced one real cross-file seam: the moved `nilIfBlank` helper collided with an existing MatchPlay helper in `settings/MatchPlayClient.swift`, so the GameRoom decoding path now uses its own local trimming helper instead of introducing another global string extension

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 228: GameRoom store snapshot and import support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStoreSnapshotSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomStoreImportSupport.swift`

Changes made in this pass:
- moved snapshot/recompute logic out of `GameRoomStore.swift` into `GameRoomStoreSnapshotSupport.swift`:
  - `activeMachines`
  - `archivedMachines`
  - `snapshot(for:)`
  - machine sorting
  - reminder task counts
  - play-count bookkeeping
  - latest event date lookup
  - effective reminder config resolution
- moved import/migration helpers out of `GameRoomStore.swift` into `GameRoomStoreImportSupport.swift`:
  - duplicate fingerprint checks
  - existing-machine lookup
  - import record application
  - saved-machine OPDB normalization/migration
- widened only the two store helpers that the extracted files legitimately needed:
  - `saveAndRecompute()`
  - `normalizedOptionalString(_:)`

Hidden seam surfaced and reduced:
1. `GameRoomStore.swift` was still a mixed controller bucket containing live published state, mutation methods, import rules, snapshot generation, and reminder bookkeeping
2. the extracted files now separate the two most stateful hidden contracts in the store:
   - imported-machine reconciliation
   - snapshot/reminder derivation
3. during the split, a stale visibility assumption showed up immediately: these helpers previously “worked” only because they shared one file, so the fix was to expose the smallest owning helpers instead of loosening the rest of the store

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 229: GameRoom catalog loader support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogLoader.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogLoaderSupport.swift`

Changes made in this pass:
- moved the pure GameRoom catalog lookup policy out of `GameRoomCatalogLoader.swift` into `GameRoomCatalogLoaderSupport.swift`:
  - catalog machine mapping
  - preferred-record selection
  - variant option normalization
  - duplicate slug-key resolution
  - variant matching/exact matching helpers
  - normalized catalog ID/title helpers
  - hosted image URL resolution
- left `GameRoomCatalogLoader.swift` focused on loading, caching, and applying that policy to the published loader state

Hidden seam surfaced and reduced:
1. `GameRoomCatalogLoader.swift` was still mixing async loader orchestration with a large pure-policy bucket for:
   - dedupe rules
   - slug-key building
   - variant scoring
   - record ranking
2. pulling that pure policy into its own support file makes future GameRoom matching review much easier without reopening the loader’s published state and network/data-loading path

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 230: GameRoom Pinside parsing support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideImport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideParsingSupport.swift`

Changes made in this pass:
- moved the pure Pinside parsing and normalization support out of `GameRoomPinsideImport.swift` into `GameRoomPinsideParsingSupport.swift`:
  - group-map resource loading
  - collection HTML validation
  - Cloudflare-challenge detection
  - basic and detailed machine parsing
  - slug extraction
  - displayed-title normalization
  - slug-derived variant inference
  - purchase-date month normalization
  - primary/fallback machine merge logic
- left `GameRoomPinsideImport.swift` focused on request orchestration, retry/fallback behavior, and fatal-vs-retryable error policy

Hidden seams surfaced and fixed:
1. `GameRoomPinsideImport.swift` had become an all-in-one file for:
   - source URL normalization
   - network fetching
   - HTML validation
   - regex parsing
   - variant/title normalization
   - date parsing
   - fallback merge rules
2. after extracting those helpers, one important stale seam appeared immediately: because the project defaults to `MainActor` isolation, the new top-level parser helpers quietly inherited actor isolation until they were explicitly marked `nonisolated`
3. that would have become a real Swift 6 error later, so the helpers are now explicitly nonisolated and safe to call from the Pinside import actor

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 231: GameRoom machine panel support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachineSupport.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomMachinePanelsSupport.swift`

Changes made in this pass:
- moved the snapshot/media summary panel and the machine action-panel UI out of `GameRoomMachineSupport.swift` into `GameRoomMachinePanelsSupport.swift`:
  - `GameRoomMachineSummaryContent`
  - `GameRoomMachineInputContent`
- left `GameRoomMachineSupport.swift` focused on the sheet-entry routing path:
  - `GameRoomMachineInputSheet`
  - `GameRoomMachineInputSheetContent`

Hidden seam surfaced and reduced:
1. `GameRoomMachineSupport.swift` was still a mixed screen-support bucket containing:
   - input-sheet routing
   - snapshot metrics and recent media presentation
   - action-grid UI for service / issue / ownership tools
2. splitting the summary and action panels out means the file boundaries now line up much more closely with the actual machine screen sections instead of grouping them only because they once fit in one file

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 215: GameRoom settings responsibility split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsComponents.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomImportSettingsView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomArchiveSettingsView.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomSettingsSupport.swift`

Changes made in this pass:
- moved the full Pinside import flow out of `GameRoomSettingsComponents.swift` into `GameRoomImportSettingsView.swift`:
  - import matching heuristics
  - purchase-date normalization
  - review-card UI
  - import execution path
- moved the archive filter/list UI into `GameRoomArchiveSettingsView.swift`
- moved shared settings-only chrome out into `GameRoomSettingsSupport.swift`:
  - adaptive popover placement
  - floating save-feedback overlay
- left `GameRoomSettingsComponents.swift` focused on the settings shell plus the machine-editing surface

Hidden seam surfaced and reduced:
1. `GameRoomSettingsComponents.swift` was still carrying at least four separate layers in one file:
   - top-level settings routing
   - Pinside import matching/import policy
   - machine editing
   - shared settings-only view infrastructure
2. the first extraction surfaced one real file-scope cleanup seam: `gameRoomAdaptivePopover(...)` was still `fileprivate` from when it lived in the same file, so the helper was widened just enough to stay reusable across the new support file boundary

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 216: GameRoom issue and media support split

Primary files:
- `Pinball App 2/Pinball App 2/gameroom/GameRoomPresentationComponents.swift`
- `Pinball App 2/Pinball App 2/gameroom/GameRoomIssueAndMediaSupport.swift`

Changes made in this pass:
- moved GameRoom issue/media entry surfaces out of `GameRoomPresentationComponents.swift` into `GameRoomIssueAndMediaSupport.swift`:
  - issue logging sheet
  - issue resolution sheet
  - media entry sheet
  - attachment tiles and preview/edit sheets
  - media import/copy helpers
  - issue-subsystem display-title support
- left `GameRoomPresentationComponents.swift` with the more generic entry sheets and event/log presentation pieces:
  - service entry
  - play-count entry
  - ownership entry
  - part/mod entry
  - log detail card
  - event edit sheet

Hidden seam surfaced and reduced:
1. `GameRoomPresentationComponents.swift` was still acting as both the generic entry-sheet bucket and the issue/media/attachment support bucket used by `GameRoomMachineView`
2. separating those responsibilities makes future GameRoom cleanup safer because attachment import/preview work no longer sits in the same file as unrelated ownership/service sheets

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 189: Android loader model and OPDB decode support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogModels.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryOPDBCatalogDecodingSupport.kt`

Changes made in this pass:
- moved Android catalog payload model types out of `LibraryDataLoader.kt`
- moved OPDB machine decode, practice-identity curation, synthetic PinProf Labs insertion, manufacturer record building, and Practice catalog decode/load helpers out of `LibraryDataLoader.kt`
- removed the stale unused `rawOpdbFallbackSlug` helper while shrinking the loader around actual orchestration work

Hidden seam surfaced and reduced:
1. `LibraryDataLoader.kt` was still serving as Android Library’s generic bucket for catalog models and OPDB decode policy, which made the hosted extraction path harder to audit than the already-cleaned iOS version
2. the loader now depends on explicit support files instead of also being the place where the raw catalog contract is defined

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 190: Android CAF asset and venue overlay support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCAFAssetSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryVenueMetadataOverlaySupport.kt`

Changes made in this pass:
- moved curated playfield/gameinfo/rulesheet/video asset parsing out of `LibraryDataLoader.kt`
- moved venue overlay record types, overlay parsing, overlay merge, and resolved venue metadata lookup out of `LibraryDataLoader.kt`
- left the loader focused on composing the hosted extraction instead of also owning low-level asset parsing and overlay lookup policy

Hidden seam surfaced and reduced:
1. Android CAF data loading was still mixing hosted extraction, overlay models, and per-record JSON parsing in one file
2. the split now mirrors the iOS Library venue-overlay cleanup more closely and makes later venue-policy review much easier

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 191: Android GameRoom synthetic import support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryGameRoomSyntheticImportSupport.kt`

Changes made in this pass:
- moved the GameRoom synthetic venue-import model, merge helper, saved-state load, and machine ordering helpers out of `LibraryDataLoader.kt`
- left the loader responsible only for threading the synthetic GameRoom import into hosted Library extraction

Hidden seam surfaced and reduced:
1. the new GameRoom-as-venue contract was already behaviorally correct, but it was still embedded inside the generic loader file
2. after the split, the GameRoom library contract lives in one explicit Android support file just like the cleaned iOS side

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 192: Android resource-path and playfield support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryResourceResolution.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryResourcePathSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryPlayfieldResolutionSupport.kt`

Changes made in this pass:
- moved hosted URL normalization, PinProf host checks, live playfield status fetch, and library cache/path normalization out of `LibraryResourceResolution.kt`
- moved playfield candidate assembly, playfield source labels, bundled-only asset exceptions, and artwork fallback policy out of `LibraryResourceResolution.kt`
- left `LibraryResourceResolution.kt` focused on rulesheet and gameinfo resource accessors instead of also owning the whole media stack

Hidden seam surfaced and reduced:
1. Android `LibraryResourceResolution.kt` was still carrying the same three-layer mix the iOS cleanup had already split:
   - generic hosted path helpers
   - live playfield network status
   - `PinballGame`-specific playfield and rulesheet behavior
2. the Android file boundaries now match those responsibilities much more closely

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 193: Android hosted-image and rulesheet screen support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/PlayfieldScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RemoteImageSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/HostedImageScreenSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetContentWebViewSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetHtmlTemplateSupport.kt`

Changes made in this pass:
- moved shared cached-image and constrained preview helpers out of `PlayfieldScreen.kt`
- moved fullscreen image title-color sampling and zoom/pan interaction support out of `PlayfieldScreen.kt`
- moved the embedded rulesheet webview content host and HTML template assembly out of `RulesheetScreen.kt`
- left both Android screen files focused on screen routing/state instead of also serving as support buckets

Hidden seams surfaced and reduced:
1. `PlayfieldScreen.kt` had become a shared image utility file used by Library, Practice, and GameRoom in addition to being a screen
2. `RulesheetScreen.kt` was still mixing route state, webview state restore, and a large HTML template string in one file
3. one compile-only split seam surfaced during extraction:
   - moved Compose imports and a stale header parameter had to be corrected after the first build
   - this was fixed immediately without broadening behavior or ownership

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 194: Android playfield candidate and display policy split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryPlayfieldResolutionSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryPlayfieldCandidateSupport.kt`

Changes made in this pass:
- moved Android playfield candidate assembly, asset-key derivation, and bundled-only asset exception handling out of `LibraryPlayfieldResolutionSupport.kt`
- left `LibraryPlayfieldResolutionSupport.kt` focused on labels, options, and public-facing playfield display policy instead of also owning every candidate-builder helper

Hidden seam surfaced and reduced:
1. `LibraryPlayfieldResolutionSupport.kt` had grown into another mixed bucket, combining low-level candidate generation with higher-level “what label should the UI show?” policy
2. one subtle cleanup risk surfaced during the split:
   - the PinProf option list must preserve the old precedence even when live playfield status is null
   - this was corrected immediately by exposing the exact internal candidate helper needed rather than rewriting the option logic

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 195: Android external rulesheet web support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetExternalWebSupport.kt`

Changes made in this pass:
- moved the external web rulesheet route and backing webview out of `RulesheetScreen.kt`
- left `RulesheetScreen.kt` focused on in-app rulesheet loading, resume/save progress behavior, and the overlay chrome

Hidden seam surfaced and reduced:
1. Android `RulesheetScreen.kt` was still carrying two screens:
   - the in-app rendered rulesheet route
   - the external web route
2. after the split, the in-app screen no longer also acts as the owner of unrelated external-webview setup

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 196: Android rulesheet HTML style and script support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetHtmlTemplateSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetHtmlStyleSupport.kt`

Changes made in this pass:
- split the large inline CSS block out of `RulesheetHtmlTemplateSupport.kt`
- split the table-wrapper enhancement script out of `RulesheetHtmlTemplateSupport.kt`
- left the HTML template file focused on document assembly instead of also being one large string blob

Hidden seam surfaced and reduced:
1. the Android rulesheet HTML support file had become hard to scan because document shell, CSS policy, and DOM enhancement script all lived inside one template string
2. a tiny compile-only typo surfaced in the new external-web support file during this batch and was fixed immediately before the final build

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 197: Android list-grid support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryListScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryListGridSupport.kt`

Changes made in this pass:
- moved the Library grid layout and Library card rendering out of `LibraryListScreen.kt`
- left `LibraryListScreen.kt` focused on route-level loading/empty/filter-sheet logic instead of also owning the leaf card view hierarchy

Hidden seam surfaced and reduced:
1. the Android list screen was still mixing route chrome and infinite-scroll handling with the actual grid/card leaf rendering
2. one compile-only cleanup seam surfaced when the moved code took some route-file imports with it
3. that was fixed immediately by restoring only the route imports still actually used

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 198: Android detail media support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDetailScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDetailMediaSupport.kt`

Changes made in this pass:
- moved fallback screenshot image handling and the video thumbnail/tile leaf views out of `LibraryDetailScreen.kt`
- left `LibraryDetailScreen.kt` focused on route-level data loading and section composition instead of also owning those reusable media leaves

Hidden seam surfaced and reduced:
1. `LibraryDetailScreen.kt` had become both the route shell and the place where reusable video tile / image fallback components lived
2. this split makes the Android detail route closer to the already-cleaned iOS Library detail structure

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 199: Android detail video and game-info support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDetailComponents.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDetailVideoSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDetailGameInfoSupport.kt`

Changes made in this pass:
- moved the detail route's video-reference card and launch panel out of `LibraryDetailComponents.kt`
- moved the markdown-backed Game Info card out of `LibraryDetailComponents.kt`
- left `LibraryDetailComponents.kt` focused on the screenshot section and the summary/resource card instead of also owning video and markdown presentation

Hidden seam surfaced and reduced:
1. the Android detail component bucket was still mixing summary/resource chrome with video-launch flow and rich-text markdown rendering
2. the initial extraction surfaced only compile-only cleanup seams:
   - one missing `clip` import in the moved video panel
   - one malformed `20.dp` reference in the moved Game Info card
3. both were fixed immediately before the final build, without changing runtime behavior

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 200: Android rulesheet screen support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetScreenSupport.kt`

Changes made in this pass:
- moved rulesheet content loading into `loadRulesheetRenderContent(...)`
- moved the progress-pill save UI into `RulesheetProgressPill(...)`
- moved the fullscreen chrome overlay into `RulesheetChromeOverlay(...)`
- moved the resume-position dialog into `RulesheetResumePrompt(...)`
- left `RulesheetScreen.kt` focused on route-level state, content status routing, and webview wiring

Hidden seam surfaced and reduced:
1. `RulesheetScreen.kt` was still carrying route state, load policy, progress-save chrome, and resume prompt UI in one file even after the earlier web/template splits
2. the extraction exposed only compile-only Kotlin/Compose wiring seams:
   - missing `getValue` delegate import in `RulesheetScreen.kt`
   - missing `animateFloat` extension import in `RulesheetScreenSupport.kt`
3. those were fixed immediately and the final build stayed green

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 201: Android OPDB practice-identity support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryOPDBCatalogDecodingSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryOPDBPracticeIdentitySupport.kt`

Changes made in this pass:
- moved OPDB group-id derivation and practice-identity curation parsing out of `LibraryOPDBCatalogDecodingSupport.kt`
- left the main decode file focused on raw machine extraction, manufacturer derivation, and practice-catalog game building instead of also owning the practice-identity fallback policy

Hidden seam surfaced and reduced:
1. the Android OPDB decode file still mixed raw export parsing with the separate practice-identity curation contract
2. the new support file now owns that identity policy directly, making it easier to review alongside the hosted `practice_identity_curations_v1.json` path without reopening the whole decode stack

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 202: Android synthetic PinProf Labs machine support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryOPDBCatalogDecodingSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryOPDBSyntheticMachineSupport.kt`

Changes made in this pass:
- moved the synthetic PinProf Labs machine constants and append helper out of the main OPDB decode file
- left the decode file focused on turning OPDB export records into catalog machines instead of also carrying the one synthetic record policy inline

Hidden seam surfaced and reduced:
1. the synthetic PinProf Labs record is intentional product policy, but it had been buried inside the generic OPDB decode bucket
2. extracting it makes that intentional override explicit and easier to keep aligned with the iOS cleanup path later

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 203: Android rulesheet HTML script support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetHtmlStyleSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetHtmlScriptSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetHtmlTemplateSupport.kt`

Changes made in this pass:
- moved the DOM table-wrapper enhancement script out of `RulesheetHtmlStyleSupport.kt`
- left the style file focused on CSS policy and the template file focused on final HTML document assembly

Hidden seam surfaced and reduced:
1. the Android rulesheet HTML path had already split document assembly away from the screen, but one file still mixed CSS and DOM enhancement script
2. separating the script keeps future rulesheet styling cleanup from reopening the JavaScript helper at the same time

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 204: Android media-resolution and hosted-image color support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryRulesheetLinkResolutionSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryVideoResolutionSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/HostedImageColorSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/HostedImageScreenSupport.kt`

Changes made in this pass:
- replaced the old mixed `LibraryMediaResolutionSupport.kt` bucket with separate rulesheet-link and video-resolution support files
- moved hosted-image title-color sampling out of `HostedImageScreenSupport.kt`
- left the hosted-image screen support file focused on zoom, gesture handling, and image fallback behavior

Hidden seam surfaced and reduced:
1. Android media resolution was still mixing two different policy families:
   - rulesheet link labeling / dedupe
   - video identity / dedupe / ordering
2. the hosted-image screen support file still mixed presentation-time color sampling with actual gesture and zoom behavior
3. both seams are now split cleanly, bringing Android closer to the already-finished iOS Library structure

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 205: Android remote rulesheet document support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetRemoteLoader.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetRemoteDocumentSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/TiltForumsRulesheetSupport.kt`

Changes made in this pass:
- moved remote fetch/document cleanup helpers out of `RulesheetRemoteLoader.kt`
- moved Tilt Forums API URL and payload parsing out of the loader object
- left `RulesheetRemoteLoader.kt` focused on source-type routing and final `RulesheetRenderContent` assembly

Hidden seam surfaced and reduced:
1. the Android remote rulesheet loader still mixed three layers:
   - remote fetch transport
   - provider-specific HTML/API cleanup
   - final rendered-content assembly
2. those responsibilities now live in narrower support files, which makes the source-policy surface easier to audit without reopening HTTP and HTML cleanup code at the same time

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 206: Android playfield asset-path support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryPlayfieldCandidateSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryPlayfieldAssetPathSupport.kt`

Changes made in this pass:
- moved local asset keys, local/sourced playfield path generation, and fullscreen candidate assembly helpers out of `LibraryPlayfieldCandidateSupport.kt`
- left `LibraryPlayfieldCandidateSupport.kt` focused on candidate precedence and final fallback policy

Hidden seam surfaced and reduced:
1. the Android playfield candidate file still mixed path-generation infrastructure with the higher-level “which source wins?” policy
2. separating those layers makes the precedence logic easier to review without reopening all the raw path assembly helpers
3. one helper visibility seam surfaced during the move: `isOpdbPlayfieldUrl(...)` needed to be widened for cross-file reuse

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 207: Android OPDB machine decoding support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryOPDBCatalogDecodingSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryOPDBMachineDecodingSupport.kt`

Changes made in this pass:
- moved raw OPDB machine decoding, image extraction, and JSON field helpers out of `LibraryOPDBCatalogDecodingSupport.kt`
- left the main decode file focused on orchestrating export decode, practice-catalog game building, and hosted load flow

Hidden seam surfaced and reduced:
1. the Android OPDB decode file still mixed low-level JSON extraction with higher-level catalog assembly
2. the new support file now owns the raw machine-record translation directly, which brings Android closer to the already-cleaned iOS structure

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 208: Android manufacturer option support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryOPDBCatalogDecodingSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogManufacturerSupport.kt`

Changes made in this pass:
- moved curated modern-manufacturer ranking and catalog manufacturer option derivation out of the OPDB decode file
- left the OPDB decode path focused on machine decode and practice-catalog projection instead of also owning manufacturer option policy

Hidden seam surfaced and reduced:
1. manufacturer ranking/featured-order policy is Library catalog behavior, not raw OPDB decode infrastructure
2. extracting it makes that product policy explicit and easier to keep aligned with future iOS/Android parity cleanup
3. the first extraction left duplicate helpers behind in the old file; that compile-only seam was fixed immediately before the final green build

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 209: Android rulesheet HTML typography and table style split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetHtmlStyleSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetHtmlTypographyStyleSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetHtmlTableStyleSupport.kt`

Changes made in this pass:
- split the large Android rulesheet CSS block into typography/base styles and table-specific styles
- left `RulesheetHtmlStyleSupport.kt` as the small coordinator that assembles the final CSS plus responsive overrides

Hidden seam surfaced and reduced:
1. the Android rulesheet style file had become one large CSS blob even after the HTML template and script had already moved out
2. splitting typography from table styling makes future rulesheet visual cleanup easier without reopening unrelated CSS sections

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 210: Android route-missing screen support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryRouteContent.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryRouteMissingSupport.kt`

Changes made in this pass:
- moved the missing-route screen helper out of `LibraryRouteContent.kt`
- left `LibraryRouteContent.kt` focused on route switching and destination composition instead of also owning the fallback error surface

Hidden seam surfaced and reduced:
1. `LibraryRouteContent.kt` was already mostly route switching, but it still carried an embedded fallback screen implementation that made the file broader than necessary
2. this split keeps the route coordinator narrow without changing any routing behavior

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 211: Android list content and filter-sheet split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryListScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryListContentSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryFilterSheetSupport.kt`

Changes made in this pass:
- moved list-body rendering out of `LibraryListScreen.kt`
- moved filter-sheet UI out of `LibraryListScreen.kt`
- left `LibraryListScreen.kt` focused on route-level state and wiring instead of also owning the body and filter-sheet view trees

Hidden seam surfaced and reduced:
1. the Android list screen still mixed route state with two distinct UI surfaces:
   - the main results/content body
   - the filter sheet
2. the first extraction surfaced only compile-only import cleanup around `verticalScroll` and stale leftover screen-local constants
3. those were fixed immediately before the final green build

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 212: Android source-state persistence support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySourceStateStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySourceStatePersistenceSupport.kt`

Changes made in this pass:
- moved JSON encode/decode and normalization helpers out of `LibrarySourceStateStore.kt`
- left the store file focused on state mutations, synchronization, and preference writes instead of also owning raw persistence translation

Hidden seam surfaced and reduced:
1. the Android source-state store still mixed persistence shape translation with the store’s actual mutation API
2. separating persistence support makes the state contract clearer and keeps the store file aligned with the earlier source-store cleanup

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 213: Android hosted-image request and gesture support split

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/HostedImageScreenSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/HostedImageRequestSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/HostedImageGestureSupport.kt`

Changes made in this pass:
- moved hosted-image request construction and loading overlay support out of `HostedImageScreenSupport.kt`
- moved gesture state and gesture handling into a dedicated `ZoomablePlayfieldGestureState` support file
- left `HostedImageScreenSupport.kt` focused on the zoomable image shell and async image rendering

Hidden seam surfaced and reduced:
1. the Android hosted-image screen still mixed:
   - async image request creation
   - gesture state and gesture handling
   - the actual zoomable image shell
2. the first gesture extraction used awkward state adapters; that was intentionally revisited and replaced with a dedicated gesture state object before calling the pass complete
3. the remaining file is now a clean coordinator for one cohesive image-viewing surface

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 214: Android Library cleanup end-state checkpoint

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDetailVideoSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/RulesheetContentWebViewSupport.kt`

Result of this pass:
- no further decomposition required for the remaining medium files
- the remaining larger files each now represent one cohesive responsibility:
  - `LibraryScreen.kt`: top-level route coordinator
  - `LibraryDataLoader.kt`: hosted extraction coordinator
  - `LibraryDetailVideoSupport.kt`: single detail video card/panel surface
  - `RulesheetContentWebViewSupport.kt`: actual WebView integration layer
- Android Library is now in the same “polish only” state as the completed iOS Library cleanup

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 184: Android Library screen state ownership cleanup

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryScreenStateSupport.kt`

Changes made in this pass:
- moved Android Library screen loading and selection-persistence helpers out of the composable body into `LibraryScreenStateSupport.kt`
- introduced a dedicated `LibraryScreenLoadedState` result so reload logic returns one explicit snapshot instead of mutating several state buckets inline
- centralized selected-source, sort, and bank persistence helpers so `LibraryScreen.kt` no longer rewrites the same `LibrarySourceState` map-update logic in multiple callbacks
- kept `LibraryScreen.kt` focused on Compose state wiring, route transitions, and UI event handling

Hidden seam surfaced and reduced:
1. `LibraryScreen.kt` still mixed one-shot data loading, store writes, and route/UI composition in the same composable body
2. the new support file makes the data-loading and persistence contract explicit and reduces the chance that future source-state changes update one callback path but not the others

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: `BUILD SUCCESSFUL`

## Pass 177: Catalog variant label and selection split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogVariantLabelSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogVariantSelectionSupport.swift`

Changes made in this pass:
- replaced the old mixed `LibraryCatalogVariantSupport.swift` bucket with two narrower support files
- moved variant-title formatting and label heuristics into `LibraryCatalogVariantLabelSupport.swift`
- moved preferred-machine and variant-selection policy into `LibraryCatalogVariantSelectionSupport.swift`
- left `LibraryCatalogResolution.swift` focused on resolved record assembly

Hidden seam surfaced and reduced:
1. the old variant support file was still carrying both presentation-oriented label rules and record-selection policy
2. those responsibilities now live separately, so future cleanup can touch either variant labeling or machine selection without reopening the other

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 178: Venue overlay model, parsing, and resolution split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogVenueSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryVenueMetadataOverlayModels.swift`
- `Pinball App 2/Pinball App 2/library/LibraryVenueMetadataOverlayParsingSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryVenueMetadataOverlayResolutionSupport.swift`

Changes made in this pass:
- replaced the old single `LibraryVenueMetadataOverlaySupport.swift` file with separate model, parsing, and resolution support files
- kept raw overlay payload shapes in `LibraryVenueMetadataOverlayModels.swift`
- moved hosted-asset and JSON decoding helpers into `LibraryVenueMetadataOverlayParsingSupport.swift`
- moved overlay lookup and imported-venue merge rules into `LibraryVenueMetadataOverlayResolutionSupport.swift`

Hidden seam surfaced and reduced:
1. venue-overlay support had become a mixed contract between payload definitions, decoding, and live overlay resolution
2. the new split makes the overlay lifecycle explicit and easier to audit against future venue-import behavior

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 179: Hosted image zoom support split

Primary files:
- `Pinball App 2/Pinball App 2/library/HostedImageScreen.swift`
- `Pinball App 2/Pinball App 2/library/HostedImageZoomSupport.swift`

Changes made in this pass:
- moved hosted-image pinch, pan, and double-tap zoom state helpers into `HostedImageZoomSupport.swift`
- left `HostedImageScreen.swift` focused on screen composition, chrome, and image loading presentation

Hidden seam surfaced and reduced:
1. the hosted image screen was carrying both the full-screen media UI and the gesture-state math that supports zooming
2. separating those concerns makes future image-view cleanup easier without disturbing gesture behavior

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 180: Rulesheet renderer delegate and scroll interaction split

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetRendererSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetRendererDelegateSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetRendererScrollInteractionSupport.swift`

Changes made in this pass:
- replaced the old `RulesheetRendererInteractionSupport.swift` file with separate delegate and scroll-interaction support files
- moved WKNavigationDelegate and message-handler behavior into `RulesheetRendererDelegateSupport.swift`
- moved scroll-view progress tracking, chrome tap, and interaction-state handling into `RulesheetRendererScrollInteractionSupport.swift`
- left `RulesheetRendererSupport.swift` focused on the representable shell and coordinator-owned state

Hidden seam surfaced and reduced:
1. renderer interaction support still mixed web delegate events and scroll interaction logic in one bucket
2. the split now matches the UIKit/WebKit boundaries more closely and reduces the risk of reopening viewport restore logic when only interaction behavior needs review

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 181: Markdown block and HTML-table parsing split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownParsing.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownBlockParsingSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownHTMLTableParsingSupport.swift`

Changes made in this pass:
- replaced the old broad `LibraryMarkdownParsingSupport.swift` bucket with block parsing and HTML-table parsing support files
- moved line/block-oriented markdown parsing helpers into `LibraryMarkdownBlockParsingSupport.swift`
- moved HTML table detection and extraction helpers into `LibraryMarkdownHTMLTableParsingSupport.swift`
- left `LibraryMarkdownParsing.swift` focused on the top-level parsing entry points

Hidden seam surfaced and reduced:
1. markdown parsing was still mixing generic block decomposition with the more specialized HTML table path
2. the split makes it clearer which rules are true markdown parsing and which are HTML-table compatibility support

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 182: Rulesheet HTML document, style, and script split

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetHTMLDocument.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetHTMLDocumentSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetHTMLStyleSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetHTMLScriptSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetWebBridge.js`

Changes made in this pass:
- replaced the old mixed `RulesheetHTMLTemplateSupport.swift` bucket with dedicated HTML document, style, and script support files
- moved the HTML shell builder into `RulesheetHTMLDocumentSupport.swift`
- moved the CSS bundle into `RulesheetHTMLStyleSupport.swift`
- moved injected bridge-script assembly into `RulesheetHTMLScriptSupport.swift`
- kept the large live bridge itself externalized in `RulesheetWebBridge.js`

Hidden seam surfaced and reduced:
1. rulesheet HTML generation still mixed document composition, raw style payloads, and script-template loading in one place
2. the split now matches the real output layers of the generated rulesheet document and leaves only small, explicit composition code in the main document builder

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 183: iOS Library completion checkpoint

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetScreen.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetRendererSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryPlayfieldResolutionSupport.swift`
- `Pinball App 2/Pinball App 2/library/HostedImageScreen.swift`

Final sweep result:
- the remaining iOS Library files are now cohesive support files rather than mixed-responsibility monoliths
- the largest remaining files mostly represent normal single-purpose buckets:
  - rulesheet CSS payload
  - playfield candidate resolution
  - rulesheet screen shell
  - hosted image presentation
- no new hidden runtime/parity issues surfaced during the final sweep

Cleanup status after this pass:
1. iOS Library is out of active decomposition territory and into polish-only territory
2. future work here should be opportunistic naming or focused behavior work, not another broad structural breakup
3. Android Library cleanup can now follow the iOS log as the parity map when we want to tackle the Android side more deeply

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 164: Library grid/card support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryGridSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryGameGridScrollSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryGameCardSupport.swift`

Changes made in this pass:
- moved list-level scroll and paging support out of `LibraryGridSupport.swift`
- moved game-card and compact-grid leaf rendering out of `LibraryGridSupport.swift`
- left `LibraryGridSupport.swift` focused on the top-level list content and empty-state routing

Hidden seam surfaced and reduced:
1. `LibraryGridSupport.swift` was still mixing parent list orchestration with the actual card and grid leaf views
2. the list/content shell can now change without reopening the reusable card/grid presentation helpers

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 165: Rulesheet HTML template extraction

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetHTMLDocument.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetHTMLTemplateSupport.swift`

Changes made in this pass:
- moved the large CSS/HTML template body out of `RulesheetHTMLDocument.swift`
- left `RulesheetHTMLDocument.swift` as a thin builder that assembles the already-extracted template and runtime values

Hidden seam surfaced and reduced:
1. `RulesheetHTMLDocument.swift` had become a mixed template bucket instead of a small HTML document builder
2. the full template can now be reviewed and edited without reopening the builder logic that injects content into it

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 166: Catalog payload-model family split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogPayloadModels.swift`
- `Pinball App 2/Pinball App 2/library/LibraryOPDBExportPayloadModels.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogMachinePayloadModels.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogSourcePayloadModels.swift`

Changes made in this pass:
- left `LibraryCatalogPayloadModels.swift` focused on the normalized catalog root model
- moved raw OPDB export records into `LibraryOPDBExportPayloadModels.swift`
- moved normalized machine payload records into `LibraryCatalogMachinePayloadModels.swift`
- moved normalized source payload records into `LibraryCatalogSourcePayloadModels.swift`

Hidden seam surfaced and reduced:
1. one file was still mixing raw upstream export shapes with normalized app payload models
2. the payload model families are now split by role, so upstream-decoding changes and normalized-catalog changes do not have to share the same file

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 167: Rulesheet viewport restore capture/scheduling split

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetRendererViewportRestoreSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetViewportRestoreSchedulingSupport.swift`

Changes made in this pass:
- left low-level viewport-capture and layout-snapshot helpers in `RulesheetRendererViewportRestoreSupport.swift`
- moved restore sequencing, retry scheduling, and release/reset orchestration into `RulesheetViewportRestoreSchedulingSupport.swift`

Hidden seam surfaced and reduced:
1. one support file was still mixing pure capture helpers with the restore state machine
2. viewport bookkeeping and restore scheduling can now evolve independently

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 168: Library browsing-state source/filter support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryPayloadParsing.swift`
- `Pinball App 2/Pinball App 2/library/LibraryBrowsingStateSourceSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryBrowsingStateFilteringSupport.swift`

Changes made in this pass:
- left `LibraryPayloadParsing.swift` focused on the payload and browsing-state data structs
- moved source-selection, visible-source, sort-label, and bank-filter helpers into `LibraryBrowsingStateSourceSupport.swift`
- moved search filtering, sorting, grouping, and section assembly into `LibraryBrowsingStateFilteringSupport.swift`

Hidden seam surfaced and reduced:
1. `LibraryPayloadParsing.swift` was still acting like both a data-model file and a browsing-state behavior file
2. the browsing-state helper surface now matches the actual responsibilities more closely: source routing vs filtering/sorting/grouping

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 169: Imported-source model and normalization split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryImportedSourcesStore.swift`
- `Pinball App 2/Pinball App 2/library/LibraryImportedSourceModels.swift`
- `Pinball App 2/Pinball App 2/library/LibraryImportedSourceNormalizationSupport.swift`

Changes made in this pass:
- moved imported-source record and provider models out of `LibraryImportedSourcesStore.swift`
- moved normalization, merge, and provider-inference helpers out of `LibraryImportedSourcesStore.swift`
- left the store focused on load/save/upsert/remove persistence entry points

Hidden seam surfaced and reduced:
1. `LibraryImportedSourcesStore.swift` was still owning three layers at once:
   - data models
   - normalization/merge policy
   - persistence API
2. the persistence entry points can now be reviewed without reopening the record-model and normalization helpers every time

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 170: PinballGame core-model ownership split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryGame.swift`
- `Pinball App 2/Pinball App 2/library/LibraryGameModels.swift`

Changes made in this pass:
- moved `PinballGame` nested helper models and coding keys into `LibraryGameModels.swift`
- left `LibraryGame.swift` focused on the core stored properties, resolved-record initializer, and stable IDs

Hidden seam surfaced and reduced:
1. `LibraryGame.swift` was still carrying both the core model surface and the nested helper/coding model bucket
2. the top-level Library game model is now much easier to scan because the coding-key and nested-link/video types no longer hide the stored-property contract

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 171: OPDB catalog machine-record support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogOPDBDecoding.swift`
- `Pinball App 2/Pinball App 2/library/LibraryOPDBMachineRecordSupport.swift`

Changes made in this pass:
- moved low-level OPDB machine-to-catalog-record extraction out of `LibraryCatalogOPDBDecoding.swift`
- moved the catalog machine post-normalization pass out with the machine-record helpers
- left `LibraryCatalogOPDBDecoding.swift` focused on the top-level OPDB catalog decode entry point

Hidden seam surfaced and reduced:
1. `LibraryCatalogOPDBDecoding.swift` was still mixing the public decode entry point with all of the low-level machine extraction policy
2. the file boundary now separates "decode the upstream export" from "shape one raw OPDB machine into a catalog machine record"

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 172: OPDB manufacturer-option and practice-catalog decode split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogManufacturerOptionSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryPracticeCatalogDecodingSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogOPDBDecoding.swift`

Changes made in this pass:
- moved OPDB manufacturer-option assembly into `LibraryCatalogManufacturerOptionSupport.swift`
- moved Practice catalog game synthesis into `LibraryPracticeCatalogDecodingSupport.swift`
- kept the shared OPDB catalog decode path as the one common source of machine extraction

Hidden seam surfaced and reduced:
1. one file was still trying to own three separate consumers of the same OPDB export:
   - catalog machines
   - manufacturer options
   - Practice catalog games
2. those consumers now live in separate support files, so future changes to one consumer do not have to reopen the others

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 173: Seeded-source machine-ID data split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibrarySeededImportedSources.swift`
- `Pinball App 2/Pinball App 2/library/LibrarySeededVenueMachineIDs.swift`

Changes made in this pass:
- moved the large default Avenue and Electric Bat machine-ID arrays out of `LibrarySeededImportedSources.swift`
- left `LibrarySeededImportedSources.swift` focused on the first-run seeded source policy and record construction

Hidden seam surfaced and reduced:
1. the seeded-source policy file was still carrying both the default-source intent and all of the raw venue machine-ID data
2. the seeded-source contract is now easier to review because the policy and the big venue payload constants no longer live in the same file

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 174: Markdown parsing model split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownParsing.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownParsingModels.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownParsingSupport.swift`

Changes made in this pass:
- moved markdown block/alignment/item model types out of `LibraryMarkdownParsing.swift`
- moved the array `safe` subscript into `LibraryMarkdownParsingSupport.swift`
- left `LibraryMarkdownParsing.swift` focused on the parser’s state machine

Hidden seam surfaced and reduced:
1. `LibraryMarkdownParsing.swift` was still carrying both the parser logic and its model type bucket
2. the parser file is now easier to scan because the state machine and the block-model definitions no longer compete for the same space

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 175: Library detail video UI split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryDetailVideoSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDetailVideoGridSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryVideoLaunchSupport.swift`

Changes made in this pass:
- left `LibraryDetailVideoSupport.swift` focused on the card-level video selection and routing
- moved the detail video grid/tile leaf views into `LibraryDetailVideoGridSupport.swift`
- moved the launch panel, YouTube metadata fetch, and shared thumbnail view into `LibraryVideoLaunchSupport.swift`

Hidden seam surfaced and reduced:
1. one file was still mixing three distinct layers:
   - the card-level section shell
   - the selectable video grid
   - the full launch/metadata panel
2. the detail video surface is now split so leaf view changes do not have to reopen the card-level selection logic

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 176: Video identity and sorting support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryVideoResolutionSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryVideoIdentitySupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryVideoSortingSupport.swift`

Changes made in this pass:
- moved canonical YouTube/video identity helpers out of `LibraryVideoResolutionSupport.swift`
- moved video provider/kind ordering and natural-label sorting out of `LibraryVideoResolutionSupport.swift`
- left `LibraryVideoResolutionSupport.swift` focused on merge/dedupe entry points

Hidden seams surfaced and fixed:
1. the extracted video identity/sorting helpers were initially too private, which showed that the old single-file layout had been hiding a cross-file ownership dependency
2. the fix was to widen only the shared helper visibility needed by the resolution entry points and the extracted video leaf views, rather than loosening unrelated state or behavior

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 157: LibraryScreen support extraction

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryScreenSupport.swift`

Changes made in this pass:
- moved Library screen shell helpers out of `LibraryScreen.swift` into `LibraryScreenSupport.swift`, including:
  - viewport observation
  - toolbar controls
  - detail destination routing
- left `LibraryScreen.swift` focused on navigation shell, task/onChange wiring, and top-level state ownership

Hidden seam surfaced and reduced:
1. `LibraryScreen.swift` had become a mixed screen shell plus support-file bucket, even though its extracted helpers were already meaningful views in their own right
2. the shell now reads more like app navigation and less like a catch-all for every Library companion view

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 158: RulesheetScreen support extraction

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetScreen.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetScreenSupport.swift`

Changes made in this pass:
- moved the Rulesheet screen surface and status-routing support out of `RulesheetScreen.swift`
- left `RulesheetScreen.swift` focused on the screen’s state, tasks, and interaction handlers

Hidden seam surfaced and reduced:
1. `RulesheetScreen.swift` was mixing screen state ownership with large surface/chrome view definitions
2. splitting those support views out makes the owner file easier to audit for behavior changes without re-reading static surface code

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 159: Library browsing-state support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryViewModel.swift`
- `Pinball App 2/Pinball App 2/library/LibraryViewModelBrowsingSupport.swift`

Changes made in this pass:
- moved computed browsing-state wrappers out of `LibraryViewModel.swift`, including:
  - `browsingState`
  - selected/visible source helpers
  - filtered/sorted/visible game helpers
  - section/grouping helpers
  - sort-menu label formatting
- left `LibraryViewModel.swift` focused on owned state and actual mutation/load work

Hidden seam surfaced and reduced:
1. the view model file was still mixing stored state ownership with a large derived-view facade
2. the browsing-state facade now lives in one dedicated extension, which makes it much easier to trace actual mutation separately from derived presentation state

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 160: Library view-model loading and selection support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryViewModel.swift`
- `Pinball App 2/Pinball App 2/library/LibraryViewModelLoadingSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryViewModelSelectionSupport.swift`

Changes made in this pass:
- moved the view model’s load trigger methods into `LibraryViewModelLoadingSupport.swift`
- moved source-selection, sort-selection, and persisted sort/bank helpers into `LibraryViewModelSelectionSupport.swift`
- kept direct owned-state mutation for:
  - `games`
  - `sources`
  - `errorMessage`
  - `isLoading`
  - `visibleGameLimit`
  in the owner file, instead of widening those setters just to satisfy the split

Compile-only ownership seam surfaced and fixed:
1. the first draft of this split tried to mutate `@Published private(set)` owner state from cross-file extensions
2. rather than loosening those protections, the load-state and visible-limit mutations were moved back to the owner file so the ownership boundary stayed explicit

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 161: Library source-state persistence and mutation support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibrarySourceStateStore.swift`
- `Pinball App 2/Pinball App 2/library/LibrarySourceStatePersistenceSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibrarySourceStateMutationSupport.swift`

Changes made in this pass:
- moved persistence/load/synchronize logic into `LibrarySourceStatePersistenceSupport.swift`
- moved source mutation helpers into `LibrarySourceStateMutationSupport.swift`
- left `LibrarySourceStateStore.swift` focused on the state type, key constants, and normalization/filter helpers

Compile-only seam surfaced and fixed:
1. the extracted persistence helpers needed access to the canonical defaults key and normalization helpers
2. those helpers were widened only to internal module scope so the split could compile without changing behavior

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 162: Native markdown leaf support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownRenderingSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownTextSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMarkdownTableSupport.swift`

Changes made in this pass:
- moved inline markdown text parsing/rendering into `LibraryMarkdownTextSupport.swift`
- moved markdown table rendering into `LibraryMarkdownTableSupport.swift`
- left `LibraryMarkdownRenderingSupport.swift` focused on block-level markdown routing

Hidden seam surfaced and reduced:
1. block rendering had become responsible for both block dispatch and the leaf implementations for inline text and full table presentation
2. the file now reads as a block renderer instead of a full markdown UI stack in one place

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 163: Rulesheet layout and chrome support split

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetScreenSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetLayoutSupport.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetChromeSupport.swift`

Changes made in this pass:
- moved layout/progress persistence helpers into `RulesheetLayoutSupport.swift`
- moved progress pill, top-gradient, and back-button chrome into `RulesheetChromeSupport.swift`
- left `RulesheetScreenSupport.swift` focused on the screen surface and status/content routing

Hidden seam surfaced and reduced:
1. `RulesheetScreenSupport.swift` was still mixing geometry/progress infrastructure with the actual surface tree
2. separating layout and chrome support makes future Rulesheet cleanup less likely to entangle viewport math with ornamental UI

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: `BUILD SUCCEEDED`

## Pass 127: Fix stale GameRoom home-card art after variant changes

Primary files:
- `Pinball App 2/Pinball App 2/library/PlayfieldScreen.swift`

Changes made in this pass:
- tightened the shared `FallbackAsyncImageView` reset rule so it only preserves an already loaded image when the primary candidate URL is unchanged
- kept the existing fallback/retry behavior when the candidate list changes but still starts from the same preferred image

Issue surfaced during manual QA:
1. on iOS only, changing the GameRoom variant for `Godzilla` could leave the GameRoom tab/home card showing Data East `Godzilla` artwork even though:
   - the GameRoom machine detail view showed the correct art
   - the Library entry showed the correct art
2. the shared fallback image view was preserving a previously loaded later-candidate URL across candidate-list changes, even when the new first-choice image had changed after the variant update

Behavioral outcome:
- GameRoom home/tab cards now reload when the primary image candidate changes after a machine edit
- no Android change was needed in this pass because Android was already behaving correctly

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 128: Fresh-install default-source QA

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryImportedSourcesStore.swift`
- `Pinball App 2/Pinball App 2/library/LibrarySourceStateStore.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryImportedSourcesStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySourceStateStore.kt`

QA steps exercised in this pass:
- uninstalled the iOS app from the booted simulator and reinstalled/launched it clean
- uninstalled the Android app from the booted emulator, reinstalled it with `installDebug`, and launched it clean
- inspected the fresh app sandboxes directly:
  - iOS `com.pillyliu.Pinball-App-2.plist`
  - Android `shared_prefs/practice-upgrade-state-v2.xml`
- relaunched both apps once more to verify the default imported-source list was not duplicated on subsequent launches

Verified outcome:
1. both platforms seed exactly 5 default imported Library sources on a clean install:
   - `The Avenue Cafe`
   - `Electric Bat Arcade`
   - `Stern`
   - `Jersey Jack Pinball`
   - `Spooky Pinball`
2. both platforms had no persisted `gameroom-state-json` on the clean pass, so the synthetic `GameRoom` source had no backing data
3. relaunching after the clean install kept the imported-source count at `5` on both platforms, so the default-source seeding did not duplicate itself once sources already existed

Hidden seam surfaced in this pass:
1. fresh launch alone does not yet materialize `pinball-library-source-state-v1` on either platform because the app starts on the `League` tab and Library source-state is still created lazily on first actual Library open
2. that means the clean sandbox inspection fully verified default imported-source seeding and empty-GameRoom behavior, but not the first-Library-open persisted pinned/selected source snapshot

Behavioral outcome:
- no code changed in this pass
- QA confirmed the default imported-source contract is correct on both platforms

## Pass 129: Align imported-source normalization order on Android

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryImportedSourcesStore.kt`

Changes made in this pass:
- brought Android imported-source normalization in line with iOS by normalizing records before save/load/upsert
- Android now sorts imported sources the same way iOS already does:
  - `type`
  - then `name`
  - then `id`
- kept the existing seeded source set the same; this pass only changes the deterministic persisted ordering and normalization path

Why this changed:
1. iOS was already normalizing imported sources to a stable sorted order
2. Android had been preserving insertion order instead, so the same default source set could appear in a different stored/manageable order across platforms

Behavioral outcome:
- both platforms now share the same imported-source ordering rule
- existing Android installs will migrate onto the normalized order the next time the imported-source store is loaded/saved

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 130: Lighten Android overlay variant-badge text on image cards

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppResourceChrome.kt`

Changes made in this pass:
- updated `AppVariantPill` so the `Overlay` style uses a light foreground instead of `brandInk`
- left the non-overlay pill styles unchanged, so this only affects image-backed card/title overlays that use `AppVariantPillStyle.Overlay`

Why this changed:
1. Android Library card badges sit over backglass/playfield art through `AppOverlayTitleWithVariant(...)`
2. the shared overlay pill was still using a dark foreground, which could become unreadable against brighter artwork

Behavioral outcome:
- Android image-card variant badges now use a light foreground for better contrast
- this is an intentional front-facing readability improvement requested during QA

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 131: Android Library screen keeps one live source-state snapshot

Primary files:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryScreen.kt`

Changes made in this pass:
- added a single in-memory `sourceState` snapshot to `LibraryScreen`
- switched pinned-source derivation to use that live snapshot instead of rereading `LibrarySourceStateStore.load(context)` inside `remember(...)`
- updated reload, source-selection, sort-selection, and bank-selection paths so the screen now mirrors persisted writes back into the same in-memory snapshot
- kept the persisted store as the source of truth for reloads, but removed the repeated disk rereads from normal UI callbacks

Hidden seam surfaced and fixed:
1. Android Library browsing was already reloading a synchronized `LibrarySourceState` during `loadLibraryExtraction(context)`, but the screen itself still reread the store directly in several callbacks
2. that meant Library had a split ownership model on Android:
   - one source-state snapshot coming back from extraction
   - separate store reads for pinned-source display and source-change resolution
3. iOS had already converged on a cleaner single-owner pattern in `PinballLibraryViewModel`, so this pass brings Android closer to that lifecycle model without changing visible behavior

Still intentionally unchanged:
1. a bare app launch still does not materialize `pinball-library-source-state-v1` until Library data is actually loaded
2. both platforms already synchronize and persist Library source-state on the first real Library extraction, so the remaining laziness is now an app-startup policy choice rather than a broken Library lifecycle path

Behavioral outcome:
- no intended front-facing behavior changed
- Android Library now keeps one live source-state snapshot while the screen is active instead of mixing that with direct rereads from persistent storage

Verification:
- `./gradlew :app:compileDebugKotlin`
- result: passed

## Pass 132: iOS Library playfield resolution split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryResourceResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryPlayfieldResolutionSupport.swift`

Changes made in this pass:
- moved the full `PinballGame` playfield/artwork resolution layer out of `LibraryResourceResolution.swift` into `LibraryPlayfieldResolutionSupport.swift`
- moved the following playfield-specific pieces together:
  - playfield URL derivation
  - local/hosted OPDB/PinProf candidate assembly
  - playfield button-label resolution
  - live-status-aware playfield option grouping
  - missing-artwork fallback handling
- left `LibraryResourceResolution.swift` focused on the remaining rulesheet/resource responsibilities instead of also carrying the playfield stack

Hidden seam surfaced and reduced:
1. `LibraryResourceResolution.swift` still had a second major responsibility cluster even after the earlier path/rulesheet support split: all playfield candidate building and artwork fallback policy still lived beside rulesheet display filtering
2. that made the file harder to audit because playfield and rulesheet behavior are now separate contracts:
   - playfield resolution depends on local/hosted/OPDB candidate precedence and live cache status
   - rulesheet resolution depends on local markdown presence and external-link filtering
3. those layers now have a cleaner file boundary, so future playfield work can happen without reopening the rulesheet path and vice versa

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 133: iOS catalog variant and preferred-machine policy split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogVariantSupport.swift`

Changes made in this pass:
- moved the catalog variant-label and machine-preference policy out of `LibraryCatalogResolution.swift` into `LibraryCatalogVariantSupport.swift`
- grouped the following variant-specific rules together:
  - normalized variant labels
  - display-title stripping of recognized variant suffixes
  - preferred manufacturer/group machine ordering
  - requested-variant match scoring
  - preferred exact machine selection for a requested variant
- left `LibraryCatalogResolution.swift` focused on turning resolved machine/source inputs into `PinballGame` records and source lookups

Hidden seam surfaced and reduced:
1. `LibraryCatalogResolution.swift` was doing two different jobs:
   - building final Library records for imported sources
   - defining all the heuristics for what counts as a variant and which machine wins when variants compete
2. the variant heuristics are a distinct policy layer that already influences multiple call sites, so isolating them makes future review easier and reduces the risk of mixing “record assembly” edits with “variant matching” edits

Still intentionally unchanged:
1. the actual variant-matching behavior and scoring rules did not change in this pass
2. the remaining visible fallbacks in Library, including `"Unknown Source"`, are still intentional keeps

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 134: LibraryScreen shell and routing cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryScreen.swift`

Changes made in this pass:
- extracted dedicated private subviews for:
  - viewport observation
  - toolbar controls
  - detail-route destination rendering
- moved the detail-screen side effect into a named handler instead of leaving the activity log/update inline in the navigation destination
- left `LibraryScreen` reading more like a shell:
  - screen scaffold
  - search / toolbar
  - load / refresh / deep-link orchestration
  - destination routing

Hidden seam surfaced and reduced:
1. `LibraryScreen.swift` was small enough to read, but it still mixed three different responsibilities directly in the body:
   - viewport geometry tracking
   - toolbar trigger composition
   - detail-route rendering plus side effects
2. those seams now have dedicated private views/handlers, which makes the top-level screen easier to scan without changing its public contract

Build seam surfaced and corrected during this pass:
1. `LibraryScreen` intentionally shares live screen state with companion files like `LibraryListScreen.swift`
2. tightening `viewModel`, `layoutMetrics`, and `cardTransition` to `private` broke that file-level contract
3. the fix was to keep those shared screen properties at the existing file-set visibility, which is now logged as an intentional Library screen organization rule

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 135: RulesheetScreen shell, layout, and progress-storage cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/RulesheetScreen.swift`

Changes made in this pass:
- introduced `RulesheetScreenLayoutMetrics` to own the top-level geometry-derived layout constants:
  - portrait / landscape detection
  - top inset
  - anchor scroll inset
  - fullscreen chrome row height
  - progress-pill padding and trailing inset
- introduced `RulesheetProgressStore` so the screen no longer reaches into `UserDefaults` directly for saved reading progress
- introduced `RulesheetScreenSurface` so the main view now delegates the background/content/chrome shell instead of building that whole stack inline
- moved screen-side actions into named handlers:
  - appear
  - status change
  - resume saved progress
  - progress updates
  - chrome visibility toggle

Hidden seam surfaced and reduced:
1. `RulesheetScreen` was still mixing three layers in its top-level view:
   - geometry-derived layout math
   - screen lifecycle and alert orchestration
   - saved-progress persistence
2. the screen still owns those responsibilities, but they now have explicit helper types and named action methods instead of living inline in the view body

Still intentionally unchanged:
1. the HTML renderer / `WKWebView` coordinator behavior did not change
2. the remaining major hotspot in `RulesheetScreen.swift` is the large embedded `RulesheetRenderer.Coordinator`, which is still a later cleanup target
3. `RulesheetWebViewSupport.swift` already centralizes most shared `WKWebView` setup, so there was no additional safe duplication cleanup needed in this batch

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 126: Restore GameRoom source visibility when rows exist

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryExtractionSupport.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`

Changes made in this pass:
- restored the special-case Library filter behavior that keeps the `GameRoom` source visible whenever payload rows exist for that source, even if it is not part of the persisted enabled-source list
- kept the new synthetic GameRoom contract intact:
  - no source when GameRoom is empty or missing
  - source appears when GameRoom contributes Library rows

Issue surfaced during manual QA:
1. after the synthetic venue-import refactor, the `GameRoom` source could still disappear from Library because it was being filtered out by normal source-state rules before the source-state store had ever enabled it
2. this regression affected the expected UX on both platforms: add a GameRoom machine, but still see no GameRoom source in Library

Behavioral outcome:
- `GameRoom` now appears in Library as soon as it has resolved rows
- `GameRoom` still disappears when it has no Library rows

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 125: GameRoom synthetic venue import contract

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryGameRoomSyntheticImport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDataLoader.swift`
- `Pinball App 2/Pinball App 2/library/LibraryCatalogVenueSupport.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`

Changes made in this pass:
- replaced the old iOS GameRoom -> Library custom row-synthesis path with a synthetic imported venue contract:
  - exact active `opdb_id` list from saved GameRoom state
  - generated venue overlay metadata for `area`, `areaOrder`, `group`, and `position`
  - reuse of the existing venue import resolution path instead of direct `PinballGame` synthesis
- added `LibraryGameRoomSyntheticImport.swift` on iOS to hold that translation layer
- updated iOS Library loading to merge:
  - persisted imported sources
  - optional synthetic GameRoom source
  - hosted venue-layout overlays plus optional GameRoom overlays
- mirrored the same contract on Android by removing the old custom `buildGameRoomOverlay(...)` path and feeding GameRoom into the existing venue import payload builder instead
- removed the Android special-case filter that treated GameRoom as an always-visible source when it had rows; it now follows the same normal source-state filtering path as iOS

Hidden seams surfaced and fixed:
1. GameRoom had been behaving like a private second import pipeline, with its own matching/media/template rules and direct `PinballGame` construction instead of the shared venue import contract
2. that meant GameRoom could drift separately from Pinball Map / venue overlay behavior even though the data shape was conceptually the same
3. the new contract makes GameRoom a synthetic venue import, so Library now resolves it the same way it resolves venue machine lists from other sources

Important contract notes now logged:
1. if GameRoom state is missing, unreadable, or has no active/loaned machines, there is no GameRoom Library source
2. active GameRoom machines without an exact `opdb_id` are skipped and emit a developer log warning instead of falling back to broader identity/template matching
3. duplicate active GameRoom machines with the exact same `opdb_id` now collide under the synthetic venue-overlay model; the current deterministic fallback is first-wins plus a developer log warning
4. no backward-compatibility shim was added for the removed custom GameRoom row builder

Behavioral outcome:
- intended Library behavior now matches the user-approved contract:
  - GameRoom behaves like a venue import built from exact `opdb_id`s plus overlay metadata
  - empty or nonexistent GameRoom state produces no source
- no front-facing copy changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 118: Hosted local rulesheet keep note

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogResolution.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogResolution.kt`

Decision recorded in this pass:
- hosted PinProf local rulesheets on `pillyliu.com` are intentional keep content and should not be revisited for deletion just because other rulesheet providers also exist
- the current value in those hosted local rulesheets is the curated TOC/mobile-formatting work, so they are not treated as redundant with `papa`, `pp`, `bob`, or other external providers
- cleanup/suppression logic should only hide the local rulesheet path when there is a direct Tilt Forums duplicate for the same rulesheet entry

Audit result captured here:
1. the current live/published rulesheet asset set has no direct `provider=tf` duplicates for the same `opdbId` as the hosted local PinProf rulesheet rows
2. `Cactus Canyon Continued` (`G4835`) is the only current local hosted rulesheet that still clearly references Tilt Forums source content, and it is explicitly intentional to keep
3. `G900001` is the PinProf Labs guide and only references Tilt Forums as a house-style note, not as an imported TF rulesheet

Follow-up policy:
1. future cleanup passes should not reopen the hosted local rulesheet set as a generic dedupe/deletion target
2. if a future deletion pass is considered, it should be based on a concrete product/content decision rather than provider overlap alone

## Pass 119: Library media-resolution extraction

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryCatalogResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryMediaResolutionSupport.swift`

Changes made in this pass:
- extracted the iOS Library rulesheet/video merge and sort helpers out of `LibraryCatalogResolution.swift` into the new `LibraryMediaResolutionSupport.swift`
- kept the hosted local-rulesheet intent comment at the actual suppression seam in the extracted support file so future cleanup passes do not reopen that question by accident
- left Android untouched in this pass because this was iOS-only structural cleanup, not a parity or behavior change

Why this split was worth doing:
1. `LibraryCatalogResolution.swift` had drifted into a mixed responsibility file that was assembling records and also owning low-level rulesheet/video merge heuristics
2. the media-resolution helpers now live together as one seam, which makes future cleanup around rulesheet/video behavior easier to audit without dragging the whole catalog resolver with it

Behavioral outcome:
- no intended front-facing behavior changed
- iOS build stayed green after the extraction and the new support file was picked up by the project automatically

Still-open visible seam after this batch:
1. `LibraryGame.swift` still falls back malformed or missing payload source names to `"Unknown Source"`
2. that fallback can become user-visible, so it remains a product-policy change rather than a silent cleanup item

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed

## Pass 120: Intentional keep notes

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryGame.swift`

Decisions recorded in this pass:
- keep the `"Unknown Source"` fallback for malformed legacy/source payloads
- keep the hosted local PinProf rulesheet set as intentional content, not redundancy

Clarifications captured here:
1. the current published rulesheet asset set has `0` direct local-plus-Tilt-Forums duplicate cases for the same `opdbId`
2. current rulesheet counts at this checkpoint:
   - iOS bundled local rulesheet markdown files: `1`
   - Android bundled local rulesheet markdown files: `1`
   - Admin workspace local rulesheet markdown files: `27` plus `.gitkeep`
   - published active local-path rulesheet asset rows: `27`

Behavioral outcome:
- no intended front-facing behavior changed
- these notes are here so future cleanup passes do not reopen either fallback/keep decision by mistake

## Pass 121: Remove dormant TF local-rulesheet suppression

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryMediaResolutionSupport.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogResolution.kt`

Changes made in this pass:
- removed the direct Tilt Forums-based local rulesheet suppression on both platforms
- local rulesheet paths now remain attached whenever a curated/local rulesheet exists
- kept the existing local/PinProf markdown-link dedupe path, so duplicate local-style links still stay out of the external link list

Why this changed:
1. the current published rulesheet asset set has no direct local-plus-TF duplicate rows
2. product policy is now that hosted local rulesheets should remain available and there will no longer be TF markdown files to justify hiding them

Behavioral outcome:
- if a TF external link reappears later for the same game, the hosted local rulesheet will still remain available instead of being suppressed

## Pass 122: GameRoom augmentation row-builder cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryGameRoomAugmentation.swift`

Changes made in this pass:
- extracted the inline GameRoom machine sort into `sortedGameRoomMachines(...)`
- extracted GameRoom-to-Library row assembly into:
  - `buildGameRoomLibraryGame(...)`
  - `resolvedGameRoomPracticeIdentity(...)`
  - `makeGameRoomLibraryRow(...)`
  - `makeGameRoomAssetPayload(...)`
- kept the JSON round-trip decode path the same, but moved the hidden mutation out of the long `compactMap` body

Hidden seam surfaced and reduced:
1. `loadGameRoomLibraryData(...)` was still mixing persisted-state loading, sort policy, template/media matching, row assembly, and decode fallback in one large function
2. the row-builder path is now explicit enough to review without re-reading the whole GameRoom augmentation flow every time

Behavioral outcome:
- no intended front-facing behavior changed
- the emitted Library rows for GameRoom machines still follow the same source/asset/template rules

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- result: passed

## Pass 123: GameRoom matching/media support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryGameRoomAugmentation.swift`
- `Pinball App 2/Pinball App 2/library/LibraryGameRoomMatchingSupport.swift`

Changes made in this pass:
- moved the GameRoom-only OPDB media indexing, media ranking, template matching, and shared identity normalization helpers out of `LibraryGameRoomAugmentation.swift`
- left `LibraryGameRoomAugmentation.swift` focused on:
  - loading persisted GameRoom state
  - sorting active machines
  - building GameRoom-backed Library rows
  - assigning visual/content assets to those rows

Hidden seam surfaced and reduced:
1. `LibraryGameRoomAugmentation.swift` had become a second policy bucket for OPDB identity matching and variant scoring, on top of already assembling the final Library records
2. the match/media rules now live in one dedicated support file, so future parity work can review that policy without re-reading row construction and JSON decode plumbing

Still intentionally unchanged:
1. the GameRoom augmentation path still uses the JSONSerialization -> JSONDecoder round-trip to materialize `PinballGame`
2. that is a stale internal seam worth revisiting later, but changing it now would be a larger behavior-sensitive cleanup than this batch

Behavioral outcome:
- no intended front-facing behavior changed

## Pass 124: Library resource-path and rulesheet support split

Primary files:
- `Pinball App 2/Pinball App 2/library/LibraryResourceResolution.swift`
- `Pinball App 2/Pinball App 2/library/LibraryResourcePathSupport.swift`
- `Pinball App 2/Pinball App 2/library/LibraryRulesheetSupport.swift`

Changes made in this pass:
- moved shared hosted-path and live-playfield-status infrastructure out of `LibraryResourceResolution.swift`:
  - PinProf host constants
  - missing-artwork path
  - hosted/local path normalization
  - shared URL resolution
  - live playfield status fetch/store
- moved rulesheet source classification and markdown-path heuristics out of `LibraryResourceResolution.swift` into `LibraryRulesheetSupport.swift`
- left `LibraryResourceResolution.swift` focused on `PinballGame` resource accessors, candidate assembly, and display filtering

Hidden seam surfaced and reduced:
1. `LibraryResourceResolution.swift` was mixing three layers at once:
   - generic hosted resource path helpers
   - network-backed live playfield status
   - `PinballGame`-specific playfield and rulesheet resolution
2. the file boundary now matches those responsibilities more closely, so future cleanup passes can touch one layer without reopening the other two

Behavioral outcome:
- no intended front-facing behavior changed

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`

## Pass 117: Source-identity name cleanup

Primary files:
- `Pinball App 2/Pinball App 2/library/LibrarySourceIdentity.swift`
- `Pinball App 2/Pinball App 2/library/LibraryImportedSourcesStore.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreDataLoaders.swift`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySourceIdentity.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryImportedSourcesStore.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreDataLoaders.kt`

Changes made in this pass:
- centralized seeded Library source names in the source-identity files on both platforms instead of repeating literal strings in:
  - seeded imported-source defaults
  - legacy Pinball Map migration targets
  - the Practice Avenue venue-layout hydration path
- updated Practice venue-layout hydration to read the Avenue source name from the canonical source-identity constant instead of hardcoding `"The Avenue Cafe"`

Hidden seams surfaced and fixed:
1. Library seeding and Practice venue-layout hydration were sharing source IDs but not sharing source names, so `"The Avenue Cafe"` and the seeded manufacturer names could drift silently across platforms
2. this was not a current user-visible bug, but it was a stale contract because the app now treats imported/default Library sources as canonical source identities rather than one-off literals

Behavioral outcome:
- no intended front-facing behavior changed
- the default-source setup and the Practice Avenue-derived records now share one source-name definition on each platform

Stale-source sweep result after this pass:
1. the remaining `"The Avenue Cafe"` references are intentional:
   - manual About copy
   - seeded source names
   - venue layout asset payload data
2. `LibraryCatalogModels.swift` still decodes `is_builtin` only for payload/schema compatibility
3. `LibraryGame.swift` still falls back to `"Unknown Source"` when incoming payload source naming is malformed or missing

Verification:
- `xcodebuild -project 'Pinball App 2/Pinball App 2.xcodeproj' -scheme 'PinProf' -destination 'generic/platform=iOS Simulator' build`
- `./gradlew :app:compileDebugKotlin`
- result: both passed
