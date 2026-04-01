# Playfield Single-Asset Migration Guide

As of 2026-04-01.

This document defines the full migration from three published PinProf playfield files:

- original `...-playfield.webp`
- `...-playfield_1400.webp`
- `...-playfield_700.webp`

to one published PinProf playfield file:

- original full-resolution `...-playfield.webp` at quality `90`

The goal is to remove every playfield-specific `700` and `1400` assumption from the apps, website, admin producer pipeline, generated payloads, manifests, tests, and docs.

## Final Invariant

After the migration:

- Every PinProf playfield override publishes exactly one web asset: `/pinball/images/playfields/<base>.webp`
- The workspace still keeps the original imported source file in `workspace/assets/playfield_sources/originals/*`
- The admin workspace may still keep a reference package in `workspace/assets/playfield_sources/references/*`, but that reference package must only point at the single published `.webp`
- `playfield_assets.json` exposes only one published local playfield path for each asset row
- iOS, Android, and the website never infer, request, prioritize, log, or display `_1400` or `_700` playfield URLs
- The synthetic bundled exception `G900001-1-playfield` ships only as `G900001-1-playfield.webp`
- There is no PinProf-local fallback ladder between original/1400/700 variants

## Scope Assumptions

- This migration is for playfields only
- Backglass `700/1400` handling is out of scope for this pass and should not be changed accidentally
- OPDB remains the remote fallback when no PinProf local playfield exists
- `No fallback` in this guide means no fallback between PinProf-local playfield size variants

## Biggest Risk

Current released clients still know about `_700` and `_1400`.

If those files are deleted from the hosted payload before new consumers ship, old app builds can break playfield loads.

Because of that, the safest rollout is:

1. update consumers first so they stop requesting variant files
2. ship/deploy those consumer changes
3. update the admin producer and published data
4. regenerate bundles/manifests
5. only then delete hosted `_700/_1400` playfield files

If you need a cutover bridge for older clients, the least-invasive temporary option is a short-lived server rewrite or redirect from `*_700.webp` and `*_1400.webp` to `*.webp`. That bridge should be temporary only.

## Canonical Contract Changes

### Published playfield path contract

Before:

```json
{
  "playfieldLocalPath": "/pinball/images/playfields/GYWBZ-MkPrr-playfield.webp",
  "playfieldWebLocalPath700": "/pinball/images/playfields/GYWBZ-MkPrr-playfield_700.webp",
  "playfieldWebLocalPath1400": "/pinball/images/playfields/GYWBZ-MkPrr-playfield_1400.webp"
}
```

After:

```json
{
  "playfieldLocalPath": "/pinball/images/playfields/GYWBZ-MkPrr-playfield.webp"
}
```

### Admin DB contract

Keep:

- `playfield_local_path`
- `playfield_original_local_path`
- `playfield_reference_local_path`
- `playfield_source_url`
- `playfield_source_page_url`
- `playfield_source_page_snapshot_path`
- `playfield_source_note`
- `playfield_mask_polygon_json`

Remove:

- `playfield_web_local_path_1400`
- `playfield_web_local_path_700`

### Reference package contract

Before:

```json
"published": {
  "highRes": "/pinball/images/playfields/GYWBZ-MkPrr-playfield.webp",
  "width1400": "/pinball/images/playfields/GYWBZ-MkPrr-playfield_1400.webp",
  "width700": "/pinball/images/playfields/GYWBZ-MkPrr-playfield_700.webp"
}
```

After:

```json
"published": {
  "localPath": "/pinball/images/playfields/GYWBZ-MkPrr-playfield.webp"
}
```

Using `"highRes"` instead of `"localPath"` would still work, but `"localPath"` is the cleaner long-term contract because it matches `playfieldLocalPath`.

### Synthetic bundled exception

`G900001-1-playfield` should exist only as:

- `/pinball/images/playfields/G900001-1-playfield.webp`

Any synthetic OPDB image fields that still require `medium` and `large` for compatibility should point both values at that same `.webp` path during the transition.

## App-First Rollout Plan

### Phase 1: Consumer code

Ship code that can live with the new single-path contract before producer-side deletion happens.

Required rules:

- Consumers should prefer exactly one PinProf local playfield URL
- Consumers should stop manufacturing `_1400` and `_700` candidate URLs
- Consumers should stop keeping two separate local PinProf playfield fields when one will do
- Consumers may still decode old persisted state during upgrade, but should re-encode the new single-path shape

### Phase 2: Producer contract

After consumers are ready:

- stop generating `_1400` and `_700`
- stop storing them in admin DB rows
- stop exporting them in CAF JSON
- stop bundling them in preload assets

### Phase 3: Cleanup

- remove stale hosted playfield variant files
- regenerate manifests and preload bundles
- run code and data sweeps to ensure no playfield variant references remain

## Exhaustive Change Inventory

## 1. App Repo: iOS

### Must change

- `Pinball App 2/Pinball App 2/library/LibraryResourcePathSupport.swift`
  - remove variant normalization regexes that collapse `_(700|1400)` to `.webp`
  - make `normalizeLibraryPlayfieldLocalPath` return the one published playfield path instead of manufacturing `_700.webp`
  - keep `normalizeLibraryCachePath` simple for direct `.webp` normalization

- `Pinball App 2/Pinball App 2/library/HostedImageCandidateSupport.swift`
  - remove `pinProf1400` and `pinProf700` priorities
  - make PinProf playfields a single hosted candidate class
  - simplify load timeout rules to single PinProf original vs OPDB/external

- `Pinball App 2/Pinball App 2/library/LibraryOPDBPracticeIdentitySupport.swift`
  - replace synthetic `G900001-1-playfield_700.webp` and `_1400.webp` constants with one `.webp`
  - ensure the synthetic `playfieldImage` shape no longer implies separate local variants

- `Pinball App 2/Pinball App 2/library/LibraryCatalogResolution.swift`
  - stop shaping local playfield state around original-vs-derived variant assumptions
  - verify `alternatePlayfieldImageURL` remains only for OPDB fallback, not local variant fallback

- `Pinball App 2/Pinball App 2/library/LibraryGame.swift`
  - collapse `playfieldLocalOriginal` and `playfieldLocal` into one local PinProf playfield field if the UI no longer needs both
  - if both properties are kept for compatibility, they must resolve to the same single `.webp` path

- `Pinball App 2/Pinball App 2/library/LibraryGameModels.swift`
  - remove duplicated playfield-local model shape if possible

- `Pinball App 2/Pinball App 2/library/LibraryGameDecodingSupport.swift`
  - stop decoding old `playfieldLocal` vs `playfieldLocalOriginal` assumptions into two different local playfield candidates
  - preserve backward decode compatibility for already-persisted snapshots if needed

- `Pinball App 2/Pinball App 2/library/LibraryPlayfieldCandidateSupport.swift`
  - remove `localFallbackPlayfieldCandidates`
  - remove `localPlayfieldURLs(widths: [1400, 700])`
  - remove any `localOriginalPlayfieldURLs()` path that exists only to support the old variant ladder
  - replace candidate ordering with:
    - explicit local playfield path
    - inferred exact hosted `.webp` playfield path by alias/machine/group specificity if still needed
    - OPDB fallback

- `Pinball App 2/Pinball App 2/library/LibraryPlayfieldResolutionSupport.swift`
  - remove `playfieldLocalOriginalURL` vs `playfieldLocalURL` split if it only exists for size variants
  - update any resolution logic that still assumes two local PinProf candidates

- `Pinball App 2/Pinball App 2/practice/PracticeHomeBootstrapSnapshot.swift`
  - collapse stored playfield snapshot state to one local playfield path
  - preserve decode compatibility for older on-device snapshots during upgrade

### Audit and likely small change

- `Pinball App 2/Pinball App 2/library/LibraryCAFAssetSupport.swift`
  - already centered on `playfieldLocalPath`
  - verify it does not depend on variant-only fields anywhere downstream

- `Pinball App 2/Pinball App 2/library/LibraryCatalogResolutionModels.swift`
  - verify `playfieldLocalPath` remains the one authoritative local field

- `Pinball App 2/Pinball App 2/library/LibraryCatalogSourcePayloadModels.swift`
  - confirm source payloads only need one local playfield path

- `Pinball App 2/Pinball App 2/library/LibraryPracticeCatalogDecodingSupport.swift`
  - verify no redundant playfield-local shape survives in practice bootstrap decoding

- `Pinball App 2/Pinball App 2/practice/PracticeStoreDataLoaders.swift`
  - verify loader glue does not rebuild the old two-path model

### Generated artifacts to replace

- `Pinball App 2/Pinball App 2/PinballPreload.bundle/preload-manifest.json`
  - remove `G900001-1-playfield_1400.webp`
  - remove `G900001-1-playfield_700.webp`

- `Pinball App 2/Pinball App 2/PinballPreload.bundle/pinball/data/playfield_assets.json`
  - remove `playfieldWebLocalPath700`
  - remove `playfieldWebLocalPath1400`

- `Pinball App 2/Pinball App 2/PinballPreload.bundle/pinball/data/opdb_export.json`
  - update synthetic `medium` and `large` playfield image paths so they no longer point at `_700`/`_1400`

### Tests and docs

- `Pinball App 2/Pinball App 2Tests/RulesheetLinkResolutionTests.swift`
  - update synthetic playfield expectations from `_700.webp` to `.webp`

- `docs/modernization/features/library/spec.md`
  - rewrite hosted playfield lookup order so it never mentions `_1400` or `_700`

- `docs/review/ios-sequential-code-review.md`
  - remove or rewrite any “current” hosted playfield contract language that still documents `_1400` and `_700`

## 2. App Repo: Android

### Must change

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryResourcePathSupport.kt`
  - remove `_700` and `_1400` normalization logic
  - stop manufacturing `_700.webp` as the normalized local playfield path

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/HostedImageCandidateSupport.kt`
  - remove `PIN_PROF_1400` and `PIN_PROF_700`
  - simplify prioritization and timeout logic to one PinProf-local playfield class

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryOPDBSyntheticMachineSupport.kt`
  - replace synthetic `_700` and `_1400` constants with one `.webp`

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogResolution.kt`
  - stop shaping local playfield state around `playfieldLocalOriginal` plus derived `playfieldLocal`
  - ensure `alternatePlayfieldImageUrl` is not used as a local variant fallback

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDomain.kt`
  - collapse duplicated local playfield model if possible

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryPlayfieldAssetPathSupport.kt`
  - remove inferred `_1400` and `_700` local path generation
  - remove any helper that manufactures size-specific fallback candidates

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryPlayfieldCandidateSupport.kt`
  - remove `localFallbackPlayfieldCandidates`
  - make single-path local PinProf playfield resolution the only local override path

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryPlayfieldResolutionSupport.kt`
  - remove the dual local-path resolution shape

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeHomeBootstrapSnapshot.kt`
  - collapse persisted local playfield snapshot fields
  - preserve decode compatibility for older installed state

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreBootstrapSupport.kt`
  - remove any rebuild of the old two-path playfield model

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStoreDataLoaders.kt`
  - same as above

### Android GameRoom follow-up

The Android GameRoom path still carries separate OPDB playfield image fields:

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogIndexingSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogMachineResolutionSupport.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogModels.kt`

These are not PinProf-local `700/1400` fields, but they do contain synthetic playfield URL handling. At minimum:

- verify the synthetic bundled game still resolves correctly after its local path becomes a single `.webp`
- confirm GameRoom never manufactures `_700/_1400` PinProf paths

### Audit and likely small change

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCAFAssetSupport.kt`
  - already centered on `playfieldLocalPath`
  - verify it stays compatible with the simplified CAF payload

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogModels.kt`
  - verify `playfieldLocalPath` remains the one authoritative local PinProf field

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`
  - verify no old `playfieldLocalOriginal` assumptions remain in loader glue

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryOPDBMachineDecodingSupport.kt`
  - likely no direct change for real OPDB data
  - confirm only the synthetic local-path bridge changes

### Generated artifacts to replace

- `Pinball App Android/app/src/main/assets/pinprof-preload/preload-manifest.json`
  - remove `_1400` and `_700` playfield entries

- `Pinball App Android/app/src/main/assets/pinprof-preload/pinball/data/playfield_assets.json`
  - remove `playfieldWebLocalPath700`
  - remove `playfieldWebLocalPath1400`

- `Pinball App Android/app/src/main/assets/pinprof-preload/pinball/data/opdb_export.json`
  - update synthetic playfield paths away from `_700/_1400`

### Tests

- `Pinball App Android/app/src/test/java/com/pillyliu/pinprofandroid/library/LibraryCatalogResolutionParityTest.kt`
  - update any expectations that still assume variant-specific PinProf playfield paths

- `Pinball App Android/app/src/test/java/com/pillyliu/pinprofandroid/library/LibraryDataLoaderParityTest.kt`
  - remove expectations for `playfieldWebLocalPath700`
  - remove expectations for `playfieldWebLocalPath1400`

## 3. Website Repo

### Must change

- `../Pillyliu Pinball Website/lpl-library/src/lib/libraryData.ts`
  - remove `PlayfieldAssetRecord.playfieldWebLocalPath700`
  - remove `PlayfieldAssetRecord.playfieldWebLocalPath1400`
  - stop treating `playfieldLocalOriginal` and `playfieldLocal` as different local playfield artifacts
  - remove `groupPlayfieldLocalOriginal` and `groupPlayfieldLocal` if they only exist for variant handling
  - remove `derivePlayfieldVariant(local, width: 700 | 1400)`
  - rewrite `explicitPlayfieldCandidates(game)` to stop adding inferred `_700/_1400` candidates
  - make `playfieldAssetForMachine()` filter only on `playfieldLocalPath`
  - in `buildLibraryGame()`, resolve one local PinProf playfield path and one optional OPDB fallback URL

### Audit and likely no code change

- `../Pillyliu Pinball Website/deploy.sh`
  - no direct variant logic was found in the deploy gate
  - still rerun deploy packaging after the new published payload exists

- `../Pillyliu Pinball Website/tools/smoke-check.mjs`
  - no direct playfield variant logic was found
  - rerun after cleanup so canonical payload validation happens against the new published set

## 4. Admin Repo: Schema, Producer, and Runtime

### Must change: schema and DB-facing code

- `../PinProf Admin/apps/admin-site-runtime/schema.sql`
  - drop `playfield_web_local_path_1400`
  - drop `playfield_web_local_path_700`

- `../PinProf Admin/apps/admin-ui/server/index.ts`
  - remove all type declarations, migrations, inserts, updates, patches, and response payload fields for:
    - `playfield_web_local_path_1400`
    - `playfield_web_local_path_700`
    - `web1400LocalPath`
    - `web700LocalPath`

Important server sections already known to require edits:

- playfield constants for `PLAYFIELD_WEBP_1400_QUALITY` and `PLAYFIELD_WEBP_700_QUALITY`
- `buildPlayfieldAssetPaths()`
- `writePlayfieldReferencePackage()`
- `publishPlayfieldDerivatives()`
- `savePlayfield(...)`
- `savePlayfieldMask(...)`
- `savePlayfieldCoverage(...)`
- any admin DB bootstrap SQL
- any upsert/update patch unions
- any API serializer that returns `web1400LocalPath` or `web700LocalPath`

### Must change: playfield file generation

- `../PinProf Admin/apps/admin-ui/server/index.ts`
  - `buildPlayfieldAssetPaths()` should only emit:
    - `publishedFsPath`
    - `publishedWebPath`
    - `originalFsPath`
    - `referenceFsPath`
    - `sourcePageSnapshotFsPath`
  - `publishPlayfieldDerivatives()` should only write one `.webp`
  - the one published `.webp` should stay at quality `90`
  - no `resize({ width: 1400 })`
  - no `resize({ width: 700 })`

### Must change: reference packages

- `../PinProf Admin/apps/admin-ui/server/index.ts`
  - `writePlayfieldReferencePackage()` should stop serializing `width1400` and `width700`
  - reference JSON should point only at the single published `.webp`

- `../PinProf Admin/workspace/assets/playfield_sources/references/*.source.json`
  - regenerate all reference packages to match the new schema

### Must change: importer and sync layer

- `../PinProf Admin/scripts/importers/sync_playfield_assets.py`
  - stop inventorying `_700` and `_1400`
  - stop stripping `_(700|1400)` from file names
  - stop using variant paths as fallback values for `playfield_local_path`
  - remove variant columns from schema bootstrap and upsert logic
  - update stale-row cleanup rules so they do not preserve playfield variant-only rows
  - ideally fail loudly if new `_700` or `_1400` playfield files are found after the migration

### Must change: published CAF export

- `../PinProf Admin/scripts/publish/export_canonical_library_layers.py`
  - remove `playfieldWebLocalPath700`
  - remove `playfieldWebLocalPath1400`
  - ensure `playfield_assets.json` publishes only `playfieldLocalPath` plus source metadata

### Audit: republish plumbing

- `../PinProf Admin/scripts/publish/rebuild-shared-pinball-payload.sh`
  - verify the republish step does not preserve stale `_700/_1400` playfield files in any staged payload
  - after the migration, stale variant files should disappear from downstream payloads because they no longer exist in the workspace source set

### Must change: app preload builder

- `../PinProf Admin/scripts/publish/build-mobile-app-preload.sh`
  - stop copying `G900001-1-playfield_1400.webp`
  - stop copying `G900001-1-playfield_700.webp`
  - only copy `G900001-1-playfield.webp`

### Must change: synthetic config

- `../PinProf Admin/configs/synthetic_library_entries.json`
  - remove `playfieldWebLocalPath700`
  - remove `playfieldWebLocalPath1400`
  - update synthetic playfield image `medium` and `large` paths away from `_700/_1400`

### Must change: admin runtime fallback logic

- `../PinProf Admin/apps/admin-site-runtime/lib/app.php`
  - `pinprof_web_path_to_fs()` should stop rewriting `_700/_1400` paths back to `.webp`
  - `pinprof_playfield_prefix_from_web_path()` should stop stripping `_(700|1400)`
  - any effective playfield URL selection should treat `playfield_local_path` as the only local PinProf playfield path

### Must change: admin UI types and copy

- `../PinProf Admin/apps/admin-ui/src/App.tsx`
  - remove `web1400LocalPath`
  - remove `web700LocalPath`
  - remove `localWeb1400Path`
  - remove `localWeb700Path`
  - update any copy that says “processed WebP plus 1400 and 700 derivatives”
  - update any “Current asset details” panel that still shows three published playfield outputs

### Docs to update

- `../PinProf Admin/docs/APP_DATA_EXPECTATIONS.md`
  - document that app consumers now get one published PinProf playfield local path

- `../PinProf Admin/docs/WEBSITE_DATA_EXPECTATIONS.md`
  - document that the website consumes one published PinProf playfield local path

- `../PinProf Admin/docs/CONTROL_BOARD_DATA_MODEL.md`
  - update the control board asset model description if it still implies multi-derivative playfield publishing

- `../PinProf Admin/docs/GAME_DATA_SIMPLIFICATION.md`
  - update the published playfield contract language so the simplification is documented as current behavior

## 5. Generated Data and Manifests

These should be regenerated, not hand-maintained long term.

### PinProf Admin generated outputs

- `../PinProf Admin/workspace/data/published/playfield_assets.json`
- `../PinProf Admin/workspace/data/published/opdb_export.json`
- `../PinProf Admin/workspace/app-preload/preload-manifest.json`
- `../PinProf Admin/workspace/app-preload/pinball/data/playfield_assets.json`
- `../PinProf Admin/workspace/app-preload/pinball/data/opdb_export.json`
- `../PinProf Admin/workspace/manifests/cache-manifest.json`
- `../PinProf Admin/workspace/manifests/cache-update-log.json`

### App repo checked-in generated bundles

- `Pinball App 2/Pinball App 2/PinballPreload.bundle/preload-manifest.json`
- `Pinball App 2/Pinball App 2/PinballPreload.bundle/pinball/data/playfield_assets.json`
- `Pinball App 2/Pinball App 2/PinballPreload.bundle/pinball/data/opdb_export.json`
- `Pinball App Android/app/src/main/assets/pinprof-preload/preload-manifest.json`
- `Pinball App Android/app/src/main/assets/pinprof-preload/pinball/data/playfield_assets.json`
- `Pinball App Android/app/src/main/assets/pinprof-preload/pinball/data/opdb_export.json`

## 6. Filesystem Cleanup

After producer and consumer changes are shipped:

- delete all hosted playfield files matching `*_700.webp`
- delete all hosted playfield files matching `*_1400.webp`
- keep:
  - `workspace/assets/playfields/*.webp`
  - `workspace/assets/playfield_sources/originals/*`
  - `workspace/assets/playfield_sources/references/*`

Do not delete backglass `_700/_1400` files during this migration.

## 7. Data Migration Rules

### Admin SQLite

Do not rely on `CREATE TABLE IF NOT EXISTS` alone.

The migration must explicitly remove old playfield variant columns from existing DBs.

Acceptable options:

- rebuild `playfield_assets` into a new table with only the surviving columns
- copy data forward
- swap tables
- recreate indexes

### App persistence compatibility

If stored practice or library snapshots currently contain both:

- `playfieldLocalOriginal`
- `playfieldLocal`

then the app upgrade should:

- decode either or both old fields
- normalize both to the single final local playfield path
- write back only the new single-path representation

This matters for already-installed mobile clients.

## 8. Verification Checklist

### Code sweep

These searches should return no playfield-variant code references after the migration:

```bash
rg -n 'playfieldWebLocalPath700|playfieldWebLocalPath1400|playfield_web_local_path_700|playfield_web_local_path_1400|G900001-1-playfield_(700|1400)|playfields/.+_(700|1400)\\.webp' \
  '/Users/pillyliu/Documents/Codex/Pinball App' \
  '/Users/pillyliu/Documents/Codex/PinProf Admin' \
  '/Users/pillyliu/Documents/Codex/Pillyliu Pinball Website'
```

Because backglass still uses variants, do not use a broad `_700|_1400` search by itself as the only proof.

### Filesystem sweep

After cleanup, this should return nothing:

```bash
find '/Users/pillyliu/Documents/Codex/PinProf Admin/workspace/assets/playfields' \
  \( -name '*_700.webp' -o -name '*_1400.webp' \)
```

### Generated data sweep

These should return nothing after republish:

```bash
rg -n 'playfieldWebLocalPath700|playfieldWebLocalPath1400|G900001-1-playfield_(700|1400)' \
  '/Users/pillyliu/Documents/Codex/PinProf Admin/workspace/data/published' \
  '/Users/pillyliu/Documents/Codex/PinProf Admin/workspace/app-preload' \
  '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/PinballPreload.bundle' \
  '/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/assets/pinprof-preload'
```

### Manual behavior checks

- iOS library game detail loads a local PinProf playfield from `.webp`
- Android library game detail loads a local PinProf playfield from `.webp`
- Website game page loads a local PinProf playfield from `.webp`
- Practice flows still show the correct playfield after app restart
- GameRoom synthetic bundled game still resolves its local playfield correctly
- Machines without a PinProf local playfield still fall back to OPDB
- Admin playfield save, mask edit, and re-save still publish one correct `.webp`
- Admin control board still shows the correct effective playfield source label and URL

### Build and smoke checks

- rebuild and run iOS tests that cover library/practice playfield resolution
- run Android unit tests for library parity/data loader coverage
- rerun website smoke check
- regenerate and inspect admin manifests

## 9. Implementation Order by Repo

If we want the lowest-risk execution order, do it in this order:

1. app repo consumer logic
2. website consumer logic
3. admin runtime compatibility logic
4. admin producer and DB schema
5. synthetic config and preload builder
6. republish CAF and preload artifacts
7. update checked-in generated app bundles
8. delete stale hosted playfield variant files
9. run verification sweeps and smoke tests

## 10. Explicit Out-of-Scope Items

Do not change these in this migration unless we intentionally open a second pass:

- backglass variant generation and storage
- OPDB’s own remote medium/large image model for non-PinProf assets
- generic deploy plumbing that does not care which playfield files exist

## 11. Definition Of Done

This migration is done only when all of the following are true:

- no playfield `_700` or `_1400` files are generated
- no playfield `_700` or `_1400` files are stored in admin data or reference packages
- no app or website runtime requests `_700` or `_1400` playfield URLs
- no generated JSON payload publishes `playfieldWebLocalPath700` or `playfieldWebLocalPath1400`
- no synthetic bundled playfield points at `_700` or `_1400`
- no docs or tests still describe the old playfield variant contract as current behavior
