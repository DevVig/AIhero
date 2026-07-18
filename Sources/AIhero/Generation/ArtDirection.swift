import Foundation

/// A forge-time art-direction choice. This is the user-facing "make the style
/// switchable" idea: the same hero genome renders in a different illustrated
/// style depending on the direction, by swapping a style clause into the
/// generation prompt. The three named directions mirror the MagicPath quality
/// references; `auto` lets the genome pick one deterministically.
enum ArtDirection: String, Codable, CaseIterable, Identifiable {
    case auto
    case cinematic   // cinematic semi-realistic 3D (the Orchestrator reference)
    case inkComic    // comic / graphic-novel ink (the Debugger reference)
    case chibiToy    // chibi cel-shaded toy mascot (the Patchwork reference)

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:      return "Auto"
        case .cinematic: return "Cinematic 3D"
        case .inkComic:  return "Ink Comic"
        case .chibiToy:  return "Chibi Toy"
        }
    }

    /// The style clause spliced into the generation prompt.
    var styleClause: String {
        switch self {
        case .auto:
            return ""   // resolved to a concrete direction before prompting
        case .cinematic:
            return "Style: cinematic semi-realistic 3D character render, dramatic rim lighting, "
                 + "sculpted armor, high polish — premium animated-film key-art / collectible-figure quality."
        case .inkComic:
            return "Style: bold comic / graphic-novel ink illustration, confident clean linework, "
                 + "cel shading, subtle halftone texture, vivid saturated flat colors, heroic and iconic."
        case .chibiToy:
            return "Style: adorable chibi cel-shaded toy mascot — oversized head, small rounded body, "
                 + "glossy vinyl-figure finish, soft shapes, cute collectible-toy charm, thick clean outlines."
        }
    }

    /// Resolve `auto` to a concrete direction, chosen deterministically from the
    /// genome seed so a hero's style is stable across relaunches.
    func resolved(seed: UInt64) -> ArtDirection {
        guard self == .auto else { return self }
        let concrete: [ArtDirection] = [.cinematic, .inkComic, .chibiToy]
        return concrete[Int(seed % UInt64(concrete.count))]
    }
}
