# Codebase Bible

This is the living architecture map for PinProf across iOS and Android.

Use it to answer four questions quickly:
- what each folder owns
- which files are the entrypoints or coordinators
- where shared or paired behavior should stay aligned across platforms
- which scripts and release tools support the app

## How To Use This

Start here, then jump to:
- `ios.md` for the SwiftUI app map
- `android.md` for the Android app map
- `tooling-and-scripts.md` for release, preload, rendering, and support scripts

The detailed cleanup history still lives in:
- `../review/ios-sequential-code-review.md`

This folder is the "what owns what" layer.
The review log is the "what changed and why" layer.

## Update Rules

Update these docs when:
- a file changes responsibility
- a feature folder gets split or renamed
- a new support layer becomes the intended owner of a behavior
- a script or release lane gets added, removed, or repurposed

When a change is paired across iOS and Android:
- try to document both sides in the same pass
- keep the description conceptually 1:1 unless the platform difference is real

When a change is not paired:
- say which platform owns the unique behavior
- say why the asymmetry is intentional

## Paired Feature Map

The main paired feature lanes are:
- app shell and onboarding
- library
- practice
- gameroom
- league
- settings
- stats
- standings
- targets
- shared UI chrome
- cache and hosted asset loading

The main support lanes that may differ more by platform are:
- app startup and runtime integration
- image loading and media presentation
- camera and score scanning
- release tooling and store upload setup

## Ownership Style

The intended structure across the app is:
- screen or route files own navigation and composition
- store, state, or view model files own mutable feature state
- support files own parsing, formatting, lookup, import, and focused UI helpers
- data and cache files own preload, caching, hosted fetch, and refresh coordination
- shared UI files own chrome, spacing, filters, pills, surfaces, and common interaction patterns

If a file starts mixing several of those layers, it is a candidate for cleanup.

## Current Late-stage Focus

As of the latest cleanup passes, the remaining planned work is:
- shared UI and theme consistency
- cache and hosted-asset validation
- paired smoke and UI automation coverage
- perf follow-up only if QA reveals a real issue
