# Android Code Map

Root app source:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/`

This document maps the current Android codebase by package ownership and file families. It is meant to clarify:
- where each route starts
- where mutable state lives
- which helper files are doing platform or domain support work
- how Android lines up with the paired iOS implementation

## Current Top-Level Inventory

| Package or folder | Files | What it mainly owns |
| --- | ---: | --- |
| package root | `13` | activity entrypoint, app shell, intro overlay, shake warning, edge-to-edge, perf trace |
| `data/` | `10` | hosted cache object, bootstrap, metadata refresh, CSV/network helpers, app display prefs |
| `library/` | `72` | hosted catalog assembly, browse/detail routes, rulesheets, media, source state |
| `practice/` | `127` | practice routes, store, canonical persistence, groups, journal, analytics, score scanner |
| `gameroom/` | `53` | owned-machine state, route content, machine flows, Pinside import, media, issue and settings support |
| `league/` | `16` | league shell, preview cards, destination host |
| `settings/` | `15` | hosted data refresh, imports, privacy, about |
| `stats/` | `5` | stats destination |
| `standings/` | `4` | standings destination |
| `targets/` | `4` | targets destination |
| `ui/` | `20` | shared Compose chrome, tokens, dialogs, bars, fullscreen seams |
| `info/` | `1` | about screen |

Runtime asset folders that also matter:
- `app/src/main/assets/pinprof-preload/` -> Android preload assets
- shared source art and mapping inputs originate in `../Pinball App 2/Pinball App 2/SharedAppSupport/`

## Runtime Spine

The main Android runtime path is:
1. `MainActivity.kt`
   - installs splash screen
   - initializes `PinballDataCache`
   - applies edge-to-edge behavior
   - runs migration, redacted-player refresh, CAF warmup, and hosted refresh
2. `PinballShell.kt`
   - owns selected tab state
   - hosts intro and shake-warning overlays
   - wires up `PracticeStore`, `GameRoomStore`, and `GameRoomCatalogLoader`
3. feature packages
   - `league`, `library`, `practice`, `gameroom`, `settings`
4. shared seams
   - `data/` for hosted cache
   - `ui/` for reusable Compose chrome

## App Shell (package root)

Primary responsibility:
- application startup, tab shell composition, root overlays, and top-level platform wiring

Key owners:
- `MainActivity.kt`
  - activity entrypoint and launch-time warmup
- `PinProfApplication.kt`
  - application-level setup home
- `PinballShell.kt`
  - root tab shell and tab-to-route wiring
- `PinballEdgeToEdge.kt`
  - edge-to-edge helpers
- `PinballPerformanceTrace.kt`
  - app-level trace hooks

File families:
- `AppIntro*`
  - intro overlay models, artwork access, view support, and completion flow
- `AppShake*`
  - motion detection, warning models, overlay support, and haptics

## Hosted Data And Cache (`data/`)

Primary responsibility:
- hosted content bootstrap
- stale-cache-first reads
- metadata refresh
- shared parsing and lightweight app-level preferences

Key files:
- `PinballDataCache.kt`
  - global cache object
- `PinballDataCacheBootstrapSupport.kt`
  - preload and cache bootstrap
- `PinballDataCacheMetadataSupport.kt`
  - manifest and update-log behavior
- `PinballDataCacheRuntimeSupport.kt`
  - runtime fetch, stale fallback, refresh coordination
- `PinballDataCacheStorageSupport.kt`
  - cache index and storage helpers
- `Csv.kt`
  - CSV parsing helpers
- `Net.kt`
  - shared network helpers
- `AppDisplayMode.kt`
  - display-mode preference helpers
- `AppIntroOverlayPrefs.kt`
  - intro overlay preference storage
- `LplNamePrivacy.kt`
  - player-name privacy helpers

## Library (`library/`)

Primary responsibility:
- assemble the runtime catalog from hosted CAF layers and imported-source state
- render list and detail routes
- resolve rulesheets, playfields, videos, and source metadata
- persist source state and activity

Primary route owners:
- `LibraryScreen.kt`
  - feature entry
- `LibraryRouteContent.kt`
  - route-level composition
- `LibraryRoutes.kt`
  - route definitions
- `LibraryListScreen.kt`
  - catalog browse screen
- `LibraryDetailScreen.kt`
  - detail route
- `LibraryScreenStateSupport.kt`
  - route-local state helpers

Hosted data and extraction families:
- `LibraryHostedData.kt`
  - hosted path constants, warmup, refresh fan-out, top-level extraction bootstrap
- `LibraryDataLoader.kt`
  - extraction entrypoints and payload filtering
- `LibraryCAFAssetSupport.kt`
- `LibraryCatalog*`
  - catalog models, manufacturer support, resolution, variant labels, source-aware payload assembly
- `LibraryOPDB*`
  - OPDB decode and practice-identity helpers
- `LibraryDomain.kt`
  - shared domain shapes

Source and import state families:
- `LibraryImported*`
  - imported source models and normalization
- `LibrarySource*`
  - source identity, source-state persistence, synchronized store behavior
- `LibrarySeededImportedSources.kt`
- `LibraryGameRoomSyntheticImportSupport.kt`
  - injects synthetic GameRoom content into the Library source universe
- `LibraryVenueMetadataOverlaySupport.kt`

Browse and detail UI families:
- `LibraryList*`
  - list content and grid rendering support
- `LibraryDetail*`
  - detail layout, media panels, game-info support, video support
- `LibrarySelectionSupport.kt`
- `LibrarySearchSupport.kt`
- `LibraryFilterSheetSupport.kt`
- `LibraryRouteMissingSupport.kt`
- `LibraryGamePresentationSupport.kt`

Media and resource resolution families:
- `LibraryGameLookup.kt`
- `LibraryResourcePathSupport.kt`
- `LibraryResourceResolution.kt`
- `LibraryRulesheetSupport.kt`
- `LibraryRulesheetLinkResolutionSupport.kt`
- `LibraryPlayfield*`
- `LibraryVideoResolutionSupport.kt`
- `LibraryYouTubeSupport.kt`
- `HostedImage*`
- `PlayfieldScreen.kt`
- `RemoteImageSupport.kt`

Rulesheet rendering families:
- `LibraryMarkdown.kt`
- `Rulesheet*`
  - screen, support, remote loader, HTML template and style helpers, external-web fallback
- `TiltForumsRulesheetSupport.kt`

Other support files:
- `LibraryActivityLog.kt`
  - shared Library and Practice activity logging
- `LibraryBrowsingState.kt`
  - filter and selected-source browse state

## Practice (`practice/`)

Primary responsibility:
- local-first practice state and canonical persistence
- home, game workspace, quick entry, groups, journal, insights, mechanics, settings
- library and league integration
- score scanner camera/OCR pipeline

Primary route owners:
- `PracticeScreen.kt`
  - feature entry
- `PracticeScreenRouteContent.kt`
  - route composition
- `PracticeScreenState.kt`
- `PracticeScreenActions.kt`
- `PracticePresentationContext.kt`
- `PracticeDialogHost.kt`
- `PracticeSheets.kt`
- `PracticeMenuComponents.kt`

State and persistence owners:
- `PracticeStore.kt`
  - central mutable state owner
- `PracticeStoreAnalytics.kt`
- `PracticeStoreBootstrapSupport.kt`
- `PracticeStoreDataLoaders.kt`
- `PracticeStoreEntry*`
- `PracticeStoreGameStateHelpers.kt`
- `PracticeStoreGroupHelpers.kt`
- `PracticeStoreJournalHelpers.kt`
- `PracticeStoreLeague*`
- `PracticeStoreLibraryStateSupport.kt`
- `PracticeStoreLoad*`
- `PracticeStoreMechanicsHelpers.kt`
- `PracticeStorePersistedStateSupport.kt`
- `PracticeStorePersistence.kt`
- `PracticeStorePreferenceHelpers.kt`
- `PracticeStoreReference*`
- `PracticeStoreRuntimeSupport.kt`
- `PracticeStoreStateAssembly.kt`

Canonical persistence family:
- `PracticeCanonicalPersistence*`
  - codec, ids, legacy migration, models, runtime parsing

Home and lifecycle families:
- `PracticeHome*`
  - home route context, section content, bootstrap snapshot, dashboard composition
- `PracticeLifecycle*`
  - higher-level route lifecycle coordination
- `PracticePersistenceIntegration.kt`
  - persistence bridge

Game workspace families:
- `PracticeGame*`
  - route context, detail cards, dialogs, entry sheets, search sheet, workspace panels, section state
- `PracticeTopBar*`
  - top bar and game picker support
- `PracticeDisplayTitles.kt`
- `PracticeCatalogSearchSupport.kt`
- `PracticeDatePickerUtils.kt`

Quick entry, video, and formatting families:
- `PracticeQuickEntry*`
  - mode fields, save logic, selection support, sheet UI
- `PracticeVideoComponents.kt`
- `PracticeScoreFormatting.kt`
- `PracticeUtils.kt`

Groups, journal, insights, mechanics, and settings families:
- `PracticeGroup*`
  - dashboard, editor logic, editor screens, sheets, game selection
- `SelectedCardsReorderStrip.kt`
- `PracticeJournal*`
  - route context, rows, edit dialog, editing integration, summary styling
- `PracticeInsights*`
- `PracticeHeadToHeadComponents.kt`
- `PracticeMechanics*`
- `PracticeSettings*`

League and library integration families:
- `PracticeLeagueIntegration.kt`
- `PracticeLeagueTimestampNormalization.kt`
- `PracticeLibraryIntegration.kt`
- `PracticeLibrarySourceSelection.kt`
- `ResolvedLeagueMachineMappings.kt`
- `ResolvedLeagueTargets.kt`

IFPA and identity families:
- `PracticeIdentityKeying.kt`
- `PracticeIfpaProfile*`

Score scanner families:
- `ScoreScanner*`
  - controller, dialog, dialog support, analyzer state, camera binding, frame analysis, preview, OCR, parsing, stability, reading support

Other shared domain files:
- `PracticeModels.kt`
- `PracticeEnums.kt`
- `PracticeKeys.kt`
- `PracticeCurrentGroupsCard.kt`
- `PracticeDashboardComponents.kt`
- `PracticeSelectedGroupDashboardCard.kt`
- `PracticeSparklineComponents.kt`

## GameRoom (`gameroom/`)

Primary responsibility:
- owned-machine persistence and snapshots
- GameRoom route content and machine routes
- add-machine search
- Pinside import
- issue, maintenance, media, and settings presentation

Primary route and state owners:
- `GameRoomScreen.kt`
  - feature entry
- `GameRoomRouteContent.kt`
  - route composition
- `GameRoomMachineRoute.kt`
  - machine detail route
- `GameRoomPresentationHost.kt`
  - sheet and presentation orchestration
- `GameRoomStore.kt`
  - central mutable state owner
- `GameRoomStateCodec.kt`
  - persistence codec

Persistence and domain-model families:
- `GameRoomRecordModels.kt`
- `GameRoomInventoryModels.kt`
- `GameRoomEnumModels.kt`
- `GameRoomStoreInventorySupport.kt`
- `GameRoomStoreRecordSupport.kt`
- `GameRoomStoreSnapshotSupport.kt`

Catalog and add-machine families:
- `GameRoomCatalog*`
  - hosted catalog load, indexing, matching, variant support, machine resolution, art support, search support
- `GameRoomAddMachineSettingsSupport.kt`

Route, screen, and settings presentation families:
- `GameRoomScreen*`
  - screen models, state support, action support, media support, route bridge support, selection support, settings-route support
- `GameRoomPresentation*`
  - reusable presentation host, components, sheet support
- `GameRoomUi*`
  - UI components and formatting
- `GameRoomSettingsSections.kt`
- `GameRoomEditMachinesSettingsSupport.kt`
- `GameRoomEditSettingsPanels.kt`

Import and external-source families:
- `GameRoomPinside*`
  - import flow, parsing, network, title support, slug support, URL support
- `GameRoomImport*`
  - review support and helper logic

Input families:
- `GameRoomInputSheet*`
- `GameRoomIssueInputSheetFormSupport.kt`
- `GameRoomMachineEventInputSheetFormSupport.kt`
- `GameRoomMaintenanceInputSheetFormSupport.kt`
- `GameRoomMediaPresentationSupport.kt`

Variant and route support:
- `GameRoomVariantPresentationSupport.kt`

## League (`league/`)

Primary responsibility:
- league shell, rotating previews, and destination handoff into stats, standings, and targets

Key files:
- `LeagueScreen.kt`
- `LeagueShellContent.kt`
- `LeagueDestinationHost.kt`
- `LeaguePreviewLoader.kt`
- `LeaguePreviewModels.kt`
- `LeaguePreviewParsingSupport.kt`
- `LeaguePreviewRotationState.kt`
- `LeaguePreviewCards.kt`
- `LeaguePreviewFormattingSupport.kt`
- `LeagueShellCardSupport.kt`
- `LeagueStatsMiniPreview.kt`
- `LeagueStatsPreviewSupport.kt`
- `LeagueStandingsMiniPreview.kt`
- `LeagueStandingsPreviewSupport.kt`
- `LeagueTargetsMiniPreview.kt`
- `LeagueNextBankSupport.kt`

## Settings (`settings/`)

Primary responsibility:
- hosted data refresh
- manufacturer, venue, and tournament imports
- privacy, appearance, and about sections

Key route files:
- `SettingsScreen.kt`
- `SettingsHomeSections.kt`
- `SettingsScreenState.kt`

Supporting families:
- `SettingsHomeHostedDataSupport.kt`
- `SettingsHomeLibrarySupport.kt`
- `SettingsHomeAppearanceSupport.kt`
- `SettingsHomePrivacyAboutSupport.kt`
- `SettingsImportScreens.kt`
- `SettingsImportHtmlSupport.kt`
- `SettingsManufacturerSupport.kt`
- `SettingsVenueImportSupport.kt`
- `SettingsTournamentImportSupport.kt`
- `SettingsDataIntegration.kt`
- `PinballMapClient.kt`
- `MatchPlayClient.kt`

## Stats, Standings, Targets

### `stats/`
- `StatsScreen.kt`
- `StatsScreenSupport.kt`
- `StatsDataSupport.kt`
- `StatsComputationSupport.kt`
- `StatsModels.kt`

### `standings/`
- `StandingsScreen.kt`
- `StandingsDataSupport.kt`
- `StandingsModels.kt`
- `StandingsViewSupport.kt`

### `targets/`
- `TargetsScreen.kt`
- `TargetsDataSupport.kt`
- `TargetsModels.kt`
- `TargetsViewSupport.kt`

## Shared UI (`ui/`)

Primary responsibility:
- reusable Compose chrome that keeps the app visually and behaviorally aligned across features

Important files:
- `PinballTheme.kt`
- `PinballDesignTokens.kt`
- `AppContentChrome.kt`
- `AppScreenSurface.kt`
- `AppSurfaceChrome.kt`
- `SharedFullscreenChrome.kt`
- `AppResourceChrome.kt`
- `AppResourcePillSupport.kt`
- `AppStatusPillSupport.kt`
- `AppButtonChrome.kt`
- `AppDialogs.kt`
- `AppFilterSheet.kt`
- `AppSearchFilterBar.kt`
- `AppSelectionChrome.kt`
- `AppInlineActionChrome.kt`
- `AppInlinePillTextSupport.kt`
- `AppInfoChrome.kt`
- `AppToggleControls.kt`
- `CommonUi.kt`
- `SharedComponents.kt`

## Info (`info/`)

Primary responsibility:
- about content

Current contents:
- `AboutScreen.kt`

## Tests (`app/src/test/`)

Current focused regression coverage:
- `AppShakeCoordinatorTest.kt`
- `gameroom/GameRoomCatalogMatchingTest.kt`
- `gameroom/GameRoomPinsideImportTest.kt`
- `league/LeaguePreviewParsingTest.kt`
- `library/LibraryCatalogResolutionParityTest.kt`
- `library/LibraryDataLoaderParityTest.kt`
- `library/LibraryImportedSourcesStoreTest.kt`
- `library/LibraryRulesheetResolutionTest.kt`
- `library/LibrarySourceIdentityTest.kt`
- `library/SearchMatchingTest.kt`
- `practice/PracticeCanonicalPersistenceTest.kt`
- `practice/PracticeLeagueImportTest.kt`
- `practice/PracticeQuickEntryDefaultsTest.kt`
- `practice/ScoreScannerServicesTest.kt`
- `settings/SettingsImportScreensTest.kt`

Resource fixtures:
- `app/src/test/resources/practice/canonical_state_v4.json`
- `app/src/test/resources/practice/legacy_state_v1.json`
