# iOS Code Map

Root app source:
- `Pinball App 2/Pinball App 2/`

The iOS app is organized primarily by feature folders plus shared support.

## App Shell

Folder:
- `Pinball App 2/Pinball App 2/app`

Purpose:
- app startup
- root shell composition
- intro overlay
- shake warning flow
- app-level performance tracing

Key files:
- `Pinball_App_2App.swift`: app entrypoint
- `ContentView.swift`: root app shell
- `AppIntroOverlay.swift`: intro overlay route shell
- `AppShakeCoordinator.swift`: shake-warning route shell
- `PinballPerformanceTrace.swift`: app-level trace hooks

## Shared App Support

Folder:
- `Pinball App 2/Pinball App 2/SharedAppSupport`

Purpose:
- static payloads and app-wide support assets that are not tied to one feature screen

Current example:
- `pinside_group_map.json`: shared Pinside title/group mapping input

## Data

Folder:
- `Pinball App 2/Pinball App 2/data`

Purpose:
- hosted data caching
- preload seeding
- metadata refresh
- CSV/shared data helpers

Key files:
- `PinballDataCache.swift`: runtime cache coordinator
- `PinballDataCacheBootstrapSupport.swift`: cache root, preload, bootstrap logic
- `PinballDataCacheMetadataSupport.swift`: manifest and update-log refresh logic
- `PinballDataCacheStorageSupport.swift`: cache storage models and path helpers
- `SharedCSV.swift`: shared CSV parsing and formatting support

## Library

Folder:
- `Pinball App 2/Pinball App 2/library`

Purpose:
- catalog loading and normalization
- list and detail presentation
- hosted media and rulesheet resolution
- imported source identity and storage

Typical ownership split:
- list and detail screens own presentation
- catalog and loader files own decode and resolution
- resource support files own rulesheets, hosted media, and playfield paths

Key coordinator files:
- `LibraryListScreen.swift`
- `LibraryDetailScreen.swift`
- `LibraryDataLoader.swift`
- `LibraryCatalogResolution.swift`
- `LibraryResourceResolution.swift`
- `LibraryImportedSourcesStore.swift`

## Practice

Folder:
- `Pinball App 2/Pinball App 2/practice`

Purpose:
- practice home and game workspace
- quick entry and group workflows
- journal and IFPA profile flows
- score scanner
- practice persistence and mutation support

Typical ownership split:
- home, game, and group files own route composition
- entry and journal support files own edit flows
- scanner files own camera, OCR, freeze flow, and display state
- store support files own canonical persistence and mutation logic

Key coordinator files:
- `PracticeHomeRootView.swift`
- `PracticeGamePresentationHost.swift`
- `PracticeGroupEditorComponents.swift`
- `PracticeJournalSettingsSections.swift`
- `ScoreScannerView.swift`
- `ScoreScannerViewModel.swift`

## GameRoom

Folder:
- `Pinball App 2/Pinball App 2/gameroom`

Purpose:
- machine collection management
- import and archive workflows
- catalog matching and Pinside integration
- machine detail, media, issue, and service flows

Typical ownership split:
- home, settings, edit, and machine files own route shells
- store and model files own state and persistence
- import and catalog support files own matching and normalization
- media and issue files own focused input and presentation support

Key coordinator files:
- `GameRoomHomeComponents.swift`
- `GameRoomSettingsSupport.swift`
- `GameRoomEditMachinesView.swift`
- `GameRoomMachineView.swift`
- `GameRoomStore.swift`
- `GameRoomCatalogLoader.swift`

## League

Folder:
- `Pinball App 2/Pinball App 2/league`

Purpose:
- league home shell
- preview cards for stats, standings, and targets
- preview parsing and next-bank support

Key files:
- `LeagueScreen.swift`
- `LeagueShellContent.swift`
- `LeaguePreviewLoader.swift`
- `LeaguePreviewParsingSupport.swift`
- `LeagueStandingsPreview.swift`
- `LeagueStatsPreview.swift`
- `LeagueTargetsPreview.swift`

## Settings

Folder:
- `Pinball App 2/Pinball App 2/settings`

Purpose:
- settings home
- hosted data and appearance settings
- manufacturer, venue, and tournament import flows
- third-party client integration

Key files:
- `SettingsScreen.swift`
- `SettingsRouteContent.swift`
- `SettingsHomeSections.swift`
- `SettingsImportScreens.swift`
- `PinballMapClient.swift`
- `MatchPlayClient.swift`

## Stats, Standings, Targets

Folders:
- `Pinball App 2/Pinball App 2/stats`
- `Pinball App 2/Pinball App 2/standings`
- `Pinball App 2/Pinball App 2/targets`

Purpose:
- full-screen league and analytics destinations

Ownership style:
- screen file owns composition
- view model owns state where needed
- models and support files own computation and presentation formatting

Key files:
- `StatsScreen.swift`
- `StandingsScreen.swift`
- `TargetsScreen.swift`

## UI

Folder:
- `Pinball App 2/Pinball App 2/ui`

Purpose:
- shared chrome and design tokens
- filter controls
- table and fullscreen support
- common presentation modifiers and toolbar actions

Key files:
- `AppTheme.swift`: shared iOS theme tokens and appearance defaults
- `AppContentChrome.swift`: shared content chrome
- `AppFilterControls.swift`: shared filter controls
- `AppResourceChrome.swift`: shared resource and media chrome
- `SharedTableUi.swift`: shared table and row UI

## Info

Folder:
- `Pinball App 2/Pinball App 2/info`

Purpose:
- About and app information screens and static assets

Key file:
- `AboutScreen.swift`

## Tests

Folder:
- `Pinball App 2/Pinball App 2Tests`

Purpose:
- service, parsing, and support-level regression coverage for iOS

Current emphasis:
- score scanner services
- shared support behavior where runtime regressions are costly
