# Production checklist

What still stands between “works great on a developer Mac” and “someone else can install and trust it.”

Last updated: 2026-07-19 · grounded in the shipped code + active plans.

---

## Already done (do not rebuild)

- [x] Native macOS collectible loop (forge → sealed shelf → unbox → desktop companion)
- [x] Menu-bar app with left-click hero menu + right-click options (Settings, Launch at Login, Quit)
- [x] Forging Chamber with honest progress / no-harness / failure paths
- [x] Personality + multi-beat origin story + dossier
- [x] Bespoke art via user’s Codex login (no AIhero API key); procedural fallback
- [x] Serialized art queue, status badges, retry, temp-dir cleanup
- [x] Read-only ambient activity + optional `aihero signal` CLI (never writes other tools’ configs)
- [x] Manual **Update** evolution (XP → level-up → re-forge portrait; genome fixed)
- [x] Resilient state load, `os.Logger`, off-screen companion clamp
- [x] Packaging scripts (`Scripts/make_app.sh`, `sign_app.sh`, `release.sh`)
- [x] Hardened-runtime forge-test from a packaged `.app` under a minimal PATH
- [x] Test suite (52 tests) + `--render` visual QA harness
- [x] Private→public GitHub repo with hand-off doc

---

## Blockers — must finish before calling it “production”

These gate a real external install.

### 1. Signed + notarized DMG

| Item | Owner | Notes |
|---|---|---|
| Apple Developer ID Application cert in keychain | You | Identity like `Developer ID Application: Name (TEAMID)` |
| One-time `notarytool store-credentials AIhero …` | You | See header of [`Scripts/sign_app.sh`](Scripts/sign_app.sh) |
| Square app-icon PNG (MagicPath hero preferred) | You | Feed to `Scripts/release.sh icon.png` |
| Run release pipeline | Either | `DEVELOPER_ID_APP="…" Scripts/release.sh icon.png` → `dist/AIhero.dmg` |
| Smoke-test Gatekeeper install on a clean Mac / fresh user | Either | Open DMG, drag to Applications, forge one hero, quit/relaunch |

**Status:** scripts verified; **credential + icon not yet applied.**

### 2. First-run polish for strangers

| Item | Status | Why it matters |
|---|---|---|
| Empty-roster auto-opens My Heroes | Done | First launch has an obvious next step |
| Honest “no Codex → built-in art” path | Done | No dead end without an image harness |
| App icon in Dock / Finder / About | Blocked on #1 | Ad-hoc / icon-less bundles look unfinished |
| Short “what AIhero does / doesn’t do” privacy blurb on first forge | Partial | Forge + Settings copy exists; worth a one-screen first-run note before strangers |

### 3. Release packaging on GitHub

| Item | Status |
|---|---|
| Tag `v0.1.0` + GitHub Release with notarized DMG | Not started (needs #1) |
| README install section points at the Release asset | README ready; link after first Release |
| CI green on `main` (`swift build` + `swift test`) | Workflow added — confirm on next push |

---

## Should-have before inviting reviewers / tech-forward users

Not hard blockers for a private DMG to friends, but they will notice.

| # | Item | Why | Plan / code home |
|---|---|---|---|
| S1 | **Live feel pass on XP / evolve pace** | Defaults (`+10 XP / 15s`, `level × 30`) are untested over a real workday | [`AppModel`](Sources/AIhero/Model/AppModel.swift) tunables |
| S2 | **Discovery / brief worker** | Source toggles still mostly flavor the forge; “really about you” needs a compact local brief from harness metadata | [`documentation/planned/features/2026-07-18_ai-hero-art-pipeline.md`](documentation/planned/features/2026-07-18_ai-hero-art-pipeline.md) Phase 4 |
| S3 | **WorkState → companion animation** | Today: energy ring + light float. Designed: Hatch-style atlas rows (`idle` / `thinking` / `working` / `shipping` / `waiting`) | Same art-pipeline plan (Phase 1 deferred / Phase 4) |
| S4 | **Gemini (or second image harness) contract** | Runtime detection is the product; Codex is proven; Gemini still needs a healthy-machine smoke test | [`HarnessProbe`](Sources/AIhero/Generation/HarnessProbe.swift) |
| S5 | **Branch protection + required CI on `main`** | Stops broken pushes to the public tree | GitHub Settings (needs admin) |
| S6 | **Delete or keep orphan test PNG** | `~/Library/Application Support/AIhero/art/40C360C3-….png` left from a render — confirm before cleanup | Local only; not in git |

---

## Nice-to-have / explicitly deferred

| Item | Notes |
|---|---|
| Unix-domain-socket ping transport | Atomic files in `~/.aihero/` are fine for v0.1 |
| Type-only thinking / waiting reads | Needs its **own** explicit consent step; do not silently deepen ambient reads |
| AIhero writing hooks into other tools | **Rejected** — never reintroduce |
| Continuous git watching | **Rejected** — evolution is manual Update only |
| Per-pixel companion hit-testing | Window is a snug bounding box today |
| “Jump to active app” routing | Designed in MagicPath; not in the native MVP |
| Cross-platform (Linux) | Out of scope; Swift/macOS is the product |

---

## Definition of “production v0.1”

All of the following are true:

1. A stranger can download a **notarized DMG**, install without Gatekeeper fights, and see a real app icon.
2. First launch opens **My Heroes**; forging works with or without Codex (bespoke art or procedural fallback).
3. Settings clearly states the privacy posture (on-device, read-only signals, no API key).
4. `swift test` is green on CI for `main`.
5. A GitHub Release `v0.1.0` hosts the DMG; README install path points at it.
6. One clean-Mac smoke: forge → unbox → companion → work a bit → Update when ready → quit/relaunch roster intact.

Until **1** and **5** land, call the product **dev-preview**, not production.

---

## What we need from you (product owner)

Only these are externally gated:

1. **Developer ID** identity string + notarytool profile stored on the release machine.
2. **App icon** — square PNG from MagicPath (or approval to derive one from a proof hero).
3. **Decision on S6** — delete the orphan local art PNG? (yes / no)
4. **Priority after the DMG** — discovery brief (S2) vs animation atlas (S3) first.

Everything else on this list can be built in-repo without waiting.
