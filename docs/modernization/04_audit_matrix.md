# Audit Matrix

Use this file to track architecture and cleanup decisions at a high level.

Status values:
- `not started`
- `in audit`
- `stable`
- `needs refactor`
- `needs split`
- `needs rewrite`
- `parity risk`

## Feature summary

| Feature | iOS status | Android status | Parity status | Notes |
| --- | --- | --- | --- | --- |
| League | in audit | in audit | in audit | Root tab is aligned, but League also owns Stats, Standings, Targets, and About as nested destinations. |
| Library | in audit | in audit | parity risk | Shared dependency for Practice and GameRoom; fallback/resource behavior must be locked before larger rewrites. |
| Practice | parity risk | parity risk | parity risk | Largest active drift surface after GameRoom; route/state complexity is still concentrated in a few large files. |
| GameRoom | stable | stable | in audit | 3.1 shipped baseline exists; needs structural cleanup, screen splitting, and hardening. |
| Settings | in audit | in audit | in audit | Smaller feature, but still part of the app-shell and design-system cleanup. |

## Shell and theme hotspots

| File | Action | Reason |
| --- | --- | --- |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/app/ContentView.swift` | in audit | Root tab shell is compact on iOS, but should be documented as the canonical top-level app map. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/MainActivity.kt` | needs refactor | Android root shell owns tab chrome, League nested routing, and bottom-bar behavior in one file. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppTheme.swift` | in audit | iOS already has semantic helpers, but they are incomplete and not yet a full system. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/PinballTheme.kt` | needs refactor | Android theme still centers on Material defaults rather than explicit semantic token roles. |

## Initial file-level hotspots

| File | Action | Reason |
| --- | --- | --- |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomScreen.swift` | needs split | Very large screen surface with mixed responsibilities. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt` | needs split | Android parity landed, but screen size indicates structural pressure. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift` | needs refactor | Large UI and behavior surface. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspace.swift` | in audit | Thin wrapper today, but useful seam for a future route/component split. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift` | needs refactor | iOS route state, dialog state, preferences, and navigation are still highly centralized. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStore.swift` | in audit | Domain state is split better than Android, but still needs a documented ownership boundary against screen state. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeDialogHost.swift` | needs refactor | Route delivery is currently split between path-based navigation and multiple sheet booleans. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt` | needs refactor | Central state surface likely to accumulate mixed responsibilities. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreen.kt` | in audit | Android route orchestration is cleaner than iOS, but still depends on a large store and UI-state bundle. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreenState.kt` | in audit | Good candidate to become the canonical UI-route state seam for both platforms. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameSection.kt` | needs refactor | Game workspace is functionally aligned, but dense enough to benefit from explicit subcomponent boundaries. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift` | needs refactor | Large shared integration point with filtering, extraction, and downstream feature coupling. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryDomain.swift` | needs split | Domain model is now large enough that metadata, resources, and parsing concerns should be separated. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt` | needs refactor | Loader is large and central to multiple features. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDomain.kt` | needs split | Domain surface is growing and should not continue absorbing resource/parsing helpers unchecked. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/league/LeagueScreen.swift` | in audit | Small file size, but it owns navigation into multiple nested subfeatures and should be specified as a shell contract. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeagueScreen.kt` | needs refactor | Android League screen combines preview loading, rotating state, card rendering, and shell concerns. |

## Current work order

1. Practice audit and route/state documentation
2. Library audit and dependency boundaries
3. League shell and nested destination contract
4. GameRoom structural cleanup plan
5. Settings consistency pass

## Next audit additions

Add rows as each feature is reviewed:
- screen files
- store/state files
- persistence files
- theme/component files
- duplicated helpers
