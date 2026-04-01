# iOS Code Map

Root app source:
- `Pinball App 2/Pinball App 2/`

This document maps the current iOS codebase by ownership, not just by screen names. It is meant to answer:
- where a feature starts
- where its mutable state lives
- which helper file families are supporting that feature
- which resource and preload folders matter to runtime behavior

## Current Top-Level Inventory

| Folder | Files | What it mainly owns |
| --- | ---: | --- |
| `app/` | `11` | app entrypoint, root tab shell, intro overlay, shake warning, perf trace |
| `data/` | `6` | hosted cache actor, bootstrap, metadata refresh, storage helpers, CSV parsing |
| `library/` | `113` | hosted catalog assembly, browse/detail UI, rulesheets, media, source state |
| `practice/` | `116` | practice state, routes, quick entry, groups, journal, analytics, score scanner |
| `gameroom/` | `99` | owned-machine state, catalog lookup, import, machine routes, media and issues |
| `league/` | `15` | league home shell, preview cards, destination handoff |
| `settings/` | `15` | hosted data refresh, imports, privacy, about |
| `stats/` | `6` | stats destination |
| `standings/` | `5` | standings destination |
| `targets/` | `4` | targets destination |
| `ui/` | `18` | shared chrome, tokens, fullscreen seams, buttons, filters |
| `info/` | `2` | about content and bundled LPL art |

Resource folders that also matter:
- `SharedAppSupport/` -> shared Pinside map, shake-warning art, intro overlay art
- `PinballPreload.bundle/` -> bundled preload manifest and data seed
- `Assets.xcassets/` -> platform asset catalog output
- `Pinball App 2Tests/` -> targeted regression coverage

## Runtime Spine

The main iOS runtime path is:
1. `app/Pinball_App_2App.swift`
   - app entrypoint
   - applies display mode
   - kicks off import migration, redacted-player refresh, CAF warmup, and hosted refresh
2. `app/ContentView.swift`
   - owns the `TabView`
   - holds `AppNavigationModel`
   - overlays intro and shake-warning presentation
3. feature folders
   - `League`, `Library`, `Practice`, `GameRoom`, `Settings`
4. shared seams
   - `data/` for hosted cache
   - `ui/` for shared chrome
   - `SharedAppSupport/` for bundled app-owned assets

## App Shell (`app/`)

Primary responsibility:
- app startup, tab shell composition, intro overlay, shake warning, and performance tracing

Key owners:
- `Pinball_App_2App.swift`
  - `@main` entrypoint
  - launch-time warmup and refresh tasks
- `ContentView.swift`
  - root `TabView`
  - `AppNavigationModel`
  - tab-to-screen mapping
  - intro and shake overlay hosting
- `PinballPerformanceTrace.swift`
  - app-level timing hooks used by bootstrap-heavy surfaces

File families:
- `AppIntro*`
  - intro overlay models, artwork lookup, view helpers, and dismissal flow
- `AppShake*`
  - detected-shake coordination, overlay models, haptics, and view support

When app-shell behavior changes:
- update this section
- update the paired Android root-package section
- update the blueprint if launch flow or root navigation changed

## Shared App Support And Resources

### `SharedAppSupport/`

Purpose:
- bundled support assets owned by the app repo rather than by hosted `/pinball` data

Current contents:
- `pinside_group_map.json`
  - shared title/group mapping used by GameRoom import and title matching
- `shake-warnings/`
  - art consumed by the shake-warning overlay
- `app-intro/`
  - intro overlay images and screenshots that get synced into platform bundles

### `PinballPreload.bundle/`

Purpose:
- preload manifest and bundled seed data used by the cache bootstrap layer

### `Assets.xcassets/`

Purpose:
- final iOS asset-catalog packaging target

## Hosted Data And Cache (`data/`)

Primary responsibility:
- hosted content bootstrap
- stale-cache-first reads
- metadata diff and refresh behavior
- cache storage paths and index records

Key files:
- `PinballDataCache.swift`
  - actor-based cache coordinator
- `PinballDataCacheBootstrapSupport.swift`
  - preload, bootstrap, and cache-root setup
- `PinballDataCacheMetadataSupport.swift`
  - manifest and update-log logic
- `PinballDataCacheRuntimeSupport.swift`
  - runtime fetch, stale fallback, and selective revalidation behavior
- `PinballDataCacheStorageSupport.swift`
  - storage models, file layout, cache index helpers
- `SharedCSV.swift`
  - shared CSV parsing used by league and import flows

Important behavior:
- first paint should prefer cached content when available
- background refresh should revalidate rather than block UI
- missing hosted optional assets should degrade cleanly rather than dead-end the screen

## Library (`library/`)

Primary responsibility:
- assemble the runtime pinball catalog from hosted CAF layers plus imported-source state
- render browse and detail UI
- resolve playfields, rulesheets, videos, and hosted metadata
- persist source selection, activity, and rulesheet progress

Primary route and state owners:
- `LibraryScreen.swift`
  - feature entry shell
- `LibraryListScreen.swift`
  - main catalog browse surface
- `LibraryDetailScreen.swift`
  - game detail route
- `LibraryViewModel.swift`
  - main list state owner
- `LibraryViewModelBrowsingSupport.swift`
- `LibraryViewModelLoadingSupport.swift`
- `LibraryViewModelSelectionSupport.swift`

Hosted data and extraction families:
- `LibraryHostedData.swift`
  - hosted path constants, CAF warmup, refresh notification fan-out
- `LibraryDataLoader.swift`
  - top-level extraction entrypoints
- `LibraryContentLoading.swift`
- `LibraryExtractionSupport.swift`
- `LibraryCAFAssetSupport.swift`
- `LibraryCatalog*`
  - OPDB decode, manufacturer options, source payloads, resolution models, variant labels, venue support
- `LibraryOPDB*`
  - OPDB export and practice-identity helpers

Source and import state families:
- `LibraryImported*`
  - imported source record models, normalization, persistence
- `LibrarySource*`
  - source identity, source-state persistence, state mutation, synchronization
- `LibrarySeededImportedSources.swift`
- `LibrarySeededVenueMachineIDs.swift`
- `LibraryGameRoomSyntheticImport.swift`
  - injects the synthetic GameRoom source into Library/Practice browsing
- `LibraryVenueMetadataOverlay*`
  - venue layout overlays layered on top of hosted metadata

Browse and detail UI families:
- `LibraryGame*`
  - domain models, lookup, decoding, cards, presentation helpers, grid behaviors
- `LibraryDetail*`
  - detail layout, resource rows, video grids, media panels
- `LibraryGridSupport.swift`
- `LibraryFilterMenuSupport.swift`
- `LibrarySearchSupport.swift`
- `LibrarySelectionSupport.swift`
- `LibraryScreenSupport.swift`

Media and resource resolution families:
- `LibraryMediaResolutionSupport.swift`
- `LibraryResourcePathSupport.swift`
- `LibraryResourceResolution.swift`
- `LibraryRulesheetSupport.swift`
- `LibraryPlayfield*`
- `LibraryVideo*`
- `HostedImage*`
- `RemoteImageViews.swift`
- `RemoteUIImageSupport.swift`

Rulesheet rendering families:
- `LibraryMarkdown*`
  - markdown parsing, HTML cleanup, table parsing, inline image handling, text rendering support
- `Rulesheet*`
  - screen, models, local and remote load, HTML support, viewport restore, renderer bridge, fallback web path
- `RulesheetWebBridge.js`
  - WebKit bridge for viewport and renderer support
- `TiltForumsRulesheetSupport.swift`

Other supporting files:
- `LibraryActivityLog.swift`
  - cross-feature activity tracking used by Library and Practice
- `LibraryBrowsingState*`
  - browse filtering and selected-source logic

## Practice (`practice/`)

Primary responsibility:
- local-first practice state
- home, game workspace, quick entry, journal, groups, insights, mechanics, settings
- league-derived imports and targets
- score scanner camera and OCR pipeline

Primary route owners:
- `PracticeScreen.swift`
  - feature entry
- `PracticeScreenRouteContent.swift`
  - route composition
- `PracticeScreenState.swift`
- `PracticeScreenActions.swift`
- `PracticeScreenContexts.swift`
- `PracticeScreenDerivedData.swift`
- `PracticeDialogHost.swift`

State and persistence owners:
- `PracticeStore.swift`
  - central mutable state owner
- `PracticeStoreAnalytics.swift`
- `PracticeStoreDataLoaders.swift`
- `PracticeStoreEntryLoggingSupport.swift`
- `PracticeStoreEntrySettingsSupport.swift`
- `PracticeStoreGroupHelpers.swift`
- `PracticeStoreJournal*`
- `PracticeStoreLeague*`
- `PracticeStoreMechanicsHelpers.swift`
- `PracticeStorePersistence.swift`
- `PracticeStoreStudyEntrySupport.swift`
- `PracticeStateCodec.swift`
- `PracticeModels.swift`
- `PracticeTypes.swift`
- `PracticeIdentityKeying.swift`

Home and lifecycle families:
- `PracticeHome*`
  - home root, host, widgets, bootstrap snapshot, resume state
- `PracticeLifecycle*`
  - higher-level route lifecycle coordination
- `PracticePresentation*`
  - presentation host/context shared by nested practice routes

Game workspace families:
- `PracticeGame*`
  - workspace context, route body, section switching, summary cards, toolbar, workspace subviews, search sheet
- `GameNoteEntrySheet.swift`
- `GameScoreEntrySheet.swift`
- `GameTaskEntrySheet.swift`
- `PracticeEntryFieldSupport.swift`
- `PracticeEntryGlassStyle.swift`

Quick entry, video, and formatting families:
- `PracticeQuickEntry*`
  - mode fields, save logic, sheet presentation
- `PracticeVideo*`
  - shared video logging and UI components
- `PracticeScoreFormatting.swift`
- `PracticeTimePopoverField.swift`
- `PracticeDisplayTitles.swift`
- `PracticeCatalogSearchSupport.swift`

Groups, journal, insights, mechanics, and settings families:
- `PracticeGroup*`
  - group dashboard, editor, action support, title selection, ordering
- `PracticeJournal*`
  - journal route context, edit sheet, list rows, settings sections, summary styling
- `PracticeInsights*`
- `PracticeMechanics*`
- `PracticeSettings*`

League and library integration families:
- `PracticeLeague*`
  - CSV import, name matching, machine resolution, remote load, repair support
- `ResolvedLeagueMachineMappings.swift`
- `ResolvedLeagueTargets.swift`

Score scanner families:
- `CameraPreviewView.swift`
- `ScoreConfirmationSheet.swift`
- `ScoreOCRService.swift`
- `ScoreParsingService.swift`
- `ScoreParsingOCRNormalizationSupport.swift`
- `ScoreScanner*`
  - camera lifecycle, freeze flow, image conversion, display state, live processing, session, view-model, reading support
- `ScoreStabilityService.swift`

## GameRoom (`gameroom/`)

Primary responsibility:
- owned-machine persistence and derived snapshots
- add-machine and edit-machine flows
- Pinside import and matching
- machine route, media, issue, maintenance, service, archive, and reminder flows

Primary route and state owners:
- `GameRoomScreen.swift`
  - feature entry route
- `GameRoomHomeComponents.swift`
  - home composition
- `GameRoomMachineView.swift`
  - machine detail route
- `GameRoomEditMachinesView.swift`
  - edit/settings route
- `GameRoomStore.swift`
  - central mutable state owner
- `GameRoomStateCodec.swift`
  - persistence codec

Persistence and domain-model families:
- `GameRoomPersistenceModels.swift`
- `GameRoomInventoryModels.swift`
- `GameRoomEnumModels.swift`
- `GameRoomEventRecord.swift`
- `GameRoomIssueRecord.swift`
- `GameRoomSnapshotRecord.swift`
- `GameRoomAttachmentRecord.swift`
- `GameRoomStoreInventorySupport.swift`
- `GameRoomStoreRecordSupport.swift`
- `GameRoomStoreSnapshotSupport.swift`
- `GameRoomStoreImportSupport.swift`

Catalog and add-machine families:
- `GameRoomCatalog*`
  - hosted catalog load, search, slug support, variant labels, machine resolution, art candidates
- `GameRoomAddMachine*`
  - add flow search, filters, result and selection support
- `GameRoomVariantPresentationSupport.swift`

Route, machine, and settings presentation families:
- `GameRoomMachine*`
  - machine route support, summary support, log support, input panels, editor fields, presentation support
- `GameRoomEditMachine*`
  - edit shell, panels, panel stack, selection state, actions
- `GameRoomSettingsComponents.swift`
- `GameRoomArchiveSettingsView.swift`
- `GameRoomPresentationComponents.swift`
- `GameRoomSheetChromeSupport.swift`
- `GameRoomAdaptivePopoverSupport.swift`
- `GameRoomCollection*`
- `GameRoomSelectedSummarySupport.swift`
- `GameRoomHomeCollectionSupport.swift`
- `GameRoomHomeSelectionSupport.swift`

Import and external-source families:
- `GameRoomPinside*`
  - page parsing, document support, service integration, import models, title normalization
- `GameRoomImport*`
  - date parsing, matching, scoring, review models, review rows, settings
- `GameRoomTextNormalizationSupport.swift`
- `GameRoomDecodingSupport.swift`

Issue, event, media, and reminder families:
- `GameRoomIssue*`
  - issue entry, attachments, logging state, subsystem, resolution
- `GameRoomEventEditSupport.swift`
- `GameRoomOwnershipEventEntrySupport.swift`
- `GameRoomServiceEventEntrySupport.swift`
- `GameRoomMachineOwnershipMediaInputSupport.swift`
- `GameRoomMachineMaintenanceInputSupport.swift`
- `GameRoomMachineIssueInputSupport.swift`
- `GameRoomMedia*`
  - entry forms, picker import, thumbnail generation, import status, media presentation
- `GameRoomReminderConfig.swift`
- `GameRoomReminderSnapshotSupport.swift`
- `GameRoomSaveFeedbackOverlaySupport.swift`

## League (`league/`)

Primary responsibility:
- league home shell, rotating previews, and destination handoff into stats, standings, and targets

Key files:
- `LeagueScreen.swift`
- `LeagueShellContent.swift`
- `LeagueDestinationView.swift`
- `LeaguePreviewModel.swift`
- `LeaguePreviewLoader.swift`
- `LeaguePreviewParsingSupport.swift`
- `LeaguePreviewRotationState.swift`
- `LeagueCardPreviews.swift`
- `LeagueStatsPreview*`
- `LeagueStandingsPreview*`
- `LeagueTargetsPreview.swift`
- `LeagueNextBankSupport.swift`
- `LeagueTypes.swift`

## Settings (`settings/`)

Primary responsibility:
- hosted data refresh
- imported-source management
- manufacturer, venue, and tournament imports
- appearance, privacy, and about/support sections

Key route files:
- `SettingsScreen.swift`
- `SettingsRouteContent.swift`
- `SettingsHomeSections.swift`

Supporting families:
- `SettingsHomeHostedDataSupport.swift`
- `SettingsHomeLibrarySupport.swift`
- `SettingsHomeAppearanceSupport.swift`
- `SettingsHomePrivacyAboutSupport.swift`
- `SettingsImportScreens.swift`
- `SettingsImportSharedViews.swift`
- `SettingsManufacturerSupport.swift`
- `SettingsVenueImportSupport.swift`
- `SettingsTournamentImportSupport.swift`
- `SettingsDataIntegration.swift`
- `PinballMapClient.swift`
- `MatchPlayClient.swift`

## Stats, Standings, Targets

These are smaller destination folders but still first-class feature surfaces.

### `stats/`
- `StatsScreen.swift`
- `StatsViewModel.swift`
- `StatsDataSupport.swift`
- `StatsFormattingSupport.swift`
- `StatsModels.swift`
- `StatsViewSupport.swift`

### `standings/`
- `StandingsScreen.swift`
- `StandingsViewModel.swift`
- `StandingsDataSupport.swift`
- `StandingsModels.swift`
- `StandingsViewSupport.swift`

### `targets/`
- `TargetsScreen.swift`
- `TargetsViewModel.swift`
- `TargetsModels.swift`
- `TargetsViewSupport.swift`

## Shared UI (`ui/`)

Primary responsibility:
- shared theme tokens and reusable chrome that keeps feature surfaces visually aligned

Important files:
- `AppTheme.swift`
  - shared color, typography, and appearance defaults
- `AppLayoutTokens.swift`
  - spacing and layout constants
- `AppContentChrome.swift`
- `AppPresentationChrome.swift`
- `SharedFullscreenChrome.swift`
- `AppResourceChrome.swift`
- `AppResourcePillChrome.swift`
- `AppStatusPillChrome.swift`
- `AppFilterControls.swift`
- `AppButtonStyles.swift`
- `AppToolbarActions.swift`
- `AppTableChrome.swift`
- `SharedTableUi.swift`
- `SharedGestures.swift`
- `AppSurfaceModifiers.swift`
- `AppInlineTitleChrome.swift`
- `AppInfoChrome.swift`
- `AppDisplayMode.swift`

## Info (`info/`)

Primary responsibility:
- about experience and bundled info-specific assets

Current contents:
- `AboutScreen.swift`
- `LPLLogo.webp`

## Tests (`Pinball App 2Tests/`)

Current focused regression coverage:
- `AppShakeCoordinatorTests.swift`
- `GameRoomPinsideImportTests.swift`
- `LeaguePreviewParsingTests.swift`
- `LibraryImportedSourcesStoreTests.swift`
- `LibrarySourceIdentityTests.swift`
- `PracticeQuickEntryDefaultsTests.swift`
- `PracticeStateCodecTests.swift`
- `RulesheetLinkResolutionTests.swift`
- `ScoreScannerServicesTests.swift`

What these tests mainly protect:
- persisted-state compatibility
- library source identity and import behavior
- rulesheet resolution behavior
- league preview parsing
- GameRoom Pinside import behavior
- shake-warning and scanner service regressions
