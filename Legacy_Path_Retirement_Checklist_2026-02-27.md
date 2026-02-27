# Legacy Path Retirement Checklist (Phase 3 Input)

## Scope
This checklist is the concrete delete/rewrite list after Phase 2 consolidation.
It focuses on legacy compatibility paths that still exist in runtime code.

## iOS candidates
1. Legacy key fallback read (`practice-upgrade-state-v1`)
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStore.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStorePersistence.swift`
- Remove only after migration horizon is closed and telemetry/manual checks confirm no remaining installs on legacy payloads.

2. Legacy Date decoding fallback in practice state codec
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStateCodec.swift`
- Remove when all persisted payloads are guaranteed millisecond timestamps.

3. Legacy practice-key alias matching
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeIdentityKeying.swift`
- Remove old alias matcher branch once canonical practice IDs are fully normalized.

4. Library asset legacy field compatibility (`*_local_legacy`)
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryDomain.swift`
- Requires content validation that v3 practice fields exist for all shipped entries.

## Android candidates
1. Legacy key fallback read (`practice-upgrade-state-v1`)
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid/league/LeagueScreen.kt`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid/practice/PracticeStore.kt`

2. Legacy payload parser + canonical bridge path
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid/practice/PracticeStorePersistence.kt`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid/practice/PracticeCanonicalPersistence.kt`
- Remove `parsePracticeStateJson` and legacy-to-canonical conversion branch when migration window closes.

3. Runtime legacy journal formatting shims used for compatibility views
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid/practice/PracticeCanonicalPersistence.kt`
- Functions currently converting canonical journal -> legacy summary/action can be removed once UI is canonical-only.

4. Legacy practice-key alias matching
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid/practice/PracticeIdentityKeying.kt`

5. Library asset legacy field compatibility (`*_local_legacy`)
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid/library/LibraryDomain.kt`

## Keep (not Phase 3 delete)
1. Cache marker names like `legacy-cache-reset-v3-assets-v1`
- Keep unless cache strategy is redesigned end-to-end.

2. Non-practice "fallback" UI sorting logic
- Targets/library fallback ordering is not legacy migration debt.

## Exit criteria before deleting items
1. iOS XCTest migration suite passes:
- `PracticeStateCodecTests` in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2Tests/PracticeStateCodecTests.swift`

2. Android migration fixture tests pass:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/test/java/com/pillyliu/pinballandroid/practice/PracticeCanonicalPersistenceTest.kt`

3. CI green on both platforms with migration tests enabled.

4. Manual smoke on practice flows after deletions:
- Quick entry
- Game input/log
- Journal edit/delete
- League mini previews with selected player
