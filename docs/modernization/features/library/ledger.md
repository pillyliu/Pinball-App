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
- Standardized iOS playfield fullscreen failure treatment by moving the primary “Could not load image.” state onto the shared `AppFullscreenStatusOverlay` seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/SharedFullscreenChrome.swift` while preserving the `Open Original URL` recovery link in `PlayfieldScreen.swift`.
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
- Extracted iOS Library browsing-state logic into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryPayloadParsing.swift`, so `LibraryDomain.swift` no longer owns inline visible-source derivation, filter/sort/group computations, sort-label shaping, and default-sort rules directly inside `PinballLibraryViewModel`.
- Extracted Android Library browsing and source-selection rules into `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryBrowsingState.kt`, so `LibraryScreen.kt` no longer owns visible-source ordering, default source/sort/bank resolution, or filter/sort/group browsing rules inline.
- Rewired Android `LibraryListScreen.kt` and `LibraryRouteContent.kt` to consume the shared `LibraryBrowseState` seam instead of duplicating selected-source, sort-label, bank-filter, and grouped-section logic across the root screen and list screen.
- Current Library builds are clean of feature-specific compiler warnings; the remaining Xcode simulator build warning is the external `appintentsmetadataprocessor` metadata-skip message, not a Library warning.
- Standardized Library rulesheet/playfield resource rows and chip chrome on both platforms by moving those helpers onto shared media/resource seams:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppResourceChrome.swift`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppResourceChrome.kt`
- `LibraryDetailComponents.swift` and `LibraryDetailComponents.kt` now consume shared resource-row, unavailable-chip, and short-rulesheet-label helpers instead of carrying feature-local copies.
- Library thumbnail and image-preview loading/missing states now also use shared media-preview placeholder seams instead of duplicated inline spinner and photo-icon fallback blocks in `PlayfieldScreen.swift`, `LibraryDetailComponents.swift`, `PlayfieldScreen.kt`, and `LibraryDetailScreen.kt`.
- Android Library game-card artwork fallback now also uses the shared media-preview placeholder seam in `LibraryListScreen.kt` instead of raw `AsyncImage` loading and error behavior in the grid/list cards.
- iOS Library video-thumbnail loading and retry behavior now also routes through the shared fallback image loader in `LibraryDetailComponents.swift` instead of keeping a feature-local `AsyncImage` candidate-rotation view beside the shared media-preview placeholder seam.
- iOS and Android Library video thumbnail tiles now also use the shared branded resource-selection chrome instead of neutral fill and separator-outline styling, aligning media selection surfaces with the broader PinProf identity layer.
- iOS and Android Library summary variant badges now also use the shared branded resource chrome instead of neutral fill and outline styling, aligning game metadata chips with the broader PinProf identity layer.
- iOS and Android Library list-card overlay variant badges now also use shared branded overlay-badge chrome instead of feature-local black/white pill styling, aligning list-level metadata chips with the broader PinProf identity layer.
- iOS and Android Library rulesheet viewers now also use shared reading-progress pill seams in `AppResourceChrome.swift` and `AppResourceChrome.kt` instead of feature-local fullscreen progress/save pill styling.

## Next audit targets

- repeated detail/resource UI
- optional future domain-shaping cleanup inside `LibraryDomain.swift` and `LibraryDomain.kt`
