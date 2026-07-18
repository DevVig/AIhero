## Summary

<!-- What changed and why (1–3 bullets). Fun, not bloat. -->

## Test plan

- [ ] `swift build`
- [ ] `swift test`
- [ ] `swift run AIhero --render /tmp/aihero-shots` (if UI changed)
- [ ] Manual smoke: forge / unbox / companion (if behavior changed)

## Privacy checklist

- [ ] No uploads / no AIhero server calls
- [ ] No API keys solicited or stored in the app
- [ ] No writing into other tools' configs (`~/.codex`, `~/.claude`, etc.)
- [ ] Activity reads stay consent-gated and mtime/presence-only (no file contents)
