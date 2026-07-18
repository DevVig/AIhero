import SwiftUI
import AppKit

/// Offscreen visual QA. Renders the real SwiftUI surfaces to PNGs with
/// `ImageRenderer` so we can inspect the procedural art and layouts without a
/// window server or screen-recording permission. Invoked via `AIhero --render`.
enum RenderHarness {
    @MainActor
    static func renderAll(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Distinct sample heroes: varied source mixes + salts exercise every
        // silhouette, palette family, and emblem.
        let mixes: [[Source]] = [
            [.codex, .claudeCode], [.cursor], [.cmux, .t3code],
            [.ghostty], [.claudeCode, .cursor, .codex], [.t3code],
            [.codex], [.cmux]
        ]
        let heroes = mixes.enumerated().map { index, sources in
            HeroForge.forge(name: nil, sources: sources, salt: UInt64(index + 7))
        }

        // 1. Portrait gallery — the core distinctness check.
        let gallery = HStack(spacing: 16) {
            ForEach(heroes) { hero in
                VStack(spacing: 6) {
                    HeroPortrait(hero: hero, aura: true).frame(width: 130, height: 170)
                    Text(hero.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    Text(hero.title).font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(28)
        .background(Color(hue: 0.66, saturation: 0.3, brightness: 0.10))
        write(gallery, size: CGSize(width: 8 * 162 + 28, height: 260), to: dir, "gallery.png")

        // 2. Companion at three scales, on a neutral desktop-like backdrop.
        let companionModel = AppModel(stateURL: tempURL("companion"))
        let companionHeroes = Array(heroes.prefix(3))
        // Register the Phase 0 bespoke-hero proof as hero #1's art so this render
        // exercises the real HeroFigure path (a generated transparent image)
        // right beside procedural fallbacks — one image, both code paths.
        if let first = companionHeroes.first {
            let proof = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("documentation/reference/phase0-proof/hero-cinematic.png")
            if let img = NSImage(contentsOf: proof) { HeroArtStore.register(img, for: first.id) }
        }
        let companionRow = HStack(spacing: 40) {
            ForEach(Array(companionHeroes.enumerated()), id: \.offset) { _, hero in
                CompanionPreview(hero: hero, state: .working)
            }
        }
        .padding(40)
        .background(LinearGradient(colors: [Color(white: 0.20), Color(white: 0.32)],
                                   startPoint: .top, endPoint: .bottom))
        write(companionRow, size: CGSize(width: 640, height: 300), to: dir, "companion.png")
        _ = companionModel

        // 3. Shelf with a mix of sealed and opened heroes.
        let shelfModel = AppModel(stateURL: tempURL("shelf"))
        for sources in mixes.prefix(5) {
            shelfModel.forge(name: nil, sources: sources)
        }
        if let first = shelfModel.heroes.first { shelfModel.unbox(first.id) }
        if shelfModel.heroes.count > 1 { shelfModel.unbox(shelfModel.heroes[1].id) }
        let shelf = ShelfView(model: shelfModel, ui: ShelfUIState(), onOpen: { _ in })
        write(shelf, size: CGSize(width: 800, height: 600), to: dir, "shelf.png")

        // 4. Forge sheet.
        let forgeModel = AppModel(stateURL: tempURL("forge"))
        let forge = ForgeView(model: forgeModel, onForged: { _ in })
        write(forge, size: CGSize(width: 640, height: 460), to: dir, "forge.png")

        // 5. Collectible boxes — the real HeroBoxView, sealed vs opened, rendered
        //    non-lazily so ImageRenderer materializes them (the shelf's ScrollView
        //    hides them offscreen, but the component itself renders faithfully).
        var boxHeroes = Array(heroes.prefix(4))
        boxHeroes[2].isUnboxed = true
        boxHeroes[3].isUnboxed = true
        // Exercise the art-generation badges too: box 0 mid-forge, box 1 failed.
        let boxStatuses: [ArtGenStatus?] = [.generating, .failed("timeout"), nil, nil]
        let boxes = HStack(spacing: 18) {
            ForEach(Array(boxHeroes.enumerated()), id: \.offset) { index, hero in
                HeroBoxView(hero: hero,
                            isActive: index == 3,
                            artStatus: boxStatuses[index],
                            onOpen: {}, onActivate: {}, onInspect: {}, onRemove: {})
                    .frame(width: 200)
            }
        }
        .padding(24)
        .background(LinearGradient(colors: [Color(hue: 0.62, saturation: 0.30, brightness: 0.16),
                                            Color(hue: 0.70, saturation: 0.35, brightness: 0.08)],
                                   startPoint: .top, endPoint: .bottom))
        write(boxes, size: CGSize(width: 4 * 218 + 24, height: 320), to: dir, "boxes.png")

        // 6. Hero dossier — the surfaced backstory, powers, and sources.
        if let dossierHero = heroes.first {
            write(HeroDossierView(hero: dossierHero), size: CGSize(width: 560, height: 760),
                  to: dir, "dossier.png")

            // 6b. Dossier with the EVOLUTION section in each state: not-yet-ready
            //     (XP progress), ready-to-Update, and mid-evolution (re-forging).
            var progressing = dossierHero; progressing.level = 2; progressing.xp = 24
            write(HeroDossierView(hero: progressing, canEvolve: false, xpToNext: 60,
                                  artStatus: nil, onEvolve: {}),
                  size: CGSize(width: 560, height: 820), to: dir, "dossier-progress.png")

            var ready = dossierHero; ready.level = 2; ready.xp = 65
            write(HeroDossierView(hero: ready, canEvolve: true, xpToNext: 60,
                                  artStatus: nil, onEvolve: {}),
                  size: CGSize(width: 560, height: 820), to: dir, "dossier-ready.png")

            var evolving = dossierHero; evolving.level = 3; evolving.xp = 5
            write(HeroDossierView(hero: evolving, canEvolve: false, xpToNext: 90,
                                  artStatus: .generating, onEvolve: {}),
                  size: CGSize(width: 560, height: 820), to: dir, "dossier-evolving.png")
        }

        // 7. Settings — the right-click options surface. Render the content
        //    directly (not through SettingsView's ScrollView, which ImageRenderer
        //    can't traverse). Native toggles/slider show as placeholders here but
        //    render for real in the running app.
        let settingsModel = AppModel(stateURL: tempURL("settings"))
        let settingsContent = SettingsContent(model: settingsModel,
                                              isClickThrough: { false },
                                              setClickThrough: { _ in },
                                              isLaunchAtLogin: { false },
                                              setLaunchAtLogin: { _ in nil })
            .frame(width: 460)
            .background(Color(nsColor: .windowBackgroundColor))
        write(settingsContent, size: CGSize(width: 460, height: 780), to: dir, "settings.png")

        // 8. Forging Chamber — the narrated progress surface, captured mid-forge
        //    (all identity beats revealed, bespoke art still rendering).
        //    `initialRevealed` forces the static state ImageRenderer can't reach
        //    via timers; a `.generating` status drives the render row's copy.
        let chamberModel = AppModel(stateURL: tempURL("chamber"))
        let chamberHero = HeroForge.forge(name: nil, sources: [.claudeCode, .codex], salt: 11)
        chamberModel.artGenerationStatus[chamberHero.id] = .generating
        let chamber = ForgingChamberView(model: chamberModel, hero: chamberHero,
                                         expectsRender: true,
                                         onReveal: {}, onSendToShelf: {},
                                         initialRevealed: 5)
        write(chamber, size: CGSize(width: 640, height: 500), to: dir, "chamber.png")

        // 8b. The two no-dead-end fallback render-rows: no image harness at all
        //     ("Using its built-in art") and a render that failed ("Kept its
        //     built-in art — you can regenerate anytime"). Both complete to the
        //     Reveal rather than trapping the user.
        let builtInHero = HeroForge.forge(name: nil, sources: [.ghostty], salt: 12)
        let builtIn = ForgingChamberView(model: AppModel(stateURL: tempURL("chamber-builtin")),
                                         hero: builtInHero, expectsRender: false,
                                         onReveal: {}, onSendToShelf: {}, initialRevealed: 5)
        write(builtIn, size: CGSize(width: 640, height: 500), to: dir, "chamber-builtin.png")

        let failedModel = AppModel(stateURL: tempURL("chamber-failed"))
        let failedHero = HeroForge.forge(name: nil, sources: [.cursor], salt: 13)
        failedModel.artGenerationStatus[failedHero.id] = .failed("harness timed out")
        let failed = ForgingChamberView(model: failedModel, hero: failedHero,
                                        expectsRender: true,
                                        onReveal: {}, onSendToShelf: {}, initialRevealed: 5)
        write(failed, size: CGSize(width: 640, height: 500), to: dir, "chamber-failed.png")

        FileHandle.standardError.write(Data("✓ rendered surfaces to \(dir.path)\n".utf8))
    }

    // MARK: - Helpers

    @MainActor
    private static func write(_ view: some View, size: CGSize, to dir: URL, _ name: String) {
        let renderer = ImageRenderer(content:
            view.frame(width: size.width, height: size.height).fixedSize())
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("✗ failed to render \(name)\n".utf8))
            return
        }
        try? data.write(to: dir.appendingPathComponent(name))
    }

    private static func tempURL(_ tag: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("aihero-render-\(tag).json")
    }
}

/// A companion figure rendered on its own (the live `CompanionView` depends on
/// an active-hero model; this shows the same composition statically).
private struct CompanionPreview: View {
    let hero: Hero
    let state: WorkState
    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [state.tint.opacity(0.45), .clear],
                                     center: .center, startRadius: 0, endRadius: 60))
                .frame(width: 120, height: 40)
                .offset(y: 70)
            HeroFigure(hero: hero, aura: true).frame(height: 150)
        }
        .frame(width: 160, height: 200)
    }
}
