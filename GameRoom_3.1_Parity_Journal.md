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
- summary card shows selected machine details (title/variant, location) plus the same read-only snapshot fields shown in `Machine View > Summary`
- summary card has no quick-action buttons; maintenance/logging actions stay in `Machine View > Input`
- snapshot metrics in both GameRoom Home summary and Machine View summary render in a 2-column grid to reduce vertical height
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

### Milestone 5
Status:
- completed on iOS

Outcome:
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

### Milestone 11
Status:
- completed on iOS

Outcome:
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

### Milestone 12
Status:
- completed on iOS

Outcome:
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

## Android 3.1 Parity Notes (Latest)

Latest Android parity pass aligned these accepted iOS behaviors:
- `Edit` heading/name flow:
  - settings heading `Edit GameRoom`
  - collapsible `Name` panel with `GameRoom Name` + persisted save
  - GameRoom venue rename flows through to store/library source naming
- Edit machine parity:
  - machine selector inline with variant pill dropdown (`None` + OPDB variant options)
  - inline editable ownership metadata (`Purchase Source`, `Serial Number`, `Ownership Notes`)
  - action row parity (`Save`, `Delete`, `Archive`)
- Variant pill parity:
  - dynamic-width pill with truncation after `Premium` length
  - visible on selected summary, home tiles/list rows, and machine view title
- Log/edit parity:
  - swipe edit/delete enabled on timeline rows
  - selected-entry detail uses fixed-height container to avoid list jump
  - edit flow supports date (`YYYY-MM-DD`) and persists `occurredAt`
  - media log rows open linked media directly
- Media parity:
  - delete uses attachment+linked-event removal behavior
  - media edit flow added (caption + linked event notes)
- Store parity:
  - added `updateVenueName`
  - extended `updateMachine` with ownership metadata fields
  - extended `updateEvent` to update event date/time
  - added `updateAttachment` and `deleteAttachmentAndLinkedEvent`
  - issue open/resolve event linkage now carries `linkedIssueID`
- Catalog/edit-add parity:
  - catalog loader now carries manufacturer metadata (`isModern`, `featuredRank`) and grouped ordering inputs for filter behavior
  - add-machine filtering remains full-catalog and optional-manufacturer (no selection = search all)
- Pinside import parity hardening:
  - Android import service now mirrors iOS input/URL validation semantics and error taxonomy
  - profile URLs without `/collection/...` now normalize to `/collection/current`
  - Android direct fetch now classifies Cloudflare challenge pages and retries through `r.jina.ai` fallback before failing import
  - fallback only bypasses retry for fatal states (`user not found`, `private collection`, invalid input/url)
  - slug extraction and import record generation remain identical to iOS expectations (`slug` fingerprint, group-map title fallback, slug-derived variant)
- GameRoom log swipe-row parity (Android Practice match):
  - replaced `SwipeToDismissBox` interaction with Practice-style left-drag reveal row actions
  - action rail now matches Practice contract (`Edit` + `Delete`, right-side reveal, single revealed row at a time)
  - row tap behavior matches Practice (tap closes revealed row first, otherwise selects row)
  - row chrome parity added (rounded container, reveal-fade background/border treatment)
- GameRoom home tile-card visual parity (Android Practice-inspired):
  - mini cards now mirror Practice mini-card image treatment (surface container, soft outline, full-image crop, and matching vertical gradient/shadowed title style)
  - selection highlight is now a tight outer ring just outside the card edge rather than an expanded padded highlight region
  - selected mini-card ring color is fixed to bright light blue for stronger active-state visibility
  - attention indicator dot now has additional shadow/contrast treatment so status color remains readable over bright translite art
  - GameRoom-specific signals remain intact (`attention` dot and variant pill)
- GameRoom machine log typography/spacing parity (Android Practice-inspired):
  - log row content now uses Practice journal summary/timestamp typography contract (`bodySmall` summary styling + `labelSmall` timestamp/meta)
  - row content spacing now matches Practice (`8dp` horizontal, `4dp` vertical, `2dp` line spacing)
  - selected-entry detail panel now uses Practice-aligned text scales and timestamp formatting for visual consistency
- GameRoom machine-view segmented selector parity:
  - `Summary / Input / Log` selector now uses the same `SingleChoiceSegmentedButtonRow` + `SegmentedButton` structure as Android Practice game view
  - selection styling and hit targets now follow the same Material segmented-control behavior used in Practice
- Pinside import matcher hardening (Android):
  - scoring now includes a slug-derived title signal (`pinside_slug` normalized without variant suffixes) to anchor matches to intended machine groups
  - prevented degenerate broad matches from empty/noisy titles by only applying contains/token title scoring when normalized raw title is non-blank
  - intended effect: avoid bad fallback matches like unrelated classic titles when modern slugs (for example King Kong) are present
- Library source visibility fix for GameRoom (Android):
  - Library source picker no longer hides non-pinned sources when pinned sources exist
  - pinned sources still appear first, but all available sources (including GameRoom venue) are now selectable in the filter list
- Pinside import exact-slug resolver parity hardening (Android):
  - catalog loader now stores OPDB `slug -> (group, practice identity, variant)` mappings
  - import draft generation now prioritizes exact OPDB slug hits before fuzzy scoring
  - exact slug hits are promoted to selected match immediately (high confidence), with fuzzy suggestions retained as alternates
  - intended effect: prevent false matches (for example `King Kong: Myth of Terror Island` drifting to unrelated titles)
- Library fallback overlay robustness (Android):
  - SQLite seed-library fallback path now injects GameRoom overlay from persisted GameRoom state (same source id `venue--gameroom`)
  - GameRoom source is now preserved in Library even when merged OPDB path is unavailable/fails
  - overlay entries carry venue naming, area/group/position ordering, and template-linked media/rulesheet/art where available
- Import parity + resolver hardening follow-up (Android):
  - scoring behavior moved closer to iOS baseline (raw-title + variant scoring) to reduce cross-platform ranking drift
  - deterministic pre-ranking now injects:
    - exact title-normalized match candidate
    - slug-derived catalog candidate (including normalized slug keys that tolerate manufacturer/year/variant suffix differences)
  - collection fetch flow now prefers `r.jina.ai` fallback results when available (more stable collection-only slug extraction) and uses direct fetch as backup
  - variant extraction now recognizes anniversary-style slugs (for example `70th-anniversary`) and defaults imported variant accordingly
- Library source visibility resilience (Android):
  - GameRoom source is now force-preserved during source-state filtering whenever GameRoom games are present
  - this avoids stale source-state edge cases suppressing GameRoom from Library selector
- Library overlay flow fix (Android):
  - removed early-return path in merged catalog resolution that bypassed GameRoom overlay when imported sources were empty
  - result: GameRoom can now appear in Library without requiring any imported venue/manufacturer source to exist first
- Import parser precision fix (Android):
  - slug extraction now uses collection-context patterns first (links associated with `View game on Pinside` / collection heading structure), then falls back to broad machine-link parsing only if strict extraction finds nothing
  - this reduces false positives from non-collection machine links leaking into import rows
- Import recommendation de-duplication (Android):
  - import suggestion list now deduplicates by display title, not only catalog id
  - avoids duplicate-title recommendations (for example multiple `Cabaret` groups) cluttering row match picks
- Import search parity reset (Android -> iOS-equivalent):
  - draft-row recommendation path now matches iOS behavior: suggestions are derived only from scored `rawTitle + variant` candidates
  - removed Android-only pre-ranking hooks from suggestion selection path (slug/title pre-injection and title-based dedupe)
  - direct Pinside fetch now remains the primary path (fallback only on failure), matching iOS preference order
  - slug extraction reverted to iOS-equivalent broad machine-link regex behavior
- iOS import variant parsing alignment:
  - Pinside slug parsing now prioritizes anniversary token detection (for example `70th-anniversary`) before generic variant suffix matching
  - imported raw variant can now default to `70th Anniversary` for relevant slugs (improves Godzilla 70th preselection/match behavior)
- Catalog ID case-collision parity fix (Android):
  - identified OPDB group-id collision where IDs differ only by case (for example `GEL0V` vs `GEL0v`)
  - Android catalog lookup now requires exact-case match first and only allows case-insensitive fallback when unambiguous
  - owned-machine duplicate detection now uses exact catalog-id equality (matching iOS behavior)
  - group-map loader now reads JSON values by raw key before normalizing slug-key casing (avoids silent misses on mixed-case keys)
  - this prevents wrong-machine resolution in import review (for example `King Kong: Myth of Terror Island` drifting to `Cabaret`)
- Machine-view hero image fit parity (Android):
  - GameRoom Machine View header now uses `ConstrainedAsyncImagePreview` (same image renderer contract as Library game view screenshot section)
  - replaced fixed-height `ContentScale.Crop` hero with dynamic-aspect `ContentScale.Fit` preview to preserve full OPDB image framing
  - candidate URL order remains variant-aware (`primary large`, `primary`, `playfield large`, `playfield`)
- Edit/Add Machine result window parity (Android):
  - `Settings > Edit GameRoom > Add Machine` now renders search results inside a constrained scroll box (fixed max height) instead of an unbounded column
  - results now use an iOS-style sliding window model with `Show Previous 25` and `Show Next 25` controls inside the results list
  - window range label now reports `Showing X-Y of Z` and query/manufacturer filter changes reset windowing to the first page
  - next-page loading keeps a bounded rendered window (max 75) to avoid growing the in-memory/rendered list indefinitely
- Area controls polish parity update:
  - area list rows now render as single-line labels in both apps: `Area Name (Area Order)`
  - Android Areas input row now mirrors iOS proportions: `Area Name` field remains wide/flexible while `Area Order` is constrained narrower
  - Android area delete action in Areas list now uses a compact trash icon button instead of text `Delete`
- Archive filter control parity (Android):
  - Archive filter selector (`All / Sold / Traded / Archived`) now uses the same segmented button bar pattern as other Android GameRoom selectors (`Summary / Input / Log`)
  - Archive settings now shows the same archive count line pattern as iOS (`Archived machines: N`, scoped to the current filter)
- Collection list mini-card visual parity update:
  - iOS GameRoom `Collection > List` rows now render as artwork-backed mini-card rows (same visual language as tile mini cards: full-bleed image + readability gradient + overlay text + variant pill)
  - Android `Collection > List` now mirrors the same mini-card treatment and no longer uses the old plain row + thumbnail style
  - Android list rows now place the attention/status light on the left (matching iOS list placement)
  - Android list rows no longer show a trailing chevron arrow
  - Android list rows removed the old selected-row buffer/divider styling and now use compact card spacing with a tight selection ring
- Add Machine window paging scroll-restore parity (Android):
  - `Show Previous 25` / `Show Next 25` in `Settings > Edit GameRoom > Add Machine` now preserve the visible position anchor (same behavior as iOS fixed flow)
  - implemented keyed lazy-list restore to keep the previously top-visible game aligned after window shifts, instead of snapping to list top
- Collection selector + row density polish:
  - collection layout selector label `Tiles` has been renamed to `Cards` on both iOS and Android
  - list-row cards in both iOS and Android were reduced in vertical height/padding for a tighter, text-fitted list presentation
  - Android card view no longer renders location text (`area/group/position`) on cards; location remains visible in list view rows
  - Android card title typography was increased for better prominence now that location is removed from card view
- Add-machine + area action button polish:
  - Add-machine action button in GameRoom settings (`Add Machine`) now uses a plus icon in both iOS and Android instead of text `Add`
  - Android Areas delete action now renders the trash icon inside an outlined button container for clearer affordance
- Machine View header + summary media parity follow-up:
  - Android `Machine View` now uses `Machine View` in the top row and renders the machine metadata block directly under hero art (title, variant pill, and location/group/position/status line), matching iOS structure
  - Android `Summary` now always renders the Media section; when empty it explicitly shows `No media attached yet.` instead of hiding the section
- Log Issue media attachment parity (iOS + Android):
  - iOS `Log Issue` sheet now supports inline `Add Photo` and `Add Video` actions using Photos picker, shows selected attachments in-sheet, and saves them with the issue
  - Android `Log Issue` sheet now supports inline `Add Photo` and `Add Video` actions using native document pickers, shows/removes selected attachments in-sheet, and saves them with the issue
  - for both platforms, issue-sheet attachments are persisted as issue-owned attachments and emit corresponding media timeline events linked to the created issue
- Android input action clean-up + add-media affordance:
  - removed `Issue Photo` and `Issue Video` quick actions from the Android `Input > Issue` action grid (Issue actions are now `Log Issue` and `Resolve Issue`)
  - Android `Input > Ownership / Media > Add Photo/Video` sheet now includes explicit `Add Photo` and `Add Video` buttons that immediately launch the native picker flow (instead of relying on Save with blank URI)
- iOS `Log Issue` media row layout refinement:
  - media controls are no longer wrapped in a separate `Media` section
  - `Add Photo` and `Add Video` now appear immediately after `Diagnosis / Notes`
  - both controls are now equal-width row buttons with balanced spacing for consistent visual weight
- iOS `Log Issue` subsystem menu default:
  - default subsystem for new issue entries is now the first option (`Flipper`) instead of `Other`
  - prevents the menu from initially opening anchored at the bottom of the subsystem list
- Android log selected-entry actions:
  - removed `Edit` and `Delete` buttons from the selected-entry detail card in `Machine View > Log`
  - edit/delete remain available from row-level swipe actions in the timeline list
- Android machine-header typography alignment:
  - `Machine View` metadata row now keeps the variant pill directly after the machine name (left-aligned cluster) instead of pushing the pill to the far right edge
  - location line under the title now uses smaller subtitle-style typography (`labelSmall`) to match iOS footnote/subtitle hierarchy
- Android summary spacing/layout parity polish:
  - `GameRoom Home > Selected Machine` now mirrors iOS hierarchy more closely:
    - stronger title row hierarchy
    - smaller location subtitle text
    - explicit `Current Snapshot` subheading above metrics
    - optional `Purchase (raw)` line shown in subdued subtitle style
  - `Machine View > Summary` now uses separate snapshot and media cards (matching iOS section framing) instead of one dense combined block
  - snapshot metric typography now matches iOS-style cadence better (`labelSmall` labels + `bodySmall` values with truncation)
- Android GameRoom summary readability follow-up:
  - increased `Location` line typography by one step in:
    - `GameRoom Home > Selected Machine`
    - `Machine View` metadata block
  - increased `Current Snapshot` metric typography by one step:
    - metric label: `labelSmall -> bodySmall`
    - metric value: `bodySmall -> bodyMedium`
- Android back-button parity normalization:
  - introduced shared `AppBackButton` in common UI and routed Android back-arrow surfaces through it
  - unified back-arrow appearance across `Practice`, `GameRoom`, and `Library` game/detail surfaces (including rulesheet/playfield overlays)
  - result: a single back-button style across Android app navigation contexts
- Android GameRoom collection typography follow-up:
  - increased machine-name typography by one step in `Collection > Cards` (tile mini cards), matching the list-view readability bump
- Android GameRoom home title alignment:
  - GameRoom venue title now matches Practice home title hierarchy/placement (`fontSize 20sp`, semibold, single-line ellipsis, left inset parity)
