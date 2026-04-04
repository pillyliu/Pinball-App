# PinProf Promo Real-Time App Fit Analysis

This pass answers a specific question:

- if the app clips play at normal speed
- and we cut against the spoken audio as recorded
- what parts of the current raw app captures still fit
- and what parts would be lost altogether

This is a first-pass rough cut plan, not a frame-accurate final edit.

## Timing Basis

Working audio:

- `/Users/pillyliu/Library/CloudStorage/Dropbox/Pinball/PinProf Promo Video/PinProf Intro Script.m4a`

Timing sources:

- `output/transcribe/pinprof_intro_script_verbose_whisper/PinProf Intro Script.verbose.json`
- `output/transcribe/pinprof_intro_script_verbose_whisper/PinProf Intro Script.words.csv`
- `output/transcribe/pinprof_intro_script_verbose_whisper/PinProf Intro Script.segments.csv`

## Spoken Section Windows

These are based on the actual spoken section starts in the recorded audio.

- `Library`: `14.82-41.56` (`26.74s`)
- `Practice`: `41.56-68.18` (`26.62s`)
- `GameRoom`: `68.18-85.62` (`17.44s`)
- `Settings`: `85.62-104.34` (`18.72s`)
- `League`: `104.34-127.58` (`23.24s`)

## Raw App Section Lengths

- `1 Library.MP4`: `37.85s`
- `2 Practice.MP4`: `55.89s`
- `3 GameRoom.MP4`: `48.04s`
- `4 Settings.MP4`: `37.74s`
- `5 League.MP4`: `48.30s`

Every raw section is still too long for the spoken window, even before title cards and transitions.

So if we keep app motion real-time, the only workable path is:

- cut at the sub-segment level
- drop setup/navigation portions
- preserve only the proof moments

## Section Findings

### Library

Raw useful action range:

- roughly `0:00.0-0:33.5`

Real-time keep plan:

- keep `0:08.8-0:20.0` for rulesheet proof
- keep `0:20.0-0:28.0` for playfield proof
- keep `0:28.0-0:33.5` for gameplay proof

What gets lost:

- `0:00.0-0:08.8`

That means we lose:

- opening Library landing
- scroll to Jurassic Park
- open game view
- open Rulesheet

Takeaway:

- Library mostly fits if we start at the rules proof instead of showing the approach to it

### Practice

Raw useful action range:

- roughly `0:00.0-0:55.5`

Real-time keep plan:

- keep `0:03.0-0:09.0` for study logging
- keep `0:13.5-0:18.5` for score scan
- keep `0:26.0-0:32.0` for study group
- keep `0:43.5-0:48.0` for notes
- keep `0:48.0-0:53.0` for game log

Approximate retained total:

- about `26.0s`

What gets lost:

- `0:00.0-0:03.0`
- `0:09.0-0:13.5`
- `0:18.5-0:26.0`
- `0:32.0-0:43.5`
- `0:53.0-0:55.5`

That means we lose or heavily reduce:

- opening Practice landing
- full `Resume Game` context
- score-entry setup before scan
- dashboard opening before study group selection
- full Bank 7 group-creation completion beat
- return-to-Practice navigation
- search setup and typing `mm`
- long game-log scroll tail

Takeaway:

- Practice only works in real time if we treat it like a proof montage of short decisive states
- the long connective navigation cannot stay

### GameRoom

Raw useful action range:

- roughly `0:00.0-0:48.0`

Real-time keep plan:

- keep `0:04.5-0:08.0` for import payoff
- keep `0:08.0-0:12.0` for organization setup
- keep `0:16.0-0:18.0` for final position proof
- keep `0:32.5-0:36.0` for issue resolution payoff
- keep `0:44.5-0:48.0` for GameRoom browse payoff

Approximate retained total:

- about `16.5s`

What gets lost:

- `0:00.0-0:04.5`
- `0:12.0-0:16.0`
- `0:18.0-0:32.5`
- `0:36.0-0:44.5`

That means we lose or heavily reduce:

- opening GameRoom landing
- opening import UI
- typing `Pillyliu`
- full area / group / position flow
- selected-machine intermediate state
- entering the issue flow
- navigate to Library
- filter change to `Flynn's Arcade`

Takeaway:

- GameRoom is one of the tightest sections
- it only fits if we show payoff states instead of the full operational flow

### Settings

Raw useful action range:

- roughly `0:00.0-0:37.5`

Real-time keep plan:

- keep `0:07.0-0:10.0` for imported venue payoff
- keep `0:13.0-0:18.0` for MatchPlay ID entry
- keep `0:18.0-0:23.0` for arena-list payoff
- keep `0:32.0-0:37.5` for IFPA profile

Approximate retained total:

- about `18.5s`

What gets lost:

- `0:00.0-0:07.0`
- `0:10.0-0:13.0`
- `0:23.0-0:32.0`

That means we lose or heavily reduce:

- opening Settings landing
- most of the venue-add workflow
- tournament import setup before the ID field
- long imported arena-list hold

Takeaway:

- Settings can fit in real time
- but only as concise payoff beats, not as a full demonstration of setup

### League

Raw useful action range:

- roughly `0:00.0-0:48.0`

Real-time keep plan:

- keep `0:01.0-0:04.0` for dashboard mini views
- keep `0:14.5-0:18.0` for filtered stats payoff
- keep `0:24.0-0:32.0` for standings scroll
- keep `0:32.0-0:34.5` for standings hold
- keep `0:44.0-0:48.0` for targets payoff

Approximate retained total:

- about `21.0s`

What gets lost:

- `0:00.0-0:01.0`
- `0:04.0-0:14.5`
- `0:18.0-0:24.0`
- `0:34.5-0:44.0`

That means we lose or heavily reduce:

- opening League landing
- open Stats
- bank / player / machine selection flow
- open Standings
- season filter change
- back out from standings
- open Targets
- Bank 7 filter setup

Takeaway:

- League still works in real time because standings scroll is one of the few scrolls worth showing
- but the filter setup and navigation steps have to go

## What This Means

If we keep app motion at normal speed, we do not lose whole sections.

What we lose is:

- setup
- navigation
- context transitions
- repetitive filter drilling
- long holds after the proof is already obvious

The sections that survive best in real time:

- `Library`
- `Settings`
- `League`

The sections that require the most aggressive sub-segment cutting:

- `Practice`
- `GameRoom`

## Editorial Rule

For the real-time version, the edit should preserve:

- the first readable proof
- the decisive interaction
- the shortest hold that confirms the result

And cut away:

- everything required only to arrive there
