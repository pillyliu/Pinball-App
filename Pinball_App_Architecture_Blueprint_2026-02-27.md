# Pinball App Architecture Blueprint (2026-02-27)

## 1. Scope and Intent

This document is an updated architecture and cleanup blueprint for the full app:
- iOS: `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2`
- Android: `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid`

Primary goals:
- Preserve existing product behavior while reducing residual compatibility complexity from v1/v2/v3 transitions.
- Identify dead/obsolete pathways that can be removed safely.
- Define a staged cleanup plan with acceptance criteria.

---

## 2. Current System Snapshot

### 2.1 High-level structure

Both platforms still follow the same functional pillars:
- League (`Stats`, `Standings`, `Targets`)
- Library (browse/detail/rulesheet/playfield/video)
- Practice (quick entry, per-game workspace, groups, journal, insights, mechanics, settings)

### 2.2 Shared data model direction

- Canonical data source for content remains `https://pillyliu.com/pinball/...`.
- Both clients use local cache + starter-pack bootstrap.
- Practice has moved toward canonical keying and schema-based persistence, but compatibility bridges remain active.

---

## 3. Audit Findings (Cross-Platform)

### 3.1 Legacy state compatibility is still active (expected, but now concentrated)

#### iOS
- Active storage key: `practice-state-json`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStore.swift`
- Legacy fallback key still read/cleaned: `practice-upgrade-state-v1`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStorePersistence.swift`
- Key canonicalization migration still runs on load:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeIdentityKeying.swift`
- League preview still contains direct fallback key awareness:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/league/LeaguePreviewModel.swift`

#### Android
- Preference container still named v2:
  - `PRACTICE_PREFS = "practice-upgrade-state-v2"`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid/practice/PracticeKeys.kt`
- Active state key: `practice-state-json`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid/practice/PracticeStore.kt`
- Legacy parsing path still available through canonical adapter:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid/practice/PracticeCanonicalPersistence.kt`
- Practice load includes runtime + canonical migration passes:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid/practice/PracticeStore.kt`

### 3.2 Practice persistence architecture differs by platform

- iOS stores one evolving `PracticePersistedState` with schema versioning.
- Android stores canonical and also reconstructs a runtime shape for UI compatibility.

Risk:
- Behavior drift when one platform adjusts migration logic and the other does not.

### 3.3 League mini-preview player targeting had coupling to persistence format

- League previews read Practice-selected player out of persisted state directly.
- This was recently fixed on Android to parse canonical payload first.

Risk:
- Any future persistence format change can break league mini previews unless this read path is centralized.

### 3.4 Cache layer is largely aligned, but marker naming preserves legacy context

Both platforms include marker constants like:
- `starter-pack-seeded-v3-only`
- `legacy-cache-reset-v3-assets-v1`

These are not immediately problematic; they are historical markers and can remain unless cache reset strategy is redesigned.

### 3.5 Toolchain/Build warnings (Android)

Current Android build remains stable but uses AGP compatibility flags that emit deprecation warnings. Attempting to remove them currently breaks plugin initialization in this project configuration.

Conclusion:
- Do not mass-remove these flags during product cleanup.
- Plan a dedicated AGP/Kotlin DSL migration project.

---

## 4. Dead Code and Removal Candidates

### 4.1 Safe-to-evaluate candidates (Phase 2+)

1. Legacy practice key fallback reads (`practice-upgrade-state-v1`) on both platforms.
2. Legacy summary/action conversion paths used only for backward compatibility in Android canonical adapter.
3. Legacy preference key migration functions once migration window is formally closed.
4. Legacy library asset fallbacks (`*_local_legacy`) after verifying v3 coverage for all shipped entries.

### 4.2 Not safe to remove yet

1. Android AGP compatibility flags in `gradle.properties` (build can fail if removed now).
2. Runtime/canonical dual representation on Android without first finishing UI/state adapter consolidation.
3. Cache legacy markers without proving cache upgrade behavior across cold installs and upgrades.

---

## 5. Cleanup Plan (Thorough, Staged)

## Phase 0: Baseline Lock (done/in progress)
- Ensure both platforms build cleanly.
- Stabilize critical flows affected by recent UI churn.
- Capture current behavior baselines for:
  - Quick entry (all modes)
  - Practice game input/log
  - Journal edit/delete/reveal interactions
  - League mini previews

## Phase 1: Readability and Local Refactors (no behavior changes)
- Extract repeated UI/data formatting helpers.
- Remove duplicated token-building logic where practical.
- Normalize naming for shared concepts (`selectedPlayer`, `leaguePlayerName`, `practiceKey`).

Acceptance criteria:
- No behavior changes in manual smoke tests.
- iOS + Android builds green.

## Phase 2: Persistence Boundary Consolidation
- iOS: centralize all legacy key fallbacks to one persistence adapter.
- Android: formalize canonical as single source of truth; isolate runtime projection layer.
- Add explicit migration-complete gates (version or one-time marker) to disable old branches safely.

Acceptance criteria:
- Upgrade tests from v1/v2/v3 fixtures all pass.
- New writes only use canonical pathway.

## Phase 3: Legacy Path Retirement
- Remove code guarded by migration-complete gates.
- Remove duplicate legacy summary/action conversion once old payloads are unsupported.
- Keep one documented compatibility horizon.

Acceptance criteria:
- No references to retired keys/parsers in runtime code.
- Cold install + upgrade scenarios validated.

## Phase 4: Toolchain Modernization (separate stream)
- AGP/Kotlin DSL migration.
- Remove deprecated `gradle.properties` flags safely.

Acceptance criteria:
- Build works with modern defaults.
- Deprecation warnings materially reduced.

---

## 6. Verification Matrix

### 6.1 Required automated checks each cleanup PR
- iOS: `xcodebuild ... build` for primary scheme.
- Android: `./gradlew :app:compileDebugKotlin`.
- Targeted unit tests where parsing/migration behavior is changed.

### 6.2 Required manual checks
- Practice quick entry for score/study/video/practice/mechanics.
- Practice game view input/log switching and swipe minimize behavior.
- Journal swipe reveal close/edit/delete behavior.
- League mini cards:
  - Stats reflects selected practice player when matched.
  - Standings alternates `Top 5` and `Around You`.
  - Around window centered with edge handling.

---

## 7. Immediate Next Actions

1. Add migration fixture tests for known legacy payloads (iOS + Android).
2. Introduce a single shared cleanup tracker (file-level checklist) for migration-path retirement.
3. Start Phase 2 with persistence-boundary consolidation before any broad deletion.

---

## 8. Change Log for This Blueprint

- Replaces prior high-level architecture view with cleanup-focused, migration-aware architecture.
- Adds explicit risk and retirement strategy for v1/v2/v3 residual code.
- Adds phased execution and validation criteria for safe cleanup across both platforms.
- 2026-02-27 (Phase 2 progress):
  - iOS league preview now uses the shared Practice persistence loader instead of direct JSON decode of legacy/current keys.
    - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStorePersistence.swift`
    - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/league/LeaguePreviewModel.swift`
  - iOS persistence decode logic is now centralized in a pure codec with legacy Date-decoding fallback detection.
    - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeStateCodec.swift`
  - Android migration tests now use fixture payloads for both legacy and canonical inputs.
    - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/test/java/com/pillyliu/pinballandroid/practice/PracticeCanonicalPersistenceTest.kt`
    - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/test/resources/practice/legacy_state_v1.json`
    - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/test/resources/practice/canonical_state_v4.json`
  - Added iOS XCTest target and fixture-based migration tests.
    - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2Tests/PracticeStateCodecTests.swift`
    - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2Tests/Fixtures/canonical_millis_v4.json`
    - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2Tests/Fixtures/legacy_reference_date_v4.json`
  - Migration checks are now release-gated in both CI and Fastlane lanes (iOS + Android) before beta/release packaging.
    - `/Users/pillyliu/Documents/Codex/Pinball App/.github/workflows/ci.yml`
    - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/fastlane/Fastfile`
    - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/fastlane/Fastfile`
  - Android lint cleanup: fixed a real `SuspiciousIndentation` failure in Targets screen and reran lint to green.
    - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid/targets/TargetsScreen.kt`
  - Android lint warning count reduced (from 7 to 6 warnings) by replacing one non-KTX SharedPreferences write path.
    - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinballandroid/practice/PracticeStore.kt`
  - Repository hygiene: local Playwright scratch artifacts are now ignored by default.
    - `/Users/pillyliu/Documents/Codex/Pinball App/.gitignore`
