# Task: Phase F — Unified activity-signal layer (real WorkState from the tools you use)
**Date Started**: 2026-07-18
**Status**: Complete (read-only ambient reader + earned manual evolution; deferred items tracked)
**Agent Lead**: 🏗️ Architect / ⚙️ Backend / 🔒 Security
**Answers the user's Phase F direction:** "tap into what the common items are that are unified
across all the different targeted harnesses / IDEs" — one common-denominator layer, not six
bespoke integrations.

## ⚠️ DIRECTION CHANGE — 2026-07-18 (privacy-first, read-only, no hooks written)
Two decisions from the user reshape this phase. **They override the "Recommended architecture"
and "MVP scope" written below** (kept for research provenance):

1. **No continuous git watching.** Drop the Tier-2 git FSEvents watcher entirely. Hero *evolution*
   becomes a **manual "Update" button** (surfaced in the hero's package/reveal and in Settings) —
   user-triggered, not passive surveillance. *(Verbatim: "I don't think we need them watching the
   git … let's have it be a button that says 'Update' … we probably need to make sure that we are
   trying to be as secure for their privacy as possible.")*
2. **Never write hooks into the user's tool configs.** Drop the "Connect your tools" flow that
   appends entries to `~/.codex/hooks.json`, `~/.claude/settings.json`, `~/.cursor/hooks.json`,
   shell rc. Instead, **read-only** ambient detection: infer *busy / needs-attention / plan-ready*
   from signals the tools **already** produce, reading only what's needed and adding nothing.
   *(Verbatim: "let's not add hooks instead. Let's just identify when things are happening, so read
   only. If we see that things are busy then we can do one … we should just be able to read those
   hooks … rather than adding to.")*

**Privacy contract for the read-only detector (hard rules):**
- Reads only the agent tools' OWN existing on-disk logs, and only for **enabled `Source`s**
  (the existing consent gate). Adds/writes NOTHING to any tool's config.
- MVP granularity = **file modification recency only** (mtime/presence) → busy↔idle. It does **not
  open or parse** those files, so no prompt or code text is ever read.
- Distinguishing *thinking / waiting / plan-ready* needs reading event **TYPES** (never bodies) and
  is left as a **separate, explicitly-consented** step — not done silently.
- Everything stays on-device; nothing is uploaded; no network.

The `aihero signal` CLI + atomic-file transport (F1/F2) **survive** — they write only to AIhero's
own `~/.aihero/` and touch no user config, so they remain a valid optional integration point (e.g.
if a user wires their own hook). They are no longer something *we* install anywhere.

## What this replaces
`WorkState` (idle/thinking/working/shipping) currently runs on a **simulated random wander**
(`AppModel.startWorkSimulation`, `simulateActivity`). This phase makes it real, driven by the
tools the user actually runs, **fully on-device and consented** — and feeds the same layer into
the forge-time "Reading your signals…" stage (see `2026-07-18_forging-experience.md`).

## Research result (2026-07-18, with direct local evidence on this machine)
Full findings + citations archived below; headline:

**Six tools collapse to four wiring points.** Three have first-class, arbitrary-command hook
systems; one shell hook covers the rest transitively:
- **Codex CLI** — TWO surfaces: `notify` program (turn-complete) **and** `~/.codex/hooks.json`
  lifecycle hooks (`UserPromptSubmit, PreToolUse, Stop, …`). Also writes passive
  `~/.codex/sessions/**/rollout-*.jsonl` with `task_started`/`task_complete`. *(Confirmed live:
  this machine's `~/.codex/config.toml` already sets `notify`, and a rollout file shows the events.)*
- **Claude Code** — richest hooks in `~/.claude/settings.json` (`UserPromptSubmit, PreToolUse,
  PostToolUse, Stop, Notification, PermissionRequest, …`); transcript JSONL per session.
- **Cursor** — first-class hooks since v1.7 (`~/.cursor/hooks.json`: `beforeSubmitPrompt,
  afterFileEdit, beforeShellExecution, stop, …`) → `.cursor/hooks.log`. (NOT hook-less as we assumed.)
- **Ghostty** — no app-level event API; covered by the **shell's** `preexec`/`precmd` (zsh) or
  `DEBUG` trap/`PROMPT_COMMAND` (bash). Command-level granularity only.
- **cmux** and **T3 Code** — hosts/orchestrators that run the SAME agent CLIs; no first-class
  subscribe API for us. Covered transitively via the wrapped agent's hooks + git.

⇒ **A single unified ping contract is feasible:** configure it once into 3 agent hook systems
(Codex/Claude/Cursor) + 1 shell hook, and you transitively cover all six.

## Recommended architecture — 3-tier hybrid (precedence: ping > git > process/fs)

**Tier 1 — Unified activity ping (primary; only tier that cleanly separates thinking vs working).**
Ship a tiny CLI subcommand `aihero signal <idle|thinking|working|shipping|waiting> --tool <name>
--cwd <path>`. It writes to a **local Unix domain socket** `~/.aihero/activity.sock` (low latency,
no disk churn) with an **atomic-file fallback** `~/.aihero/state.json`. Wired once per tool via a
one-click "Connect your tools" that appends AIhero's hook entries to:
- `~/.codex/hooks.json`: UserPromptSubmit→thinking, PreToolUse→working, `git push` matcher→shipping, Stop→idle (+ keep `notify` as idle backstop)
- `~/.claude/settings.json` hooks: same mapping (PreToolUse Edit/Write/Bash→working, `git push`→shipping, Notification/PermissionRequest→waiting)
- `~/.cursor/hooks.json`: beforeSubmitPrompt→thinking, afterFileEdit/beforeShellExecution→working, stop→idle
- shell rc (covers Ghostty + bare terminals + cmux panes): preexec→working, precmd→idle

**Tier 2 — Git state watcher (universal source of truth for `shipping`; tool-agnostic).**
FSEvents on each tracked repo's `.git`: `logs/HEAD` change → commit → **shipping**; remote-ref/
reflog update → push → **shipping** (best-effort); dirty worktree via periodic `git status
--porcelain` → **working**, quiet → **idle**. Single most reliable `shipping` detector; can't see
thinking or attribute to a tool.

**Tier 3 — Process + FSEvents liveness fallback (for un-wired tools, e.g. OpenCode/Gemini).**
`ps` for agent binaries (`codex`, `claude`, `cursor-agent`, gated `node`) + high CPU → busy;
FSEvents in project dir → working. Coarse working↔idle only; `node` is noisy → gate by cwd.

**Zero-config supplement:** passively tail Codex rollout JSONL (`task_started`/`task_complete`)
and Claude transcript JSONL for users who haven't installed hooks — **read event *types* only,
never message bodies** (privacy).

**Resolution:** shipping (git) overrides working; debounce back to idle after N s of silence.

## Honest gaps / risks (carry into UX copy)
- thinking vs working reliable **only** from hooks; git/process/shell tiers collapse to "busy".
- local `git push` detection is best-effort (remote-ref/reflog lag); catch `git push` in a hook where possible.
- Codex `notify` is turn-complete only (no start); `[hooks]` is newer/less-documented.
- shell/Ghostty hooks are command-level — a whole `claude` session is one command.
- cmux/T3 Code expose no first-class API to us; covered only via wrapped agents + git.
- process/CPU noisy, hard to attribute to a project.
- **Privacy:** ping + hooks are fully local and user-configured (good consent story). Passive log
  reads must restrict to event *types*; never parse prompt/code bodies.

## MVP scope (this phase)
1. **`ActivitySignal` + local listener in Swift** — socket `~/.aihero/activity.sock` + file
   fallback; maps pings → `WorkState`; feeds `AppModel.workState`. Replaces the simulated wander
   when connected; keeps simulated mode **clearly labeled** when not.
2. **`aihero signal …` CLI subcommand** — the ping writer (also usable by hooks/shell).
3. **Git watcher (Tier 2)** — the tool-agnostic baseline that works with zero setup for repos.
4. **"Connect your tools" consent flow** — opt-in per tool; shows exactly what file it edits and
   what it writes; reversible ("Disconnect" removes AIhero's entries). Nothing uploaded.
5. Wire into the forge "Reading your signals…" gather stage (richer brief → better art prompt).

**Deferred (fast-follow):** Tier 3 process/FS fallback; passive JSONL tailing; per-project
attribution UI; multi-repo management.

## Tasks (revised for the direction change)
- [x] F1: `ActivitySignalListener` (atomic-file + directory watch) → `WorkState`; labeled simulated fallback.
- [x] F2: `aihero signal` CLI subcommand (argument parsing, writes ping). *(Optional integration point; not auto-installed.)*
- [x] ~~F3: Git FSEvents watcher~~ — **DROPPED** (no passive git watching; see direction change).
- [x] ~~F4: "Connect your tools" hook-writing flow~~ — **DROPPED** (never write to user tool configs).
- [ ] **F3′ (new): Read-only ambient activity reader** — infer busy↔idle from the recency (mtime
      only) of enabled tools' OWN existing session logs; adds/parses nothing. Drives `WorkState`.
- [x] **F4′ (new): Manual "Update" button** for hero evolution — user-triggered. **Behavior chosen
      by the user: "Evolution: re-forge art"** → clicking Update levels the hero up AND re-runs the
      bespoke-art harness so the portrait visibly evolves at a higher tier. Surfaced in the dossier
      (EVOLUTION section) and Settings (HERO section). XP is earned from real read-only signals.
- [~] F5: Precedence/debounce resolver — **partial**: live-takeover + silence-decay-to-idle done in
      `AppModel.tickWork`; ambient (coarse working) yields to finer ping states (waiting/shipping).
- [x] F6: tests — **52 total, 0 failures**: transport round-trip, verb mapping, CLI contract, model
      go-live, real DispatchSource listener, ambient-reader inference (9), evolution/XP (8). Remaining
      nice-to-have: forge "gather"-stage wiring assertion.
- [x] Move to `active/` on approval; log per task.

### F4′ evolution — minimal proposal (needs a yes before building the button)
The "Update" button is only worth adding if it *does* something honest. Minimal MVP idea: on click,
AIhero re-reads the currently-enabled ambient signals (read-only), records a `lastUpdated` stamp +
a coarse "recently active with: <tools>" summary on the hero, and (later) bumps a small
level/streak. Full XP/story evolution is its own arc — do **not** build hollow UI. Confirm the
minimal behavior (or a richer one) before implementing.

### Settled decisions
- **Socket vs file:** MVP ships the **atomic-file transport**; Unix-domain-socket fast path is a
  tracked fast-follow, not a blocker.
- **Consent gate:** the read-only reader is gated by the existing `enabledSources` set — revocable
  per tool in Settings; reads nothing for a disabled source.

## Implementation Log

### 2026-07-18 — F3′ Read-only ambient reader (DONE)
- **Changes Made:** Built `AmbientActivityReader` — a read-only, metadata-only detector that infers
  busy↔idle from the *modification recency* of the tools' own session logs. It never opens/parses
  those files (mtime + presence only), adds nothing to any tool's config, gates on `enabledSources`,
  and is coarse by design (busy → `.working`). Pure core (`isBusy`, `newestMTime`) split out for
  deterministic tests; a `DispatchSourceTimer` on a utility queue polls every 3s (busy window 8s).
  Default probes: Codex (`~/.codex/sessions`, `~/.codex/log`) + Claude Code (`~/.claude/projects`);
  the other four sources are honest no-ops (empty probes) since they keep no stable global log we can
  read this way.
- **Files:** `Sources/AIhero/Activity/AmbientActivityReader.swift` (new);
  `Sources/AIhero/Model/AppModel.swift` (started production-only in `startActivityMonitoring`;
  `receiveAmbientBusy` lifts an idle ring + goes live + refreshes the liveness clock, and **yields**
  to finer ping states; `setSourceEnabled` pushes consent changes to the reader live);
  `Sources/AIhero/Settings/SettingsView.swift` (ACTIVITY now shows a live/simulated dot + "Simulate
  when idle"; SIGNALS copy states read-only / no-content / never-changes-your-tools).
- **Tests:** `Tests/AIheroTests/AmbientActivityTests.swift` — 9 tests: `isBusy` window/skew, newest-
  mtime (recency, suffix filter, nested, empty/missing), real-timer reader fires for an enabled
  source + stays quiet for a disabled one, and model goes-live-but-yields. **Full suite: 44 tests,
  0 failures.** `--render settings.png` re-verified: layout + honesty copy read cleanly.
- **Decisions/trade-offs:** mtime-only is the privacy-maximal MVP; distinguishing thinking/waiting
  needs type-only reads and is deferred as an explicit opt-in. `maxFilesScanned` bounds the poll (may
  miss the newest file in a pathological history — acceptable for a toy companion). Precedence:
  ambient only lifts `.idle`; it never stomps a finer state a ping set.

### 2026-07-18 — F4′ "Update" button = hero evolution (DONE)
- **User's choice:** "Evolution: re-forge art." Update isn't a hollow refresh — it advances a level
  AND re-runs the bespoke-art harness so the portrait visibly ascends, spending one harness run under
  the user's own Codex login. Evolution is *earned*: XP accrues only from real, read-only activity
  signals (rate-limited), so the collectible keeps reflecting the work that made it.
- **Changes Made:**
  - `AppModel`: `xpForNextLevel(_:) = max(1,level)*30`, `canEvolve(_:)`, `awardXP(_:to:)` (testable),
    `grantWorkXP()` (rate-limited: 10 XP / 15s of real activity, to the active hero), and
    `evolve(_:)` — guards `canEvolve`, spends XP with carry-over, `level += 1`, saves, then (only in
    production, i.e. `override == nil`) enqueues an art re-forge via the first available image harness.
    `receiveAmbientBusy`/`receiveActivityPing` now grant work XP; idle pings never do.
  - `HeroPromptBuilder.evolutionClause(for:)`: level-aware tiers (2–3 seasoned / 4–6 ascended /
    7+ legendary), each explicitly ordering "keep the identity, palette, emblem, and silhouette
    unchanged" so an evolved hero is the *same collectible*, visibly leveled — genome stays fixed.
  - `HeroDossierView`: new EVOLUTION section (manual GeometryReader progress bar) with three states —
    progress ("Keep working to evolve — X / target"), ready ("Ready to evolve" + **Update** button),
    evolving ("Evolving… re-forging the portrait on your Mac"). Injected from the live model via
    `ShelfView`'s dossier sheet, so it updates in real time while open.
  - `SettingsView`: new HERO section mirrors the same status + **Update** button (disabled unless
    ready / while evolving).
- **Files:** `Sources/AIhero/Model/AppModel.swift`, `Sources/AIhero/Generation/HeroPromptBuilder.swift`,
  `Sources/AIhero/Shelf/HeroDossierView.swift`, `Sources/AIhero/Shelf/ShelfView.swift`,
  `Sources/AIhero/Settings/SettingsView.swift`, `Sources/AIhero/Support/RenderHarness.swift`
  (3 new dossier evolve-state shots); `Tests/AIheroTests/HeroEvolutionTests.swift` (new, 8 tests).
- **Verified:** `swift build` clean; `swift test` 52 tests / 0 failures; `--render` produced
  `dossier-progress.png` / `dossier-ready.png` / `dossier-evolving.png` — all three EVOLUTION states
  read cleanly (Update button shows as the expected native-control placeholder in offscreen QA; it
  renders for real in the running app).
- **Privacy note:** the re-forge runs the SAME on-device harness the initial forge uses (user's own
  Codex `image_gen`, key-free). No AIhero server, no API key, nothing uploaded. Gated on
  `isProduction` so tests/renders never spawn a subprocess.
- **Tunables (un-runtime-validated):** `xpGrant = 10`, `xpGrantInterval = 15s`,
  `xpForNextLevel = level * 30`. Reasonable defaults; easy to retune after living with it.

**Phase F is functionally complete.** Deferred/tracked (not blockers): Unix-domain-socket fast-path
for the ping transport; type-only reads to distinguish thinking / waiting / plan-ready (explicit
opt-in); a forge "gather"-stage wiring test.

## Full research report (archived)
See the completed research in the task transcript; key per-tool table, payload shapes (Codex
`notify`: `type/thread-id/turn-id/cwd/input-messages/last-assistant-message`; Claude hook stdin:
`session_id/transcript_path/cwd/permission_mode/hook_event_name` + event-specific), and the
"can it run a command on activity?" feasibility matrix (all six: yes, directly or by proxy) are
captured there. Primary sources: Codex config-reference & config-advanced, Claude Code hooks
reference, Cursor Hooks docs, Ghostty shell-integration/OSC-133, cmux + T3 Code repos.
