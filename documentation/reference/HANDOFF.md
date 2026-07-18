# AIhero — Engineering Hand-off

**Audience:** the next engineer picking this up.
**Last updated:** 2026-07-18.
**Read the "Hard constraints" section first — it is the part that is easy to break and expensive to get wrong.**

---

## 1. What AIhero is (in one paragraph)

AIhero is a tiny, fun, **on-device** macOS collectible-superhero companion. It lives in the menu bar
(`NSApplication.accessory` — no Dock icon), and a transparent hero figure stands on your desktop and
reacts to whether you're working. You "forge" heroes deterministically from the coding tools you use
(Codex, Claude Code, Cursor, Ghostty, cmux, T3 Code), and each hero can get **bespoke AI-generated
portrait art** rendered on your own machine. Heroes level up as you work and can be **evolved** (a
manual "Update" button) to re-forge their portrait at a higher tier. The north star is **"fun, not
bloat"** — this is a collectible toy, *not* a web-admin dashboard. Everything stays on the user's Mac.

Product direction of record: the user's memory notes — collectible companion, native Swift,
menu-bar-only ops, canonical UI/hero-art lives in the user's **MagicPath** project.

---

## 2. Hard constraints (do not violate — these are load-bearing)

These come directly from the product owner and shape the whole architecture. Breaking one isn't a bug,
it's a betrayal of the product's promise.

### Privacy / security
- **Everything is on-device.** AIhero ships **no API key** and calls **no AIhero server**. Nothing is
  ever uploaded. The word "on your Mac" appears in the UI as a promise — keep it true.
- **Bespoke art is generated through the user's OWN installed Codex CLI** (`codex exec`, using its
  built-in key-free `image_gen`, authenticated under the user's own Codex login). AIhero does **not**
  call the OpenAI Image API directly and must **never** ask the user to paste an API key into the app.
- **Read-only on other tools.** The activity layer (Phase F) only *reads* what the user's tools
  already write, and only **file modification times / presence** — it never opens or parses file
  contents (no prompt text, no code). It **never writes to another tool's config** (no installing
  hooks into `~/.codex`, `~/.claude`, `~/.cursor`, shell rc). This was an explicit reversal of an
  earlier "install hooks" design — do not reintroduce it.
- **Consent-gated.** Every source the app reads is behind the existing `enabledSources` toggle in
  Settings. Turn a source off → it is not read. Changes are pushed to the reader live.
- **Never modify `scripts/image_gen.py`** (the system imagegen skill) and never call the Image API
  directly from app code. Use the Codex harness path only.

### Product taste
- Fun, collectible, on-brand. Not a dashboard, not an admin console, not bloated. When in doubt,
  fewer knobs.
- Canonical visual target lives in the user's **MagicPath** project (illustrated hero figures, 3
  switchable art directions). Procedural art in-repo is the **fallback**, not the aspiration.

---

## 3. Build / run / test / package (exact commands)

Native Swift 6 Swift Package. **No Xcode project** — it's SwiftPM, runs from the terminal.

| Task | Command |
|---|---|
| Build | `swift build` |
| Run the menu-bar app | `swift run AIhero` |
| Run tests | `swift test` (currently **52 tests, 0 failures**) |
| Print version | `swift run AIhero --version` |
| **Offscreen visual QA** | `swift run AIhero --render /tmp/aihero-shots` → writes PNGs of every surface |
| Headless end-to-end art check | `swift run AIhero --forge-test` (spawns a **real** Codex art run) |
| Activity ping (optional) | `swift run AIhero signal working --tool codex --cwd $PWD` |
| Package a `.app` | `Scripts/make_app.sh [debug\|release]` → `dist/AIhero.app` |
| Sign + notarize + DMG | `DEVELOPER_ID_APP="Developer ID Application: … (TEAMID)" Scripts/release.sh [icon.png]` |

- **Platform / toolchain:** macOS 14 target, `swift-tools-version: 6.0`, **`.swiftLanguageMode(.v5)`**
  on both targets. The v5 language mode intentionally relaxes strict concurrency so the `final class`
  + private `DispatchQueue` + weak-`self` `@Sendable` closure pattern compiles without hand-written
  `Sendable` conformances. If you flip to v6 mode you will get a wave of concurrency errors — that's a
  deliberate deferral, not an oversight.
- **`--render` is your primary QA loop.** It uses `ImageRenderer` to render real SwiftUI views to PNGs
  with no window server. Two traps live here (see §8): native controls (Toggle/Button/Slider/
  ProgressView) render as **placeholder glyphs** offscreen — that's expected; and `LazyVGrid` does
  **not** render offscreen (use manual layouts / `GeometryReader`), while eager `HStack`/`VStack` do.

---

## 4. Repository map

```
Package.swift            swift-tools 6.0, macOS 14, language mode v5, exe + test target
Sources/AIhero/
  App/                   Process entry + AppKit shell
    main.swift             arg routing: signal / --forge-test / --render / --version / (default → UI)
    AppDelegate.swift      NSApp lifecycle, .accessory activation
    MenuBarController.swift menu-bar item + right-click menu
    WindowManager.swift     owns shelf / settings windows
  Model/                 Pure-ish domain + the app's single source of truth
    AppModel.swift         @MainActor ObservableObject — roster, persistence, workState, art queue,
                           activity monitoring, XP/evolution. THE central file (~biggest).
    Hero.swift             Codable hero (genome, level, xp, sources, isUnboxed, story/powers)
    Archetype.swift        titles / taglines / creeds
    Source.swift           the 6 tools (Codex, Claude Code, Cursor, Ghostty, cmux, T3 Code)
    WorkState.swift        idle/thinking/working/shipping/waiting (+ init?(signalName:))
  Forge/                 Deterministic hero creation + the narrated "forging" sheet
    HeroForge.swift        seed → hero (deterministic; SeededRNG)
    ForgeView.swift        setup surface (pick sources / name)
    ForgingChamberView.swift narrated reveal-in-progress surface
  Art/                   Procedural fallback art (SwiftUI vector)
    HeroFigure.swift       full-body figure (used by companion + dossier)
    HeroPortrait.swift     framed portrait (used by gallery/box)
    Palette.swift          seeded color system
  Generation/            The bespoke (real AI) art pipeline
    HarnessProbe.swift     detects an installed image harness (currently: `codex`)
    HeroArtGenerator.swift spawns `codex exec -s danger-full-access …` → writes a transparent PNG
    HeroPromptBuilder.swift builds the image prompt (incl. level-aware evolutionClause)
    ArtDirection.swift     cinematic / inkComic / chibiToy / auto
  Activity/              Phase F — real work signals (all read-only, on-device)
    ActivityPing.swift       the ping value type
    ActivitySignalCLI.swift  `aihero signal …` writer (optional integration point)
    ActivitySignalListener.swift  watches ~/.aihero for pings → WorkState
    AmbientActivityReader.swift   READ-ONLY mtime detector over enabled tools' own logs
  Companion/            The transparent desktop figure (borderless click-through panel)
  Reveal/              The full-screen unboxing burst
  Shelf/               "My Heroes" window: boxes, dossier, shelf grid
    HeroDossierView.swift   backstory + EVOLUTION section (Update button)
    HeroBoxView.swift       collectible box (sealed/opened, art status badges)
    ShelfView.swift         the grid + forge/dossier sheets
  Settings/            One small settings surface (+ launch-at-login)
  Support/             Log (os.Logger), SeededRNG, RenderHarness (the --render QA harness)
Tests/AIheroTests/     8 files, 52 tests
Scripts/               make_app / make_icon / sign_app / release (packaging)
documentation/         planned → active → completed → reference (see §9)
```

### Persistence
`AppModel` persists the roster as JSON to a state file (`init(stateURL:)`). Load is resilient: a
corrupt file is backed up before reset (never silently nuked). Generated art PNGs live under
`~/Library/Application Support/AIhero/art/<hero-uuid>.png` via `HeroArtStore`.

---

## 5. The bespoke-art pipeline (how a hero gets real art)

1. `HarnessProbe.availableImageHarnesses()` looks for an installed `codex` binary. No harness →
   the app cleanly falls back to procedural `HeroFigure`/`HeroPortrait` and says so (no dead ends).
2. `HeroPromptBuilder.transparentHeroPrompt(for:direction:outputPath:)` builds a prompt from the
   hero's fixed genome + art direction + (if leveled) an `evolutionClause`.
3. `HeroArtGenerator.generate(...)` spawns the user's Codex:
   `codex exec -s danger-full-access --skip-git-repo-check -C <tmp> "<prompt>"` in a throwaway temp
   dir, stdin = `/dev/null` (else codex hangs), stdout/stderr → a temp log, `PATH` widened so a
   Finder-launched app can still find homebrew tools. Success = exit 0 **and** the PNG exists.
4. `AppModel` runs generation through a **serialized queue** (`maxConcurrentArtGenerations = 1`,
   idempotent enqueue, retained tasks, `retryArtGeneration(for:)`). UI reflects state via
   `artGenerationStatus: [UUID: ArtGenStatus]` (`.generating` / `.ready` / `.failed(String)`), which
   drives the box badges and the dossier/settings evolution copy.

**Why it's gated on `isProduction`:** `AppModel.isProduction` is true only when no state-URL override
is passed. Tests and `--render` pass an override, so they never spawn a real Codex subprocess. Keep
any new subprocess-spawning code behind this gate.

Proof artifacts that the pipeline works live in `documentation/reference/phase0-proof/` and
`phase3-proof/`.

---

## 6. Activity signals + evolution (Phase F — the most recent work, now complete)

This is the part most likely to be misunderstood, because it was **redesigned mid-flight** for privacy.

**What it does now:**
- `AmbientActivityReader` polls (a `DispatchSourceTimer` on a utility queue, ~3s, 8s busy window) the
  **modification recency** of the enabled tools' own on-disk logs — Codex (`~/.codex/sessions`,
  `~/.codex/log`) and Claude Code (`~/.claude/projects`). It reads **mtime/presence only**, never file
  contents. The other four sources are honest no-ops (no stable global log to read this way).
- When it sees recent writes it calls `AppModel.receiveAmbientBusy()`, which: marks the signal "live",
  lifts an **idle** ring to `.working` (and *yields* to any finer state a real ping set — it never
  stomps `waiting`/`shipping`), refreshes the liveness clock, and grants work XP.
- **Evolution is the payoff.** Real activity earns the active hero XP (rate-limited: `xpGrant = 10`
  per `xpGrantInterval = 15s`). `xpForNextLevel(level) = max(1, level) * 30`. When
  `canEvolve(hero)` is true, the **"Update" button** (dossier EVOLUTION section + Settings HERO
  section) is enabled. Clicking it (`AppModel.evolve(id)`) spends XP with carry-over, bumps the level,
  saves, and — in production — **re-forges the portrait** via the same Codex harness with a
  level-aware prompt. The genome (identity/palette/emblem/silhouette) stays **fixed** so an evolved
  hero is recognizably the *same collectible*, just leveled.
- The old "simulated random wander" still exists as a **clearly-labeled** fallback ("Simulate when
  idle") for when no real activity is detected. Settings shows a live/simulated status dot honestly.

**The `aihero signal` CLI + `ActivitySignalListener`** survive as an *optional* integration point:
they only ever write to AIhero's own `~/.aihero/`, touching no user config. AIhero does **not** install
them anywhere — a user could wire their own hook to call `aihero signal` if they wanted finer
(thinking/waiting) states. Distinguishing thinking vs waiting vs plan-ready would require reading event
*types* (not bodies) and is deliberately deferred as a future **explicit opt-in**.

Full detail + rationale: `documentation/completed/features/2026-07-18_unified-activity-signals.md`.

---

## 7. Current status

**Done & verified (52 tests green; every surface visually QA'd via `--render`):**
- Core: deterministic forge, procedural art, transparent companion, shelf, unboxing reveal, menu bar.
- Hero dossier (backstory/powers/sources) + enriched origin generation.
- Bespoke-art seam end-to-end (probe → generate → store → display) with status badges + retry.
- Production hardening: serialized/retried art queue, temp-dir cleanup, clamp restored window to a
  live screen, resilient state load (backup-before-reset), `os.Logger`, harness health honesty.
- Packaging pipeline (bundle/sign/notarize/DMG scripts) — runtime-gated on the user's Apple Developer
  cert + a MagicPath icon PNG.
- **Phase F complete:** read-only ambient activity reader + earned manual "Update" evolution.

**Completed docs (closed for v0.1):** MVP + production-hardening live under
`documentation/completed/milestones/`. Phase F write-up:
`documentation/completed/features/2026-07-18_unified-activity-signals.md`.

**Open-source front door:** root `README.md`, MIT `LICENSE`, `CONTRIBUTING.md`,
`SECURITY.md`, `CODE_OF_CONDUCT.md`, `.github/` CI + issue/PR templates,
`documentation/reference/RELEASE.md`, and `--render` shots in
`documentation/reference/screenshots/`.

**Deferred / tracked (not blockers):**
- Unix-domain-socket fast path for the ping transport (currently atomic-file).
- Type-only reads to distinguish thinking / waiting / plan-ready (needs its own explicit consent step).
- A forge "gather"-stage wiring test.
- Signed/notarized DMG is gated on the user's Apple Developer cert being available
  (procedure documented in `documentation/reference/RELEASE.md`).
- Evolution tunables (`xpGrant=10`, `xpGrantInterval=15s`, `xpForNextLevel=level*30`) are sensible
  defaults but **haven't been felt out in a long live session** — expect to retune the pace.
- Full Hatch-style atlas animation / discovery worker — still in
  `documentation/planned/features/2026-07-18_ai-hero-art-pipeline.md` (post-v0.1).
- **Orphan test PNG** at `~/Library/Application Support/AIhero/art/40C360C3-2DED-4571-A42F-D09B94D58C62.png`
  — left from a render; the owner has **not** approved deleting it. Do not delete without confirming.

---

## 8. Gotchas / traps (things that will waste your afternoon)

1. **History is thin but real.** The repo has an initial commit and an open-source packaging
   layer on top; treat `main` as the source of truth and prefer small, reviewable commits over
   rewriting history.
2. **SourceKit index-lag false positives.** After creating a new Swift file you'll see editor/
   diagnostic errors like *"Cannot find type 'X' in scope"* or *"Cannot infer contextual base in
   reference to member 'idle'"*. These are **not real** — `swift build` is the source of truth and
   compiles cleanly. Don't "fix" them; rebuild.
3. **`--render` control placeholders.** Native controls (Button/Toggle/Slider/ProgressView) show as a
   yellow "no-entry" placeholder glyph in offscreen QA — this is expected; they render for real in the
   running app. If you need a bar/indicator to show in QA, build it manually (see the dossier's
   `GeometryReader` progress bar). And **`LazyVGrid` renders nothing offscreen** — use eager stacks or
   manual grids for anything you want to QA via `--render`.
4. **`isProduction` gate.** Any code that spawns a subprocess (art generation, evolution re-forge)
   must stay behind `AppModel.isProduction` so tests/`--render` never fork a real Codex run. Test
   models pass a state-URL override, which sets `isProduction = false`.
5. **Codex subprocess quirks:** stdin must be `/dev/null` or `codex` hangs; PATH must be widened for
   Finder-launched runs; success requires exit 0 **and** the output PNG existing (a 0 exit with no
   file = failure).
6. **`@MainActor` test helpers.** `AppModel.init` is `@MainActor`; test factory helpers that build one
   must be marked `@MainActor` or you'll get "call to main actor-isolated initializer in a synchronous
   nonisolated context."
7. **Don't reintroduce hook-writing or git-watching.** Both were explicitly dropped for privacy. The
   design is read-only + manual. See §2 and the Phase F completed doc.

---

## 9. Docs & workflow discipline

Documentation lifecycle (enforced by the owner's global CLAUDE.md):
`documentation/planned/[category]/` → `active/` (flat, max 3–5) → `completed/[category]/` →
`archive/YYYY-MM/`. Reference docs (like this one) live in `documentation/reference/` with **no date
prefix** and are continually updated. Work items are `YYYY-MM-DD_description.md` (date = when started).

Start non-trivial work in **plan mode**, write the plan to `planned/`, get approval, then move it to
`active/` while implementing and log changes as you go. The most useful reading order for a newcomer:
1. Root `README.md` (product pitch + quickstart).
2. This file.
3. `documentation/completed/features/2026-07-18_unified-activity-signals.md` (Phase F, the newest and
   most nuanced subsystem, with the full privacy rationale).
4. `documentation/completed/milestones/2026-07-18_production-hardening.md` (what "production-ready"
   meant for v0.1).
5. `documentation/completed/features/2026-07-18_forging-experience.md` (the forge/reveal UX).
6. `documentation/planned/features/2026-07-18_ai-hero-art-pipeline.md` (where the art pipeline is
   headed — post-v0.1).
7. `documentation/reference/RELEASE.md` (tags + cert-gated notarization).

---

## 10. Suggested first moves for the next engineer

1. `swift build && swift test` (expect 52/0) and `swift run AIhero` — get the companion on your
   desktop and forge a hero to build intuition.
2. Browse `documentation/reference/screenshots/` (or re-run
   `swift run AIhero --render documentation/reference/screenshots`) — the fastest way to see every
   surface.
3. Live-test the evolution pace: work for a while with Codex/Claude Code enabled, watch XP accrue, hit
   "Update," and confirm the re-forge feels good. Retune the XP tunables to taste.
4. When Apple Developer credentials + a MagicPath icon PNG are ready, cut a notarized DMG per
   `RELEASE.md` and attach it to a GitHub Release.
5. When you touch anything that deploys or ships, re-read §2 — the privacy promises are the product.
