# Task: AIhero — Native macOS Collectible Companion (MVP v0.1)
**Date Started**: 2026-07-17
**Status**: Completed (MVP core loop shipped; see production-hardening + activity-signals for later phases)
**Agent Lead**: 💻 Frontend / ⚙️ Backend

## Plan
### Objective
Build the approved AIhero product: a tiny, delightful macOS **collectible superhero companion**.
Core loop: **forge a hero (locally) → sealed figure lands on the "My Heroes" shelf → open the box
(unboxing cinematic) → hero bursts out and settles bottom-right as a transparent, draggable,
scalable desktop companion → switch heroes from the shelf.** IDE/harness activity tracking lives
only in the menu bar. Everything is on-device.

### Approach (stack decision)
- **Native macOS, Swift 6 (SwiftUI + AppKit), built as a Swift Package** (`swift build`, opens in
  Xcode too). Chosen over Electron (footprint — the reason Electron was rejected in design) and over
  a Rust core (not installed; unnecessary complexity for MVP). A Rust core stays a *future*
  extraction point via C FFI if cross-platform becomes real.
- Menu-bar **accessory app** (`NSApp.setActivationPolicy(.accessory)`) — no Dock icon, no Info.plist
  needed to run from a SwiftPM build.
- Hero art is **100% procedural / deterministic** from a genome seed (no baked art, no image model),
  so every hero is unique and the app stays microscopic.

## Architecture (Sources/AIhero/)
- `App/` — `main.swift` (entry + `--render` QA hook), `AppDelegate`, `WindowManager` (top-level
  coordinator wiring every surface), `MenuBarController` (status item + live-rebuilt menu, activity
  tracker, glyph tinted by work state).
- `Model/` — `Source` (consented signal connectors), `Archetype` (identity lenses + name pools),
  `Hero`/`HeroGenome`, `WorkState`, `AppModel` (`ObservableObject` source of truth + JSON persistence
  to `~/Library/Application Support/AIhero/state.json`; supports an override URL for tests/render).
- `Forge/` — `HeroForge` (deterministic on-device generation: seed→archetype→codename→origin→powers),
  `ForgeView` (tiny setup sheet: name + signal toggles + live preview + reroll).
- `Art/` — `Palette` (color identity from seed), `HeroPortrait` (modular figure: per-silhouette body,
  cape, hood, emblem, visor/eyes, aura).
- `Companion/` — `CompanionPanel` (borderless transparent floating `NSPanel`), `CompanionHostingView`
  (drag-to-move / click-to-open-mission-menu), `CompanionView` (hero + work-state energy ring +
  landing burst), `CompanionController` (lifecycle, bottom-right landing, scaling, mission menu,
  click-through toggle).
- `Shelf/` — `ShelfView` ("My Heroes" case), `HeroBoxView` (sealed collectible box ↔ opened pedestal
  figure), `ShelfWindowController`.
- `Reveal/` — `RevealView` + `RevealController` (full-screen transparent click-through unboxing:
  box drops → lid bursts → hero flies to bottom-right → hands off to companion).
- `Support/` — `SeededRNG` (SplitMix64 + FNV-1a), `RenderHarness` (offscreen `ImageRenderer` visual QA).

## Tasks
- [x] Model + deterministic Forge (RNG, genome, archetypes, roster, persistence, work state)
- [x] Procedural hero art (palette + modular portrait, 5 silhouettes)
- [x] Transparent desktop companion (draggable, scalable, energy ring, mission menu, click-through)
- [x] My Heroes shelf + Forge sheet (sealed/opened boxes, forge with live preview + privacy note)
- [x] Unboxing reveal + menu-bar wiring
- [x] Build, package `.app`, run, visual QA

## How to run
```
Scripts/make_app.sh release      # builds dist/AIhero.app
open dist/AIhero.app             # menu-bar ⚡ appears; first run opens the shelf
.build/debug/AIhero --render /tmp/aihero-shots   # offscreen visual QA → PNGs
```

## Implementation Log
### 2026-07-17 — MVP core loop complete
- **Built** the full collectible loop end-to-end in native Swift; compiles clean, `.app` launches as a
  menu-bar accessory, full runtime init (menu bar + companion + work timer + state load) with no crash.
- **Visual QA** via offscreen `ImageRenderer` (`--render`): `gallery.png` (8 distinct heroes),
  `companion.png`, `forge.png`, `boxes.png` (sealed vs opened) all render correctly and match the
  approved look. `shelf.png` and standard controls show `ImageRenderer` placeholders (it can't draw
  `ScrollView`/`LazyVGrid` or AppKit-backed `TextField`/`.bordered` buttons offscreen) — a harness
  limitation only; those render normally in the live app.
- **Key decisions/trade-offs**: procedural genome art (unique + tiny, no assets); work-state activity
  is clearly *simulated* until real harness connectors land; click-through toggle lives in the menu
  bar (not on the hero) so it can never trap the user.

### 2026-07-17 — Art depth + backstory pass (user feedback: "heroes look like trash, one-dimensional, no backstory")
- **Dimensional portrait rewrite** (`Art/HeroPortrait.swift`, `Art/Palette.swift`): single fixed key
  light (upper-left) drives every layer. Torso now has base color + edge occlusion (multiply) + chest
  core light (screen) + costume yoke seam + two-tone rim light (glow on the lit contour, accent on the
  far edge). Added shoulder pauldrons (lit/shadowed pair), a raised metal emblem plate with an embossed
  symbol, helmet with radial top-light + jaw occlusion + rim crescent, glossy visor with a reflection
  highlight, hot-core glowing eyes, optional helmet crest, cape with a cast-shadow layer + centre fold,
  and a ground contact shadow. `Palette` gained `highlight` + `shadowTone` for consistent shading.
  Stays fully procedural/deterministic and transparent-background-safe (companion unchanged).
- **Backstory now surfaced**: `Archetype` gained `nemesis` + `creed`; `HeroForge.composeOrigin` rewritten
  into a 3-beat origin (origin moment → forging signals/traits → nemesis + signature power + creed).
  New `Shelf/HeroDossierView.swift` shows portrait, identity, LEVEL/XP/SIGNALS, the origin story, power
  chips, "forged from" source chips, and the creed. Reachable from any unboxed hero (context menu
  "View Dossier", hover "Dossier" button, or tap the figure). Forge preview now shows name/title + an
  origin-story teaser under the live portrait.
- **Verified** via `--render`: `gallery.png` (8 heroes now read as dimensional figurines), `boxes.png`
  (sealed teasers + opened pedestals), `dossier.png` (full backstory), `forge.png` (story teaser).
  Fixed a real clip bug the render caught — the dossier now sizes to content instead of a fixed height.
  `.app`/debug binary launches and initializes without crashing.
- **Files added**: `Shelf/HeroDossierView.swift`. **Modified**: `HeroPortrait.swift`, `Palette.swift`,
  `Archetype.swift`, `HeroForge.swift`, `HeroBoxView.swift`, `ShelfView.swift`, `ForgeView.swift`,
  `Support/RenderHarness.swift`.

## Notes for Next Engineer
- **Shipped after this MVP note:** read-only ambient activity + earned evolution ("Update"),
  bespoke Codex art pipeline, production hardening, open-source repo front door. See
  `documentation/completed/` and `documentation/reference/HANDOFF.md`.
- **Still future scope:** per-pixel companion hit-testing; "Jump to active app" routing;
  full Hatch-style atlas animation (planned art pipeline).
- Verification used `--render` offscreen PNGs + live launches; screenshots live in
  `documentation/reference/screenshots/`.
