# Security Policy

AIhero is an **on-device** macOS companion. The product promise is simple:
nothing leaves your Mac, and the app never asks you to paste an API key.

## Supported versions

| Version | Supported |
| ------- | --------- |
| 0.1.x   | Yes       |
| main    | Best effort |

## Threat model (what we never do)

Please treat regressions of these as **security bugs**, not product polish:

1. **No uploads.** AIhero must not send prompts, code, hero data, or telemetry
   to an AIhero server (there is none) or any third-party endpoint from app code.
2. **No API keys in the app.** Bespoke art uses the user's own installed Codex
   CLI (`codex exec` + their Codex login). The app must never solicit or store
   an OpenAI / image API key.
3. **Read-only on other tools.** Activity detection may read **file modification
   times / presence** of enabled tools' own logs. It must never open or parse
   file contents (no prompt text, no source code).
4. **No writing into other tools.** Never install hooks or rewrite configs under
   `~/.codex`, `~/.claude`, `~/.cursor`, shell rc files, etc.
5. **Consent-gated sources.** Disabled sources in Settings must not be read.

## Reporting a vulnerability

Please **do not** open a public issue for security-sensitive reports.

1. Prefer GitHub's **Private vulnerability reporting** on
   [DevVig/AIhero](https://github.com/DevVig/AIhero) (Security → Advisories), or
2. Open a minimal private channel with the maintainers if advisories are
   unavailable.

Include: macOS version, AIhero version (`swift run AIhero --version` or the
bundled binary), steps to reproduce, and impact. We will acknowledge reports as
quickly as we can and coordinate a fix before any public disclosure.
