# Task: The Forging Experience — themed, narrated hero forging (+ personality)
**Date Started**: 2026-07-18
**Status**: Complete
**Agent Lead**: 🎨 Designer / ⚙️ Backend / 💻 Frontend

## The ask (user, verbatim intent)
> As we build the forging we're probably also going to need some identification saying
> "this is going to take a while." You're here, super hero. Theme it as the superhero
> forging, then show progress on where it is — pulling from what harnesses, what it's
> gathering, building the backstory for each superhero. Each superhero should have their
> own origin story of how they came to be, their personality, and their superhero powers.
> Hopefully that's somewhat animated when it's in the bottom-right corner.

## What exists today (the gap)
- **`HeroForge.forge()` is instant.** Name, title, origin story, powers are deterministic
  local template composition (microseconds). There is no wait to narrate for identity.
- **The real wait is the art render** — one `codex exec` subprocess, ~2 min / ~50k tokens,
  under the user's own Codex login (`HeroArtGenerator`). Today it runs *silently in the
  background* after the reveal; the hero bursts out with procedural art and the bespoke
  portrait swaps in later.
- **No progress narration.** The only art-progress surface is a small "Forging portrait…"
  pill on the shelf box (`HeroBoxView`, Phase A).
- **`Hero` has `originStory` + `powers` but NO `personality`.**
- **The companion figure is static** — only `EnergyRing` pulses (`CompanionView`). The full
  WorkState→sprite-atlas animation is the tracked fast-follow (art-pipeline plan, Phase 4).

## The reframe: a Forging Chamber between Forge and Reveal
Today's flow: `Forge → (instant) → Reveal burst → Companion`, art in background.
New flow: `Forge → **Forging Chamber (narrated progress)** → Reveal burst → Companion`.

The Chamber is the "this may take a while, you're here super hero" moment. Crucially it is
**honest**: the identity beats really do get composed (just fast — we pace them for delight,
clearly framed as *revealing what was forged*, not a fake loading bar), and then it sits on
the genuinely-long **art render** with real elapsed time. Because we now *wait* for the
render, the Reveal bursts out the **finished bespoke portrait** instead of procedural-then-swap
— a strictly better payoff.

### Never trap the user (the ~2-min honesty rule)
The art render can take a couple minutes or fail. The Chamber must never be a dead-end:
- **Default — "Reveal when ready":** the Chamber waits, then auto-plays the Reveal with the
  finished portrait.
- **Always available — "Send to shelf":** drop the hero to a sealed box *now* (exactly the
  current behavior); the render finishes in the background (existing serialized queue +
  "Forging portrait…" pill), and opening the box later plays the Reveal.
- **No harness / render fails / watchdog timeout:** the Chamber completes gracefully to the
  Reveal with the procedural look — no error dead-end. (This is already the fallback contract;
  the Chamber just surfaces it honestly: "Kept its built-in art — you can regenerate anytime.")

### Chamber stages (mapped to real work — honesty first)
| Stage copy (themed) | Real work behind it | Timing |
| --- | --- | --- |
| "Reading your signals…" | The consented sources feeding the forge seed (today: selection as seed input; **real local reads land with Phase F**, see Dependency) | paced ~0.6s each source |
| "Forging an identity…" | archetype + codename + title | instant, paced ~0.5s |
| "Writing the origin…" | 3-beat `originStory` | instant, paced ~0.6s |
| "Divining a personality…" | NEW `personality` (below) | instant, paced ~0.6s |
| "Naming the powers…" | `powers` | instant, paced ~0.5s |
| "Rendering the hero…" | **the real `codex exec` art render** | genuinely ~1–2 min; honest indeterminate spinner + elapsed + "running on your machine under your Codex login" |

The early stages are a themed checklist that ticks as each beat is revealed (they ARE done
instantly — we're unveiling, not faking). Only the final stage is a true wait, shown as an
honest indeterminate render with elapsed time. **We do not draw a fake determinate progress
bar for work that already finished.**

## New: hero `personality`
Add a first-class identity trait so each hero has origin + **personality** + powers.
- **Model:** `Hero.personality: String?` (optional for Codable back-compat, mirroring
  `artDirectionID`). A computed `personalityText` returns the stored value, or regenerates it
  deterministically for legacy heroes (see below).
- **Derivation (back-compat-safe):** personality is derived from a **fresh**
  `SeededRNG(seed: genome.seed &+ personalitySalt)` — an *independent* stream, NOT woven into
  the main forge RNG sequence. This (a) keeps existing `originStory`/`powers` determinism
  intact (adding personality doesn't shift the shared stream), and (b) lets any legacy hero
  regenerate a stable personality from `genome.seed` alone.
- **Content:** a short, characterful line composed from archetype-flavored trait pools —
  a temperament (e.g. "wry, unshakeable"), a tell/quirk, and how they carry themselves —
  seeded so a genome always yields the same personality. Kept to ~1–2 sentences.
- **Surfacing:** `HeroDossierView` (new "Personality" line beside Origin & Powers), the
  `ForgeView` preview, and the Chamber's "Divining a personality…" reveal.
- **Feeds the art prompt:** `HeroPromptBuilder` gains a personality clause (influences
  expression/pose/stance — e.g. "wry, unshakeable" → subtly confident posture), so the
  bespoke portrait reflects who they are. Content itself is never logged (privacy discipline).

## Companion animation (bottom-right) — "somewhat animated" now, full atlas as fast-follow
Two tiers, honest about what's shipping:
- **Now (MVP, cheap, no generated frames):** add subtle always-on motion to `HeroFigure` in
  `CompanionView` — a gentle vertical float + breathing scale whose period tracks `WorkState`
  (calm idle → livelier working/shipping), layered over the existing `EnergyRing`. Makes the
  corner feel alive immediately.
- **Fast-follow (already tracked):** the full WorkState→sprite-atlas animation (idle/thinking/
  working/shipping rows) from the art-pipeline plan Phase 4 — needs the 9-row generation and
  the Swift atlas runtime. Not in this task's MVP.

## Honesty guardrails (carry-over constraints)
- **No over-claiming the gather.** Source toggles are currently *flavor/seed inputs*, not deep
  local reads (known honesty gap). The "Reading your signals…" copy must match what we actually
  read. It upgrades to real substance only when the Phase F signal layer lands. (This also
  finally closes production honesty item #2 — the Forge "Signals" consent copy.)
- **No fake progress.** Instant stages are framed as *reveals*; the render is honest-indeterminate.
- **On-device only.** No new network calls; the render still delegates to the user's own harness.

## Dependency on Phase F (the unified signal layer)
"Pulling from what harnesses / what it's gathering" is the **same** local-signal surface Phase F
is mapping right now (the unified common-denominator layer across Codex / Claude Code / Cursor /
Ghostty / cmux / T3 Code). The forge-time **gather** and the live **WorkState** are two consumers
of one layer. This task can ship the themed Chamber, the escapable flow, `personality`, and the
companion motion **without** blocking on Phase F; the "Reading your signals…" stage gains real
substance (actual local reads → richer brief → better art prompt) when Phase F lands. Plan doc:
`documentation/planned/features/` (Phase F, pending its research agent).

## Tasks (MVP-first, each independently shippable)
- [x] **T1 — `personality` model + forge.** Add `Hero.personality: String?` + `personalityText`;
      `HeroForge.composePersonality(genome:archetype:)` on an independent `genome.seed`-keyed RNG;
      Codable back-compat; extend forge/genome tests + legacy-decode test.
- [x] **T2 — Surface personality.** Dossier line, ForgeView preview, prompt clause in
      `HeroPromptBuilder` (+ its tests).
- [x] **T3 — Forging Chamber view.** New themed progress view: staged checklist that ticks the
      identity beats, then honest indeterminate render (elapsed + on-device note), with
      "Send to shelf" always available and "Reveal when ready" as default. Reuses `HeroFigure`
      for a silhouette-coalescing preview.
- [x] **T4 — Wire the flow.** `ForgeView.forge()` → present Chamber (not instant dismiss);
      subscribe to `artGenerationStatus[hero.id]`; on `.ready`/`.failed`/timeout → play Reveal
      with the (now-finished or procedural) hero → Companion. "Send to shelf" short-circuits to
      today's sealed-box path. No-harness path completes to Reveal with procedural art.
- [x] **T5 — Companion motion (MVP).** Float/breathing on `HeroFigure` in `CompanionView`,
      period tracking `WorkState`. `--render`-verify.
- [x] **T6 — Verify.** `swift build` + `swift test` clean; `--render` the Chamber + companion;
      confirm the no-harness and fail/timeout paths reach the Reveal (no dead-ends).
- [ ] Move this doc to `active/` on approval; log per task.

## Out of scope (deliberately, MVP discipline)
- Full sprite-atlas WorkState animation (fast-follow; needs 9-row generation).
- Real deep local signal reads for the gather stage (arrives with Phase F).
- Parsing the codex run.log for sub-render milestones (stretch; MVP render stage is honest-indeterminate).
- Hero evolution (level/xp/story chapters) — separate tracked post-v1 item.

## Implementation Log

### 2026-07-18 — T1: personality model + forge
- **Changes**: `Hero.personality: String?` (optional → Codable back-compat like `artDirectionID`)
  + computed `personalityText` that regenerates from the genome for legacy heroes.
  `HeroForge.personality(for:)` composes on an INDEPENDENT `SeededRNG` keyed on
  `combine(genome.seed, hash(archetype.id), personalitySalt)` — so it's stable per hero,
  regenerable for old heroes, and does NOT shift the main forge stream (origins/powers
  byte-identical). Content pools (`PersonalityPool`: temperaments / quirks / bearings) added
  next to `NamePool`. Wired into `forge()`.
- **Tests**: +2 (25 total, all pass). `testForgePopulatesStablePersonality` (populated + stored ==
  regenerated), personality equality in the reproducibility test, and
  `testDecodesLegacyHeroWithoutPersonality` (strip the key → `personalityText` regenerates,
  equals `HeroForge.personality(for:)`).
- **Files**: `Model/Hero.swift`, `Forge/HeroForge.swift`, `Model/Archetype.swift`,
  `Tests/…/{HeroForge,HeroCodable}Tests.swift`.

### 2026-07-18 — T2: surface personality
- **Changes**: `HeroDossierView` new "PERSONALITY" section (italic, after ORIGIN); `ForgeView`
  preview shows the personality line under the title (updates on reroll); `HeroPromptBuilder`
  gained a `Bearing:` clause feeding `personalityText` into the portrait prompt ("read only in
  face and posture, never as text"). Content never logged.
- **Tests**: existing prompt tests green (hero literal updated with `personality:`); chroma-key
  branches unaffected.
- **Files**: `Shelf/HeroDossierView.swift`, `Forge/ForgeView.swift`, `Generation/HeroPromptBuilder.swift`.

### 2026-07-18 — T3–T6: Forging Chamber, wiring, companion motion, verify
- **T3 — Chamber (`Forge/ForgingChamberView.swift`, new)**: two-pane sheet-sized (640×500)
  surface. Left = the hero coalescing in a forge glow with name/title (revealed at beat 2) and
  personality (beat 4). Right = "Forging your hero / You're here, super hero. This can take a
  moment." + a 5-row identity checklist that ticks every ~0.56s (a genuine *reveal* of
  already-composed beats, not a fake bar) + a 6th **render row** that is honestly indeterminate:
  `.generating` → "Rendering the hero… / Runs on your machine · ~1–2 min · m:ss" (live elapsed).
  Auto-reveals (`maybeFinish`, fires once) only after the beats finish AND the render resolves.
  `initialRevealed` seam lets the static `--render` harness capture a mid-forge state.
- **T4 — wiring**: `ForgeView.forge()` no longer `dismiss()`es — it calls `onForged(hero)` and the
  parent transitions the *same* sheet. `ShelfView` gained `@State forgingHero`; the forge sheet
  now shows `ForgeView` until a hero is forged, then swaps to `ForgingChamberView`.
  `expectsRender` = `artGenerationStatus[hero.id] != nil` (harness engaged, set synchronously in
  `model.forge`). `onReveal` → dismiss sheet + `onOpen(hero)` (full-screen Reveal burst →
  companion). `onSendToShelf` → just dismiss (hero is already a sealed box; render continues in
  the background). No-harness / `.failed` paths complete to the Reveal — no dead-ends.
- **T5 — companion motion (`Companion/CompanionView.swift`)**: subtle always-on float + breathing
  scale (anchored at the feet) on the `HeroFigure`, period = `WorkState.pulsePeriod × 1.3` (calmer
  than the ring so they don't lockstep), restarted on `onAppear` and `onChange(workState)`. Cheap
  MVP; full sprite-atlas animation remains the tracked fast-follow.
- **T6 — verify**: `swift build` clean; `swift test` 25/25 pass. `--render` harness gained
  `chamber.png` (rendering), `chamber-builtin.png` (no harness → "Using its built-in art"), and
  `chamber-failed.png` (→ "Kept its built-in art — you can regenerate anytime"). All three
  visually confirmed; both fallback rows complete gracefully to the Reveal.
- **Files**: `Forge/ForgingChamberView.swift` (new), `Forge/ForgeView.swift`, `Shelf/ShelfView.swift`,
  `Companion/CompanionView.swift`, `Support/RenderHarness.swift`.
- **Decision taken**: default = **wait-and-auto-reveal** with **"Send to shelf"** always one click
  (per the recommendation below; not overridden).

## One decision to confirm
Default Chamber behavior while the art renders: **wait-and-auto-reveal** (recommended — matches
"you're here super hero, this may take a while") with **"Send to shelf"** always one click away.
Alternative: default to drop-to-shelf immediately with the Chamber as a peek. I recommend the
former; flag if you'd rather the latter.
