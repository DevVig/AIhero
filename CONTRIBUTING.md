# Contributing to AIhero

Thanks for wanting to play with the toy. AIhero is a **fun, on-device collectible** —
not a dashboard, not an admin console. When in doubt: fewer knobs, more delight.

## Hard rules (please read)

These are load-bearing product promises. PRs that break them will be declined:

- **Everything stays on the user's Mac.** No AIhero servers. No uploads.
- **No API keys in the app.** Art goes through the user's own Codex CLI login.
- **Activity sources are read-only** (mtime/presence only) and **consent-gated**.
- **Never write into another tool's config** (`~/.codex`, `~/.claude`, etc.).
- **Fun, not bloat.** Features should feel like a collectible companion.

Full rationale: [documentation/reference/HANDOFF.md](documentation/reference/HANDOFF.md).

## Dev loop

Requires **macOS 14+** and a **Swift 6** toolchain.

```bash
swift build
swift test
swift run AIhero
swift run AIhero --render /tmp/aihero-shots   # offscreen visual QA → PNGs
Scripts/make_app.sh release                   # → dist/AIhero.app (unsigned OK)
```

Notes:

- `swift build` is the source of truth. SourceKit “cannot find type” noise after
  adding a new Swift file is often index lag — rebuild before “fixing” it.
- `--render` shows placeholder glyphs for some native controls offscreen; that
  is expected. Prefer eager stacks over `LazyVGrid` for surfaces you want in QA.
- Subprocess art generation is gated on production mode so tests/`--render`
  never spawn a real Codex run.

## Documentation lifecycle

Non-trivial work:

1. Plan under `documentation/planned/[category]/`
2. Move to `documentation/active/` while implementing (keep active thin)
3. Move to `documentation/completed/[category]/` when done

Reference docs (no date prefix) live in `documentation/reference/`.

## Pull requests

- Keep PRs focused and small when you can.
- Run `swift test` (and `--render` if you touch UI).
- Fill out the PR template privacy checklist.
- Be kind — see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Security reports

See [SECURITY.md](SECURITY.md). Do not file public issues for vulnerabilities.
