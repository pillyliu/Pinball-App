# Library Spec

## Status

- core cross-feature dependency
- feeds Practice and GameRoom behavior

## Scope summary

Library includes:
- source filtering
- game list
- game detail
- rulesheets
- playfields
- game info
- video/resource presentation
- GameRoom venue overlay integration

## 3.2 focus

- normalize source behavior
- normalize resource availability states
- document fallback rules for rulesheets and playfields
- reduce cross-feature coupling surprises

## Current structural baseline

- iOS catalog resolution helpers now live in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryCatalogResolution.swift` instead of remaining embedded in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`.
- Android catalog resolution helpers now live in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogResolution.kt` instead of remaining embedded in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`.
- Both platforms now route seed-database imported-source resolution through that same catalog-resolution seam instead of maintaining a second imported-game assembly path.
- The active local asset contract is now v3-only:
  - `pinball_library_v3.json`
  - practice-ID `rulesheets/*.md`
  - practice-ID `gameinfo/*.md`
  - practice-ID `playfields/*_700.webp` and `*_1400.webp`
- Library should no longer assume local `v1` or `v2` resource names, slug-based local rulesheets/gameinfo, or legacy fallback keys in starter-pack data.
