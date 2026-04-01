# Codebase Bible

This folder is the living ownership map for PinProf across iOS and Android.

Use it to answer five questions quickly:
- what each platform folder or package owns
- which files are the entrypoints, state owners, and route coordinators
- how the paired iOS and Android surfaces line up
- where release, preload, CI, and shared-asset tooling lives
- which docs must move together when the architecture changes

## Canonical Doc Set

| File | Role | Update when |
| --- | --- | --- |
| `README.md` | Workspace entrypoint, release anchors, and doc index | versions, top-level layout, or active doc set changes |
| `docs/codebase/ios.md` | iOS folder-by-folder ownership map | iOS files move, split, or change responsibility |
| `docs/codebase/android.md` | Android package-by-package ownership map | Android files move, split, or change responsibility |
| `docs/codebase/tooling-and-scripts.md` | Build, release, CI, script, preload, and doc workflow map | tooling, automation, or asset flow changes |
| `Pinball_App_Architecture_Blueprint.md` | system-level runtime and data-flow blueprint | runtime contracts, domain boundaries, or publish flow changes |

Companion layers:
- `docs/review/` explains cleanup history and why changes were made.
- `docs/modernization/` tracks broader parity and future-direction planning.
- `docs/marketing/` holds non-code product collateral.
- `archive/` holds retired or historical material.

## Current Platform Inventory

The active source surfaces currently break down like this:

| Surface | iOS | Android | Notes |
| --- | --- | --- | --- |
| App shell and startup | `app/` (`11` files) | package root (`13` files) | launch tasks, tab shell, intro overlay, shake warning, perf trace |
| Hosted data and cache | `data/` (`6`) | `data/` (`10`) | cache actor/object, bootstrap, metadata refresh, CSV/network helpers |
| Library | `library/` (`113`) | `library/` (`72`) | largest read-only content domain and runtime assembly substrate |
| Practice | `practice/` (`116`) | `practice/` (`127`) | largest mutable user-data domain |
| GameRoom | `gameroom/` (`99`) | `gameroom/` (`53`) | owned-machine management, import, media, issue, service flows |
| League | `league/` (`15`) | `league/` (`16`) | home shell plus preview cards and destination handoff |
| Settings | `settings/` (`15`) | `settings/` (`15`) | imports, hosted data refresh, privacy, about |
| Stats / Standings / Targets | `15` total | `13` total | full-screen league destinations |
| Shared UI | `ui/` (`18`) | `ui/` (`20`) | shared chrome, pills, surfaces, filters, fullscreen seams |
| Info | `info/` (`2`) | `info/` (`1`) | about screens and bundled LPL art |

Bundled support assets that also matter to the architecture:
- iOS: `Pinball App 2/Pinball App 2/SharedAppSupport/`
- iOS preload bundle: `Pinball App 2/Pinball App 2/PinballPreload.bundle/`
- Android preload assets: `Pinball App Android/app/src/main/assets/pinprof-preload/`

## Ownership Vocabulary

These naming patterns are used heavily across both platforms:

| Pattern | Usually means |
| --- | --- |
| `*Screen`, `*View`, `*RouteContent`, `*ShellContent` | top-level route composition or primary UI surface |
| `*Host`, `*Presentation*`, `*DialogHost`, `*Sheet*` | presentation orchestration around child content |
| `*Context`, `*State`, `*Selection*` | route-local state and derived UI context |
| `*Store`, `*ViewModel` | mutable feature-state owner |
| `*Support`, `*Helpers`, `*Formatting*`, `*Resolution*` | narrowly scoped domain or UI helpers |
| `*Models`, `*Types`, `*Domain`, `*Record` | value types and encoded domain shapes |
| `*Codec`, `*Persistence*`, `*Load*`, `*Bootstrap*`, `*Integration*` | persistence, hydration, and external-domain bridges |

Preferred mental model:
- route files own navigation and composition
- store or view-model files own mutable state
- support files own focused helpers, parsing, lookup, formatting, and small UI building blocks
- data files own cache and hosted payload coordination
- shared UI files own reusable chrome and presentation seams

## Cross-Platform Feature Lanes

Paired feature lanes:
- app shell and onboarding
- hosted data cache
- library
- practice
- gameroom
- league
- settings
- stats, standings, targets
- shared UI chrome

Expected parity:
- same root tabs
- same hosted CAF and OPDB runtime contracts
- same library fallback behavior
- same practice identity rules
- same GameRoom exact `opdb_id` expectations
- same settings import concepts

Acceptable platform-specific differences:
- navigation primitives
- top-bar and back behavior
- fullscreen gesture implementations
- camera and scanner plumbing
- theme and surface rendering details that do not change meaning

## Maintenance Contract

Naming rule for living docs:
- active docs keep stable names
- frozen snapshots go under `archive/` in dated folders
- do not put `latest` in active filenames

Update this doc set when:
- a file changes responsibility
- a route gets split or merged
- a new support layer becomes the intended owner of a behavior
- hosted data contracts change
- a release or tooling path changes

For architecture-affecting changes, update in this order:
1. the relevant platform map
2. `docs/codebase/tooling-and-scripts.md` if build, release, preload, or CI behavior changed
3. `Pinball_App_Architecture_Blueprint.md` if domain boundaries, runtime flow, or publish flow changed
4. `README.md` if release anchors or doc entrypoints changed

If the blueprint markdown changes, rerender the print artifact:
- `./scripts/generate_architecture_blueprint.sh`
