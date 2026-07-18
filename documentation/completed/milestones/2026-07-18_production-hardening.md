# Task: Production Hardening
**Date Started**: 2026-07-18
**Status**: Completed (Phases A–F done; signed/notarized DMG remains cert-gated — see RELEASE.md)
**Agent Lead**: 🏗️⚙️

## Plan
### Objective
Take AIhero from "works on the dev machine via `swift run`" to "installable, honest,
and resilient for a real user." Grounded in the 2026-07-18 production audit.

### Audit corrections (things already done right)
- **Storage is correct** — state + art both live in `~/Library/Application Support/AIhero/`
  (`AppModel.makeStateURL` `AppModel.swift:174`, `HeroArtStore.artDirectory` `HeroFigure.swift:20`).
  A Finder-launched `.app` (cwd `/`) is fine. Not a bug.
- **Bundle assembles** — `Scripts/make_app.sh` builds a real bundle with a correct
  `Info.plist` (`LSUIElement`, id `ai.aihero.companion`). It just isn't signed/iconed.

### Phases (worst-first; each independently shippable)

- **Phase A — Generation feedback + safe concurrency + retry** *(fully buildable/verifiable here)*
  - Surface the already-published `ArtGenStatus` in the shelf ("Forging portrait…" / "Portrait failed · Retry").
  - Cap concurrent Codex subprocesses (serialize; forging N heroes must not spawn N `danger-full-access` processes).
  - Retain generation Tasks; add a retry entry point for `.failed` heroes.
  - Clean up the per-run temp log dir.
- **Phase B — Harness health/auth honesty**
  - Non-blocking `codex` runnability probe so ForgeView doesn't promise a renderer that will fail.
  - Auth failures already surface via Phase A's visible `.failed` + retry.
- **Phase C — Packaging pipeline** *(final steps need the user's Apple Developer cert)*
  - App icon (`.icns` + `CFBundleIconFile`).
  - Extend `make_app.sh` (or add `sign_app.sh`): hardened runtime, entitlements, Developer ID sign, notarize, staple, DMG.
  - Version sourced from the bundle, not the hardcoded `AIheroInfo.version`.
- **Phase D — Resilience & multi-display**
  - Clamp restored companion frame into a live `visibleFrame` (`CompanionController.swift:87`).
  - Structured `os.Logger`; back up `state.json` before a decode-failure reset (`AppModel.load` `:183`).
- **Phase E — Tests**
  - Add a `testTarget`; unit-test the deterministic forge, genome, and prompt builder.
- **Phase F — Real activity signals** *(the product bet; Phase 4 of the art plan)*
  - Replace simulated work-state with consented, real signal hooks — or keep clearly labeled.

### Tasks
- [x] A1: Surface generation status on the shelf box (generating / failed+retry)
- [x] A2: Serialize + retain + retry generation in AppModel
- [x] A3: Clean up temp forge log dir
- [x] A4: Render + verify the new affordances
- [x] D1: Clamp restored companion frame onto a live screen
- [x] B: Harness health/auth honesty (non-blocking runnability probe + advisory)
- [x] C: Packaging pipeline built + verified (runtime-gated on user's cert + MagicPath PNG)
- [x] D2: os.Logger + resilient state load (backup before reset)
- [x] E: Test target (23 tests: forge / genome / prompt / codable / resilient state)
- [x] F: Real activity signals (read-only ambient reader + earned manual "Update" evolution;
      see `2026-07-18_unified-activity-signals.md`. 52 tests / 0 failures. Deferred non-blockers
      tracked there: UDS fast-path, type-only thinking/waiting reads, forge-gather test.)

## Implementation Log

### 2026-07-18 — Phase A: generation feedback + safe concurrency + retry
- **Changes**:
  - `AppModel.swift` — replaced fire-and-forget generation with a serialized
    queue (`artQueue`/`artTasks`/`activeArtGenerations`, `maxConcurrentArtGenerations = 1`).
    `enqueueArtGeneration` is idempotent; `pumpArtQueue` releases one at a time;
    added `retryArtGeneration(for:)` that re-probes for a harness. Fixes the
    "forge 5 heroes → 5 concurrent `danger-full-access` subprocesses" hazard.
  - `HeroBoxView.swift` — added optional `artStatus` + `onRetryArt`; a top-of-box
    pill shows "Forging portrait…" (spinner) while generating and a
    "Portrait failed · Retry" chip on failure. Added an always-present
    "Regenerate Portrait" context-menu item so retry survives relaunch (transient
    status is not persisted).
  - `ShelfView.swift` — passes `model.artGenerationStatus[hero.id]` + retry closure.
  - `HeroArtGenerator.swift` — removes the throwaway temp working/log dir after
    each run (was accreting under `$TMPDIR`).
- **Verification**: `swift build` clean; `--render` boxes.png shows the forging
  pill on box 0 and the retry chip on box 1 (native spinner stubs as a placeholder
  offscreen; renders live). Serialization/retry logic verified by reading.
- **Decisions**: cap = 1 because each run is a heavy full-access subprocess;
  status intentionally not persisted (a relaunch reloads real art from disk, and
  the context-menu item covers deliberate regeneration).

### 2026-07-18 — Phase D1: off-screen companion recovery
- **Changes**: `CompanionController.swift` — added `clampToVisibleScreen(_:)`,
  called after frame restore in `show()` and after `applyScale()`. If the panel
  overlaps no connected screen's `visibleFrame`, it re-lands bottom-right on main.
- **Verification**: `swift build` clean. (Multi-display restore path is logic-only;
  can't detach a display in this environment.)

### 2026-07-18 — Phase C: packaging pipeline (scaffolding complete)
- **Changes**: `Scripts/make_icon.sh` (sips→iconutil .icns), `Scripts/make_app.sh`
  (assembles `dist/AIhero.app` + Info.plist, embeds icon if present),
  `Scripts/sign_app.sh` (hardened runtime, no entitlements, notarize+staple+DMG),
  `Scripts/release.sh` (orchestrator). `AIheroInfo.version` now reads
  `CFBundleShortVersionString` with a `0.1-dev` fallback; `AIhero --version` added.
- **Verification**: dev `--version` → `0.1-dev`; packaged binary `--version` →
  `0.1.0`; `plutil -lint Info.plist` OK; `.icns` valid; signature adhoc (pre-cert).
- **Gated on user assets** (approved answers: "Yes, I have Developer ID" / "From my
  MagicPath art"): export the icon as a square PNG and run
  `DEVELOPER_ID_APP="Developer ID Application: … (TEAMID)" Scripts/release.sh icon.png`
  after a one-time `xcrun notarytool store-credentials AIhero …`.

### 2026-07-18 — Phase B: harness runnability honesty
- **Changes**: `HarnessProbe.probeRunnable(_:)` — async, non-blocking `<binary>
  --version` ping with a 6s watchdog (one-shot `OneShotBool` box). Deliberately
  does NOT check auth or touch the network; a logged-out-but-runnable Codex still
  passes, and auth failures surface later as Phase A's retryable `.failed`.
  `ForgeView` runs it from a `.task(id: selectedHarnessID)` and, only if the
  harness is present-but-unresponsive, shows an orange advisory. Never gates Forge.
- **Verification**: `swift build` clean; probe path is subprocess-based (exercised
  live in the running app, not in unit tests to avoid spawning processes in CI).

### 2026-07-18 — Phase D2: logging + resilient state load
- **Changes**: `Support/Log.swift` — `os.Logger` façade (subsystem
  `ai.aihero.companion`, categories model/art/login); hero names, stories, and
  prompts are never logged. `AppModel.load()` now distinguishes "no file" (clean
  first launch) from "present but unreadable/undecodable" (corruption): on the
  latter it moves the file to `state.{corrupt,unreadable}-<timestamp>.json` BEFORE
  any save can overwrite it, then continues empty. Fixes silent whole-collection
  loss on a corrupt `state.json`. `save()` now logs encode/write failures instead
  of dropping them.
- **Verification**: unit-tested (see Phase E) — corrupt state is preserved, a
  missing file makes no spurious backup, and valid state reloads.

### 2026-07-18 — Phase E: test target
- **Changes**: added `AIheroTests` testTarget (`@testable import` of the executable
  target, works on macOS SwiftPM). 23 tests across five files:
  - `SeededRNGTests` — determinism, zero-seed guard, FNV-1a offset-basis
    known-answer, order-sensitive combine, deterministic array pick.
  - `HeroForgeTests` — same-inputs-reproduce-identity, source-order independence,
    salt divergence, blank/absent name handling, art-direction round-trip.
  - `HeroPromptBuilderTests` — output-path + `SAVED` trailer, originality guard +
    identity, and the green→magenta chroma-key switch (both branches).
  - `HeroCodableTests` — lossless round-trip + legacy decode without
    `artDirectionID` (→ `.auto`).
  - `AppModelStateTests` — the D2 collection-loss guard end-to-end.
- **Verification**: `swift test` → 23 passed, 0 failures. `swift build -c release`
  clean, no new warnings.
