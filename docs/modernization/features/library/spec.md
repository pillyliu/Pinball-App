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
- iOS resource URL normalization plus rulesheet/game-info/playfield fallback shaping now live in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryResourceResolution.swift` instead of remaining embedded in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryDomain.swift`.
- Android resource URL normalization plus rulesheet/game-info/playfield fallback shaping now live in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryResourceResolution.kt` instead of remaining embedded in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDomain.kt`.
- Android legacy Library payload JSON parsing now lives in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryPayloadParsing.kt` instead of remaining embedded in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDomain.kt`.
- iOS YouTube oEmbed metadata fetch now lives in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryVideoMetadata.swift` instead of remaining embedded in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryDomain.swift`.
- The active local asset contract is now v3-only:
  - `pinball_library_v3.json`
  - practice-ID `rulesheets/*.md`
  - practice-ID `gameinfo/*.md`
  - playfields in `/pinball/images/playfields/` named by OPDB specificity:
    - `GROUP-playfield_*`
    - `GROUP-MACHINE-playfield_*`
    - `GROUP-MACHINE-ALIAS-playfield_*`
- Library should no longer assume local `v1` or `v2` resource names, slug-based local rulesheets/gameinfo, or legacy fallback keys in starter-pack data.

## Resource contract

- Rulesheets resolve only by practice identity / OPDB group key.
- Game info resolves only by practice identity / OPDB group key.
- Playfields resolve by specificity ladder:
  - exact local `group-machine-alias`
  - local `group-machine`
  - local `group`
  - OPDB remote playfield
- Any matching local curated playfield should win over OPDB, even when the local asset is only group-scoped.

## Hosted playfield contract

- Starter bundles stay intentionally small and do not need to contain every playfield that exists on `pillyliu.com`.
- Live app builds should still infer hosted playfield files from `pillyliu.com` for any already-known game identity.
- Hosted playfield lookup order is:
  - explicit local original path from exported data
  - inferred hosted original `...-playfield.{webp,jpg,jpeg,png}`
  - inferred hosted `...-playfield_1400.webp`
  - inferred hosted `...-playfield_700.webp`
  - less-specific local OPDB-group fallback
  - OPDB-provided playfield fallback
- That means newly uploaded hosted playfields can work without a starter-bundle update as long as the game already has the correct OPDB/practice identity in app data.
