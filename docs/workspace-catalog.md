# Workspace Catalog

This document inventories the parts of the workspace that are not the primary app source code.

Excluded from this catalog:
- iOS feature source under `Pinball App 2/Pinball App 2/`
- Android feature source under `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/`

The goal here is to make cleanup easier by separating:
- active operational assets we should keep visible
- generated or local-only artifacts we can safely purge
- sensitive local files that should stay private
- archival material that should move only into dated snapshots

## Active Shared Docs And References

| Path | Role | Suggested status |
| --- | --- | --- |
| `README.md` | workspace entrypoint and release anchors | keep active |
| `Pinball_App_Architecture_Blueprint.md` | active system blueprint | keep active |
| `Pinball_App_Architecture_Blueprint_print_layout.pdf` | rendered companion to the active blueprint | keep active |
| `RELEASE_NOTES_3.5.0.md` | latest checked-in release-notes snapshot | keep active until replaced by a newer snapshot |
| `docs/codebase/` | code bible and ownership map | keep active |
| `docs/review/` | cleanup and review history | keep active, low churn |
| `docs/modernization/` | future-facing planning and parity work | keep active |
| `docs/marketing/` | promo and collateral planning | keep active |
| `docs/ios_rulesheet_rotation_preservation.md` | focused technical note | keep active |
| `docs/score-scan-calibration-chart.svg` and `docs/rendered/score-scan-calibration-chart.png` | calibration/support visual asset | keep active |

## Operational Tooling And Automation

| Path | Role | Suggested status |
| --- | --- | --- |
| `.github/workflows/` | CI workflow definitions | keep active |
| `.xcodebuildmcp/config.yaml` | simulator/debug session defaults | keep active |
| `scripts/` | doc rendering, asset sync, and API helper scripts | keep active |
| `Pinball App 2/fastlane/` | iOS release automation | keep active |
| `Pinball App Android/fastlane/` | Android release automation | keep active |
| `Pinball App 2/Gemfile` and `Pinball App 2/Gemfile.lock` | iOS Fastlane Ruby dependencies | keep active |
| `Pinball App Android/Gemfile` and `Pinball App Android/Gemfile.lock` | Android Fastlane Ruby dependencies | keep active |
| `Pinball App Android/gradle/`, `gradlew`, `gradlew.bat`, `gradle.properties`, `settings.gradle.kts` | Android build tooling | keep active |
| `Pinball App Android/docs/android-material3-screen-audit.md` | Android-specific supporting doc | keep active |

## Branding, Exported Assets, And Web Assets

| Path | Approx size | Role | Suggested status |
| --- | ---: | --- | --- |
| `exported_logo_assets/source/PinProf Logo Cropped HQ.jpg` | part of `15M` source folder | tracked in-workspace source master | keep active as source asset |
| `exported_logo_assets/source/PinProf Logo Upscaled HQ.jpg` | part of `15M` source folder | tracked in-workspace source master | keep active as source asset |
| `exported_logo_assets/` | `2.7M` | exported icons, splash assets, favicon, platform outputs | keep active |
| `web-assets/` | `172K` | website-facing asset support | keep active |

Recommendation:
- root-level logo masters have been moved out of the repo root into the tracked source-assets folder `exported_logo_assets/source/`
- keep future master branding assets in tracked source folders rather than in the repo root
- the truly largest PNG masters can live outside the workspace, but these tracked JPGs are the in-repo regeneration source assets

## Archive And Historical Material

| Path | Approx size | Role | Suggested status |
| --- | ---: | --- | --- |
| `archive/` | `4.1M` | dated retired docs and scripts | keep active as the only historical snapshot area |
| `archive/README.md` | archive policy and rationale | keep active |

Archiving rule going forward:
- active docs keep stable names
- snapshots move into dated folders under `archive/`
- example:
  - `archive/2026-04-01-doc-snapshot/Pinball_App_Architecture_Blueprint.md`
  - `archive/2026-04-01-doc-snapshot/Pinball_App_Architecture_Blueprint_print_layout.pdf`

## Local Virtual Environments

| Path | Approx size | Role | Suggested status |
| --- | ---: | --- | --- |
| `.venv/` | `80M` | general local Python environment | local-only, safe to recreate |
| `.venv-architecture-docs/` | `37M` | architecture render environment | local-only, safe to recreate |
| `.venv_pdf/` | `40M` | PDF-related environment | local-only, safe to recreate |
| `tmp/pdfs/.venv/` | included in `tmp/` | nested temp environment | local-only, cleanup candidate |

Recommendation:
- keep if they speed up local work
- delete whenever space matters; scripts can recreate them

## Generated Output And Temporary Work Areas

| Path | Approx size | Role | Suggested status |
| --- | ---: | --- | --- |
| `output/` | `1.7M` | generated output artifacts | safe to purge |
| `tmp/` | `99M` | temp render and PDF work area | safe to purge |
| `Pinball App 2/build/` | ignored | Xcode build output | safe to purge |
| `Pinball App Android/build/` | ignored | Gradle build output | safe to purge |
| `Pinball App Android/.gradle/`, `.idea/`, `.kotlin/`, `vendor/`, `.bundle/` | ignored or local tooling state | local-only, safe to purge selectively |
| `output/.DS_Store` | tiny | Finder metadata | delete |
| `Pinball App 2/fastlane/report.xml` and `Pinball App Android/fastlane/report.xml` | test/report artifact | safe to purge |

Most obvious cleanup candidates right now:
- regenerated `tmp/` output when it reappears
- regenerated `output/` output when it reappears
- Fastlane `report.xml` artifacts

## Release Artifacts

| Path | Approx size | Role | Suggested status |
| --- | ---: | --- | --- |
| `archive/2026-04-01-release-artifacts/PinProf.ipa` | part of `36M` archive folder | archived local iOS release artifact | keep archived locally or move to external release storage |
| `archive/2026-04-01-release-artifacts/PinProf.app.dSYM.zip` | part of `36M` archive folder | archived local crash-symbol bundle | keep archived locally or move to external release storage |

Recommendation:
- these no longer live in the working app folder
- preferred long-term home is either the dated local archive folder or external release storage

## Sensitive And Local-Only Credentials

| Path | Role | Suggested status |
| --- | --- | --- |
| `Pinball App Android.jks` | Android signing key | keep private, do not move into active docs areas |
| `Pinball App Android/keystore.properties` | signing config | keep private |
| `Pinball App Android/local.properties` | local SDK path config | keep private and machine-local |
| `Pinball App Android/fastlane/play-store-service-account.json` | Play API credential | keep private |
| `Pinball App 2/fastlane/.env.default` | local iOS Fastlane env file | keep private/local-only |

Recommendation:
- keep these out of catalog snapshots unless the snapshot is explicitly private and local-only

## Suggested Cleanup Order

1. Safe immediate cleanup:
   - delete regenerated `tmp/`
   - delete regenerated `output/`
   - delete regenerated Finder metadata and Fastlane report artifacts
2. Low-risk workspace organization:
   - keep loose asset masters and release artifacts out of the repo root and app folders
3. Space recovery if needed:
   - remove local virtualenvs
   - remove local build caches and IDE state
4. Leave in place:
   - `docs/`
   - `scripts/`
   - `archive/`
   - `exported_logo_assets/`
   - `web-assets/`
   - CI and simulator config

## Recommended Steady-State Root Layout

The root should ideally stay focused on:
- the two app folders
- active top-level docs (`README.md`, release notes snapshot, stable blueprint files)
- `docs/`
- `scripts/`
- `archive/`
- asset folders that are still intentionally shared across platforms

The root should ideally not accumulate:
- loose logo masters
- old `.ipa` or symbol archives
- temp render directories
- generated outputs that can be rebuilt
