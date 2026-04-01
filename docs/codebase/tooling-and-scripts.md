# Tooling And Scripts

This file tracks the non-feature support layer for the repo: build systems, release automation, CI, preload assets, shared-asset sync, and documentation generation.

## Build Systems

### iOS

Primary project:
- `Pinball App 2/Pinball App 2.xcodeproj`

Version anchors:
- `MARKETING_VERSION = 3.5.2`
- `CURRENT_PROJECT_VERSION = 98`

Important supporting folders:
- `Pinball App 2/Pinball App 2/PinballPreload.bundle/` -> bundled preload manifest and cached-seed payloads
- `Pinball App 2/Pinball App 2/SharedAppSupport/` -> app-owned shared source assets for both platforms

### Android

Primary project:
- `Pinball App Android/app/build.gradle.kts`

Version anchors:
- `versionName = "3.5.2"`
- `versionCode = 59`

Important supporting folders:
- `Pinball App Android/app/src/main/assets/pinprof-preload/` -> Android preload assets
- Android drawables and other generated/shared app assets are refreshed from `SharedAppSupport` via the sync script

## Release Automation

### iOS Fastlane

Folder:
- `Pinball App 2/fastlane`

Key files:
- `Fastfile` -> iOS lanes for build, upload, submit, beta, and release-history support
- `Appfile` -> App Store identifiers and account wiring
- `.env.default.example` -> expected environment variable template
- `README.md` -> auto-generated lane reference

### Android Fastlane

Folder:
- `Pinball App Android/fastlane`

Key files:
- `Fastfile` -> Android lanes for tests, release build, and Play uploads
- `Appfile` -> package/account wiring
- `README.md` -> lane usage reference

## CI

Workflow:
- `.github/workflows/ci.yml`

Current CI coverage:
- Android
  - `./gradlew :app:assembleDebug`
  - `./gradlew :app:testDebugUnitTest --tests com.pillyliu.pinprofandroid.practice.PracticeCanonicalPersistenceTest`
- iOS
  - resolves a current simulator dynamically
  - `xcodebuild ... build-for-testing`
  - `xcodebuild ... -only-testing:"Pinball App 2Tests/PracticeStateCodecTests" test-without-building`

## Local Simulator And QA Tooling

Folder:
- `.xcodebuildmcp/`

Key file:
- `config.yaml` -> XcodeBuildMCP defaults for simulator QA and debug sessions in this repo

Use this for:
- iOS simulator build and run
- manual QA passes
- UI inspection and screenshot capture
- debugger attach flows

## Project Scripts

Folder:
- `scripts/`

Architecture and docs:
- `generate_architecture_blueprint.sh` -> one-command blueprint render entrypoint
- `render_architecture_pdf_upgraded.py` -> PDF generation pipeline
- `render_mermaid_blocks.py` -> Mermaid block rendering support
- `mermaid_print_theme.json` -> print-theme config for rendered diagrams

Shared app support and assets:
- `sync_shared_app_assets.sh` -> refreshes shared intro and shake-warning assets into platform-specific bundles

Pinball API and data utilities:
- `pinball_api_auth.py` -> auth helpers for Pinball API tasks
- `pinball_api_clients.py` -> shared client helpers
- `export_bob_rulesheet_urls.py` -> rulesheet URL export and normalization helper

## Shared Support Assets

Bundled source-of-truth assets live in:
- `Pinball App 2/Pinball App 2/SharedAppSupport/pinside_group_map.json`
- `Pinball App 2/Pinball App 2/SharedAppSupport/shake-warnings/`
- `Pinball App 2/Pinball App 2/SharedAppSupport/app-intro/`

These assets are app-owned, not part of the hosted `/pinball` publish payload.

## Generated And Local-Only Output Areas

Working output folders:
- `docs/rendered/` -> rendered documentation assets used by docs
- `output/` -> generated output artifacts
- `tmp/` -> temporary generated content, including PDF work areas

Historical and retired material:
- `archive/` -> retired docs, scripts, and prior blueprint refresh snapshots

Local helper environments:
- `.venv/`
- `.venv-architecture-docs/`
- `.venv_pdf/`

These support local rendering and automation and are not part of the product runtime.

## Documentation Workflow

When architecture docs need refresh:
1. update `README.md` if versions, layout, or doc entrypoints changed
2. update `docs/codebase/ios.md` and or `docs/codebase/android.md` for ownership changes
3. update this file if tooling, scripts, CI, preload, or release flow changed
4. update `Pinball_App_Architecture_Blueprint.md` for system-model changes
5. rerun `./scripts/generate_architecture_blueprint.sh` to refresh `Pinball_App_Architecture_Blueprint_print_layout.pdf`
