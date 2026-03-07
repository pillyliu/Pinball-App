# GameRoom 3.1 Android Parity Kickoff

Source of truth:
- `/Users/pillyliu/Documents/Codex/Pinball App/GameRoom_3.1_Parity_Journal.md`
- `/Users/pillyliu/Documents/Codex/Pinball App/GameRoom_3.1_Master_Plan.md`

Branch:
- `codex/3.1-gameroom`

Goal:
- implement Android with behavior and naming parity to accepted iOS 3.1 GameRoom behavior

## Parity Contract (Do Not Drift)

- Root tab names/order target:
  - `League`
  - `Library`
  - `Practice`
  - `GameRoom`
  - `Settings`
- Root `About` tab must not exist.
- `About Lansing Pinball League` is nested under `League`.
- GameRoom routes:
  - `GameRoom Home`
  - `Machine View`
  - `GameRoom Settings`
- GameRoom settings selector labels:
  - `Import`
  - `Edit`
  - `Archive`
- Machine view subviews:
  - `Summary`
  - `Input`
  - `Log`

## Android Current Status

- Android now has a full `gameroom` package and integrated routes in root navigation.
- Core GameRoom iOS file mapping is in place:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomModels.kt`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomStore.kt`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomCatalogLoader.kt`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomPinsideImport.kt`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt`
- Library integration hooks are implemented:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogStore.kt`

## Milestone Execution Order (Android)

### M1. Reclaim root tab + nested League About

Status:
- completed (Android)

Acceptance:
- no root `About` tab
- League home includes footer card `About Lansing Pinball League`
- tapping footer opens nested about destination in League stack

Primary files:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/MainActivity.kt`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/league/LeagueScreen.kt`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/info/AboutScreen.kt`

### M2. Add GameRoom shell

Status:
- completed (Android)

Acceptance:
- add root `GameRoom` tab after `Practice`
- route placeholders:
  - `GameRoom Home`
  - `GameRoom Settings`
  - `Machine View`
- top-right gear on GameRoom Home opens GameRoom Settings
- Settings has segmented selector: `Import / Edit / Archive` (single-row, inline content)

Suggested files:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/MainActivity.kt`
- new package:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/`

### M3. GameRoom data model + persistence

Status:
- completed (Android foundation)

Acceptance:
- Android equivalents to iOS entities:
  - `GameRoomArea`
  - `OwnedMachine`
  - `OwnedMachineSnapshot` (derived)
  - `MachineEvent`
  - `MachineIssue`
  - `MachineAttachment`
  - `MachineReminderConfig`
  - `MachineImportRecord`
- schema/versioned persistence keying
- `areaOrder` stored on area, not machine
- active/archive partition helpers + snapshot recompute

### M4. Settings Edit flows (manual setup)

Status:
- completed (Android implementation; QA pass pending)
- current outcome:
  - `Edit` heading now matches iOS naming: `Edit GameRoom`
  - `Edit` includes collapsible `Name` panel with `GameRoom Name` + `Save` wired to persisted venue name
  - `Edit` now renders real collapsible sections in-order: `Add Machine`, `Areas`, `Edit Machines`
  - Add Machine now loads OPDB catalog, supports search + optional manufacturer filter, and pages results in 25-row windows with explicit previous/next
  - manufacturer filter uses catalog manufacturer metadata (`isModern` + `featuredRank`) and grouped ordering (`modern`, `classic popular`, `other`)
  - Areas now supports create/update/delete with area-level `areaOrder`
  - Edit Machines now supports machine selection plus `Save`, `Delete`, `Archive` actions and inline status/area/group/position/variant editing
  - Edit Machines now includes ownership fields with persistence parity:
    - `Purchase Source`
    - `Serial Number`
    - `Ownership Notes`
  - machine selector row now mirrors iOS pattern:
    - machine dropdown inline with variant pill dropdown (`None` + OPDB variant options)

Acceptance:
- Edit panel order:
  - `Add Machine`
  - `Areas`
  - `Edit Machines`
- add-machine uses full OPDB catalog
- manufacturer filter optional (empty == search all)
- result paging strategy (25 page size, explicit prev/next)
- area name + order inline row with save/edit actions
- edit machine supports:
  - machine dropdown
  - inline variant pill menu with `None`
  - status selector
  - actions `Save`, `Delete`, `Archive`

### M5-M8. Home interaction + Machine View + logging + log editing

Status:
- completed (Android implementation; QA pass pending)
- current outcome:
  - GameRoom Home now renders from persisted store data (not hardcoded sample data)
  - Home has selected summary card above collection
  - summary metrics render in 2-column grid
  - collection now supports `Tiles`/`List` toggle
  - tile mode uses compact 2-column cards
  - list mode renders selectable rows with selected highlight/outline
  - first tap selects, second tap opens Machine View route
  - attention status dots render on cards/rows from derived snapshot attention state
  - variant pills now render across GameRoom surfaces:
    - selected summary card
    - home tiles
    - home list rows
    - machine-view header/title
  - Machine View now has segmented `Summary / Input / Log` subview switching
  - Input now writes real events/issues into persisted store state
  - Log now renders machine timeline rows, selectable detail card, and edit/delete actions
  - selected log detail card is fixed-height with internal scroll to prevent list hopping on selection changes
  - swipe gestures are active on log rows:
    - swipe right -> edit
    - swipe left -> delete
  - log edit flow now supports date editing (`YYYY-MM-DD`) and persists updated event timestamp + content
  - media-type log row taps now open linked media preview directly (photo/video)

Acceptance highlights:
- GameRoom home:
  - selected summary card above collection card
  - list/tile toggle
  - compact 2-column tiles
  - first tap select, second tap open
  - no quick buttons in summary
  - summary snapshot uses 2-column metric grid
- Machine View:
  - image header + variant pill
  - `Summary / Input / Log`
  - input grouped buttons 2-per-row full width
  - log row selection shows full detail card
  - swipe edit/delete

### M9-M12. Archive + Library integration + Pinside import + media

Status:
- completed (Android implementation; QA pass pending)
- current outcome:
  - Archive settings section now supports segmented filters: `All / Sold / Traded / Archived`
  - archive rows are openable and route into historical `Machine View` for that machine instance
  - Library now overlays a dynamic GameRoom venue source (`venue--gameroom`) when GameRoom has at least one active/loaned machine
  - GameRoom venue name in Library uses saved GameRoom name (fallback `GameRoom`)
  - GameRoom Library rows are synthesized from owned machine instances with area/group/position fields
  - GameRoom Library ordering now uses area-level `areaOrder` (then area name, group, position, title)
  - GameRoom Library hydration resolves OPDB machine/media variant-aware, while preserving local template assets where present
  - GameRoom state save now emits `LibrarySourceEvents.notifyChanged()` so Library reflects edits/import changes without app restart
  - Pinside import service added (username/public URL input, public page fetch, slug extraction, title/variant normalization, user-facing errors)
  - import input supports keyboard submit (`Go`/return) to trigger collection fetch
  - Import review UI added under `GameRoom Settings > Import`:
    - `Fetch Collection`
    - `All / Needs Review` filter
    - per-row match confidence badge
    - match picker (top suggestions + clear)
    - variant picker
    - raw purchase-date input + normalized first-of-month date
    - duplicate warnings (existing machine + existing import fingerprint)
    - `Import Selected Matches` summary result
  - Store import helpers added:
    - fingerprint duplicate checks
    - owned-machine duplicate checks by catalogGameID+variant
    - import-owned-machine creation with `MachineImportRecord` persistence
  - Pinside fetch path now has Cloudflare fallback:
    - direct request first
    - fallback via `r.jina.ai` proxy when direct Pinside returns challenge/403
  - Machine Input is now form/sheet driven (not direct one-tap writes):
    - service entry sheets for clean glass, clean playfield, swap balls, check pitch, level machine, general inspection
    - issue entry sheets for log issue (severity/subsystem/diagnosis) and resolve issue
    - ownership/media entry sheets for ownership update, install mod, replace part, log plays, add photo/video
  - GameRoom art rendering now uses catalog variant-aware resolver:
    - tile/list cards render primary translite art
    - Machine View renders a hero image (playfield preferred, translite fallback)
  - Media attachments wired in GameRoom Machine View:
    - Input section now supports `Add Photo/Video` entry with caption/notes before picker
    - picking media creates a linked media event (`photoAdded` / `videoAdded`) and attachment record
    - Summary shows machine-level media as 2-column square thumbnail grid
    - Log selected-entry card shows event-level media thumbnails
    - media preview supports full-screen open/zoom/swipe-back/delete
    - media preview now supports inline `Edit` of caption + linked event notes
    - media delete uses iOS-parity behavior (`deleteAttachmentAndLinkedEvent`) to remove media and linked timeline event
    - issue-linked media is supported via `Issue Photo` / `Issue Video` attach paths

Acceptance highlights:
- archive is machine-instance history
- Library shows GameRoom custom source only when GameRoom has >=1 machine
- variant-aware art/rulesheet/video hydration for GameRoom rows
- Pinside import (one-time, review/confirm, confidence, duplicate guards)
- media picker + grid + open/edit/delete behaviors

## iOS -> Android File Mapping (Practical)

iOS GameRoom core:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomModels.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomStore.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomCatalogLoader.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomPinsideImport.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomScreen.swift`

Android parity targets:
- new `gameroom` package with similarly separated files:
  - `GameRoomModels.kt`
  - `GameRoomStore.kt`
  - `GameRoomCatalogLoader.kt`
  - `GameRoomPinsideImport.kt`
  - `GameRoomScreen.kt`
  - optional split files for large composables (match existing Android style)

Library integration mapping:
- iOS:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryDataLoader.swift`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift`
- Android:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryCatalogStore.kt`

## Immediate Next Steps

1. Run full emulator QA matrix for parity-critical flows:
- add/edit/archive machine with variant + ownership metadata
- input entry forms (service/issue/ownership/mod/log plays/media) including date persistence
- log swipe edit/delete and selected-entry detail behavior
2. Validate GameRoom->Library end-to-end:
- source appears only when GameRoom has >=1 active/loaned machine
- sort respects area order/group/position
- variant art/rulesheet/video hydrate correctly
3. Validate Pinside and media durability:
- import by username and public URL
- duplicate guards + confidence/manual override paths
- media URI persistence and reopen behavior across cold restart
