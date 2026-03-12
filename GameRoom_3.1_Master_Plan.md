# GameRoom 3.1 Master Plan (Comprehensive)

This document is the full v3.1 planning contract derived from the complete chat thread.

Use:
- product scope and decision source for iOS implementation
- Android parity design source (with parity journal as implementation-truth ledger)

Companion implementation ledger:
- `/Users/pillyliu/Documents/Codex/Pinball App/GameRoom_3.1_Parity_Journal.md`

Branch:
- `codex/3.1-gameroom`

Platform strategy:
- iOS first
- Android follows iOS behavior, naming, and structure for parity

---

## 1. Version 3.1 Goal

Build a new `GameRoom` root tab that lets owners track a personal pinball machine collection as physical machine instances, including ownership lifecycle and maintenance logs, while preserving existing Library behavior.

---

## 2. Naming and Top-Level IA

Confirmed naming:
- feature name: `GameRoom`
- root tab label: `GameRoom`

Rejected/considered names:
- Home Arcade (considered; final selection is `GameRoom`)

Root tab order (target):
1. `League`
2. `Library`
3. `Practice`
4. `GameRoom`
5. `Settings`

League/About restructuring:
- root `About` tab is removed
- add footer mini-card on League Home: `About Lansing Pinball League` with small logo
- tap footer opens nested `About Lansing Pinball League` inside League stack
- this restructuring intentionally frees root-tab space for `GameRoom`

---

## 3. Product Rules and Domain Boundaries

GameRoom identity:
- GameRoom is effectively a user-defined custom venue for owned games
- GameRoom tracks machine instances (not only title records)
- same game can appear multiple times across lifecycle (trade out, reacquire, etc.) as separate instances

Sorting semantics:
- sort by `areaOrder` -> `area` -> `group` -> `position` -> fallback title/id
- `areaOrder` belongs to the area definition, not to each machine row
- all machines in same area share that area’s single `areaOrder` value

Library behavior contract:
- Library behavior does not change for now
- future: Library can show GameRoom as a custom venue/source

Archive contract:
- archive is machine-instance based (not title-group based)

---

## 4. GameRoom Home Spec

Layout:
- top selected-machine summary box
- collection box below
- both boxes span standard app content width (no narrow intrinsic cards)

Collection presentation:
- toggle between `Cards` and `List`
- tile mode uses compact/short mini cards (Practice-like visual density)
- tile grid is 2 columns
- status light(s) in upper-right on mini cards
- status dot colors:
  - red: urgent/open severe issue
  - yellow: attention/due soon
  - green: healthy/recently serviced
  - gray: archived/incomplete

Interaction:
- tap on unselected card selects/highlights it
- tap selected card again opens machine view
- selected cards/rows should show highlight plus accent outline

Selected summary card:
- shows selected machine identity + location plus the same read-only snapshot fields used in Machine View summary
- contains no quick actions; machine actions/logging stay in Machine View input

Variant badge behavior:
- show badge where variant is available (summary/list/tile where space allows)
- badge should use exact explicit variant when saved
- fallback inference from title text only when explicit variant absent
- badge sizing behavior:
  - shrinks to content for short labels
  - expands up to cap (roughly premium-length)
  - truncates with ellipsis beyond cap

---

## 5. GameRoom Settings Spec

Entry point:
- top-right gear icon on GameRoom Home (match Practice affordance)

Settings screen IA:
- segmented selector on one row with exact labels:
  - `Import`
  - `Edit`
  - `Archive`
- selector style intent: iOS liquid-glass style parity with Practice segmented controls
- no extra duplicate header text inside body (`GameRoom Settings` title already in nav bar)
- selecting a segment swaps content inline on this screen
- `Edit` is inline content, not a separate pushed page/sheet
- swipe/back returns to GameRoom Home

Sections:
- Import section heading: `Import from Pinside`
- Edit section heading: `Edit Machines`
- Archive section heading: `Machine Archive`

---

## 6. Edit Machines Spec (Detailed)

General:
- presented under Settings -> `Edit`
- three collapsible sections in this order:
  1. Add Machine
  2. Areas
  3. Edit Machines

### 6.1 Add Machine

Search behavior:
- search is machine-group oriented for add selection
- default with empty query: search all
- use full OPDB catalog (not limited by currently enabled Library sources)

Manufacturer filter:
- optional; none selected means search all manufacturers
- dropdown grouping preference:
  - modern manufacturers
  - divider
  - classic popular manufacturers
  - divider
  - other

Performance constraints:
- do not render/load full 2k+ catalog in one pass
- use explicit paging approach
- page size target: 25
- search results viewport visually limited (short list area, roughly 5 rows visible before scroll)
- paging should preserve reading position intent and avoid jumpy behavior

### 6.2 Areas

Area editor:
- one row: `Area Name` + `Area Order`
- action row below for area save/edit actions
- selecting existing area loads it for editing

Area deletion:
- deleting area clears linked area assignment from machines
- areaOrder remains area-level source of truth

### 6.3 Edit Machines

Machine selection:
- current chip selector is acceptable short-term but does not scale for large collections
- keep TODO to replace with scalable selector (searchable picker/grouped modal/etc.)

Machine edit fields/actions:
- action order: `Save`, `Delete`, `Archive`
- remove nickname from schema and UI (not used)
- variant selected via dropdown in edit row
- variant selector stays inline with machine name row
- variant selector should include a `None` option label (exact text `None`)
- in selector lists/chips for selecting which machine to edit, show game name only (no variant badge there)

Variant/identity intent:
- user adds by game group (not raw alias-focused add UX)
- user selects variant for machine instance
- OPDB group/machine/alias mapping should be respected behind the scenes
- display preference is group-oriented naming in selection UX instead of alias-oriented naming where practical

---

## 7. Machine View Spec

Header:
- top image area at top of machine page (same visual role as Practice game view)
- machine title row with optional variant badge

Subview selector:
- segmented control:
  - `Summary`
  - `Input`
  - `Log`

Summary subview:
- read-only state summary for current machine
- no quick-action buttons in this header area (actions belong in Input)

Input subview:
- grouped sections with separators:
  - service actions
  - issue actions
  - ownership/media actions
- button layout: 2 per row, full half-row width (match Practice input density)
- entry interactions should mirror Practice sheet patterns
- sheets use half-height style (medium + large detents)

Log subview:
- appearance/formatting mirrors Practice log style
- timeline rows with summary + timestamp styling
- swipe left reveals edit/delete
- edit + delete behavior mirrors Practice journal interaction expectations
- log entry editing should use the same interaction conventions as Practice journal entry editing

---

## 8. Event, Issue, Ownership, and Media Logging Scope

Service events to support:
- clean glass
- clean playfield (capture cleaner used)
- swap/replace balls
- check pitch (capture pitch value and measurement point)
- level machine
- general inspection
- flipper/rubber/part service entries (as service depth expands)

Issue events/state:
- log issue with severity + subsystem + notes
- resolve issue with resolution notes
- issues should maintain status lifecycle and timestamps

Ownership events:
- purchased
- moved
- loaned out
- returned
- listed for sale
- sold
- traded
- reacquired

Media:
- photo/video attachments should link to issue/event context
- media can also be surfaced at machine level with backlink to source event/issue

Snapshot behavior:
- derived snapshot recomputes after create/edit/delete of relevant logs
- owner can view current machine maintenance state and routine task recency

---

## 9. Pinside Import v1 Plan

Import scope:
- import once flow
- public collection parsing by username/public URL
- user confirms final selections/mappings

Matching:
- OPDB backed matching with confidence:
  - high
  - medium
  - low
  - manual
- if uncertain, app suggests aliases/options
- user has final picker/confirm authority
- canonical naming defers to OPDB naming/mapping
- import review should prioritize machine-group correctness first, then variant confirmation

Dates:
- capture raw imported date text
- also store normalized date (first day of month convention)

Potential private-data note:
- Pinside private details (price, serial, manufacture date) may not be importable publicly
- v1 should prioritize robust public import flow

---

## 10. Data Model Planning Contract

Persisted root:
- `GameRoomPersistedState`
- schema versioned

Entities:
- `GameRoomArea`
- `OwnedMachine`
- `OwnedMachineSnapshot` (derived)
- `MachineEvent`
- `MachineIssue`
- `MachineAttachment`
- `MachineReminderConfig`
- `MachineImportRecord`

Key semantics:
- machine instance identity is stable (`OwnedMachine.id`)
- archive/sold/traded are status/lifecycle outcomes on instance
- snapshots are denormalized projections, not source-of-truth
- area ordering model is centralized at area level

Removed/de-scoped:
- machine nickname (removed from schema/UI)

---

## 11. Performance and Usability Constraints

Catalog search performance:
- do not load/render entire OPDB list into visible UI at once
- keep list viewport constrained
- page in controlled chunks (target 25/page)
- paging interactions should avoid disorienting jumps

Layout consistency:
- settings cards and section panels should use full standard width, consistent with rest of app
- avoid mixed-width panel regressions (`selected machine`, `import`, and `archive` panels must align visually)

Large collection editing:
- current selector is functional but not final
- dedicated scalable selector remains an explicit TODO

---

## 12. Milestone Roadmap (Canonical v3.1)

1. Reclaim root tab (About nested under League)  
2. Add GameRoom shell  
3. Build data model + persistence  
4. Build Areas + Edit Machines manual setup  
5. Build GameRoom Home interaction model  
6. Build Machine View base  
7. Build event and issue entry flows  
8. Build log editing + swipe parity  
9. Build archive lifecycle behavior  
10. Build Library integration as GameRoom venue  
11. Build Pinside import flow  
12. Build media attachment workflow

Release grouping:
- Release A: milestones 1-4
- Release B: milestones 5-8
- Release C: milestones 9-11
- Release D: milestone 12

---

## 13. Current Status vs Roadmap

Done:
- 1, 2, 3, 4 (v1), 5 (v1), 6
- 8 (core parity behavior implemented)

In progress:
- 7
- 9
- 12

Not started:
- 10
- 11

---

## 14. Micro-Decision Contracts (from planning thread)

These are small but explicit decisions to prevent drift.

Settings and labels:
- GameRoom settings top-right action is a gear icon (Practice-home style)
- settings selector labels remain exactly `Import`, `Edit`, `Archive`
- settings section body should not show duplicate `GameRoom Settings` header text

GameRoom Home:
- mini cards are intentionally short to fit more machines on screen
- summary card sits above collection card
- first tap select, second tap open is required behavior

Edit Machines:
- Add/Areas/Edit sections are collapsible and remain in that order
- Area Name and Area Order are on one line
- area action row is on next line
- machine action row order is always `Save`, then `Delete`, then `Archive`
- machine selector chips/list should avoid variant clutter

Variant behavior:
- variant badge and variant dropdown are not both shown in same edit row
- variant badge should truncate beyond premium-length cap
- short variant text should remain naturally compact

Input/Log behavior:
- no header quick actions inside Machine View (actions are in Input)
- Input buttons are two-per-row and full width per column
- Input sheets are medium/large detent style
- Log mirrors Practice row styling and swipe affordances

Import:
- v1 is import-once, public collection only
- store raw date text plus normalized first-of-month date
- confidence-based matching + user confirmation is mandatory

---

## 15. Android Parity Operating Rule

Execution model:
1. implement behavior on iOS
2. validate UX/data behavior
3. record final behavior in parity journal
4. port to Android with matching names, structure, and interaction

Parity emphasis:
- route naming parity
- model/entity naming parity
- sorting semantics parity
- list/tile and selection behavior parity
- entry-sheet and log interaction parity

---

## 16. Open Backlog and Deferred Decisions

Known open/deferred items:
- scalable machine selector for large collections in Edit Machines
- complete Library integration milestone (GameRoom as custom venue source)
- full Pinside parser and review/confirm UX
- richer reminder/due-task logic and summary surfacing
- expanded service/mod/part event coverage depth
- app-wide variant fidelity strategy (deferred by product decision):
  - venue local playfield assets for The Avenue/RLM may be LE/Premium art and are currently reused at group level, so Pro machines can show non-Pro playfield art
  - in Practice, game identity intentionally collapses by OPDB group (not per-variant), so Pro/Premium/LE strategic differences are not represented in separate practice tracks yet
  - future decision needed on whether to support per-variant practice identity, per-variant playfield/rulesheet assets, and per-variant strategy/risk guidance

---

## 17. Change-Control Rule for Docs

This master plan:
- should remain comprehensive planning intent
- should include confirmed design decisions and deferred decisions

Parity journal:
- should contain only final implemented behavior and accepted contracts
- should be pruned/reworded when behavior changes so it remains authoritative for Android porting
