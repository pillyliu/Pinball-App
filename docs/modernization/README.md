# 3.2 Modernization Docs

This folder is the source of truth for the PinProf modernization effort on branch `codex/3.2-modernization`.

Recommended chat/thread title:
- `3.2 Modernization Foundation`

Use this docs set instead of relying on long chat history.

## Document hierarchy

1. `00_program_overview.md`
2. `01_workflow.md`
3. `02_design_system.md`
4. `03_parity_rules.md`
5. `04_audit_matrix.md`
6. `features/<feature>/spec.md`
7. `features/<feature>/parity.md`
8. `features/<feature>/ledger.md`
9. `features/<feature>/checklist.md`

## Rules

- Chat is for discussion. Markdown is the contract.
- Update docs before implementation when behavior or scope changes.
- Do not start Android parity work until the canonical behavior is written.
- Do not mark a feature complete until its checklist is checked against both platforms.
- Record drift, bugs, and deferrals in the feature ledger instead of leaving them implicit.

## Feature folders

- `features/gameroom/`
- `features/practice/`
- `features/library/`
- `features/league/`
- `features/settings/`
