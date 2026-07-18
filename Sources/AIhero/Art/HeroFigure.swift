import SwiftUI
import AppKit

/// Resolves and caches a hero's **bespoke, harness-generated** art. Each hero's
/// art is a transparent PNG stored locally at
/// `Application Support/AIhero/art/<hero-id>.png` — produced at forge time by the
/// user's own image-capable harness (e.g. Codex `image_gen`), already cut to
/// alpha. Nothing here ever leaves the machine; if no art exists the app simply
/// falls back to the deterministic procedural `HeroPortrait`.
///
/// UI-only: touch from the main thread (SwiftUI `body`), as the views do.
enum HeroArtStore {
    private static var cache: [UUID: NSImage] = [:]
    /// Ids we've already looked up and found no art for — avoids re-hitting the
    /// filesystem every render for the (common, MVP) procedural-fallback case.
    private static var knownMissing: Set<UUID> = []

    /// `Application Support/AIhero/art`, created on demand. Sits alongside the
    /// roster's `state.json` so a hero and its art travel together.
    static func artDirectory() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser
        let dir = base.appendingPathComponent("AIhero/art", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func artURL(for id: UUID) -> URL {
        artDirectory().appendingPathComponent("\(id.uuidString).png")
    }

    /// The hero's bespoke image, or `nil` when none has been generated yet.
    static func image(for id: UUID) -> NSImage? {
        if let cached = cache[id] { return cached }
        if knownMissing.contains(id) { return nil }
        let url = artURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path),
              let image = NSImage(contentsOf: url) else {
            knownMissing.insert(id)
            return nil
        }
        cache[id] = image
        return image
    }

    /// Call after (re)generating a hero's art so the next render picks it up.
    static func invalidate(_ id: UUID) {
        cache[id] = nil
        knownMissing.remove(id)
    }

    /// Register an image for a hero id in-memory (QA/tests and, later, the moment
    /// generation finishes) without a filesystem round-trip.
    static func register(_ image: NSImage, for id: UUID) {
        cache[id] = image
        knownMissing.remove(id)
    }
}

/// The hero's on-screen figure: the bespoke generated art when it exists,
/// otherwise the procedural `HeroPortrait`. A drop-in replacement for
/// `HeroPortrait` at every *revealed* display site (companion, opened box,
/// dossier, reveal), so the whole app upgrades to real art the moment a hero is
/// generated — and degrades gracefully when it isn't.
struct HeroFigure: View {
    let hero: Hero
    /// Passed through to the procedural fallback; a bespoke transparent PNG is
    /// self-lit and needs no procedural aura.
    var aura: Bool = true

    var body: some View {
        if let art = HeroArtStore.image(for: hero.id) {
            Image(nsImage: art)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            HeroPortrait(hero: hero, aura: aura)
        }
    }
}
