import SwiftUI

/// A hero's color identity, derived deterministically from its palette seed.
/// Assembling color locally (rather than shipping baked art or calling an image
/// model) is what lets every hero look unique while the app stays tiny.
struct Palette {
    let baseHue: Double        // 0...1
    let primary: Color
    let secondary: Color
    let accent: Color
    let glow: Color
    let deep: Color
    let highlight: Color       // lit-surface tint (top-left light)
    let shadowTone: Color      // deep occluded tone (bottom-right)

    init(seed: UInt64) {
        let hue = Double(seed % 3600) / 3600.0
        self.baseHue = hue
        let analog = (hue + 0.083).truncatingRemainder(dividingBy: 1.0)   // +30°
        let comp = (hue + 0.5).truncatingRemainder(dividingBy: 1.0)       // +180°
        let accentHue = (hue + 0.14).truncatingRemainder(dividingBy: 1.0) // +50°

        self.primary = Color(hue: hue, saturation: 0.68, brightness: 0.92)
        self.secondary = Color(hue: analog, saturation: 0.58, brightness: 0.80)
        self.accent = Color(hue: accentHue, saturation: 0.80, brightness: 0.98)
        self.glow = Color(hue: comp, saturation: 0.72, brightness: 1.0)
        self.deep = Color(hue: hue, saturation: 0.74, brightness: 0.42)
        // Form shading: a bright, desaturated tint for surfaces facing the light
        // and a near-black saturated tone for the occluded side. Consistent use
        // of these two across every layer is what gives the figure volume.
        self.highlight = Color(hue: hue, saturation: 0.30, brightness: 1.0)
        self.shadowTone = Color(hue: hue, saturation: 0.90, brightness: 0.16)
    }
}

/// Maps a palette seed to a human color word, used in origin-story text.
enum PaletteDescriptor {
    private static let names: [(range: ClosedRange<Double>, word: String)] = [
        (0.00...0.04, "crimson"), (0.04...0.09, "ember"), (0.09...0.14, "amber"),
        (0.14...0.19, "gold"), (0.19...0.38, "verdant green"), (0.38...0.50, "teal"),
        (0.50...0.60, "cobalt"), (0.60...0.72, "indigo"), (0.72...0.82, "violet"),
        (0.82...0.92, "magenta"), (0.92...1.00, "rose")
    ]

    static func name(forSeed seed: UInt64) -> String {
        name(forHue: Double(seed % 3600) / 3600.0)
    }

    static func name(forHue rawHue: Double) -> String {
        let hue = rawHue.truncatingRemainder(dividingBy: 1.0)
        let wrapped = hue < 0 ? hue + 1.0 : hue
        return names.first { $0.range.contains(wrapped) }?.word ?? "spectral"
    }
}
