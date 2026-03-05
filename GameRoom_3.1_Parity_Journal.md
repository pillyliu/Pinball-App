# GameRoom 3.1 Parity Journal

This file records the accepted iOS-first contract for `3.1-gameroom`.

Companion planning source:
- `/Users/pillyliu/Documents/Codex/Pinball App/GameRoom_3.1_Master_Plan.md`

Purpose:
- define the canonical feature shape for `GameRoom`
- preserve naming, structure, and behavior choices for Android parity
- avoid cross-platform drift in routes, models, sorting, and interaction patterns
- record final implemented behavior only (not superseded experiments)

Branch:
- `codex/3.1-gameroom`

Lead client:
- iOS is the reference implementation

Parity rule:
- iOS may explore first
- once behavior is accepted, it becomes the Android parity target unless there is an explicit platform-specific exception

## Canonical Naming

Root tabs:
- `League`
- `Library`
- `Practice`
- `GameRoom`
- `Settings`

League nested destination:
- `About Lansing Pinball League`

GameRoom routes:
- `GameRoom Home`
- `Machine View`
- `GameRoom Settings`

GameRoom Settings selector labels:
- `Import`
- `Edit`
- `Archive`

GameRoom Settings section headings:
- `Import from Pinside`
- `Edit Machines`
- `Machine Archive`

Machine View subviews:
- `Summary`
- `Input`
- `Log`

## Confirmed Product Rules

GameRoom:
- is a root tab
- represents a user-owned collection layer over the canonical catalog
- tracks physical machine instances, not just titles
- allows the same title to exist multiple times across ownership history as separate instances

Library:
- keeps current behavior unchanged
- may later expose GameRoom as a custom source/venue
- when GameRoom is exposed as a custom venue source, its venue name comes from user-configurable GameRoom settings (defaults to `GameRoom`)
- Library source menu always includes `GameRoom` when present so it is selectable even if not pinned in the quick source list
- GameRoom-backed library rows hydrate OPDB media/rulesheet fields from best matching catalog entries (variant-aware) so Library cards/detail can show images and rulesheet resources for owned machines
- Hydration copies both remote fields and local asset-path metadata (`playfield`, `rulesheet`, `gameinfo`) from the matched catalog template so GameRoom rows retain resource availability even when a game only has local asset references
- Hydration also copies `videos` from the matched catalog template so Library `Video References` in GameRoom entries matches normal catalog game view behavior
- For GameRoom rows in Library, translite/primary image resolution is variant-aware against OPDB machine records (by selected owned-machine variant) instead of relying solely on merged Library template order
- For non-GameRoom legacy venue rows, when a row already specifies a variant (for example `Premium`/`LE`) but carries a group-level or ambiguous machine ID, Library resolution should choose the variant-matching OPDB machine record within that group for translite/primary image selection
- Playfield source labeling in Library uses resolved source semantics:
  - `Playfield (OPDB)` for OPDB-hosted assets
  - `Local` for local/curated assets (including pillyliu-hosted playfields and any local path-backed assets), and local paths take precedence over inherited OPDB labels
- Library detail always renders a `Rulesheet:` row; when no rulesheet resource exists it shows `Unavailable` as a non-interactive button

Sorting:
- `areaOrder` belongs to the area definition, not the machine
- machine sort order is:
  - `areaOrder`
  - `area`
  - `group`
  - `position`
  - fallback title/id

GameRoom Home:
- has a selected-machine summary card at the top
- has a collection card below it
- supports list/tile toggle
- keeps panel widths consistent with the app; cards span the available content width
- uses compact 2-column mini cards in tile mode
- first tap selects/highlights a mini card
- second tap on the selected card opens `Machine View`
- summary card shows selected machine details (title/variant, location, issue/due/last service line)
- selected summary title row can show a right-aligned variant pill tag (`LE`, `Premium`, `Pro`) when detectable

Mini-card status dots:
- red = open issue / urgent
- yellow = due soon
- green = healthy / recently serviced
- gray = archived or incomplete

Machine View:
- shows the machine image at the top, matching existing game-view patterns
- uses `Summary / Input / Log`
- keeps `Summary` read-only
- puts all creation actions under `Input`
- supports Practice-like log editing from `Log`

Media:
- attaches to issues/events
- is surfaced back onto the machine summary with source context

Pinside import:
- v1 is import-once
- public current collection only
- user confirmation is final
- canonical names defer to OPDB/app catalog
- store both raw imported date text and normalized first-of-month date
- match confidence values are:
  - `high`
  - `medium`
  - `low`
  - `manual`

## Data Model Contract

Persisted root state:
- `GameRoomPersistedState`

Current schema version:
- `1`

Current iOS storage key:
- `gameroom-state-json`

Core entities:
- `GameRoomArea`
- `OwnedMachine`
- `OwnedMachineSnapshot`
- `MachineEvent`
- `MachineIssue`
- `MachineAttachment`
- `MachineReminderConfig`
- `MachineImportRecord`

Important enum names:
- `OwnedMachineStatus`
- `GameRoomAttentionState`
- `MachineEventCategory`
- `MachineEventType`
- `MachineIssueStatus`
- `MachineIssueSeverity`
- `MachineIssueSubsystem`
- `MachineAttachmentOwnerType`
- `MachineAttachmentKind`
- `MachineReminderTaskType`
- `MachineReminderMode`
- `MachineImportSource`
- `MachineImportMatchConfidence`

Current `OwnedMachineStatus` values:
- `active`
- `loaned`
- `archived`
- `sold`
- `traded`

Current `GameRoomAttentionState` values:
- `red`
- `yellow`
- `green`
- `gray`

Snapshots:
- are derived in the store
- are not the canonical source of truth
- currently derive from:
  - events
  - issues
  - machine status

Current derived snapshot fields:
- last glass clean
- last playfield clean
- last balls clean/replace
- last pitch check
- current pitch value / measurement point
- last level
- last flipper service
- last general inspection
- last service date
- open issue count
- due task count placeholder
- attention state

Area rule:
- `areaOrder` is stored on `GameRoomArea`
- machines reference an area by `gameRoomAreaID`
- machines do not own independent `areaOrder`

Import date rule:
- `MachineImportRecord` carries both:
  - `rawPurchaseDateText`
  - `normalizedPurchaseDate`

## Milestone Outcomes

### Milestone 1
Status:
- completed on iOS

Outcome:
- removed the root `About` tab
- moved LPL about content under `League`
- added a footer card on League home that opens `About Lansing Pinball League`

Files:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/app/ContentView.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/info/AboutScreen.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/league/LeagueScreen.swift`

### Milestone 2
Status:
- completed on iOS

Outcome:
- added root `GameRoom` tab
- added `GameRoom Home`
- added routed `GameRoom Settings`
- added placeholder `Machine View`
- `GameRoom` sits after `Practice` in the root tab order
- `GameRoom Settings` uses a single-row segmented selector matching the interaction style of Practice segmented views
- `GameRoom Settings` relies on the navigation title only and does not duplicate an in-page page header

Current UI contract:
- `GameRoom Home` uses a top-right `gearshape` button
- tile mode uses compact 2-column mini cards
- tile shape is short and visually aligned with Practice mini cards
- status dots live in the upper-right of the mini card
- machine title overlays near the lower-left of the tile
- `GameRoom Settings` includes editable `GameRoom Name` (venue name) with explicit save action
- `Edit` section heading is `Edit GameRoom`
- GameRoom naming is under `Edit GameRoom` as the first collapsible block:
  - header: `Name`
  - text field placeholder: `GameRoom Name`
  - `Save` action persists venue name

Files:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/app/ContentView.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomScreen.swift`

### Milestone 3
Status:
- completed on iOS

Outcome:
- added GameRoom model and persistence foundation
- persistence is local-first
- GameRoom store owns:
  - state loading
  - state saving
  - active/archive partition helpers
  - area-aware machine sorting
  - derived snapshot recomputation

Files:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomModels.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomStateCodec.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomScreen.swift`

### Milestone 4
Status:
- completed on iOS

Outcome:
- `Edit` is now a real inline management surface inside `GameRoom Settings`
- `Edit` contains these panels in order:
  - `Add Machine`
  - `Areas`
  - `Edit Machines`
- add-machine search is backed by the full bundled OPDB catalog, not the currently enabled Library source subset
- manufacturer filter is optional; no selection means search all
- manufacturer grouping is:
  - `Modern`
  - `Classic Popular`
  - `Other`
- area creation/editing stays inline
- area name and area order share one horizontal row
- the action row below contains `Save` and `Edit`
- tapping an existing area loads it back into the inline controls for editing
- deleting an area clears linked machine area assignments
- `Edit Machines` machine selection now uses an inline machine-name dropdown menu
- machine selector row keeps machine-name dropdown and variant selector inline
- variant selector is rendered as a variant pill (defaults `None`) and opens a dropdown menu on tap
- collapsible `Edit Machines` header includes active collection count: `Edit Machines (N)`
- machine-name dropdown options are grouped by area (ordered by `areaOrder` then area name) for faster scanning on larger collections
- selected machine details edit inline on the same page
- archive remains machine-instance based
- archive status can be set from inline machine editing
- machine editor action row uses `Save`, `Delete`, `Archive` (in that order; `Archive` shown when applicable)
- machine editor includes explicit variant selection for machine instances (group add + instance variant assignment)
- variant selector is inline on the machine title row in Edit Machines
- add machine, areas, and edit machines are collapsible sections inside Edit

Add Machine result-list contract:
- uses the full OPDB catalog dataset for filtering
- remains machine-group oriented for add selection
- uses a short internal scroll viewport
- does not render the entire filtered result set at once
- current intended paging model is explicit previous/next paging rather than automatic mutation while dragging
- page size target is `25`
- search/filter changes reset paging back to the start

Files:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogLoader.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomScreen.swift`

### Milestone 5 (In Progress)
Status:
- in progress on iOS

Current outcome:
- `GameRoom Home` now renders real collection data from `GameRoomStore` instead of placeholder cards
- collection supports `Tiles` and `List` layouts via segmented toggle
- tile/list rows are interactive:
  - first tap selects a machine
  - tapping the selected machine opens `Machine View`
- selected-summary panel is wired to real machine/snapshot data
- variant pills (`LE`, `Premium`, `Pro`) can render from either explicit variant data or title fallback
- when a machine instance has an explicit saved variant, the pill uses that exact variant text (with truncation) and only falls back to inferred labels when no explicit variant exists
- list rows use a clear selected-state outline highlight; selected tiles also use accent outline
- variant pills size to their content text (no forced max-width cap)
- machine-view navigation now passes selected machine id from home
- machine view is now machine-specific with segmented `Summary / Input / Log` shell (replacing generic placeholder)
- `Machine View > Input` actions are now wired to entry sheets and persistence instead of placeholders
- input sections stay grouped as:
  - `Service`
  - `Issue`
  - `Ownership / Media`
- input buttons are full-width in a 2-column grid (Practice-like density)
- each input action creates real records:
  - service actions append `MachineEvent` entries (`glass`, `playfield`, `balls`, `pitch`)
  - issue logging creates both `MachineIssue` + linked `MachineEvent`
  - issue resolution updates issue status + appends a linked resolution event
  - ownership update appends ownership events (`purchased/moved/loaned/returned/listed/sold/traded/reacquired`)
  - media input appends media events and stores event-linked attachments (`photo`/`video` + URI/caption)
- `Log Plays` input action added:
  - opens a half-sheet entry form (`Date`, `Total Plays`, optional notes)
  - each save sets the machine total play count (absolute value), not an additive increment
  - persists as a custom machine event with `playCountAtEvent` storing the logged total
- service input now includes:
  - `Level Machine`
  - `General Inspection`
  in addition to existing service actions
- ownership/media input now includes:
  - `Install Mod`
  - `Replace Part`
  as structured event-entry sheets (with part/mod details)
- snapshot fields now update from newly created service events via recompute
- snapshot now tracks `currentPlayCount` derived from accumulated play-log events
- `dueTaskCount` is now interval-based instead of placeholder:
  - if a machine has explicit `MachineReminderConfig` rows, those are used
  - if a machine has no reminder configs, iOS applies default reminders:
    - `glassCleaned`: every 30 days
    - `playfieldCleaned`: every 90 days
    - `ballsReplaced`: play-based every 5000 plays
    - `pitchChecked`: no timer default
    - `machineLeveled`: no timer default (same timer behavior as pitch)
    - `generalInspection`: every 45 days
  - configured date-based tasks with no prior matching event are treated as due
- `playBased` reminder mode is now active and evaluates against current machine play count
    - baseline is the play count observed at the last matching maintenance event for that task
    - if no prior matching maintenance event exists, baseline is `0`
    - task is due when `(currentPlayCount - baseline) >= intervalPlays`
  - `manualOnly` reminder mode is not counted
  - due counting applies to `active` and `loaned` machines only
- machine summary now surfaces:
  - last level date
  - last general inspection date
- attention-state rules now include due-task impact:
  - `gray` for archived/sold/traded
  - `red` for open high/critical issues
  - `yellow` for open non-critical issues or any due tasks
  - `green` otherwise
- `Machine View > Log` now supports selected-entry detail viewing:
  - tapping a log row selects it
  - selected entry shows full captured details in a detail card above timeline (notes, consumables, parts/mod, pitch fields, type/category)
  - swipe edit/delete behavior remains unchanged
- GameRoom entry/edit sheets use half-height detents (`medium` + `large`) with drag indicator, matching Practice interaction intent
- for GameRoom forms with enum pickers (`severity`, `subsystem`, `ownership event`, `issue selector`), picker style is explicit menu for reliable selection in sheet presentation
- archive settings now include filter segments:
  - `All`
  - `Sold`
  - `Traded`
  - `Archived`
- archived machine rows are openable and route into historical `Machine View` for that machine instance
- Library extraction overlays a GameRoom venue source when active/loaned GameRoom machines exist:
  - source id: `venue--gameroom`
  - source name: `GameRoom`
  - source type: `venue`
  - machine rows are derived from GameRoom instances with area/group/position mapping
- GameRoom image rendering is now variant-aware:
  - home mini cards load OPDB primary image candidates for each owned machine
  - home mini cards now use the same image treatment as Practice mini cards (black base + full-bleed fill + identical readability gradient stops)
  - Machine View header loads OPDB image candidates for the selected machine
  - Machine View header now uses the same preview component pattern as Library/Practice game view (`ConstrainedAsyncImagePreview`, `4:3` cap, no padding)
  - image resolution priority is:
    - exact saved variant within the machine's catalog group
    - exact canonical practice identity
    - other images in the same catalog group
    - same-title fallback matches

### Milestone 11 (In Progress)
Status:
- in progress on iOS

Current outcome:
- `Import` in `GameRoom Settings` is now a real flow (no longer placeholder)
- input accepts either:
  - Pinside username
  - public Pinside collection URL
- fetch step parses public collection machine slugs from the Pinside page
- slug-to-title resolution uses bundled `pinside_group_map.json` (OPDB-aligned naming preference)
- each imported row receives:
  - raw title
  - inferred variant from slug (when detectable)
  - candidate catalog matches with confidence scoring
- import review supports confidence badges and filter mode:
  - `All`
  - `Needs Review` (non-high confidence, unmatched, or duplicate-warning rows)
- review step supports per-row override:
  - choose alternate suggested match
  - clear match
  - select variant (including `None`) from OPDB-derived variant options for the selected group
- duplicate warnings are shown before import for:
  - already imported fingerprints
  - existing owned machine collisions (same catalog group + variant)
- confirm step imports selected rows into owned machines and writes `MachineImportRecord`
- duplicate safeguards on import:
  - skip rows already imported by fingerprint
  - skip rows that already exist in owned machines for same catalog group + variant
- result summary reports imported vs skipped counts
- import input supports return-key submit (`Go` triggers fetch)
- import failure messaging now distinguishes:
  - user/profile not found
  - private/unavailable collection
  - generic parse failure
- purchase date visibility:
  - import review captures raw text and normalized first-of-month
  - machine summary displays normalized purchase date and raw imported date text when present

### Milestone 12 (In Progress)
Status:
- in progress on iOS

Current outcome:
- `Add Photo/Video` input now supports real media picking from Photos library
  - photo picker for photo mode
  - video picker for video mode
- picked assets are copied into app support storage (`GameRoomMedia`) and attachment URI is auto-filled
- media is shown in `Machine View > Summary` as a 2-column square thumbnail grid
  - thumbnails are center-cropped squares (Photos-style density)
  - video thumbnails render with a play indicator overlay
- photo open behavior matches playfield-view interaction:
  - full-screen image route
  - tap to show/hide chrome
  - pinch zoom
  - double-tap zoom
  - swipe-back interactive navigation gesture
- tapping `Photo Added` / `Video Added` log events opens linked media directly
- media tiles expose context actions:
  - `Edit Media`
  - `Delete Media`
- `Edit Media` allows updating:
  - attachment caption
  - linked event notes
- `Delete Media` removes:
  - selected attachment
  - linked media event
  - other attachments linked to that same event (if present)
- sheet interaction reliability for media picking:
  - keeps half-sheet detent behavior (`medium` + `large`)
  - clears text focus and applies a short deferral before presenting the picker

Files:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomScreen.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogLoader.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideImport.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryDataLoader.swift`

## Android Parity Targets

Android should mirror:
- root tab names and order
- League footer-card route for LPL About
- `GameRoom Home / Machine View / GameRoom Settings`
- segmented `Import / Edit / Archive` settings selector
- no duplicate in-page settings header when the app bar already shows the title
- compact 2-column tile presentation for GameRoom tile mode
- selected-summary-above-collection layout
- tap behavior contract:
  - first tap selects
  - second tap on selected opens machine view
- summary panel shows selected machine details and snapshot-derived status line
- right-aligned variant pill tags where available (`LE`, `Premium`, `Pro`) on home summary/list rows
- clear selected-state outline highlight for list rows
- full-width panel behavior for GameRoom cards (no narrow, intrinsic-width cards)
- full-catalog add-machine search independent of current Library enabled-source state
- add flow remains machine-group oriented; instance variant is chosen in machine editing
- add-machine group representative selection is deterministic and not raw-file-order:
  - prioritize earliest release year within a group
  - then variant preference (`Premium`, `LE`, `Pro`, then others)
  - avoid defaulting modern commemorative variants (for example `30th Anniversary`) when original-run variants exist
- optional manufacturer filter with no selection meaning search all
- manufacturer grouping semantics:
  - modern
  - classic popular
  - other
- inline `Edit` surface rather than a separate edit route
- `Edit` panel order:
  - add machine
  - areas
  - edit machines
- `Edit Machines` includes a variant selector menu for physical-instance variant assignment
- one-line area-name/area-order controls with a separate `Save / Edit` action row
- area deletion behavior that clears linked machine area assignments unless intentionally changed on both platforms
- horizontal machine chip selector for choosing which owned machine to edit
- Practice-like machine-view structure and log editing behavior
- Practice-like input flow pattern where button taps open focused entry sheets and persist directly into timeline state

## Guardrails

Keep these rules aligned across platforms:
- do not move `areaOrder` onto machines
- do not let GameRoom naming drift from the canonical route/entity names above
- do not tie add-machine search to currently enabled Library sources
- do not make `Edit` a separate pushed settings subroute unless intentionally changed on both platforms
- do not persist snapshots as the primary source of truth

## Open TODOs

- evaluate whether machine-name dropdown should also support text search in addition to area grouping for very large collections
- variant-fidelity backlog (intentional deferral): decide if Practice and non-GameRoom venue rendering should move from OPDB-group defaults to per-variant identity/assets to avoid Pro vs Premium/LE strategy and playfield mismatches
