# Archived Pinball App Files

Archived local-only files that are no longer part of the supported app workflow live under this folder.

Guidelines:

- keep archived files for local reference only
- do not treat archive contents as active app runtime, preload, or build dependencies
- archive contents are gitignored so historical planning/spec files do not drift back into the main workspace by accident

## Archived on 2026-03-25

Folder:

- `archive/2026-03-25-retired-docs/`

Archived today:

- historical root planning/checklist/blueprint documents that no longer describe the current app architecture
- generated PDF snapshots for those historical documents
- `docs/ios_shake_warning_parity_spec.md`

Why these were archived:

- the active app docs are now `README.md`, `Pinball_App_Architecture_Blueprint_latest.md`, and the still-relevant docs under `docs/`
- old blueprint revisions, dated rollout plans, and parity notes were cluttering the repo root after the CAF migration landed
- the retired shake-warning parity spec still described `shared/pinball`, starter-pack assets, and hosted warning art, which are no longer the active app path

## Archived on 2026-03-25 (Retired helper scripts)

Folder:

- `archive/2026-03-25-retired-scripts/`

Archived today:

- `scripts/audit_rulesheet_links.py`
- `scripts/build_external_rulesheet_resources.py`
- `scripts/build_library_seed_db.py`
- `scripts/build_local_asset_intake.py`
- `scripts/build_matchplay_tutorial_enrichment.py`
- `scripts/fetch_opdb_snapshot.py`

Why these were archived:

- they were legacy app-side bridge helpers from the old `shared/pinball` and starter-pack era
- their active replacements now live in `PinProf Admin/scripts`, where CAF generation and publish work actually belongs
- keeping them in the app repo made it look like the app still owned data generation, catalog bridging, or starter-pack maintenance

## Archived on 2026-03-25 (Doc refresh snapshots)

Folder:

- `archive/2026-03-25-doc-refresh/`

Archived today:

- pre-refresh copies of `docs/modernization/features/library/ledger.md`
- pre-refresh copies of `docs/modernization/features/library/spec.md`
- pre-refresh copies of `docs/modernization/features/library/parity.md`

Why these were archived:

- the live library modernization docs were updated to describe the CAF preload/hosted contract instead of starter-pack or merged-bridge terminology
- keeping a local snapshot preserves the old wording for reference without leaving stale architecture language in the active docs tree
