# Contributing

## Before you change code

1. Read the hard constraints in [`documentation/reference/HANDOFF.md`](documentation/reference/HANDOFF.md) — especially privacy (on-device only, no API keys, read-only on other tools).
2. Check [`PRODUCTION.md`](PRODUCTION.md) so you don’t reinvent finished work or reintroduce rejected designs (hook injection, continuous git watching).

## Local loop

```bash
swift build
swift test
swift run AIhero --render /tmp/aihero-shots   # visual QA
```

`swift build` is the source of truth. SourceKit “cannot find type” errors after adding a new Swift file are usually index lag — rebuild before “fixing” them.

## PRs

- Prefer small, focused PRs against `main`.
- Keep generation / subprocess code behind `AppModel.isProduction` so tests and `--render` never spawn Codex.
- Update the nearest plan doc’s implementation log when the change is non-trivial.
