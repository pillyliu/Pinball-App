# Android Code Map

Root app source:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid`

The Android app mirrors the major feature lanes from iOS, with Android-specific app shell and Compose support files at the package root.

## App Shell

Package root files:
- `MainActivity.kt`: Android activity entrypoint
- `PinProfApplication.kt`: application-level startup
- `PinballShell.kt`: top-level app shell and route composition
- `AppIntroOverlay.kt`: intro overlay route shell
- `AppShakeWarning.kt`: shake warning route shell
- `PinballEdgeToEdge.kt`: edge-to-edge helpers
- `PinballPerformanceTrace.kt`: app-level performance trace hooks

Purpose:
- startup
- root navigation and shell composition
- intro and shake-warning overlays
- activity/application integration

## Data

Folder:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/data`

Purpose:
- hosted data caching
- preload seeding
- metadata refresh
- shared CSV and network helpers

Key files:
- `PinballDataCache.kt`: runtime cache coordinator
- `PinballDataCacheBootstrapSupport.kt`: cache root, preload, and bootstrap logic
- `PinballDataCacheMetadataSupport.kt`: manifest and update-log refresh logic
- `PinballDataCacheRuntimeSupport.kt`: runtime fetch, stale fallback, and background revalidate support
- `PinballDataCacheStorageSupport.kt`: cache storage and file/index helpers
- `Csv.kt`: shared CSV support
- `Net.kt`: shared network utilities

## Library

Folder:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library`

Purpose:
- catalog loading and normalization
- list and detail presentation
- hosted media and rulesheet resolution
- imported source identity and storage

Key coordinator files:
- `LibraryListScreen.kt`
- `LibraryDetailScreen.kt`
- `LibraryDataLoader.kt`
- `LibraryCatalogResolution.kt`
- `LibraryResourceResolution.kt`
- `LibraryImportedSourcesStore.kt`

## Practice

Folder:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice`

Purpose:
- practice home and game workspace
- quick entry and group workflows
- canonical persistence and store support
- IFPA profile
- score scanner dialog and controller

Typical ownership split:
- screen and route files own composition
- store and persistence files own state and canonical storage
- scanner files own camera, preview, analysis, and OCR flows

Key coordinator files:
- `PracticeHomeComponents.kt`
- `PracticeGameRouteContext.kt`
- `PracticeGroupEditorScreens.kt`
- `PracticeStore.kt`
- `ScoreScannerDialog.kt`
- `ScoreScannerController.kt`

## GameRoom

Folder:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom`

Purpose:
- machine collection management
- import and archive workflows
- catalog matching and Pinside integration
- machine detail, media, issue, and maintenance flows

Key coordinator files:
- `GameRoomScreen.kt`
- `GameRoomRouteContent.kt`
- `GameRoomStore.kt`
- `GameRoomCatalogLoader.kt`
- `GameRoomPinsideImport.kt`
- `GameRoomPresentationHost.kt`

## League

Folder:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league`

Purpose:
- league home shell
- mini previews for stats, standings, and targets
- preview parsing and next-bank support

Key files:
- `LeagueScreen.kt`
- `LeagueShellContent.kt`
- `LeaguePreviewLoader.kt`
- `LeaguePreviewParsingSupport.kt`
- `LeagueStandingsMiniPreview.kt`
- `LeagueStatsMiniPreview.kt`
- `LeagueTargetsMiniPreview.kt`

## Settings

Folder:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings`

Purpose:
- settings home
- hosted data and appearance settings
- manufacturer, venue, and tournament import flows
- third-party client integration

Key files:
- `SettingsScreen.kt`
- `SettingsHomeSections.kt`
- `SettingsImportScreens.kt`
- `PinballMapClient.kt`
- `MatchPlayClient.kt`

## Stats, Standings, Targets

Folders:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/stats`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/standings`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/targets`

Purpose:
- full-screen league and analytics destinations

Ownership style:
- screen file owns composition
- support and model files own computation and presentation formatting

Key files:
- `StatsScreen.kt`
- `StandingsScreen.kt`
- `TargetsScreen.kt`

## UI

Folder:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui`

Purpose:
- shared Compose chrome and design tokens
- filter sheets and bars
- dialogs, surfaces, pills, action chrome, and fullscreen support

Key files:
- `PinballTheme.kt`: shared Compose theme
- `PinballDesignTokens.kt`: shared design tokens
- `AppContentChrome.kt`: shared content chrome
- `AppScreenSurface.kt`: screen surface and layout shell
- `AppResourceChrome.kt`: shared resource and media chrome
- `CommonUi.kt`: remaining shared card and row UI

## Info

Folder:
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/info`

Purpose:
- About and app information screens

Key file:
- `AboutScreen.kt`
