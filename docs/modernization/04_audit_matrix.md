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
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift` | needs refactor | Large UI and behavior surface, but now consumes explicit workspace context and grouped route-local state. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspace.swift` | stable | `Game` route now builds an explicit workspace context instead of passing raw store/binding dependencies directly into the section view. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceContext.swift` | stable | `Game` route dependencies now live behind an explicit seam instead of being threaded ad hoc through the section view. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceState.swift` | stable | `Game` route transient UI state is now grouped in one explicit seam instead of scattered across many local `@State` properties. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceSubviews.swift` | stable | `Summary`, `Input`, and `Log` panels now live outside the main game route file, reducing composition pressure in `PracticeGameSection.swift`. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift` | needs refactor | iOS route state, dialog state, preferences, and navigation are still highly centralized. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreenActions.swift` | stable | Root Practice navigation, quick-entry, journal mutation, group-editor, and insights refresh helpers now live outside the main screen declaration. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreenState.swift` | stable | First explicit iOS Practice UI-state seam now groups route, dialog, and transient screen state. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeHomeContext.swift` | stable | Practice home/root dependencies now live behind an explicit seam instead of being assembled inline inside the dialog host. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeHomeHost.swift` | stable | Practice home rendering is now driven by a dedicated context, reducing root-surface concentration in `PracticeDialogHost.swift`. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeLifecycleContext.swift` | stable | Practice first-load and observer dependencies now live behind an explicit seam instead of being assembled inline inside the dialog host. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeLifecycleHost.swift` | stable | Practice root-level `.task`, `.onChange`, and notification wiring now lives outside `PracticeDialogHost.swift`. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStore.swift` | in audit | Domain state is split better than Android, but still needs a documented ownership boundary against screen state. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeDialogHost.swift` | in audit | Now uses explicit route and sheet enums, dispatches routes without a generic context bundle, and delegates modal and lifecycle concerns through dedicated seams. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticePresentationContext.swift` | stable | Practice sheet and reset-alert dependencies now live behind an explicit presentation seam instead of being assembled inline inside the dialog host. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticePresentationHost.swift` | stable | Practice sheet and reset-alert rendering now lives outside the route host, reducing presentation concentration in `PracticeDialogHost.swift`. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardContext.swift` | stable | `GroupDashboard` now has a dedicated dependency seam instead of relying on a shared route bundle. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeInsightsContext.swift` | stable | `Insights` now has a dedicated dependency seam instead of relying on the broader route-content bundle. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeJournalContext.swift` | stable | `Journal` now has a dedicated dependency seam instead of relying on the broader route-content bundle. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeMechanicsContext.swift` | stable | `Mechanics` now has a dedicated dependency seam instead of relying on the broader route-content bundle. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeSettingsContext.swift` | stable | `Settings` now has a dedicated dependency seam instead of relying on the broader route-content bundle. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreenRouteContent.swift` | in audit | Route body composition now resolves explicit per-route contexts, but root orchestration remains concentrated elsewhere. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeTypes.swift` | in audit | Explicit `PracticeRoute` and `PracticeSheet` enums now exist, but the contract still needs to expand to remaining drill-ins and sub-surfaces. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt` | needs refactor | Central state surface likely to accumulate mixed responsibilities. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreen.kt` | in audit | Android route orchestration is cleaner than iOS, but still depends on a large store and UI-state bundle. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreenState.kt` | in audit | Good candidate to become the canonical UI-route state seam for both platforms. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreenRouteContent.kt` | in audit | Healthy route-to-section seam already exists, but the context object is still too wide and should shrink as ownership is clarified. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameSection.kt` | needs refactor | Game workspace is functionally aligned, but dense enough to benefit from explicit subcomponent boundaries. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift` | needs refactor | Large shared integration point with filtering, extraction, and downstream feature coupling. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryDomain.swift` | needs split | Domain model is now large enough that metadata, resources, and parsing concerns should be separated. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt` | needs refactor | Loader is large and central to multiple features. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDomain.kt` | needs split | Domain surface is growing and should not continue absorbing resource/parsing helpers unchecked. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/league/LeagueScreen.swift` | in audit | Small file size, but it owns navigation into multiple nested subfeatures and should be specified as a shell contract. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeagueScreen.kt` | needs refactor | Android League screen combines preview loading, rotating state, card rendering, and shell concerns. |

## Current work order

1. Practice state ownership and route-model normalization plan
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
