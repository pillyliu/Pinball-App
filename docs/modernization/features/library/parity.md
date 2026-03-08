# Library Parity

## Must match

- source ordering rules
- filtering behavior
- detail layout intent
- rulesheet fallback behavior
- playfield fallback behavior
- GameRoom overlay behavior
- v3 starter-pack resource naming contract

## Allowed native differences

- reader rendering details
- image viewer gesture feel
- back button material treatment

## Current parity baseline

- Both platforms now resolve local Library assets against the same v3-only names and should not reintroduce local slug-based rulesheet or game-info fallbacks.
- Both platforms now route imported-game and rulesheet/video resolution through dedicated catalog-resolution helper files rather than leaving that behavior embedded in the main loader/store file.
- Both platforms now route seed-db imported-source resolution through the same catalog-resolution seam rather than maintaining a second imported-game assembly path.
- Both platforms now route resource URL normalization and local-vs-remote rulesheet/game-info/playfield fallback through dedicated resource-resolution helper files rather than leaving that behavior embedded in the main domain file.
- Both platforms now resolve playfields through the same manifest-backed v3 ladder:
  - local `group-machine-alias`
  - local `group-machine`
  - local `group`
  - OPDB remote
- Android legacy payload parsing is now isolated behind a dedicated parsing seam, while iOS video metadata fetch is isolated behind a dedicated service seam; the next parity step is to narrow the remaining iOS payload-decoding block to match that separation better.
