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
