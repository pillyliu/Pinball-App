# Practice Spec

## Status

- active feature
- large surface area
- likely highest modernization risk after GameRoom

## Scope summary

Practice includes:
- home
- game workspace
- quick entry
- rulesheet/playfield drill-ins
- IFPA profile
- group dashboard/editor
- journal
- insights
- mechanics
- practice settings

## Current route inventory

Current Practice surfaces in code:
- `Home`
- `Game`
- `Rulesheet`
- `Playfield`
- `IfpaProfile`
- `GroupDashboard`
- `GroupEditor`
- `Journal`
- `Insights`
- `Mechanics`
- `Settings`

## Current architecture snapshot

iOS:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift` now uses a dedicated `PracticeScreenState.swift` value to group route, dialog, and transient UI state, but still owns most orchestration and mutation wiring.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGroupDashboardContext.swift` now isolates the `GroupDashboard` route dependency surface so iOS no longer routes non-game surfaces through one generic bundle.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeHomeContext.swift` now isolates the home-screen dependency surface so `PracticeScreen.swift` no longer assembles `PracticeHomeRootView` inline.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticePresentationContext.swift` now isolates sheet and reset-alert dependencies so iOS presentation wiring is no longer assembled ad hoc inside `PracticeDialogHost.swift`.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeInsightsContext.swift` now isolates the `Insights` route dependency surface from the rest of iOS Practice route wiring.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeJournalContext.swift` now isolates the `Journal` route dependency surface from the rest of iOS Practice route wiring.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeMechanicsContext.swift` now isolates the `Mechanics` route dependency surface from the rest of iOS Practice route wiring.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeSettingsContext.swift` now isolates the `Settings` route dependency surface from the rest of iOS Practice route wiring.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceContext.swift` now isolates the `Game` route dependency surface from the rest of iOS Practice screen wiring.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceState.swift` now groups `Game` route transient UI state instead of keeping it as scattered `@State` properties inside the route view.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceSubviews.swift` now isolates the `Summary`, `Input`, and `Log` workspace subviews from the main game route file.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameEntrySheets.swift` now isolates the `Score`, `Note`, and task-entry sheets from the main game route file.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameToolbarMenu.swift` now isolates the game/source picker toolbar from the main game route file.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGamePresentationContext.swift` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGamePresentationHost.swift` now isolate game-route sheets, alerts, and save-banner feedback from the main game route file.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameLifecycleContext.swift` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameLifecycleHost.swift` now isolate game-route first-load and selected-game synchronization from the main game route file.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameRouteBody.swift` now isolates the screenshot, segmented workspace card, note, and resource-card layout from the main game route file.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift` is still a major UI hotspot, but it now consumes an explicit workspace context and grouped state seam, and no longer renders the three workspace subviews inline.
- Store responsibilities are partially split across helper files, route dispatch is now driven by per-route contexts, but screen orchestration is still heavily centralized.
- Route model is now more explicit than before via `PracticeRoute` and `PracticeSheet`, but the iOS product-surface contract is still incomplete compared with Android because some drill-ins remain local to subviews and root orchestration is still centralized.

Android:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreen.kt` is better separated at the route layer than iOS.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt` remains the main responsibility concentration point.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameWorkspacePanels.kt` now isolates the segmented workspace card plus the `Summary`, `Input`, and `Log` panels from the main Android game route file.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameDetailCards.kt` now isolates the Android `Game Note` and `Game Resources` cards from the main game route file.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameDialogs.kt` now isolates Android delete/edit dialog wiring from the main game route file.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameSectionState.kt` now isolates Android `Game` route transient edit/delete/log-row UI state from the main game route file.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGameRouteContext.kt` now isolates Android `Game` route dependencies from the shared route-content context so route-specific state is not threaded through every Practice destination.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeTopBarGamePickerContext.kt` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeTopBarGamePicker.kt` now isolate Android top-bar game/source picker behavior from the broader top-bar component.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeHomeRouteContext.kt`, `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGroupDashboardContext.kt`, `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeInsightsRouteContext.kt`, `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeMechanicsRouteContext.kt`, and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeSettingsRouteContext.kt` now isolate the main Android non-game route dependencies from the shared route-content context.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeJournalRouteContext.kt` now isolates Android `Journal` route dependencies from the remaining shared route-content contract.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeJournalRows.kt` now isolates the Android journal timeline row, swipe-reveal actions, and row-body rendering from the main journal section file.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeJournalEditDialog.kt` now isolates the Android journal edit modal from the main journal section file.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreenActions.kt` now isolates Android navigation, selection, quick-entry, route drill-in, and reset/import helpers from the main screen declaration.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeLifecycleContext.kt` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeLifecycleHost.kt` now isolate Android first-load, back handling, observer, and route-level effect wiring from the main screen declaration.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticePresentationContext.kt` now isolates Android sheet/dialog dependencies from the main screen declaration.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeIfpaProfileContext.kt` and `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeGroupEditorRouteContext.kt` complete the Android route-seam split so `PracticeScreenRouteContent.kt` no longer needs a generic route-content context.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreenState.kt` now groups Android Practice UI state into navigation, journal, game, quick-entry, presentation, insights, and mechanics substate objects instead of keeping the whole surface as one flat mutable bag.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeLeagueIntegration.kt` now isolates Android league targets, league-player lookup, league CSV import, and head-to-head comparison behind a dedicated store dependency seam.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeLibrarySourceSelection.kt` now centralizes the Android "All games" source sentinel and normalization rules so top bar and home source selection do not drift.
- Persistence and codec work has already been separated more clearly than on iOS.
- Route model is more explicit via `PracticeRoute`, and `PracticeScreenState` is now grouped more intentionally, but the store still remains broader than the screen-state seam.

## Current route contract

### Home

- Primary chrome:
  - iOS: custom welcome header with gear button; navigation bar hidden
  - Android: welcome header in `PracticeTopBar` with settings icon; no back button
- Core content:
  - resume/recent game area
  - library source picker
  - quick-entry launch buttons
  - active groups summary
  - hub cards for group dashboard, journal, insights, mechanics
- Special behavior:
  - welcome/name prompt can block the home screen
  - player name in welcome header opens IFPA profile/setup

### Game

- Primary chrome:
  - iOS: navigation title is selected game name; top-right game picker menu
  - Android: `PracticeTopBar` shows selected game name with dropdown picker
- Core content:
  - segmented subviews `Summary`, `Input`, `Log`
  - rulesheet/playfield/video/resource launching
  - game summary note
  - score and target stats
  - quick-entry launchers from game context
- Special behavior:
  - entering game marks the game as viewed/browsed
  - selected game can be changed from the route chrome

#### Current Game route section order

Common high-level structure on both platforms:
1. inline playfield/image preview
2. main game workspace panel
3. freeform game note
4. game resources and videos

Inside the main game workspace panel, both platforms use the same three subviews:
- `Summary`
- `Input`
- `Log`

#### Summary subview

Current summary content on both platforms:
- active group progress summary when a group applies
- `Next Action`
- `Alerts`
- `Consistency`
- score stats
- target scores

#### Input subview

Current input shortcuts on both platforms:
- `Rulesheet`
- `Playfield`
- `Score`
- `Tutorial`
- `Practice`
- `Gameplay`

These launch quick-entry flows or score entry from game context.

#### Log subview

Current log behavior on both platforms:
- shows only entries related to the selected game
- empty state: `No actions logged yet.`
- supports edit/delete on user-editable entries
- uses a constrained scroll area rather than letting the full screen height grow indefinitely

#### Game note section

- Separate from the segmented workspace panel on both platforms
- Stores a freeform summary note for the selected game
- Explicit save action exists on both platforms

#### Resources section

Current resource content on both platforms:
- rulesheet row with fallback/source chips
- playfield row with source chip or unavailable state
- video launch panel above video tiles
- video tile list/grid beneath the launch panel

#### Current layout divergence

- iOS packages the `Summary/Input/Log` content inside one large panel, then renders `Game Note` and `Game Resources` as separate cards below.
- Android does the same in product terms, but the card boundaries and inner headings are rendered differently.
- iOS game switching lives in a top-right menu inside the navigation bar.
- Android game switching lives in the top bar title area as a dropdown control.
- Product intent is aligned, but the visual grouping rules are not yet defined as one shared component contract.

### Rulesheet

- Dedicated full-screen drill-in on both platforms
- Opens either embedded/local/remote rulesheet content depending on resolved source
- Back returns to the prior Practice route context

### Playfield

- Dedicated full-screen drill-in on both platforms
- Uses resolved fullscreen playfield candidates
- Back returns to the prior Practice route context

### IFPA Profile

- Dedicated route on both platforms
- Accessible from the home welcome header
- Title is `IFPA Profile`

### Group Dashboard

- Dedicated route on both platforms
- Title is `Group Dashboard`
- Supports selecting groups, archiving, deletion, priority, recommended game, and opening games
- Opens group editor/create flows from this route

### Group Editor

- iOS: presented as an explicit `PracticeSheet.groupEditor`, not an ad hoc boolean
- Android: dedicated route
- Titles:
  - iOS: `Create Group` or `Edit Group`
  - Android: same intent via route title logic
- Supports template selection, game selection, and save/cancel

### Journal

- Dedicated route on both platforms
- Title is `Journal Timeline`
- Includes filter controls, mixed practice/library timeline items, and entry editing/deletion flows
- Route-specific edit mode exists on both platforms:
  - iOS: trailing pencil/cancel toolbar action
  - Android: trailing edit/cancel top-bar action

### Insights

- Dedicated route on both platforms
- Title is `Insights`
- Contains score summaries, trends, opponent comparison, and head-to-head refresh behavior

### Mechanics

- Dedicated route on both platforms
- Title is `Mechanics`
- Contains tracked skill selection, competency logging, mechanics notes, and history

### Settings

- iOS: opened as a navigation destination from a home gear action
- Android: dedicated route
- Title is `Practice Settings`
- Contains player/profile settings, league CSV import, sync settings, and reset behavior

## Current structural divergence to remove

- iOS now models the main pushed surfaces explicitly via `PracticeRoute` and modal surfaces via `PracticeSheet`.
- iOS still differs from Android because Android models more of the full product surface as one unified route layer.
- Android models most primary surfaces as explicit routes.
- Product behavior is broadly aligned, but the route architecture is not.
- Modernization should normalize this into one explicit route contract per product surface, regardless of platform implementation details.

## Current state ownership snapshot

iOS current split:
- `PracticeScreenState.swift`
  - grouped route state
  - explicit `PracticeRoute` navigation path
  - explicit `PracticeSheet` presentation state
  - transient form and draft state
  - journal edit-selection state
  - head-to-head loading state
  - viewport/layout state
- `PracticeScreen.swift`
  - owns the `PracticeScreenState` instance
  - still performs most state mutation and route orchestration
  - still mixes navigation helpers with screen/domain coordination
- `PracticeStore`
  - persisted practice domain state
  - game/resource loading
  - analytics and derived summaries
  - journal mutation helpers
- Result:
  - better than before because route/UI state is grouped explicitly
  - still too much orchestration logic lives in the root screen

Android current split:
- `PracticeScreenState.kt`
  - explicit route
  - route history
  - sheet/dialog flags
  - selected game/resource route state
  - journal selection/edit mode state
  - mechanics and insights transient UI state
- `PracticeStore.kt`
  - persisted practice domain state
  - resource/game loading
  - journal/scores/notes/groups state
  - profile/settings state
  - analytics and derived summaries
- Result:
  - route/UI state is cleaner than iOS
  - domain/runtime state is still heavily concentrated in one store

## Current file responsibility map

iOS current wiring:
- `PracticeScreenState.swift`
  - groups route, modal, and transient UI state into one explicit seam
  - is the first iOS equivalent in role to Android's `PracticeScreenState.kt`
- `PracticeScreen.swift`
  - owns root `NavigationStack`
  - owns the `PracticeScreenState` instance and resume behavior
  - still owns quick-entry remembered defaults via `AppStorage`
  - now constructs explicit route, home, presentation, and lifecycle contexts
  - still owns high-level cross-route coordination, but no longer carries every mutation helper inline
- `PracticeScreenActions.swift`
  - isolates navigation, quick-entry, journal mutation, group-editor, and insights refresh helpers from the root screen declaration
- `PracticeHomeContext.swift`
  - isolates the `Home` route dependency surface
  - keeps home-screen closure assembly out of the root host
- `PracticeDialogHost.swift`
  - owns destination delivery for settings, group editor, date picker, and journal editor
  - now delivers pushed surfaces via `PracticeRoute` and modal surfaces via `PracticeSheet`
  - now delegates sheet and reset-alert content through `PracticePresentationContext.swift`
  - now focuses on destination delivery instead of first-load effects and app-level observers
- `PracticeLifecycleContext.swift`
  - isolates first-load and root observer dependencies
- `PracticeLifecycleHost.swift`
  - owns first-load, sheet-dismiss, journal-filter, library-source-change, and last-viewed-library-game effect wiring
- `PracticePresentationContext.swift`
  - isolates sheet, reset-alert, and modal cleanup dependencies
  - keeps modal content wiring out of the route host
- `PracticeScreenRouteContent.swift`
  - owns route body composition for group dashboard, journal, insights, mechanics, and settings
  - now resolves explicit per-route dependency seams instead of closing over root-screen state directly
- `PracticeGroupDashboardContext.swift`
  - isolates the `GroupDashboard` route dependency surface
- `PracticeJournalContext.swift`
  - isolates the `Journal` route dependency surface
- `PracticeInsightsContext.swift`
  - isolates the `Insights` route dependency surface
  - isolates game/library/opponent/head-to-head concerns from the rest of iOS Practice orchestration
- `PracticeMechanicsContext.swift`
  - isolates the `Mechanics` route dependency surface
- `PracticeSettingsContext.swift`
  - isolates the `Settings` and IFPA-profile dependency surface
- `PracticeGameWorkspaceContext.swift`
  - isolates the `Game` route dependency surface from the rest of the Practice screen
- `PracticeGameWorkspaceState.swift`
  - groups `Game` route transient UI state into one explicit seam
- `PracticeGameWorkspace.swift`
  - now builds an explicit game-workspace context instead of passing raw store and bindings directly into the section view
- `PracticeGameWorkspaceSubviews.swift`
  - owns the `Summary`, `Input`, and `Log` workspace subviews so the main game route file no longer renders those panels inline
- `PracticeGameEntrySheets.swift`
  - owns the `Score`, `Note`, and task-entry sheets so the main game route file no longer embeds modal form implementations inline
- `PracticeTypes.swift`
  - now defines explicit `PracticeRoute` and `PracticeSheet` enums
  - still does not fully encode every Practice drill-in and sub-surface as one canonical product contract

Android current wiring:
- `PracticeScreen.kt`
  - now focuses on high-level state derivation and route-context assembly
  - builds dedicated contexts for `Home`, `IFPA Profile`, `GroupDashboard`, `GroupEditor`, `Journal`, `Insights`, `Mechanics`, `Settings`, and `Game`
  - coordinates route changes, back behavior, and drill-ins
- `PracticeScreenActions.kt`
  - owns shared root navigation, selection, quick-entry, drill-in, reset, and import helpers
- `PracticeLifecycleHost.kt`
  - owns initial load, back handling, observer sync, and route-triggered effects
- `PracticeDialogHost.kt`
  - now consumes `PracticePresentationContext.kt` instead of taking a long raw parameter list
- `PracticeScreenState.kt`
  - now groups state into navigation, journal, game, quick-entry, presentation, insights, and mechanics substate objects
  - still owns a broad UI-state surface, but the ownership boundaries are more explicit than before
- `PracticeScreenRouteContent.kt`
  - cleanly maps route to section composable
  - no longer relies on a generic shared route-content context; primary routes now resolve explicit contexts directly
- `PracticeStore.kt`
  - still owns too many persisted and derived concerns at once: notes, scores, groups, settings, analytics, and resource/game loading
- `PracticeLeagueIntegration.kt`
  - owns league-target loading, league-player discovery, league CSV import, and head-to-head comparison for Android Practice

## Target ownership model

Practice should be normalized into four ownership buckets on both platforms:

1. Route state
   - current route
   - route history/path
   - selected game identity
   - drill-in payloads such as selected rulesheet/playfield target
2. Dialog and transient presentation state
   - quick-entry sheet visibility and preset
   - group editor/date picker visibility and editing target
   - reset confirmation and name-prompt visibility
   - journal editor selection
3. Route-local drafts
   - game note draft
   - journal selection/edit mode
   - insights comparison opponent and loading state
   - mechanics form draft values
4. Store/domain state
   - persisted practice log, scores, groups, settings, and sync state
   - game/resource loading and fallback resolution
   - analytics, summaries, and derived projections

Modernization goal:
- iOS should gain an explicit route-state seam equivalent in role to `PracticeScreenState.kt`.
- Android should keep its route seam, but shrink the context and move more non-route logic out of `PracticeStore.kt`.
- Both platforms should describe the same ownership model even if the concrete types and files differ.

Current status:
- the first iOS route-state seam now exists as `PracticeScreenState.swift`
- iOS now also has explicit `PracticeRoute` and `PracticeSheet` enums for the main pushed and modal surfaces
- iOS non-game routes now resolve explicit per-route contexts instead of sharing one generic route-content bundle
- iOS home content now also resolves through an explicit `PracticeHomeContext.swift` seam
- `GroupDashboard`, `Journal`, `Insights`, `Mechanics`, and `Settings` now each have dedicated iOS context seams
- sheet and reset-alert presentation now also resolve through a dedicated iOS presentation context
- the next iOS step is to reduce how much `PracticeScreen.swift` still directly owns first-load orchestration and cross-route mutation helpers

## First implementation sequence

1. Normalize iOS route state
   - in progress: route identity, dialog flags, and transient UI state are now grouped in `PracticeScreenState.swift`
   - in progress: iOS now uses `PracticeRoute` for pushed surfaces and `PracticeSheet` for modal surfaces instead of separate sheet booleans
   - next: move remaining drill-in payloads and route orchestration into a cleaner explicit product-surface contract
2. Separate modal state from route state
   - quick entry, group editor, date picker, reset prompt, and journal editor should be tracked as presentation state rather than mixed into navigation decisions
3. Split route-local drafts out of the root screen
   - in progress: route content now resolves per-route contexts instead of pulling directly from root state
   - in progress: `GroupDashboard`, `Journal`, `Insights`, `Mechanics`, and `Settings` now have dedicated contexts
   - next: remaining coordination helpers and presentation orchestration should not all live in `PracticeScreen.swift` and `PracticeDialogHost.swift`
4. Reduce Android store surface
   - after route ownership is stabilized, decompose `PracticeStore.kt` by domain concern rather than adding more helpers to one file
5. Only then start UI/design-system cleanup
   - visual rework should follow a stable ownership model, not happen while route and draft state are still shifting

## Do not change yet

- do not redesign the Practice IA while route ownership is still unsettled
- do not merge route state into the domain store to "simplify" file count
- do not chase card styling parity before the navigation and draft-state contract is explicit
- do not add more boolean presentation flags on iOS as new surfaces are introduced

## First refactor seams

1. Extract a dedicated Practice route state model on iOS instead of storing all navigation and modal flags in `PracticeScreen.swift`.
2. Continue splitting Practice Game workspace into explicit subcomponents shared by contract:
   - remaining route-level helper ownership
   - note/resources contract hardening
   - remaining save-banner helper ownership
3. Mirror the same `Game` route boundaries on Android so the platforms are structurally comparable:
   - keep segmented workspace card outside `PracticeGameSection.kt`
   - keep note/resources and dialog wiring outside `PracticeGameSection.kt`
   - keep route-local transient state outside `PracticeGameSection.kt`
   - keep route-specific dependencies outside the shared route-content context
   - keep top-bar game/source selection outside the broader top-bar component
   - avoid shifting those responsibilities into `PracticeStore.kt`
   - next split should target the remaining shared top-bar/state coupling
3. Continue decomposing Android `PracticeStore.kt` into narrower state and mutation modules so it does not remain the second monolith after iOS screen cleanup.
4. Normalize quick-entry, journal editing, and group-editor launch state so both platforms describe the same ownership model in docs.

## 3.2 focus

1. inventory exact route flow and top-bar behavior
2. document game workspace section order and interaction contracts
3. identify duplicated logic between summary, journal, mechanics, and quick-entry flows
4. reduce responsibility concentration in `PracticeScreen.swift` and `PracticeStore.kt`
5. define the canonical Practice IA before visual modernization

## Initial findings

- Practice is a feature family, not a single screen.
- iOS currently has more ephemeral UI state living in the top-level screen file than Android.
- Android currently has a clearer route enum model, but its store remains large enough to become a second monolith if left unchecked.
- Practice should be the first feature-level modernization audit because small parity drifts here are easy to miss and compound quickly.
- Practice route parity should be defined at the product-surface level first, then the navigation architecture should be normalized.
- The Game route already has strong functional overlap across platforms; modernization should focus on section contracts, component boundaries, and state ownership rather than inventing new behavior.
- The first real Practice refactor should target state ownership, not visuals.
- The first code change should likely be an iOS route-state extraction, because it unlocks cleaner parity work without requiring immediate UI changes.
- The first code change has now landed: iOS Practice state is grouped into `PracticeScreenState.swift` without changing product behavior.
- The next code change has also landed: iOS Practice now uses explicit `PracticeRoute` and `PracticeSheet` models for the main pushed and modal surfaces, replacing the old route wrapper plus sheet booleans.
- The next code change after that has also landed: iOS route sections moved behind explicit dependency seams instead of closing over `PracticeScreen.swift` directly.
- The next code change after that has also landed: `GroupDashboard`, `Journal`, `Insights`, `Mechanics`, and `Settings` now each use their own route-specific context on iOS.
