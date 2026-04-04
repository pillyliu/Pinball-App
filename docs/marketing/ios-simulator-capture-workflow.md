# iOS Simulator Capture Workflow

This workflow is for capturing cleaner promo footage from the `iPhone 17 Pro` simulator instead of filming the physical phone.

The goal is a hybrid workflow:

- let the script handle repeatable simulator prep
- do the remaining app-specific or timing-sensitive actions manually

Primary script:

- [record_ios_sim_clip.py](/Users/pillyliu/Documents/Codex/Pinball%20App/scripts/record_ios_sim_clip.py)

## What The Script Automates

The capture script can:

- boot the `iPhone 17 Pro` simulator
- open `Simulator.app`
- optionally build and install `PinProf`
- launch the app
- force dark appearance
- hide the intro overlay
- clean the status bar for promo capture
- set a simulator GPS location
- optionally set the GameRoom name in app state
- start and stop a simulator MP4 recording

## What You Still Do Manually

These are the parts that are still better done by hand:

- navigating to the exact screen for a shot
- performing the taps, scrolls, or scan gestures that are the actual content of the clip
- setting up complex app state that is more specific than a simple preference
- deciding when the take is good enough to stop

## First-Time Setup

Recommended first capture command:

```bash
python3 scripts/record_ios_sim_clip.py \
  --build \
  --clip-name "library-rulesheet" \
  --out-dir "$HOME/Movies/PinProf Simulator Captures" \
  --location "42.7335,-84.5488" \
  --gameroom-name "Flynn's Arcade"
```

What this does:

- builds and installs the app
- boots the `iPhone 17 Pro` simulator
- forces dark mode
- hides the intro overlay
- sets a clean status bar
- sets the simulator location
- pre-names the GameRoom
- waits for you to frame the shot
- records until you press Enter again

## Fast Repeat Takes

Once the app is already installed, skip the build step:

```bash
python3 scripts/record_ios_sim_clip.py \
  --clip-name "practice-score-scan" \
  --out-dir "$HOME/Movies/PinProf Simulator Captures" \
  --location "42.7335,-84.5488" \
  --gameroom-name "Flynn's Arcade"
```

## Timed Capture

If you want the script to auto-stop after a fixed duration:

```bash
python3 scripts/record_ios_sim_clip.py \
  --clip-name "league-standings" \
  --out-dir "$HOME/Movies/PinProf Simulator Captures" \
  --duration 10
```

## Recommended Promo Commands

Library / Practice / League shots that do not depend on venue lookup:

```bash
python3 scripts/record_ios_sim_clip.py \
  --clip-name "library-playfield-zoom" \
  --out-dir "/Users/pillyliu/Library/CloudStorage/Dropbox/Pinball/PinProf Promo Video/Simulator Captures"
```

Settings venue-import shots that depend on current location:

```bash
python3 scripts/record_ios_sim_clip.py \
  --clip-name "settings-venue-import" \
  --out-dir "/Users/pillyliu/Library/CloudStorage/Dropbox/Pinball/PinProf Promo Video/Simulator Captures" \
  --location "42.7335,-84.5488"
```

GameRoom shots that should open with your preferred room name:

```bash
python3 scripts/record_ios_sim_clip.py \
  --clip-name "gameroom-home" \
  --out-dir "/Users/pillyliu/Library/CloudStorage/Dropbox/Pinball/PinProf Promo Video/Simulator Captures" \
  --gameroom-name "Flynn's Arcade"
```

## Suggested Capture Loop

For each clip:

1. Run the script with the right clip name and any needed location or GameRoom name.
2. Let the script launch the app and apply the reusable capture settings.
3. Do the last manual prep inside the app.
4. Press Enter to start recording.
5. Perform the shot.
6. Press Enter to stop recording.
7. Repeat with a new clip name for the next take.

## Good Defaults For Promo Footage

The script already biases toward capture-friendly defaults:

- simulator: `iPhone 17 Pro`
- app appearance: `dark`
- status bar time: `9:41`
- carrier name: empty
- battery: `100%`
- codec: `h264`

Those can all be overridden from the command line if needed.

## Important Notes

- Simulator recordings capture the app cleanly at the simulator device resolution, which is much easier to scale into the 4K promo pane than camera footage of the physical phone.
- The script currently assumes the built app is `PinProf.app` and the bundle id is `com.pillyliu.Pinball-App-2`.
- If you already have meaningful GameRoom data in the simulator, changing `--gameroom-name` updates the room name while preserving the rest of the stored GameRoom JSON.
- For location-based import flows, the script grants simulator location permission before setting coordinates.

## When To Capture Manually Instead

Manual capture is still the better choice when:

- a shot depends on improvising several actions in sequence
- you need to re-try subtle timing by feel
- you want to do a complicated custom state setup before the shot starts

In those cases, still use the script for prep, then do the actual take manually.
