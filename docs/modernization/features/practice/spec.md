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
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreen.swift` still owns a large amount of route state, modal state, preference state, and navigation wiring.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift` is a major UI hotspot.
- Store responsibilities are partially split across helper files, but screen orchestration is still heavily centralized.
- Route model is currently split between `PracticeNavRoute` and multiple boolean-driven sheets/destinations.

Android:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreen.kt` is better separated at the route layer than iOS.
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt` remains the main responsibility concentration point.
- Persistence and codec work has already been separated more clearly than on iOS.
- Route model is more explicit via `PracticeRoute`, but still mixed with modal flags inside `PracticeScreenState`.

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

- iOS: presented as a sheet, not a navigation route
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

- iOS models only three explicit navigation cases (`destination`, `game`, `ifpaProfile`) and pushes other surfaces through booleans/sheets.
- Android models most primary surfaces as explicit routes.
- Product behavior is broadly aligned, but the route architecture is not.
- Modernization should normalize this into one explicit route contract per product surface, regardless of platform implementation details.

## Current state ownership snapshot

iOS current split:
- `PracticeScreen.swift`
  - route path
  - sheet/dialog presentation flags
  - quick-entry remembered selections
  - player/profile form state
  - mechanics form state
  - journal edit-selection state
  - head-to-head loading state
  - viewport/layout state
- `PracticeStore`
  - persisted practice domain state
  - game/resource loading
  - analytics and derived summaries
  - journal mutation helpers
- Result:
  - too much ephemeral route/UI state still lives in the root screen

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

## First refactor seams

1. Extract a dedicated Practice route state model on iOS instead of storing all navigation and modal flags in `PracticeScreen.swift`.
2. Split Practice Game workspace into explicit subcomponents shared by contract:
   - summary
   - input
   - log
   - note
   - resources
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
