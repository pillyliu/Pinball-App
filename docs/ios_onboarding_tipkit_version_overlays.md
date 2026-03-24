# iOS Onboarding, TipKit, and Version Overlay Guidelines

## Purpose

This note turns the current feature guide into a practical education plan for the iOS app:
- one-time intro overlay on startup
- contextual TipKit guidance after the intro
- version-based "what changed" overlays for meaningful releases

Primary feature reference:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball_App_Feature_Guide_3.4.7_2026-03-22.md`

Current iOS shell references:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/app/ContentView.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeHomeSection.swift`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeHomeRootView.swift`

## Recommendation In One Sentence

Use a short global intro once, use TipKit for feature discovery where the user actually needs help, and use a compact version overlay only when a release changes user behavior in a way worth calling out.

## Three-Layer Model

### 1. App intro overlay

Use this for first install and for users who have never completed the intro before.

What it should do:
- orient the user to the app's mental model
- show the five most important product areas in a swipeable format
- explain the "discover, study, log, improve" loop
- end with one clear start action

What it should not do:
- explain every button
- replace setup prompts inside individual tabs
- become a release-notes screen

### 2. TipKit

Use this after the intro for small, contextual hints tied to real controls.

Best use cases:
- first time on `Practice Home`
- first time in `Game Workspace`
- first time using `Library Detail`
- first time opening `Group Editor`
- first time in `GameRoom` machine detail
- first time in `Settings` import flows

TipKit should answer:
- what is this control for
- why would I use it
- what happens if I tap it

### 3. Version overlay

Use this only after an upgrade, and only when the release includes meaningful product changes.

Good reasons to show it:
- a new tab or major route appears
- a core flow changed
- a major capability landed that users would otherwise miss

Bad reasons to show it:
- bug-fix-only release
- cosmetic polish
- tiny label changes

## Startup Intro Overlay

### Trigger rules

Show the intro when either of these is true:
- the app is running after first install
- the user has not completed the intro before

Do not show it:
- while the app is still blocked by initial loading
- on top of another blocking overlay
- on every new version by default

Recommended persistence keys:
- `app-intro-completed`
- `app-intro-completed-version`
- `app-whats-new-last-seen-version`

Recommended behavior:
- if `app-intro-completed` is false, show the intro
- if intro content changes materially later, bump `app-intro-completed-version`
- add a manual "Show Intro Again" entry in `Settings`

### Presentation guidelines

Recommended presentation:
- full-screen modal presentation with a custom translucent overlay background
- horizontally swipeable `TabView` with page dots
- `Skip` on every card
- `Back` and `Next` buttons for users who do not swipe
- final card primary CTA: `Start Exploring`

Why this is better than a loose overlay:
- it prevents accidental interaction with the tab shell underneath
- it gives cleaner gesture behavior
- it makes the onboarding feel intentional instead of incidental

### Recommended card count

Recommended default: 5 cards.

Why 5 works:
- short enough to finish
- long enough to map the product
- aligns well with the current five-tab mental model without feeling like a tour of chrome

If you want strict tab parity, use 6 cards:
- 1 welcome card
- 5 tab cards

For the current app, 5 cards is the better default.

### Recommended 5-card structure

The strongest deck for the current app is not a pure tab tour. It should feel like a short "how PinProf helps me improve" story.

Recommended sequence:
1. welcome and brand promise
2. study the machine
3. log what you learn
4. see what to practice next
5. make the app yours

### Visual direction from the shake warning overlays

Model the intro cards on the current shake warning overlay treatment:
- same glowing material card language
- same centered art treatment with a framed image box
- same dark-to-brand gradient wash behind the card
- same slightly theatrical tone instead of plain utility chrome

Useful existing references:
- `AppShakeWarningOverlay`
- `AppShakeProfessorArt`
- `Font.appShakeProfessorSubtitle`

Typography recommendation:
- large display title can stay bold and high-contrast like the shake title
- supporting line should reuse the existing Baskerville-style subtitle helper
- body copy should stay concise and readable, not fully ornamental

### Card 1: Welcome to PinProf

Art:
- main PinProf logo or professor art in the center image box

Headline:
- `Welcome to PinProf`

Supporting line:
- `Welcome to PinProf, a pinball study app. Go from pinball novice to pinball wizard in no time!`

Why this works:
- it sets the tone immediately
- it matches the professor motif already established by the shake overlays
- it gives the deck a clear mascot-led opening

### Card 2: Study the Machine

Art ideas:
- Library detail hero art
- a rulesheet or playfield collage
- a branded study illustration if no screenshot reads well

Headline:
- `Study the Machine`

Supporting line:
- `Open rulesheets, playfields, and tutorial videos to learn shots, modes, and strategy before you step up to the game.`

Optional bullet ideas:
- `Browse the Library`
- `Read rulesheets and inspect playfields`
- `Watch tutorial and gameplay videos`

Why this should be card 2:
- it teaches the first real action a beginner can take
- it frames PinProf as a learning tool before it becomes a logging tool

### Card 3: Log What You Learn

Art ideas:
- Practice quick entry screenshot
- score scanner artwork
- per-game workspace screenshot focused on `Input`

Headline:
- `Log What You Learn`

Supporting line:
- `Use Quick Entry and game workspaces to record scores, study progress, practice sessions, and mechanics in seconds.`

Optional bullet ideas:
- `Quick Entry for fast logging`
- `Track scores, rulesheets, videos, and reps`
- `Keep everything tied to the game you are learning`

Why this should be card 3:
- it turns study into measurable progress
- it introduces the app's most important repeat-use behavior

### Card 4: See What to Practice Next

Art ideas:
- Practice summary card
- Journal plus Insights montage
- League targets or score trends visual

Headline:
- `See What to Practice Next`

Supporting line:
- `Review targets, journal history, and game summaries to spot weak points, track improvement, and choose your next session with confidence.`

Optional bullet ideas:
- `Review your journal`
- `Use targets and trends`
- `Turn league data into practice goals`

Why this should be card 4:
- it completes the learn-log-review loop
- it explains the value of the deeper analytics surfaces without overwhelming the user

### Card 5: Make It Yours

Art ideas:
- Settings source cards
- GameRoom collection tile or machine card
- a combined setup collage if it reads clearly

Headline:
- `Make It Yours`

Supporting line:
- `Add your own sources, refresh data, and track your machines so PinProf fits the places, events, and games you actually play.`

Optional bullet ideas:
- `Add venue, manufacturer, or tournament sources`
- `Track your collection in GameRoom`
- `Reopen this intro from Settings anytime`

Primary CTA ideas:
- `Start Exploring`
- `Open Library`
- `Open Practice`

Recommended final CTA:
- `Start Exploring`

### Interaction and copy rules

Keep each intro card lean:
- one headline
- one Baskerville-style supporting line
- zero to three short helper bullets
- one strong centered image

Avoid:
- tiny screenshots with unreadable UI
- long explanatory paragraphs
- a card that tries to cover multiple unrelated tasks

Best tone:
- warm
- encouraging
- a little theatrical
- still practical enough to be understood in 3 to 5 seconds

## Relationship To Existing Practice Welcome Overlay

The current `PracticeWelcomeOverlay` should stay task-specific.

Recommendation:
- keep the global intro focused on app orientation
- keep the Practice name prompt focused on identity setup
- never stack them at the same time

Recommended presentation priority:
1. loading and migration blockers
2. global intro overlay
3. version overlay
4. task-specific prompts like the Practice name prompt
5. TipKit tips

If the user lands in `Practice` after intro completion and still has no player name, then show the Practice name prompt there.

## TipKit Plan

TipKit should start only after the intro has been completed or dismissed.

### Tip priorities

First wave of tips:
1. `Practice Home`
- explain source selection
- explain `Quick Entry`
- explain that the game workspace is the deeper per-title view

2. `Practice Game Workspace`
- explain the segmented switcher
- explain `Input` versus `Study` versus `Log`

3. `Library Detail`
- explain rulesheet chips and video categories

4. `Quick Entry`
- explain mode selection
- explain video progress entry
- explain score scanner discovery

5. `Group Editor`
- explain drag reorder
- explain delete affordance in edit mode

6. `GameRoom`
- explain machine detail entry
- explain add-event actions

7. `Settings`
- explain `Refresh Pinball Data`
- explain what a source import changes elsewhere in the app

### TipKit rules of thumb

Do:
- attach tips to controls with real ambiguity
- limit to one meaningful tip at a time
- retire a tip after the user successfully uses the feature

Do not:
- tip obvious tab bar items
- show multiple competing tips on one screen
- repeat the same tip every session

### Suggested tip categories by feature guide

From the current feature guide, highest-value TipKit targets are:
- `Library List` search and source controls
- first `Library Detail` rulesheet/playfield/video launch
- `Practice Home` quick entry and resume
- first `Game Workspace` segmented switcher
- `Group Editor` reorder and delete controls
- `GameRoom` add-event entry points
- `Settings` add-source and refresh actions

## Version Overlay Guidelines

Version overlays should feel like "what changed for me," not "full release notes."

### Trigger rules

Show once when:
- current marketing version is greater than the last acknowledged version
- and the release is flagged as user-visible

Do not show:
- on first install
- if the global intro has not been completed yet
- for maintenance-only updates

Recommended persistence key:
- `app-whats-new-last-seen-version`

### Format

Recommended default:
- one compact modal sheet or overlay
- 1 to 3 highlight cards max

Each highlight should include:
- a short title
- a one-sentence explanation
- an optional "where to find it" line

Example shape:
- `GameRoom is live`
- `Track service, issues, notes, and media for each machine from the GameRoom tab.`
- `Find it in the GameRoom tab.`

### Content sourcing

Use the generated feature and architecture docs as the source of truth for version overlay planning:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball_App_Feature_Guide_3.4.7_2026-03-22.md`
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball_App_Architecture_Blueprint_3.4.7_2026-03-23.md`

Good version-overlay categories:
- new tab or route
- new import path
- new study or logging capability
- major workflow simplification

## Technical Integration Notes

### Root hook

Best attachment point:
- `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/app/ContentView.swift`

Reason:
- the intro and version overlays are app-shell concerns
- the root `TabView` is already there
- it is the cleanest place to prevent interaction with tabs while onboarding is visible

### Suggested structure

Recommended new files:
- `app/AppEducationCoordinator.swift`
- `app/AppIntroOverlay.swift`
- `app/AppVersionHighlightsOverlay.swift`

Possible responsibilities:
- coordinator decides which education surface is eligible
- intro overlay renders the swipe cards
- version overlay renders compact upgrade highlights

### Suggested state model

Possible state inputs:
- first-launch or intro-completed flags from `@AppStorage`
- current marketing version from bundle info
- previous acknowledged version from `@AppStorage`
- "is bootstrapping" signals if you want to delay presentation until initial load stabilizes

Recommended precedence:
- if loading blocker is visible, show nothing else
- else if intro is required, show intro
- else if version overlay is required, show version overlay
- else allow TipKit and local prompts

### Manual re-entry

Add two Settings actions:
- `Show Intro Again`
- `What's New`

This gives users a safe way back into the education surfaces without reinstalling.

## Final Recommendation

If we only do one thing first, do this:
- add a short 5-card global intro in the app shell
- keep the existing Practice welcome prompt as a separate setup step
- add TipKit only for `Practice`, `Library`, `Group Editor`, `GameRoom`, and `Settings` high-friction controls
- reserve version overlays for meaningful, user-visible releases

This keeps onboarding short, keeps contextual help contextual, and avoids turning startup into a stack of competing overlays.
