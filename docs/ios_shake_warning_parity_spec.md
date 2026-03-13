# iOS Shake Warning Feature Spec

Date captured: 2026-03-13

Purpose: document the current iOS shake-warning easter egg in enough detail to reproduce it 1:1 on Android later. This is not a formal version release note. It is a feature baseline and parity spec.

Reference commits:
- App repo: `7795cee` (`Add app-wide pinball shake warnings`)
- Shared website/data repo: `4297c3e` (`Add shared shake warning artwork assets`)

## Feature Summary

The app now has an app-wide "pinball warning" shake easter egg on iOS.

Behavioral rule:
- If native iOS shake-to-edit would handle the shake, the app does nothing custom.
- If native iOS shake-to-edit would *not* handle the shake, the app shows a custom overlay and plays escalating haptics.

Escalation sequence:
1. `DANGER`
2. `DANGER DANGER`
3. `TILT`

This sequence is intentionally modeled after warning escalation in a pinball machine when a player nudges too aggressively.

## Exact User-Facing Copy

Level copy is defined in `Pinball App 2/Pinball App 2/app/AppShakeCoordinator.swift`.

| Level | Title | Subtitle |
| --- | --- | --- |
| 1 | `DANGER` | `A little restraint, if you please.` |
| 2 | `DANGER DANGER` | `Really, this is most uncivilised shaking.` |
| 3 | `TILT` | `That is quite enough! I will not tolerate any further indignity in this cabinet of higher learning.` |

## Where the Feature Lives

### Runtime iOS files

- `Pinball App 2/Pinball App 2/app/ContentView.swift`
  Attaches the shake handler to the root `TabView` and overlays the warning UI above the entire app.
- `Pinball App 2/Pinball App 2/ui/SharedGestures.swift`
  Implements device-motion-based shake detection.
- `Pinball App 2/Pinball App 2/app/AppShakeCoordinator.swift`
  Contains:
  - warning level definitions
  - escalation state machine
  - native undo gating
  - haptics
  - overlay UI
  - art loading
- `Pinball App 2/Pinball App 2/library/LibraryResourceResolution.swift`
  Centralizes the missing-art fallback path used by both the library and the shake overlay.
- `Pinball App 2/Pinball App 2Tests/AppShakeCoordinatorTests.swift`
  Unit coverage for key behavior.

### Shared asset and packaging files

These live in the separate website/data repo and matter because the professor images are shared assets, not iOS-only assets.

- `../Pillyliu Pinball Website/shared/pinball/images/playfields/fallback-image-not-available_2048.webp`
- `../Pillyliu Pinball Website/shared/pinball/images/ui/shake-warnings/professor-danger_1024.webp`
- `../Pillyliu Pinball Website/shared/pinball/images/ui/shake-warnings/professor-danger-danger_1024.webp`
- `../Pillyliu Pinball Website/shared/pinball/images/ui/shake-warnings/professor-tilt_1024.webp`
- `../Pillyliu Pinball Website/tools/sync-pinball-data.mjs`
- `../Pillyliu Pinball Website/tools/smoke-check.mjs`
- `../Pillyliu Pinball Website/deploy.sh`

### Starter-bundle copies

The iOS runtime loads these from the starter bundle:

- `Pinball App 2/Pinball App 2/PinballStarter.bundle/pinball/images/playfields/fallback-image-not-available_2048.webp`
- `Pinball App 2/Pinball App 2/PinballStarter.bundle/pinball/images/ui/shake-warnings/professor-danger_1024.webp`
- `Pinball App 2/Pinball App 2/PinballStarter.bundle/pinball/images/ui/shake-warnings/professor-danger-danger_1024.webp`
- `Pinball App 2/Pinball App 2/PinballStarter.bundle/pinball/images/ui/shake-warnings/professor-tilt_1024.webp`

The Android starter-pack copies are already present for the later port:

- `Pinball App Android/app/src/main/assets/starter-pack/pinball/images/playfields/fallback-image-not-available_2048.webp`
- `Pinball App Android/app/src/main/assets/starter-pack/pinball/images/ui/shake-warnings/professor-danger_1024.webp`
- `Pinball App Android/app/src/main/assets/starter-pack/pinball/images/ui/shake-warnings/professor-danger-danger_1024.webp`
- `Pinball App Android/app/src/main/assets/starter-pack/pinball/images/ui/shake-warnings/professor-tilt_1024.webp`

## App-Wide Wiring

`ContentView` owns a single `@StateObject` `AppShakeCoordinator`.

Key wiring:
- The shake handler is attached at the root app shell level, not to a single screen.
- The handler is enabled only when `scenePhase == .active`.
- The overlay is rendered as a root `.overlay { ... }` above the full `TabView`.

Implication:
- The feature works anywhere in the app where the root `ContentView` is present.
- It is not scoped to Practice.
- It is intentionally global, while still respecting native undo behavior.

## Native Undo Gating

The custom warning is a fallback, not a replacement for iOS behavior.

The coordinator first checks `UIApplication.shared.applicationSupportsShakeToEdit`.

If shake-to-edit is supported, it checks for undo/redo availability in this order:
- current first responder undo manager
- key window undo manager
- key window root view controller undo manager

If any of those can undo or redo, the app does not show the custom warning and does not play the custom haptic.

Important parity rule:
- Android should preserve the spirit of this gating rule once the platform behavior is defined.
- The custom warning should only fire when it is not stomping on a native or expected text-editing undo affordance.

Important state rule:
- A shake that is consumed by native undo does **not** reset the custom escalation sequence.

## Shake Detection

Shake detection is implemented with `CMMotionManager` device motion tuned to feel closer to the native iOS shake gesture, rather than a loose single-spike trigger.

### Lifecycle

- Starts on `onAppear`
- Stops on `onDisappear`
- Reconfigures on `isEnabled` changes
- Does nothing if device motion is unavailable
- Does not start a second motion stream if one is already active

### Sampling

- Update interval: `1 / 30` seconds
- Effective sampling rate: `30 Hz`

### Motion math

It uses `motion.userAcceleration`.

Calculated values:
- magnitude = `sqrt(x^2 + y^2 + z^2)`
- peakAxis = `max(abs(x), abs(y), abs(z))`

### Shake thresholds

The detector uses a short two-hit confirmation window instead of accepting a single qualifying sample.

A shake is accepted only if:
- at least `0.85s` has elapsed since the last accepted shake
- one qualifying motion sample is followed by a second qualifying sample within `0.18s`
- and each qualifying sample satisfies either:
  - magnitude `> 2.45`
  - or magnitude `> 1.85` and peakAxis `> 1.35`

This is intentionally less sensitive than the original implementation and better matches the feel of a deliberate iPhone shake.

## Escalation State Machine

Internal state:
- `fallbackShakeCount`
- `overlayLevel`
- `overlayToken`

### Rules

- The first eligible shake presents `DANGER`
- The second eligible shake presents `DANGER DANGER`
- The third eligible shake presents `TILT`
- When `TILT` is reached, `fallbackShakeCount` immediately resets to `0`
- While `overlayLevel == .tilt`, additional shakes are ignored
- After `TILT` has dismissed, the next eligible shake starts over at `DANGER`

### Timer behavior

Each presentation increments `overlayToken`.

Dismissal tasks compare their token against the current token before clearing the overlay. This prevents an older dismissal task from removing a newer overlay if the user escalates quickly while a previous level is still on-screen.

### What this feels like

- Shake once: `DANGER`
- Shake again while eligible: overlay upgrades in place to `DANGER DANGER`
- Shake a third time while eligible: overlay upgrades in place to `TILT`
- Wait for `TILT` to clear: next cycle begins again at `DANGER`

## Timing Spec

### Overlay display durations

| Level | Duration |
| --- | --- |
| `DANGER` | `3.0s` |
| `DANGER DANGER` | `3.5s` |
| `TILT` | `4.5s` |

### Animation timing

- Show animation: `easeInOut(duration: 0.18)`
- Hide animation: `easeOut(duration: 0.30)`
- Transition type: `.opacity`

Important visual rule:
- The overlay does **not** scale down on dismiss.
- It simply fades away.

## Haptics Spec

Haptics are only played on the custom fallback path.

If native undo handles the shake:
- no custom haptic
- no custom overlay

### Start delays

| Level | Haptic start delay |
| --- | --- |
| `DANGER` | `0.05s` |
| `DANGER DANGER` | `0.20s` |
| `TILT` | `0.20s` |

### Core Haptics implementation

Core Haptics is used first when hardware supports it.

`DANGER`
- pulse count: `1`
- spacing: `0.00s`
- intensity: `0.74`
- sharpness: `0.36`
- continuous buzz duration: `0.11s`

`DANGER DANGER`
- pulse count: `2`
- spacing: `0.17s`
- intensity: `0.82`
- sharpness: `0.38`
- continuous buzz duration per pulse: `0.11s`

`TILT`
- pulse count: `3`
- spacing: `0.15s`
- intensity: `1.00`
- sharpness: `0.45`
- continuous buzz duration per pulse: `0.14s`

Each pulse is built from:
- one `.hapticTransient`
- one `.hapticContinuous`

### UIKit fallback haptics

If Core Haptics is unavailable:

`DANGER`
- `UIImpactFeedbackGenerator(style: .rigid)`
- intensity `1.0`
- count `1`

`DANGER DANGER`
- `UIImpactFeedbackGenerator(style: .rigid)`
- intensity `1.0`
- count `2`
- spacing `170ms`

`TILT`
- `UIImpactFeedbackGenerator(style: .heavy)`
- intensity `1.0`
- count `3`
- spacing `150ms`

### Engine behavior

- One static `CHHapticEngine` is reused
- `isAutoShutdownEnabled = true`
- `resetHandler` and `stoppedHandler` both nil out the cached engine
- A previous playback task is cancelled before a new one starts

Parity note:
- Android should match the count, spacing, and escalation feel as closely as possible, even if the vibration API differs.

## Visual Design Spec

### Full-screen overlay background

The overlay covers the full screen and ignores safe areas.

Background:
- `LinearGradient`
- start: `.top`
- end: `.bottom`

Opacity values:

| Level | Top color | Bottom color |
| --- | --- | --- |
| `DANGER` | `level.tint.opacity(0.20)` | `black.opacity(0.42)` |
| `DANGER DANGER` | `level.tint.opacity(0.20)` | `black.opacity(0.42)` |
| `TILT` | `level.tint.opacity(0.32)` | `black.opacity(0.58)` |

### Level colors

Literal level colors:

| Level | Tint | Glow |
| --- | --- | --- |
| `DANGER` | `Color(red: 1.00, green: 0.62, blue: 0.18)` | `Color(red: 1.00, green: 0.82, blue: 0.36)` |
| `DANGER DANGER` | `Color(red: 1.00, green: 0.34, blue: 0.16)` | `Color(red: 1.00, green: 0.52, blue: 0.18)` |
| `TILT` | `Color(red: 1.00, green: 0.14, blue: 0.14)` | `Color(red: 1.00, green: 0.28, blue: 0.18)` |

Approximate hex equivalents:

| Level | Tint | Glow |
| --- | --- | --- |
| `DANGER` | `#FF9E2E` | `#FFD15C` |
| `DANGER DANGER` | `#FF5729` | `#FF852E` |
| `TILT` | `#FF2424` | `#FF472E` |

### Card container

The warning content sits inside a centered rounded-rectangle card.

Card styling:
- corner radius: `28`
- fill: `.ultraThinMaterial`
- border: `level.glow.opacity(0.78)`, line width `1.2`
- shadow: `level.tint.opacity(0.35)`, radius `28`, y `12`

Additional glow overlay inside the card:
- `LinearGradient`
- colors:
  - `level.glow.opacity(0.34)`
  - `clear`
  - `level.tint.opacity(0.22)`
- start: `.topLeading`
- end: `.bottomTrailing`

### Progress bars

There are always `3` capsules, one for each possible warning level.

Bar styling:
- shape: `Capsule`
- active fill: `level.glow`
- inactive fill: `white.opacity(0.14)`
- height: `8`

Widths:
- portrait: `52`
- landscape: `44`

Active bar count:
- `DANGER`: `1`
- `DANGER DANGER`: `2`
- `TILT`: `3`

### Title and subtitle typography

Title:
- font: `.system(size: 34, weight: .black, design: .rounded)`
- tracking: `2.5`
- color: `level.glow`

Subtitle:
- size: `17`
- preferred fonts, in order:
  - `Baskerville-SemiBoldItalic`
  - `Baskerville-Italic`
  - `TimesNewRomanPS-ItalicMT`
  - fallback: semibold serif italic system font
- color: `white.opacity(0.88)`
- line spacing: `2`

### Layout spacing

Copy section spacing:
- outer copy stack spacing: `16`
- inner title/subtitle stack spacing: `8`

Portrait content stack spacing:
- `18`

### Interaction

The overlay uses:
- `.allowsHitTesting(false)`

That means it is visually present but does not intercept touches.

## Portrait Layout

Portrait keeps a stacked layout:
- square professor image box on top
- warning bars + title + subtitle below

Portrait sizing:
- outer horizontal padding: `28`
- outer vertical padding: `24`
- card horizontal padding: `28`
- card vertical padding: `24`
- card width clamp: `min(max(screenWidth - 56, 280), 420)`
- image box side: `min(portraitCardWidth - 56, 360)`

Important current rule:
- The portrait image box is square.
- The image uses `scaledToFill()`.
- The image is clipped by the rounded rectangle, so corner cropping is intentional and acceptable.

## Landscape Layout

Landscape uses a side-by-side centered layout:
- square image pane on the left
- square text pane on the right

Key intent:
- the image/text split should land at the middle of the screen
- the whole card must stay on-screen

Landscape sizing:
- outer horizontal padding: `28`
- outer vertical padding: `24`
- card horizontal padding: `22`
- card vertical padding: `20`
- pane spacing: `20`
- max card width: `min(screenWidth - 56, 760)`
- max card height: `min(screenHeight - 48, 340)`
- pane width:
  `min((maxLandscapeCardWidth - (cardHorizontalPadding * 2) - landscapeSpacing) / 2,
       maxLandscapeCardHeight - (cardVerticalPadding * 2))`

Derived card size:
- card width = `paneWidth * 2 + landscapeSpacing + cardHorizontalPadding * 2`
- card height = `paneWidth + cardVerticalPadding * 2`

Important current rule:
- The left art box is always square in landscape.
- The right copy block is framed to the same square width and height.

## Image Box Spec

The professor image box is shared between portrait and landscape.

Styling:
- corner radius: `24`
- background fill: `AppTheme.atmosphereBottom.opacity(0.96)`
- border: `level.glow.opacity(0.72)`, line width `1.2`
- shadow: `level.tint.opacity(0.24)`, radius `18`, y `8`

Image behavior:
- source image view is `resizable()`
- content mode is `scaledToFill()`
- the containing rounded rectangle clips the image
- no letterboxing is desired

This is an important parity rule for Android:
- fill the square box
- crop as needed
- let the rounded shape crop the image corners
- do not use fit-with-padding

## Art Loading Order

For each level, art loading order is:

1. Shared bundled starter-bundle file at `bundledArtPath`
2. Local asset catalog by `artAssetName`
3. Shared bundled missing-art fallback image at `libraryMissingArtworkPath`
4. Emergency placeholder view if even the fallback cannot load

This means the shared starter-bundle images are the canonical source right now.

### Current art paths

| Level | Bundled path |
| --- | --- |
| `DANGER` | `/pinball/images/ui/shake-warnings/professor-danger_1024.webp` |
| `DANGER DANGER` | `/pinball/images/ui/shake-warnings/professor-danger-danger_1024.webp` |
| `TILT` | `/pinball/images/ui/shake-warnings/professor-tilt_1024.webp` |

### Asset-catalog fallback names

| Level | Asset name |
| --- | --- |
| `DANGER` | `ProfessorShakeDanger` |
| `DANGER DANGER` | `ProfessorShakeDoubleDanger` |
| `TILT` | `ProfessorShakeTilt` |

### Current shared image inventory

| File | Role | Size |
| --- | --- | --- |
| `fallback-image-not-available_2048.webp` | shared missing-art fallback | `2048x1536`, about `353 KB` |
| `professor-danger_1024.webp` | `DANGER` art | `1024x1024`, about `93 KB` |
| `professor-danger-danger_1024.webp` | `DANGER DANGER` art | `1024x1024`, about `125 KB` |
| `professor-tilt_1024.webp` | `TILT` art | `1024x1024`, about `141 KB` |

Professor images were intentionally converted to `webp` at quality `85`.

## Emergency Placeholder

The emergency placeholder should only appear if the shared image and the normal fallback image both fail to load.

Placeholder styling:
- background gradient:
  - `black.opacity(0.76)`
  - `level.tint.opacity(0.18)`
  - `AppTheme.brandInk.opacity(0.92)`
- icon: `person.crop.rectangle.stack.fill`
- icon size: `56`
- icon color: `level.glow.opacity(0.94)`
- message: `Sorry, no image available`
- footer text: `Drop artwork into asset: <asset name>`

## Shared Data and Deploy Pipeline

### Canonical shared location

Professor warning art is intentionally **not** stored under `images/playfields`.

It lives under:
- `shared/pinball/images/ui/shake-warnings/`

Reason:
- it is UI illustration, not actual playfield media
- `playfields` should remain reserved for real machine/playfield artwork and playfield fallbacks

### Starter-pack sync behavior

`tools/sync-pinball-data.mjs` copies `shared/pinball` into iOS and Android starter packs, then prunes playfield files.

Key rule:
- playfields are usually pruned down to practice-ready `_700.webp` images
- `fallback-image-not-available_2048.webp` is a deliberate exception

The exception list is:
- `/pinball/images/playfields/fallback-whitewood-playfield_700.webp`
- `/pinball/images/playfields/fallback-image-not-available_2048.webp`

Important nuance:
- the professor warning art does not need a special prune exception because it is stored under `images/ui/shake-warnings/`, not under `images/playfields/`

### Smoke-check contract

`tools/smoke-check.mjs` now requires these shared images to exist and to be present in `shared/pinball/cache-manifest.json`:

- `playfields/fallback-image-not-available_2048.webp`
- `ui/shake-warnings/professor-danger_1024.webp`
- `ui/shake-warnings/professor-danger-danger_1024.webp`
- `ui/shake-warnings/professor-tilt_1024.webp`

### Deploy contract

`deploy.sh` stages the pinball payload and treats the following as required:

- `images/playfields/fallback-image-not-available_2048.webp`
- `images/ui/shake-warnings/professor-danger_1024.webp`
- `images/ui/shake-warnings/professor-danger-danger_1024.webp`
- `images/ui/shake-warnings/professor-tilt_1024.webp`

If one of those files is missing from the shared payload during staging, the deploy script will try to copy it from fallback starter-pack sources.

## Tests and What They Cover

`AppShakeCoordinatorTests` currently verify:
- exact display durations
- exact haptic start delays
- exact shared bundled art paths
- native undo suppresses the custom overlay
- fallback shakes escalate across separate shakes
- native undo does not reset the escalation sequence
- escalating levels dispatch escalating haptic calls

What is **not** covered in automated tests:
- actual Core Haptics feel on hardware
- visual geometry of portrait vs landscape overlay
- motion threshold tuning on real devices
- the end-to-end shared asset sync/deploy pipeline inside the app repo

## Android Parity Requirements

Do not simplify these on port unless we consciously decide to diverge later:

- App-wide scope, not Practice-only
- Native undo-or-equivalent precedence over the custom warning
- Same warning titles and subtitles
- Same escalation order
- Same persistence of escalation state across fallback shakes
- Same reset-after-tilt behavior
- Same `0.85s` accepted-shake debounce
- Same `0.18s` two-hit confirmation window
- Same motion thresholds: `2.45` strong, or `1.85` magnitude plus `1.35` peak axis
- Same display durations: `3.0s`, `3.5s`, `4.5s`
- Same haptic lead-ins: `0.05s`, `0.20s`, `0.20s`
- Same escalating feel: 1 / 2 / 3 pulses
- Same image asset filenames and folder structure
- Same portrait and landscape layout intent
- Same square image box in both orientations
- Same image fill behavior with rounded-corner cropping
- Same progress bars, typography hierarchy, and warning colors
- Same fade-only dismissal behavior
- Same non-blocking overlay interaction behavior

## Android Port Notes

Android runtime behavior has now been implemented, using the same escalation, timing, art paths, and tuned shake-detection profile described above.

Shared preparation that supports Android:
- starter-pack copies of all warning images
- shared canonical paths
- smoke/deploy awareness in the shared repo

Android-specific follow-up still worth validating later:
- hardware feel of the tuned shake thresholds on multiple devices
- haptic feel across different vibrator hardware
- any future native undo-equivalent precedence changes if Android gains a stronger platform-level convention

## Recommended Refinement Order

1. Load the exact bundled images from the Android starter-pack asset paths.
2. Recreate the escalation state machine and native-undo gating behavior.
3. Match the iOS timing and vibration cadence exactly.
4. Recreate the overlay visuals with portrait and landscape parity.
5. Validate on hardware, especially shake thresholds and haptic feel.

## Reference Baseline

This document should be treated as the current source-of-truth behavior spec for the iOS implementation, and the parity target for future Android refinements, as of 2026-03-13.
