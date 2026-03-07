# Program Overview

## Name

- Program: `3.2 Modernization`
- Branch: `codex/3.2-modernization`
- Recommended chat title: `3.2 Modernization Foundation`

## Goal

Modernize the iOS and Android apps so they have:
- true product parity
- consistent internal structure
- consistent visual rules within each platform
- shared behavior contracts across platforms
- native platform expression where appropriate
- a stronger branded PinProf personality over time

## What this is

- a design-system-led modernization effort
- an incremental rewrite guided by refactoring
- a file-by-file and screen-by-screen audit program

## What this is not

- not a blind full rewrite from scratch
- not chat-driven implementation
- not Android "roughly matching" iOS
- not brand decoration applied on top of inconsistent UI

## Working definitions

- `refactor`: improve structure without changing intended behavior
- `selective rewrite`: replace weak or oversized surfaces while preserving product intent
- `parity`: same IA, behavior, copy, states, and edge-case handling unless a difference is explicitly allowed
- `native adaptation`: platform-specific rendering or interaction style built on the same semantic contract

## Current program order

1. Establish docs and workflow.
2. Audit current architecture and files.
3. Build a semantic design system.
4. Normalize app shell and navigation parity.
5. Modernize features one by one.
6. Add stronger PinProf personality after the system is stable.

## Current priorities

1. Lock the modernization workflow.
2. Create and maintain a real audit matrix.
3. Prevent parity drift.
4. Reduce oversized screens and mixed responsibilities.

## Canonical baseline

- `GameRoom 3.1` is the most fully specified parity effort to date.
- Existing source docs remain valid inputs:
  - `/Users/pillyliu/Documents/Codex/Pinball App/GameRoom_3.1_Master_Plan.md`
  - `/Users/pillyliu/Documents/Codex/Pinball App/GameRoom_3.1_Parity_Journal.md`
  - `/Users/pillyliu/Documents/Codex/Pinball App/GameRoom_3.1_Android_Parity_Kickoff.md`

## Current product map

Root tabs on both platforms:
- `League`
- `Library`
- `Practice`
- `GameRoom`
- `Settings`

Nested League destinations:
- `Stats`
- `Standings`
- `Targets`
- `About Lansing Pinball League`

Practice sub-surfaces currently present in code:
- home
- game workspace
- quick entry
- IFPA profile
- groups dashboard/editor
- journal
- insights
- mechanics
- practice settings
- rulesheet/playfield drill-ins

Library sub-surfaces currently present in code:
- game list
- game detail
- rulesheet
- playfield
- game info and resources
- source filtering
- GameRoom venue overlay integration

## Current structural realities

- iOS and Android share the same top-level tab model.
- League is documented as one feature, but it owns multiple nested destinations and should be audited as a shell-plus-subfeatures bundle.
- Practice is not one screen in product terms, even though it still contains large centralized screen/state surfaces in code.
- Library acts as shared infrastructure for Practice and GameRoom, so Library changes have broader parity risk than the tab count suggests.
- GameRoom has the best parity documentation so far, but still has oversized implementation files.

## Initial modernization work order

1. Audit and document the real app shell and feature map.
2. Audit Practice as the highest drift-risk feature.
3. Audit Library as the highest cross-feature dependency.
4. Audit League shell plus nested destinations.
5. Do post-ship GameRoom cleanup and screen splitting.
6. Run a design-system pass across shell, cards, controls, and sheets.
