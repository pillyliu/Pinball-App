# Live Duplicate Conflict Report

Checked on `2026-03-27` against the current hosted data on `https://pillyliu.com/pinball/data/...`.

Scope:
- `lpl_machine_mappings_v1.json`
- `lpl_targets_resolved_v1.json`
- `opdb_export.json`

Purpose:
- confirm whether the current developer-log duplicate warnings should be firing on live data
- surface concrete duplicate-like cases we may want to resolve intentionally

## Current exact-conflict result

No exact duplicate conflicts were found in the three currently logged paths:

- `ResolvedLeagueMachineMappings`
  - duplicate key rule checked: normalized machine name via `LibraryGameLookup.normalizeMachineName(_:)`
  - live result: `0` duplicate normalized machine keys
- `ResolvedLeagueTargets`
  - duplicate key rule checked: duplicate non-empty `practice_identity`
  - live result: `0` duplicate practice identities
- `GameRoomCatalogLoader`
  - duplicate key rule checked: duplicate slug-match keys after `buildSlugKeys(from:)`
  - live result: `0` duplicate slug keys

As of this snapshot, the new duplicate developer warnings are guardrails, not active live-data noise.

## Concrete duplicate-like case found during review

Earlier in the March 27 review, the league machine mapping file contained one intentional alias cluster:

- practice identity: `Gd2Xb`
- mapped machine strings:
  - `TMNT`
  - `Teenage Mutant Ninja Turtles`

Why it does not count as a logged conflict:
- the app normalizes those names to different lookup keys (`tmnt` vs `teenagemutantninjaturtles`)
- both rows resolve to the same underlying machine identity, so this is alias coverage rather than a collision

Why it is still useful:
- if we ever decide to tighten league mapping maintenance, this is the clearest current example to review together as “intentional alias pair vs redundant row”
- the app already carries the same alias relationship in `LibraryGameLookup.machineAliases`, so the hosted dual-row coverage may now be redundant instead of necessary
- after checking `../PinProf Admin`, the source league data itself uses both names across seasons (`TMNT` in older rows and `Teenage Mutant Ninja Turtles` in newer rows), so the dual-row mapping is also defensible as explicit source-data normalization rather than dead duplication

## Recommendation

- keep the duplicate warnings in developer logs
- keep checking live hosted data before or after data publishes when a mapping/target export changes
- use the `TMNT` / `Teenage Mutant Ninja Turtles` pair as the first concrete cleanup conversation if we want to reduce intentional alias duplication later
- do not remove that pair casually from the admin data source unless we explicitly decide to rely on the app-side alias fallback for historical league rows

## Follow-up Decision

Approved follow-up in `../PinProf Admin`:

- historical `LPL_Stats.csv` rows were normalized from `TMNT` to `Teenage Mutant Ninja Turtles`
- `LPL_Targets.csv` was normalized to `Teenage Mutant Ninja Turtles`
- the duplicate-like `TMNT` row was removed from `lpl_machine_mappings_v1.json`
- `lpl_targets_resolved_v1.json` was regenerated from the normalized targets source
- `docs/LPL_LEAGUE_DATA_WORKFLOW.md` now explicitly says future stats updates must keep using `Teenage Mutant Ninja Turtles`

## Publish Verification

After the same-day publish/deploy completed, the hosted payloads were rechecked on `2026-03-27` and now show the normalized full-name state live on `pillyliu.com`:

- hosted `LPL_Stats.csv`: `TMNT=0`, `Teenage Mutant Ninja Turtles=466`
- hosted `LPL_Targets.csv`: `TMNT=0`, `Teenage Mutant Ninja Turtles=1`
- hosted `lpl_machine_mappings_v1.json`: one remaining `Teenage Mutant Ninja Turtles` row, no `TMNT` row
- hosted `lpl_targets_resolved_v1.json`: one `Teenage Mutant Ninja Turtles` row, no `TMNT` row

So the concrete alias case surfaced in this review is now resolved both in the admin source workspace and in the live hosted payload.
