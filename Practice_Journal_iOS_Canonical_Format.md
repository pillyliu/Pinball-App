# iOS Canonical Practice Journal / Persistence Format (Reference Spec)

This document describes how the iOS app records practice activity and how it is persisted in `practice-state-json`.

Use this as the canonical reference for Android parity.

## Scope

This covers:
- the persisted practice JSON schema on iOS
- how journal entries are written for each user action
- how summaries shown in the Journal Timeline are derived
- edit/delete behavior and linked data updates
- what Android must match for true cross-platform/cloud-sync parity

## Important Distinction: Persisted Practice Journal vs Journal Timeline UI

The iOS **Journal Timeline UI** merges two sources:
1. `PracticePersistedState.journalEntries` (persisted in `practice-state-json`)
2. `LibraryActivityLog` events (separate library activity log, not part of practice JSON)

So when discussing cross-platform practice-data parity, the canonical target is the **practice persisted state**, especially `journalEntries` plus the linked arrays (`studyEvents`, `videoProgressEntries`, `scoreEntries`, `noteEntries`).

## Storage Location and Key (iOS)

- UserDefaults key: `practice-state-json`
- Legacy fallback key: `practice-upgrade-state-v1`

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStore.swift:120`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStorePersistence.swift:4`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStorePersistence.swift:22`

## Serialization Format (iOS)

iOS persists the full `PracticePersistedState` using `JSONEncoder` / `JSONDecoder` with default settings.

Consequences:
- `UUID` values encode as strings.
- enums encode as raw strings.
- `Date` values encode using Swift's default `Date` Codable behavior (`deferredToDate`), which is a numeric timestamp in seconds relative to Apple reference date (2001-01-01), typically as a JSON number.
- optional fields are omitted when `nil` (synthesized Codable behavior).

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStorePersistence.swift:12`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStorePersistence.swift:24`

## Canonical Game ID

All persisted practice data uses canonical `practice_identity` (v3 OPDB group) after load-time migration.

- Canonicalization entrypoint: `canonicalPracticeGameID(_:)`
- Migration rewrites persisted state arrays/maps and preference game IDs to canonical IDs

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeIdentityKeying.swift:21`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeIdentityKeying.swift:52`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeIdentityKeying.swift:65`

## Top-Level Persisted State (iOS)

`PracticePersistedState` (canonical schema):

- `studyEvents: [StudyProgressEvent]`
- `videoProgressEntries: [VideoProgressEntry]`
- `scoreEntries: [ScoreLogEntry]`
- `noteEntries: [PracticeNoteEntry]`
- `journalEntries: [JournalEntry]`
- `customGroups: [CustomGameGroup]`
- `leagueSettings: LeagueLinkSettings`
- `syncSettings: SyncSettings`
- `analyticsSettings: AnalyticsSettings`
- `rulesheetResumeOffsets: [String: Double]`
- `videoResumeHints: [String: String]`
- `gameSummaryNotes: [String: String]`
- `practiceSettings: PracticeSettings`

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeModels.swift:405`

## Core Journal-Linked Models (iOS)

### `JournalEntry` (structured event row)
Fields:
- `id: UUID`
- `gameID: String` (canonical practice key)
- `action: JournalActionType`
- `task: StudyTaskKind?`
- `progressPercent: Int?`
- `videoKind: VideoProgressInputKind?`
- `videoValue: String?`
- `score: Double?`
- `scoreContext: ScoreContext?`
- `tournamentName: String?`
- `noteCategory: PracticeCategory?`
- `noteDetail: String?`
- `note: String?`
- `timestamp: Date`

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeModels.swift:212`

### Linked arrays (used for reconciliation + analytics)
- `StudyProgressEvent` (progress time series for tasks)
- `VideoProgressEntry` (video input kind + value)
- `ScoreLogEntry`
- `PracticeNoteEntry`

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeModels.swift:113`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeModels.swift:129`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeModels.swift:145`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeModels.swift:194`

## Action Enums (iOS)

### `JournalActionType`
Raw values:
- `rulesheetRead`
- `tutorialWatch`
- `gameplayWatch`
- `playfieldViewed`
- `gameBrowse`
- `practiceSession`
- `scoreLogged`
- `noteAdded`

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeModels.swift:23`

### `StudyTaskKind`
Raw values:
- `playfield`
- `rulesheet`
- `tutorialVideo`
- `gameplayVideo`
- `practice`

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeModels.swift:3`

### `actionType(for:)` mapping
- `rulesheet` -> `rulesheetRead`
- `playfield` -> `playfieldViewed`
- `tutorialVideo` -> `tutorialWatch`
- `gameplayVideo` -> `gameplayWatch`
- `practice` -> `practiceSession`

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStore.swift:153`

## How iOS Writes Journal Entries (by User Action)

All writes go through `PracticeStore` mutation methods.

Code (write entrypoints):
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift:29`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift:49`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift:88`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift:111`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift:144`

### 1. Rulesheet / Playfield / Practice (task-based study writes)
Method: `addGameTaskEntry(gameID:task:progressPercent:note:)`

Effects:
- appends `StudyProgressEvent` only if `progressPercent != nil`
- appends structured `JournalEntry` with:
  - `action` from `actionType(for: task)`
  - `task = task`
  - `progressPercent`
  - `note`

This is used by quick entry and game workspace for:
- rulesheet
- playfield
- practice

Call sites:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeQuickEntrySheet.swift:353`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeQuickEntrySheet.swift:383`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeQuickEntrySheet.swift:404`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspace.swift:1050`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspace.swift:1082`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspace.swift:1110`

### 2. Tutorial / Gameplay Video (structured video writes)
Method: `addManualVideoProgress(gameID:action:kind:value:progressPercent:note:)`

Effects:
- appends `VideoProgressEntry(gameID, kind, value)`
- appends `StudyProgressEvent` if `progressPercent != nil`
- appends structured `JournalEntry` with:
  - `action` (`tutorialWatch` or `gameplayWatch`)
  - `task` inferred from action
  - `progressPercent`
  - `videoKind`
  - `videoValue`
  - `note`

Call sites:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeQuickEntrySheet.swift:373`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameWorkspace.swift:1071`

### 3. Score
Method: `addScore(gameID:score:context:tournamentName:)`

Effects:
- appends `ScoreLogEntry`
- appends `JournalEntry(action: .scoreLogged, score, scoreContext, tournamentName)`

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift:88`

### 4. Note (including mechanics notes)
Method: `addNote(gameID:category:detail:note:)`

Effects:
- appends `PracticeNoteEntry`
- appends `JournalEntry(action: .noteAdded, noteCategory, noteDetail, note)`
- auto-tags mechanics aliases into the note text when detected

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift:111`

### 5. Mechanics (how it is represented)
Mechanics is not a separate `JournalActionType`.
It is stored as a **note entry** (`noteAdded`) with category `.general` and mechanics-tagged note text.

Examples of mechanics write paths:
- Quick entry mechanics -> `addNote(...)`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeQuickEntrySheet.swift:419`
- Mechanics screen log -> `addNote(gameID: "", ...)` (all-games mechanics)
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeScreenRouteContent.swift:181`

### 6. Game Browse
Method: `markGameBrowsed(gameID:)`

Effects:
- appends `JournalEntry(action: .gameBrowse)` with debounce (skips duplicate browse events within 45s for same game)

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift:144`

## Journal Summary Rendering (UI text)

The persisted `JournalEntry` is structured. The human-readable line shown in Journal Timeline is derived at render time by `journalSummary(for:)`.

Important: **summary text is not the canonical stored representation on iOS**.

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreJournalHelpers.swift:73`

Examples (derived):
- rulesheet: `Read 40% of <Game> rulesheet`
- tutorial/gameplay: uses `videoValue` first if present, else progress percent, else note fallback
- playfield: note fallback or `Viewed <Game> playfield`
- practice: progress/note fallback
- score: formats score and context/tournament
- note: formats category/detail/note text

## Edit/Delete Semantics (iOS)

The iOS journal editor/deleter mutates both the journal row and linked arrays, not just the displayed row.

Supported editable/deletable user-entered actions:
- `rulesheetRead`
- `tutorialWatch`
- `gameplayWatch`
- `playfieldViewed`
- `practiceSession`
- `scoreLogged`
- `noteAdded` (includes mechanics notes)

Non-editable:
- `gameBrowse`

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift:205`

Key reconciliation behaviors:
- score edits update matching `ScoreLogEntry`
- note edits update matching `PracticeNoteEntry`
- study/practice edits reconcile matching `StudyProgressEvent`
- tutorial/gameplay edits reconcile `VideoProgressEntry` and `StudyProgressEvent`
- deletes remove linked entries from the corresponding arrays

Code:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift:215`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift:333`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift:403`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift:435`

## Canonical JSON Shape Example (iOS)

Simplified example (illustrative only; dates are numeric in iOS JSON):

```json
{
  "studyEvents": [
    {
      "id": "UUID",
      "gameID": "Gd2Xb",
      "task": "rulesheet",
      "progressPercent": 40,
      "timestamp": 789123456.0
    }
  ],
  "videoProgressEntries": [
    {
      "id": "UUID",
      "gameID": "Gd2Xb",
      "kind": "percent",
      "value": "60% (Tutorial 1)",
      "timestamp": 789123499.0
    }
  ],
  "scoreEntries": [
    {
      "id": "UUID",
      "gameID": "Gd2Xb",
      "score": 123456789,
      "context": "practice",
      "timestamp": 789123500.0,
      "leagueImported": false
    }
  ],
  "noteEntries": [
    {
      "id": "UUID",
      "gameID": "Gd2Xb",
      "category": "general",
      "detail": "Drop Catch",
      "note": "#DropCatch competency 3/5. Felt better today",
      "timestamp": 789123600.0
    }
  ],
  "journalEntries": [
    {
      "id": "UUID",
      "gameID": "Gd2Xb",
      "action": "rulesheetRead",
      "task": "rulesheet",
      "progressPercent": 40,
      "timestamp": 789123456.0
    },
    {
      "id": "UUID",
      "gameID": "Gd2Xb",
      "action": "tutorialWatch",
      "task": "tutorialVideo",
      "progressPercent": 60,
      "videoKind": "percent",
      "videoValue": "60% (Tutorial 1)",
      "note": "Focused on ball control section",
      "timestamp": 789123499.0
    },
    {
      "id": "UUID",
      "gameID": "Gd2Xb",
      "action": "scoreLogged",
      "score": 123456789,
      "scoreContext": "practice",
      "timestamp": 789123500.0
    },
    {
      "id": "UUID",
      "gameID": "Gd2Xb",
      "action": "noteAdded",
      "noteCategory": "general",
      "noteDetail": "Drop Catch",
      "note": "#DropCatch competency 3/5. Felt better today",
      "timestamp": 789123600.0
    }
  ]
}
```

## What Android Must Match for True Parity (Required)

If Android is to “completely match iOS” and cloud sync must be platform-neutral, Android should write/read the same canonical schema (or a superset that preserves iOS fields exactly).

Required parity items:
- same top-level `PracticePersistedState` field names and types
- structured `journalEntries` (not summary-only rows)
- `JournalActionType` compatible values (`rulesheetRead`, `tutorialWatch`, etc.)
- linked arrays preserved (`studyEvents`, `videoProgressEntries`, `scoreEntries`, `noteEntries`)
- same canonical `gameID` semantics (v3 `practice_identity` / OPDB group)
- same edit/delete reconciliation semantics across linked arrays
- same timestamp serialization strategy (or explicit cross-platform agreed strategy)

## Current Cross-Platform Reality (as of now)

iOS and Android are **not yet identical** in storage schema.
Android currently uses a flatter practice state model and flatter journal rows in its persisted JSON.

This means platform can still affect the stored JSON shape today, even if UI behavior is similar.

## Recommendation (Next Implementation Step)

Make iOS the canonical storage spec and migrate Android persistence to the iOS schema:
1. Add Android parser for iOS `PracticePersistedState` shape
2. Migrate existing Android state into canonical structured fields
3. Write only canonical schema going forward
4. Add cross-platform fixture tests (same JSON round-trips on both)

