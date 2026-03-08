# Library Ledger

## 2026-03-06

- Library is now a shared integration point for GameRoom overlay behavior on both platforms.

## 2026-03-07

- Locked the starter-pack/runtime contract to v3-only local Library assets on both platforms:
  - `pinball_library_v3.json`
  - practice-ID rulesheets and game-info markdown
  - practice-ID playfield webp assets
- Removed local runtime dependence on legacy library asset naming and slug-based rulesheet/game-info fallback behavior.
- Extracted iOS catalog imported-game, rulesheet, video, and machine-selection helpers into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryCatalogResolution.swift`.
- Extracted Android catalog imported-game, rulesheet, video, and machine-selection helpers into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogResolution.kt`.
- Left both main Library integration files smaller but still not “done”; remaining work is to keep reducing loader/store concentration and align seed-database assembly structure with the new resolution seam.
- Rewired iOS seed-database imported-source loading in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibrarySeedDatabase.swift` to feed the shared catalog-resolution seam instead of assembling imported games inline.
- Rewired Android seed-database imported-source loading in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySeedDatabase.kt` to feed the shared catalog-resolution seam instead of assembling imported games inline.
- Replaced single-key playfield lookup on both platforms with a manifest-backed fallback ladder:
  - exact local `group-machine-alias`
  - local `group-machine`
  - local `group`
  - OPDB remote playfield
- Removed the old detail-view behavior that opened OPDB playfields externally before local curated images were attempted.
- Extracted built-in seed-db row assembly on both platforms into explicit row-to-domain seams so `LibrarySeedDatabase` now loads built-in rows, resolves machine preference, and maps through one helper instead of hand-building `PinballGame` inline.
- Extracted Library resource URL normalization, local playfield manifest lookup, and rulesheet/game-info/playfield fallback shaping into dedicated resource-resolution seams:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryResourceResolution.swift`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryResourceResolution.kt`
- Left both `LibraryDomain` files smaller and more focused on domain parsing plus metadata fetch, while the new resource-resolution seams own v3 asset naming and fallback behavior.
- Extracted Android legacy Library payload JSON parsing into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryPayloadParsing.kt`, so `LibraryDomain.kt` now focuses more on domain-facing types, formatting, YouTube launch behavior, and metadata fetch.
- Extracted iOS YouTube oEmbed metadata fetch into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryVideoMetadata.swift`, so `LibraryDomain.swift` no longer carries that service inline.
- Standardized Library detail section headings on both platforms by moving iOS `Video References`, `Game Info`, and `Sources` card titles plus Android `Sources` section heading onto the shared section-title seams instead of leaving feature-local headline/semibold heading treatment in `LibraryDetailComponents.swift` and `LibraryDetailComponents.kt`.
- Standardized Android Library screen header composition by moving the Library detail title row plus playfield/rulesheet viewer header rows onto the shared `AppScreenHeader` seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt` instead of keeping feature-local back-button plus centered-title rows in `LibraryDetailScreen.kt`, `PlayfieldScreen.kt`, and `RulesheetScreen.kt`.
- Standardized iOS Library fullscreen back-button chrome by moving the playfield/rulesheet floating back-button overlay into the shared `AppFullscreenBackButton` seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/SharedFullscreenChrome.swift` instead of duplicating the same material-circle back control in `PlayfieldScreen.swift` and `RulesheetScreen.swift`.
- Standardized Library root/list loading and empty/error treatment on both platforms by moving iOS `LibraryListScreen.swift` and Android `LibraryListScreen.kt` / `LibraryRouteContent.kt` onto shared panel-status and panel-empty seams instead of feature-local fallback text, and Android Library now exposes real reload failures instead of silently clearing to an empty list.
- Standardized Library detail `Game Info` loading/missing/error treatment on both platforms by moving `LibraryDetailComponents.swift` and `LibraryDetailComponents.kt` onto shared inline-status and panel-empty seams instead of feature-local fallback text.
- Standardized Library detail video-empty and iOS sources-empty treatment by moving `LibraryDetailComponents.swift` and `LibraryDetailComponents.kt` onto shared panel-empty seams instead of feature-local empty-state surfaces.
- Extracted hosted Library payload and OPDB catalog fetch/decode entry points into dedicated platform seams:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryHostedData.swift`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryHostedData.kt`
- Rewired both `LibraryDataLoader` files to consume the new hosted-data seams instead of keeping hosted fetch paths, bundled fallback loading, and OPDB manufacturer-option decoding split across Library and Settings files.
- Settings manual hosted-data refresh now routes through the same Library hosted-data seams on both platforms instead of maintaining a feature-local hosted fetch path.
- Extracted iOS legacy payload/source parsing helpers into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryPayloadParsing.swift`, so `LibraryDomain.swift` now focuses more on view models, rulesheet/game-info loaders, markdown parsing, and `PinballGame` domain types instead of also owning payload-root/source decode helpers.
- Extracted iOS seed-db row models, rulesheet dedupe logic, SQLite helpers, and built-in-row-to-domain mapping into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibrarySeedDatabaseModels.swift`, reducing `LibrarySeedDatabase.swift` back toward database orchestration instead of mixed row-model plus helper ownership.
- Extracted Android seed-db row models, cursor helpers, and built-in-row/domain mapping into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySeedModels.kt`, reducing `LibrarySeedDatabase.kt` back toward query/orchestration ownership.
- Extracted Android seed-db GameRoom overlay decode/filter helpers into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySeedOverlay.kt`, so `LibrarySeedDatabase.kt` no longer carries both SQLite loading and GameRoom JSON overlay parsing inline.
- Extracted iOS markdown block parsing, ordered-list handling, and markdown table parsing into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryMarkdownParsing.swift`, so `LibraryDomain.swift` no longer owns the native markdown parser inline.
- Extracted iOS game-info and rulesheet loading state/view models into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryContentLoading.swift`, so `LibraryDomain.swift` is reduced further toward domain/resource ownership instead of mixed domain plus screen-loader state.
- Extracted repeated iOS seed-db rulesheet/video query helpers into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibrarySeedQueryLoaders.swift`, reducing `LibrarySeedDatabase.swift` toward query orchestration instead of mixed query body duplication.
- Extracted repeated Android seed-db rulesheet/video query helpers into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySeedQueries.kt`, reducing `LibrarySeedDatabase.kt` toward query orchestration instead of mixed query body duplication.
- Extracted iOS seed-db bootstrap, bundled/local copy rules, and manufacturer-option query into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibrarySeedStorage.swift`, so `LibrarySeedDatabase.swift` no longer mixes entry-point orchestration with database-open and bundle-copy mechanics.
- Extracted iOS built-in/imported seed-game assembly into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibrarySeedGameAssembly.swift`, so `LibrarySeedDatabase.swift` is now closer to an extraction facade than a mixed loader and mapper bucket.
- Extracted Android seed-db bootstrap, asset copy rules, and manufacturer-option query into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySeedStorage.kt`, so `LibrarySeedDatabase.kt` no longer mixes entry-point orchestration with file-sync and database-open mechanics.
- Extracted Android built-in/imported seed-game assembly into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibrarySeedGameAssembly.kt`, so `LibrarySeedDatabase.kt` is now closer to an extraction facade than a mixed loader and mapper bucket.

## Next audit targets

- source-state synchronization
- repeated detail/resource UI
- remaining markdown/content-domain shaping inside `LibraryDomain.swift`
- remaining query composition and final extraction orchestration inside the two `LibrarySeedDatabase` files
