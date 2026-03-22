# PinProf Guidance Inventory and Strategy

Date: 2026-03-22

## Goal

Create a guidance system that feels native to PinProf:

- Use custom illustrated overlays for rare, high-importance moments
- Use TipKit for lightweight, in-context discovery on iOS
- Keep one central guidance model so overlays, version callouts, and tips do not compete

This note is intentionally grounded in the current app structure before deciding what deserves a full-screen overlay versus a small contextual tip.

---

## 1. Current App Inventory

### iOS app structure

Root tabs:

- `League`
- `Library`
- `Practice`
- `GameRoom`
- `Settings`

Primary iOS entry files:

- `Pinball App 2/Pinball App 2/app/ContentView.swift`
- `Pinball App 2/Pinball App 2/app/Pinball_App_2App.swift`

Existing custom full-screen overlay pattern:

- `Pinball App 2/Pinball App 2/app/AppShakeCoordinator.swift`

Why this matters:

- The app already has a polished full-screen, illustrated overlay system
- That pattern is a strong fit for branded onboarding and version callouts
- We do not need to force that behavior into TipKit

### iOS: feature surfaces that matter for guidance

#### Library

Primary surfaces:

- Library list and toolbar filters
- Library detail
- Rulesheet
- Playfield
- Video references

Key files:

- `Pinball App 2/Pinball App 2/library/LibraryScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryListScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDetailScreen.swift`
- `Pinball App 2/Pinball App 2/library/LibraryDetailComponents.swift`
- `Pinball App 2/Pinball App 2/library/RulesheetScreen.swift`

Important discovery surfaces:

- Filter menu in the Library toolbar
- Rulesheet chips
- Playfield chips
- Video grid and video launch panel

#### Practice

Primary surfaces:

- Practice Home
- Quick Entry
- Game Workspace
- Group Dashboard
- Journal Timeline
- Insights
- Mechanics
- Practice Settings

Key files:

- `Pinball App 2/Pinball App 2/practice/PracticeScreen.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeRootView.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeQuickEntrySheet.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeGameWorkspaceSubviews.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeVideoComponents.swift`

Important discovery surfaces:

- Quick Entry buttons on Practice Home
- Game Workspace segmented card: `Summary / Input / Study / Log`
- Game Input shortcuts for `Rulesheet / Playfield / Score / Tutorial / Practice / Gameplay`
- Study Resources card for rulesheets, playfields, and videos

#### Current first-run behavior

There is already a Practice-specific name prompt and welcome overlay.

Relevant files:

- `Pinball App 2/Pinball App 2/practice/PracticeHomeRootView.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeHomeSection.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeScreenContexts.swift`

Interpretation:

- The app already has a first-run concept
- It is currently scoped to Practice instead of app-wide guidance
- This is a good seed, but not yet a central onboarding or feature-discovery system

### Existing user signals we can reuse

#### Library activity already tracked

The app already records:

- game browse
- rulesheet open
- playfield open
- video tap

Key file:

- `Pinball App 2/Pinball App 2/library/LibraryActivityLog.swift`

This is valuable because it lets guidance use real behavior rather than extra booleans whenever possible.

#### Practice progress already tracked

The app already knows:

- latest study progress by task
- whether a game has practice logged
- whether a game has playfield/rulesheet/video activity
- score history
- completion percent
- focus priority and gaps

Key files:

- `Pinball App 2/Pinball App 2/practice/PracticeStoreAnalytics.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeModels.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeStoreEntryMutations.swift`

This means the future guidance layer should derive as much as possible from:

- `LibraryActivityLog`
- `PracticeStore`

instead of creating duplicate feature-state flags for everything.

### Android app structure

Root tabs:

- `League`
- `Library`
- `Practice`
- `GameRoom`
- `Settings`

Primary Android entry files:

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/MainActivity.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/PinballShell.kt`

Existing custom full-screen overlay pattern:

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/AppShakeWarning.kt`

Practice entry and dialog flow:

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeLifecycleHost.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeDialogHost.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeHomeSection.kt`

Library entry and route flow:

- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryScreen.kt`
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryRouteContent.kt`

Interpretation:

- Android already has the same basic custom-overlay host concept as iOS
- That makes custom illustrated callouts viable cross-platform
- Android does not currently show an equivalent TipKit-style discovery layer

---

## 2. Recommended Guidance Architecture

Use three layers, each for a different job.

### Layer A: onboarding overlay

Use for:

- first app launch only

Characteristics:

- custom PinProf art
- full-screen or near full-screen
- branded
- one clear promise
- one CTA

### Layer B: versioned feature callout overlay

Use for:

- major new releases only
- changes that alter the mental model of the app
- features large enough to deserve art and a memorable narrative frame

Characteristics:

- custom PinProf art
- full-screen or near full-screen
- version gated
- never used for minor quality-of-life changes

### Layer C: contextual tips

Use for:

- filters
- quick-entry nudges
- study and tutorial discovery
- score logging nudges
- “you are here, this is useful now” hints

Characteristics:

- iOS: TipKit
- small and native
- tied to a visible control
- short and action-oriented
- dismissed once learned

### Central coordinator

Create one app-level guidance coordinator/store that decides:

- whether onboarding should appear
- whether a version callout should appear
- whether a contextual tip is eligible
- whether something else is already showing

High-level stored state:

- `hasSeenOnboarding`
- `lastSeenAppVersion`
- overlay impression/dismiss state
- tip impression/dismiss state
- a few explicit “learned” flags where derived state is not enough

Recommendation:

- derive feature-learning state from real behavior first
- add explicit booleans only when behavior cannot be derived cleanly

---

## 3. What Is Worthy of a Full Overlay?

Full overlays should be rare. If we overuse them, they become expensive popups instead of memorable product moments.

### Good overlay rule

A feature deserves a full overlay when at least one of these is true:

- it changes the app’s core story
- it introduces a new major workflow or tab
- it introduces a new mode of interaction
- it benefits from strong character art and a clear narrative frame

### Not overlay-worthy by default

These should usually stay out of overlays:

- filters
- sort modes
- bank selectors
- simple settings
- small menu additions
- routine polish changes

---

## 4. Suggested Overlay Candidates

### A. First Launch: “Welcome to PinProf”

Why it deserves an overlay:

- this is the one branded onboarding moment
- it sets the app’s identity and promise

Draft direction:

- Headline: `Welcome to PinProf`
- Body idea: `Study a game, track your reps, and see your progress in one place.`
- Optional supporting line: `Library teaches. Practice remembers. League gives you targets.`

Art direction:

- Professor/host character presenting a machine with floating rulesheet, playfield, score card, and journal elements
- should feel like PinProf is a guide, not a warning

### B. Major workflow callout: “The Study Loop”

Use only if a release makes the Library-to-Practice loop much more explicit.

Why it deserves an overlay:

- this is a core product story, not a minor feature
- it explains what makes PinProf different from a plain reference app

Draft direction:

- Headline: `Learn. Practice. Track.`
- Body idea: `Open a rulesheet or tutorial, then log what you worked on without leaving your flow.`

Art direction:

- motion or composition from left-to-right:
  - game reference
  - practice input
  - progress journal

### C. Major feature launch: “Score Scanner”

Use only when scanner quality is ready enough that the feature can carry a release moment.

Why it deserves an overlay:

- it introduces a new input mode
- camera-driven interaction is a large enough shift to justify a callout

Draft direction:

- Headline: `Scan your score`
- Body idea: `Capture scores from the machine and keep your progress moving.`

Art direction:

- professor + camera/viewfinder + segmented score digits
- should feel precise, clever, and reliable

### D. Major feature launch: “GameRoom”

Use when GameRoom is positioned as a headline feature, not just another tab.

Why it deserves an overlay:

- it expands PinProf from player workflow into cabinet ownership / machine management
- that is a real product boundary expansion

Draft direction:

- Headline: `GameRoom is open`
- Body idea: `Track machines, service history, and room-level details alongside your player workflow.`

Art direction:

- workshop / backbox / service notes / machine lineup

### E. Major competitive feature launch: “Targets and Trends”

Only if a release meaningfully upgrades competitive feedback loops.

Why it deserves an overlay:

- it sharpens PinProf’s value for improvement-minded players
- still more narrative than a tip

Draft direction:

- Headline: `Play with better targets`
- Body idea: `Compare your scores against league benchmarks and see where your floor needs work.`

Art direction:

- charts, target score cards, professor coaching from a score sheet

### Best near-term overlay candidates

If choosing only a few:

1. `Welcome to PinProf`
2. `The Study Loop`
3. `Score Scanner` when shipped
4. `GameRoom` only if promoted as a major release

---

## 5. What Should Be TipKit Instead?

These are better as small, contextual, behavior-aware tips.

## Priority 1: Library filter tip

Anchor:

- Library toolbar filter control

Why TipKit:

- small control
- easy to explain in one sentence
- only relevant once the user has browsed enough games to feel the need

Suggested copy:

- `Narrow the library by source, sort, or bank.`

Suggested display rule:

- user has opened multiple Library game pages
- user has not changed source, sort, or bank yet
- currently on Library list

Invalidate when:

- any source, sort, or bank filter is changed

## Priority 2: Save study progress tip

Anchor options:

- Practice Home `Study` quick entry button
- Practice Game `Input` panel
- possibly the Study resources card if we want tighter context

Why TipKit:

- this is a workflow nudge, not a brand moment
- should appear when the user is already consuming study content

Suggested copy:

- `Log a study step after reading or watching to keep progress moving.`

Suggested display rule:

- user has opened rulesheets, playfields, or videos
- user has not created study-related practice entries yet
- user is on Practice Home or a game workspace

Invalidate when:

- first study entry is saved
- first study progress value is recorded

## Priority 3: Watch tutorial tip

Anchor:

- video section in Library detail or Practice Study resources

Why TipKit:

- specific, contextual, and tied to visible content

Suggested copy:

- `Try a tutorial video for a faster read on this game.`

Suggested display rule:

- current game has videos
- user has opened rulesheet or playfield for this game
- user has never tapped a video for this game
- currently on the game’s detail or study screen

Invalidate when:

- first video tap for that game
- first tutorial/gameplay watch entry for that game

## Priority 4: Score logging tip

Anchor:

- Practice Game `Score` button
- or Practice Home `Score` quick entry button

Why TipKit:

- important feature, but still a contextual control
- should not interrupt users before they have context for why score logging matters

Suggested copy:

- `Log a score here to unlock trend and variance feedback.`

Suggested display rule:

- user has opened the same game multiple times
- user has no scores for that game
- ideally user has some other practice or study activity already

Invalidate when:

- first score is logged for that game

## Good secondary TipKit candidates

These are probably second wave, not first wave:

- `Insights` tip after several scores exist but the user has never opened Insights
- `Journal Timeline` tip after enough activity exists to make the timeline useful
- `Group Dashboard` tip after the user works across multiple games but has no active group
- `Mechanics` tip after the user uses Practice often but has never logged technique work

---

## 6. Recommended First Wave

If we keep scope disciplined, the first shipping wave should be:

### Overlay

- first-launch `Welcome to PinProf`

### Version callout overlay

- one release-worthy callout only if we have a truly major feature to announce

### TipKit

1. Library filter tip
2. Save study progress tip
3. Watch tutorial tip
4. Score logging tip later, after the first three feel correct

Reason:

- these map closely to the current PinProf loop
- they are already supported by existing activity and practice signals
- they teach the app gradually instead of front-loading explanation

---

## 7. Android Equivalent to TipKit

Short answer:

- Android does not appear to have a direct built-in equivalent to TipKit with the same package-level idea of rules, persistence, and automatic feature education
- the closest official UI primitive is Material 3 tooltips in Jetpack Compose

Verified official Android guidance:

- Android’s Compose docs describe `TooltipBox` as the way to implement tooltips
- official tooltips come in two forms:
  - `PlainTooltip`
  - `RichTooltip`

Official sources:

- Android Developers: https://developer.android.com/develop/ui/compose/components/tooltip
- Material Design 3 tooltips: https://m3.material.io/components/tooltips/overview

What the official docs clearly support:

- anchor a tooltip to a visible control
- show plain or rich contextual help
- manually control display via tooltip state

What I did not find in official Android docs:

- a framework-level equivalent to TipKit’s rule engine
- built-in persistence for “already learned” feature education
- a system-owned feature-discovery coordinator

Inference:

- for Android, the practical equivalent is:
  - custom guidance state in `SharedPreferences`
  - a central coordinator
  - Compose `TooltipBox` / `RichTooltip` / `PlainTooltip` for the presentation layer
  - the existing custom overlay host for hero callouts

This is actually a good architectural match for PinProf, because Android already has:

- a root overlay host in `PinballShell.kt`
- a custom full-screen overlay style in `AppShakeWarning.kt`
- a preference-backed app state model

So cross-platform guidance can be:

- shared concept
- platform-native implementation

### Suggested Android mapping

Custom hero overlays:

- use the existing root overlay-host pattern

Contextual discovery:

- use Material 3 Compose tooltips

Persistence and rules:

- implement in app state, not in the tooltip UI layer

---

## 8. Copy and Art Prompt Workshop Targets

Before generating overlay art, these are the copy decisions worth locking down first:

### For onboarding

- What is the one-sentence PinProf promise?
- Is the professor character welcoming, instructive, or slightly theatrical?
- Do we want the overlay to foreground `Library + Practice + League`, or only `Study + Track + Improve`?

### For version callouts

- Which features are important enough to deserve art?
- Which release themes should be treated as product moments versus ordinary release notes?
- Should callouts focus on one feature or one workflow?

### For tips

- Which specific control is the anchor?
- What exact action do we want next?
- What event means “the user learned this”?

---

## 9. Recommended Next Steps

1. Finalize the first-launch overlay message and character tone.
2. Decide which upcoming or existing major feature, if any, deserves a version callout overlay.
3. Define a central guidance store before implementing TipKit.
4. Ship the first three iOS tips:
   - Library filter
   - Save study progress
   - Watch tutorial
5. Add Android parity later using:
   - custom overlay host
   - Compose Material 3 tooltips
   - app-managed eligibility rules

