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

## Next audit targets

- source-state synchronization
- GameRoom overlay logic
- rulesheet/playfield fallback ordering
- repeated detail/resource UI
- seed-database assembly seams
