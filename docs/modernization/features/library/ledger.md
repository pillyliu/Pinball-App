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

## Next audit targets

- source-state synchronization
- GameRoom overlay logic
- repeated detail/resource UI
- iOS payload-decoding split inside `LibraryDomain`
