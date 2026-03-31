# Tooling And Scripts

This file tracks the main non-feature support tooling in the repo.

## Release Tooling

### iOS Fastlane

Folder:
- `Pinball App 2/fastlane`

Key files:
- `Fastfile`: iOS release lanes and App Store submission flow
- `Appfile`: App Store app identifiers and account wiring
- `.env.default`: expected environment configuration
- `README.md`: lane usage reference

Use this for:
- iOS distribution uploads
- metadata submission
- build-number and release lane operations

### Android Fastlane

Folder:
- `Pinball App Android/fastlane`

Key files:
- `Fastfile`: Android release lanes and Play upload flow
- `Appfile`: Play package/account wiring
- `README.md`: lane usage reference

Use this for:
- Android production uploads
- release bookkeeping

## Build And Simulator Tooling

Folder:
- `.xcodebuildmcp`

Key file:
- `config.yaml`: XcodeBuildMCP session defaults for the repo

Use this for:
- iOS simulator build, run, QA, and UI automation with XcodeBuildMCP

## Project Scripts

Folder:
- `scripts`

Current scripts:
- `export_bob_rulesheet_urls.py`: exports or normalizes Bob's Rulesheet URL data
- `generate_architecture_blueprint.sh`: generates the architecture blueprint workflow entrypoint
- `render_architecture_pdf_upgraded.py`: renders architecture output to PDF
- `render_mermaid_blocks.py`: renders Mermaid blocks for docs output
- `pinball_api_auth.py`: shared auth support for Pinball API automation
- `pinball_api_clients.py`: shared API client helpers for Pinball API tasks
- `sync_shared_app_assets.sh`: syncs shared assets across app targets
- `mermaid_print_theme.json`: Mermaid rendering theme config

## Generated And Support Outputs

Common generated/support folders:
- `docs/rendered`: rendered documentation assets
- `output`: generated output artifacts
- `tmp`: temporary generated content
- `archive`: retired docs and scripts kept for reference

## Preload And Shared Assets

iOS:
- `Pinball App 2/Pinball App 2/PinballPreload.bundle`: bundled preload assets for cache seeding

Android:
- preload data is read from Android assets through the cache storage helpers

Shared exported assets:
- `exported_logo_assets`: icon, splash, and branding exports
- `web-assets`: web-facing asset support

## Documentation Layers

The repo now has several doc layers:
- `docs/codebase`: living architecture and ownership map
- `docs/review`: sequential cleanup and change log
- `docs/modernization`: broader parity and modernization planning
- `docs/marketing`: promo and video planning materials

Use them this way:
- codebase docs explain ownership
- review docs explain change history
- modernization docs explain longer-range direction
- marketing docs are non-code product collateral
