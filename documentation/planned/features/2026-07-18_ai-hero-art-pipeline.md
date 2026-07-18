# Task: Bespoke per-user hero generation via the user's own harness (Hatch-style)
**Date Started**: 2026-07-18
**Status**: Planning (awaiting approval)
**Agent Lead**: 🏗️ Architect / ⚙️ Backend / 🎨 Designer
**Supersedes** the earlier "authoring-time bundled art pack" draft of this same file.

## The correction that reset this plan
An earlier draft had me **bundling pre-made hero art** (the 3 MagicPath figures) keyed by
archetype×direction. That was backwards. The user's actual product:

> 1. Someone says "I want to create a superhero."
> 2. They click a button; it pulls what their installed harnesses know about them (locally).
> 3. It generates the hero **using their selected harness**.
> 4. It personifies — art + backstory — for **them**.
> 5. A one-of-one hero. **Not pre-made / pre-established.**

And, on how to build the generator: **"do it however the Hatch skill does it now."**

⇒ Generation is **runtime, per-user, via the user's own logged-in harness** — never a shipped pack.
The three MagicPath figures (`documentation/reference/hero-style-refs/`) are the **style/quality bar**
fed into the prompt, not assets we ship. Procedural `HeroPortrait` is demoted to a **fallback**.

## Capability detection is RUNTIME + PER-USER (not baked from the dev machine)
The dev machine (Jon's) is **only one sample** — Jon is **not** the end user. Each end user has their
own installed harnesses and their own auth state, so the app must **detect capabilities at runtime, on
the user's machine**, and degrade defensively. For every candidate harness, probe three things
*separately*:
1. **Installed?** (binary on PATH)
2. **Authed/usable right now?** (installed ≠ working — e.g. on the dev machine Gemini is installed but
   its login is auth-blocked; that's a state to handle gracefully, never a crash)
3. **Image-capable?** (can emit a saved image at all)

Route on the result: image-capable + healthy → generate art; text-only + healthy (Claude/Cursor) →
backstory only; none healthy → procedural fallback (still name/story via any working text harness).
Never hardcode a winner from the dev box. Phase 0 proves each *integration contract* is sound; it does
not pick the harness for all users.

## Generation-capability matrix (mechanism, sampled on the dev machine 2026-07-18)
Installed here: `codex exec`, `claude -p`, `cursor-agent`, `gemini -p`. Dev-machine auth state:
Codex healthy; **Gemini auth-blocked** (`IneligibleTierError`, unsupported free-tier client — a
per-machine state, NOT a product limitation).

| Job | Harnesses that can do it (key-free, user's own login) |
| --- | --- |
| **Text** — identity, origin, powers, and the *art prompt* | Codex, Claude, Cursor, Gemini — **any** |
| **Image** — the actual hero art | **Codex** (`$imagegen` built-in path via `codex login`) and **Gemini** (native image models via the user's Google login). Claude Code & Cursor: **cannot generate images from the CLI.** |

This is the hard constraint: the *story* is fully harness-agnostic; the *art* needs an image-capable
harness (Codex/Gemini) or falls back to procedural. AIhero ships **no API key** and calls **no AIhero
server** — it delegates to tools the user already runs under their own auth.

## How Hatch does it (what we mirror)
Hatch (`~/.claude/skills/hatch-pet`) takes a **concept/brief** (+ optional references, + an optional
lightweight **discovery worker** that builds a compact brief), then runs, all through `$imagegen`:
`base "main look"` → 9 state row-strips → deterministic extract/compose into an **8×9 atlas**
(192×208 cells, 1536×1872 `spritesheet.webp`) → validate transparency → QA contact sheet → package
`pet.json` + `spritesheet.webp`. Deterministic Python owns geometry; the model owns pixels.

**AIhero mapping:** the "pull their data" step (2) = a Hatch-style **discovery worker that assembles a
compact hero brief** from the person's *selected* harness signals — the analog of Hatch's brand
discovery. The art-direction selection (ink-comic / cinematic-3D / chibi-toy, per the 3 references, +
`auto`) maps onto Hatch's style presets and reference images. The rest is Hatch's pipeline verbatim,
**but invoked at forge time through the user's harness.**

## WorkState → animation-row mapping (companion animation; unchanged, already designed)
| WorkState | Atlas row | Reads as |
| --- | --- | --- |
| `idle` | 0 `idle` | calm breathing/blink |
| `thinking` | 8 `review` | focused, inspecting |
| `working` | 7 `running` | active task work |
| `shipping` | 4 `jumping` | celebratory beat |
Remaining rows generated for the full contract + near-future (`waving` greet, `running-right/left`
walk-to-app, `waiting` needs-consent, `failed` error).

## MVP discipline: base look first, animation as fast-follow
A full atlas is ~10 image jobs — heavy at forge time (cost + minutes, per user). So:
- **MVP target = Hatch's `base` step only:** one bespoke, style-locked hero image per forge, via the
  user's harness → transparent cutout → the desktop companion + reveal + shelf. One generation, seconds.
- **Fast-follow = full animated atlas** (the remaining 9 rows) once the base loop is proven and the
  Swift atlas runtime exists.

## Architecture
1. **Forge** — art-direction selection + source/brief selection + optional name.
2. **Brief** — Hatch-style discovery assembles a compact hero brief from selected signals (local only).
3. **Generate** — AIhero shells out to the chosen (image-capable) harness (`codex exec` / `gemini -p`)
   to run the **hero-forge skill** (hatch-pet adapted for heroes): base look (MVP), later full atlas.
4. **Swift runtime** — forge triggers the subprocess, shows Hatch-style progress
   ("Imagining… Picturing poses… Hatching…"), loads the result; companion shows the bespoke figure
   (animated by WorkState once the atlas exists; still image for MVP).
5. **Fallback** — no image-capable harness logged in, or generation fails ⇒ procedural `HeroPortrait`
   (still generate the text identity via any harness).

## Phase 0 — RESULT (2026-07-18): PASSED via Codex ✅
Ran the gate on the dev machine. Outcome:
- **Codex `codex exec` + built-in `image_gen`: full contract proven.** Key-free (no `OPENAI_API_KEY`,
  runs under the user's Codex login), headless (`-s danger-full-access`, stdin closed via `< /dev/null`
  — first attempt hung on stdin), emits a saved PNG at an arbitrary path. Two artifacts (preserved in
  `documentation/reference/phase0-proof/`): a 256×256 glowing-circle sanity image, and **one bespoke
  full-body hero** ("The Sentinel of Merged Mains", cinematic-3D, matte-charcoal armor + cyan seams +
  cape + a *git-merge-glyph chest emblem* driven purely by the prompt) at **MagicPath quality**,
  clearly original. ~50k tokens / ~2 min each.
- **Transparent cutout is a solved, bundled step.** Codex ships
  `$CODEX_HOME/skills/.system/imagegen/scripts/remove_chroma_key.py` (`--auto-key border --soft-matte
  --despill`). Generate the hero on a flat `#00ff00` chroma background → run the helper → clean alpha
  (hero: ~58% transparent, only ~3.6k soft-edge px, transparent corners). Because *we* own the
  background at generation time, even a **dark** figure cuts cleanly — this kills the old dark-on-dark
  matte failure (the Orchestrator cutout problem).
- **Gemini: FAILED on the dev machine — auth-blocked** (`IneligibleTierError`, unsupported free-tier
  client). A per-machine state, not a product limitation; its integration contract still needs
  validation wherever a healthy Gemini exists.
⇒ The bespoke-per-user-via-the-user's-own-harness architecture is real. Codex is a proven image path;
build the Codex integration first, keep Gemini as a second detected path, procedural as fallback.

## Phasing (MVP-first)
- **Phase 0 — Generation spike (GATE; needs the user's harness auth).** Prove headless, key-free image
  generation: `codex exec` via `$imagegen`, and `gemini -p` native image, each emitting a saved PNG.
  Then run hatch-pet once end-to-end via `codex exec` to produce one hero base look. If neither path
  emits a file cleanly, the runtime-generation product needs rethinking — so this gates everything.
- **Phase 1 — Swift atlas/figure runtime (no harness needed).** `HeroAtlas` + `SpriteAnimator` +
  `AtlasHeroView`, WorkState→row, companion/shelf consume it; built & `--render`-verified against a
  placeholder made from the procedural figure. Also: a `HeroFigure` view that prefers a bespoke image
  and falls back to procedural. Biggest unblocked chunk.
- **Phase 2 — Hero-forge skill.** Adapt hatch-pet for heroes: hero states, style-locked prompt from
  (brief × art-direction), transparent companion cutout, `hero.json` + `spritesheet.webp` (MVP: base
  look only). Reuse Hatch's deterministic scripts.
- **Phase 3 — Forge orchestration in Swift.** Capability detection of installed/logged-in harnesses;
  subprocess invocation with Hatch-style progress; load result; procedural fallback; art-direction picker.
- **Phase 4 — Discovery/brief worker + full atlas + polish.** Real signal→brief assembly; the
  remaining 9 animation rows; QA rubric.

## Dependencies & risks
- **Phase 0 is the crux.** Uncertain whether `gemini -p` writes a generated image *to a file* headless
  (no image extension installed by default); Codex `$imagegen` under `codex exec` may need sandbox/network
  config. Resolve empirically before building on it.
- **Cost/latency at forge time** is real (per-user generation). MVP base-look keeps it to one job.
- **Consistency** across the eventual 9 rows relies on Hatch's identity-lock discipline.
- **Privacy:** signals stay local except as the prompt to the user's own model; no shipped key; no AIhero server.

## Tasks
- [x] Phase 0: PASSED via Codex — key-free headless PNG + bundled chroma-key alpha + one MagicPath-quality bespoke hero (proof in `documentation/reference/phase0-proof/`). Gemini auth-blocked on dev machine.
- [x] Phase 1 (MVP still-image seam): `HeroArtStore` + `HeroFigure` (bespoke transparent PNG → procedural `HeroPortrait` fallback), swapped into companion/opened-box/dossier/reveal (sealed teaser stays procedural). `--render` verified: companion.png shows the Phase 0 bespoke hero beside procedural fallbacks. Art lives at `Application Support/AIhero/art/<id>.png`. **Deferred to animation fast-follow:** `HeroAtlas`/`SpriteAnimator`/`AtlasHeroView` (full 9-row WorkState animation).
- [x] Phase 3 (end-to-end forge, MVP): Swift now forges → probes for an image harness → shells out to
  generate the bespoke hero and drops it at `art/<id>.png`, which `HeroFigure` picks up. Pieces:
  `HarnessProbe` (runtime PATH probe; Codex only until Gemini's headless contract is validated),
  `ArtDirection` (auto/cinematic/inkComic/chibiToy style clauses), `HeroPromptBuilder` (genome →
  style-locked transparent-cutout prompt following the imagegen workflow), `HeroArtGenerator` (async
  `Process` running `codex exec -s danger-full-access` with stdin closed, PATH augmented, 300s watchdog,
  success = exit 0 **and** file present). Wiring: `Hero.artDirectionID` (optional, back-compat),
  `HeroForge.forge(…, artDirection:)`, `AppModel.forge(…, artDirection:harness:)` + `ArtGenStatus` +
  background `startArtGeneration`, `ForgeView` portrait section (style picker; harness note when one,
  picker when >1; "no harness → built-in art"), and a `--forge-test` headless hook. Builds clean
  (Swift 6-warning-free). **Live end-to-end validation:** _in progress_ (one real `codex exec` run).
- [ ] Phase 2 (deferred behind MVP): reusable hero-forge skill (hatch-pet adapted; transparent cutout)
- [ ] Phase 4: discovery/brief worker; full 9-row atlas; QA
- [ ] Move this doc to `active/` on approval; log per-phase
