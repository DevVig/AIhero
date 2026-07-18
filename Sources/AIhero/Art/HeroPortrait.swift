import SwiftUI

/// Per-silhouette proportions and costume flags. Kept in one place so a hero's
/// body reads consistently whether it's rendered at 300pt in the reveal or 90pt
/// on the desktop.
private struct SilhouetteSpec {
    var shoulderHalfW: CGFloat
    var neckHalfW: CGFloat
    var shoulderY: CGFloat
    var neckY: CGFloat
    var headR: CGFloat          // relative to height
    var headCY: CGFloat
    var capeSpread: CGFloat     // 0 = no cape
    var hooded: Bool
    var fadeBottom: Bool
    var eyeCount: Int
    var pauldronScale: CGFloat  // 0 = no shoulder armor
    var crest: Bool             // helmet crest fin

    static func spec(for s: Silhouette) -> SilhouetteSpec {
        switch s {
        case .sentinel:
            return .init(shoulderHalfW: 0.42, neckHalfW: 0.10, shoulderY: 0.60, neckY: 0.42,
                         headR: 0.165, headCY: 0.27, capeSpread: 0.10, hooded: false,
                         fadeBottom: false, eyeCount: 2, pauldronScale: 1.15, crest: true)
        case .vanguard:
            return .init(shoulderHalfW: 0.31, neckHalfW: 0.085, shoulderY: 0.58, neckY: 0.40,
                         headR: 0.150, headCY: 0.25, capeSpread: 0.34, hooded: false,
                         fadeBottom: false, eyeCount: 2, pauldronScale: 0.85, crest: false)
        case .oracle:
            return .init(shoulderHalfW: 0.33, neckHalfW: 0.09, shoulderY: 0.60, neckY: 0.42,
                         headR: 0.165, headCY: 0.28, capeSpread: 0.16, hooded: true,
                         fadeBottom: false, eyeCount: 2, pauldronScale: 0.0, crest: false)
        case .artificer:
            return .init(shoulderHalfW: 0.38, neckHalfW: 0.10, shoulderY: 0.62, neckY: 0.44,
                         headR: 0.155, headCY: 0.28, capeSpread: 0.0, hooded: false,
                         fadeBottom: false, eyeCount: 3, pauldronScale: 1.0, crest: true)
        case .phantom:
            return .init(shoulderHalfW: 0.27, neckHalfW: 0.075, shoulderY: 0.56, neckY: 0.40,
                         headR: 0.145, headCY: 0.25, capeSpread: 0.26, hooded: false,
                         fadeBottom: true, eyeCount: 1, pauldronScale: 0.6, crest: false)
        }
    }
}

// MARK: - Shapes

private struct BodyShape: Shape {
    let spec: SilhouetteSpec
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        let hw = spec.shoulderHalfW, nh = spec.neckHalfW
        let sy = spec.shoulderY, ny = spec.neckY
        var path = Path()
        path.move(to: pt(0.5 - hw, 1.0))
        // Trapezius sweep up to the neck.
        path.addQuadCurve(to: pt(0.5 - hw, sy), control: pt(0.5 - hw - 0.012, (sy + 1.0) / 2))
        path.addQuadCurve(to: pt(0.5 - nh, ny), control: pt(0.5 - hw * 0.70, ny + 0.015))
        path.addLine(to: pt(0.5 + nh, ny))
        path.addQuadCurve(to: pt(0.5 + hw, sy), control: pt(0.5 + hw * 0.70, ny + 0.015))
        path.addQuadCurve(to: pt(0.5 + hw, 1.0), control: pt(0.5 + hw + 0.012, (sy + 1.0) / 2))
        path.closeSubpath()
        return path
    }
}

private struct CapeShape: Shape {
    let spec: SilhouetteSpec
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        let hw = spec.shoulderHalfW, spread = spec.capeSpread
        let sy = spec.shoulderY - 0.02
        var path = Path()
        path.move(to: pt(0.5 - hw * 0.8, sy))
        path.addQuadCurve(to: pt(0.5 - (hw + spread), 1.04), control: pt(0.5 - (hw + spread) * 0.85, 0.80))
        path.addQuadCurve(to: pt(0.5, 1.08), control: pt(0.5 - hw * 0.5, 1.07))
        path.addQuadCurve(to: pt(0.5 + (hw + spread), 1.04), control: pt(0.5 + hw * 0.5, 1.07))
        path.addQuadCurve(to: pt(0.5 + hw * 0.8, sy), control: pt(0.5 + (hw + spread) * 0.85, 0.80))
        path.closeSubpath()
        return path
    }
}

/// A soft V-fold down the centre of the cape — the single line that most sells
/// the cape as cloth with depth rather than a flat sheet.
private struct CapeFold: Shape {
    let spec: SilhouetteSpec
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        var path = Path()
        path.move(to: pt(0.5, spec.shoulderY))
        path.addQuadCurve(to: pt(0.5, 1.06), control: pt(0.52, 0.82))
        return path
    }
}

private struct HoodShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w, y: rect.minY + h * 0.7),
                          control: CGPoint(x: rect.minX + w * 1.02, y: rect.minY + h * 0.12))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h),
                          control: CGPoint(x: rect.minX + w * 0.82, y: rect.minY + h))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.7),
                          control: CGPoint(x: rect.minX + w * 0.18, y: rect.minY + h))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY),
                          control: CGPoint(x: rect.minX - w * 0.02, y: rect.minY + h * 0.12))
        path.closeSubpath()
        return path
    }
}

// MARK: - Portrait

/// A fully procedural, deterministic hero figure assembled from its genome.
///
/// Everything is lit from a single fixed source in the upper-left. Each layer —
/// torso, pauldrons, emblem plate, helmet, cape — carries its own highlight and
/// shadow consistent with that light, which is what gives the figure volume
/// instead of reading as a flat silhouette. The whole thing stays on a
/// transparent background so it drops straight onto the desktop as a companion.
struct HeroPortrait: View {
    let hero: Hero
    var aura: Bool = true

    /// Fixed key light, upper-left. Shared by every radial gradient so shading
    /// stays coherent across layers.
    private let lightPoint = UnitPoint(x: 0.30, y: 0.20)

    private var palette: Palette { Palette(seed: hero.genome.paletteSeed) }
    private var spec: SilhouetteSpec { SilhouetteSpec.spec(for: hero.genome.silhouette) }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let s = spec
            let p = palette

            ZStack {
                if aura {
                    // Rim glow behind the figure and a contact shadow beneath it,
                    // both transparent-safe so the companion still floats clean.
                    Circle()
                        .fill(RadialGradient(colors: [p.glow.opacity(0.30), p.glow.opacity(0.06), .clear],
                                             center: .center, startRadius: 0,
                                             endRadius: size.width * 0.6))
                        .frame(width: size.width * 1.25, height: size.width * 1.25)
                        .position(x: size.width * 0.5, y: size.height * 0.46)
                        .blur(radius: size.width * 0.03)

                    Ellipse()
                        .fill(RadialGradient(colors: [.black.opacity(0.38), .clear],
                                             center: .center, startRadius: 0,
                                             endRadius: size.width * 0.32))
                        .frame(width: size.width * 0.62, height: size.height * 0.07)
                        .position(x: size.width * 0.5, y: size.height * 0.975)
                }

                figure(size: size, p: p, s: s)
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.35), radius: size.height * 0.02,
                            x: size.height * 0.012, y: size.height * 0.016)
                    .mask(s.fadeBottom
                          ? AnyView(LinearGradient(stops: [.init(color: .white, location: 0.0),
                                                           .init(color: .white, location: 0.74),
                                                           .init(color: .white.opacity(0.12), location: 1.0)],
                                                   startPoint: .top, endPoint: .bottom))
                          : AnyView(Color.white))
            }
        }
        .aspectRatio(0.80, contentMode: .fit)
    }

    // MARK: - Figure assembly

    private func figure(size: CGSize, p: Palette, s: SilhouetteSpec) -> some View {
        ZStack {
            if s.capeSpread > 0 { cape(size: size, p: p, s: s) }
            torso(size: size, p: p, s: s)
            if s.pauldronScale > 0 { pauldrons(size: size, p: p, s: s) }
            emblemPlate(size: size, p: p, s: s)
            head(size: size, p: p, s: s)
        }
    }

    // MARK: - Cape

    private func cape(size: CGSize, p: Palette, s: SilhouetteSpec) -> some View {
        ZStack {
            // Cast layer, dropped down-right, reads as the cape's own shadow.
            CapeShape(spec: s)
                .fill(p.shadowTone.opacity(0.9))
                .offset(x: size.width * 0.02, y: size.height * 0.012)
                .blur(radius: size.width * 0.01)
            CapeShape(spec: s)
                .fill(LinearGradient(colors: [p.secondary, p.deep, p.shadowTone],
                                     startPoint: .top, endPoint: .bottom))
            // Lit left half.
            CapeShape(spec: s)
                .fill(LinearGradient(colors: [p.highlight.opacity(0.5), .clear],
                                     startPoint: .topLeading, endPoint: .init(x: 0.55, y: 0.6)))
                .blendMode(.screen)
            CapeFold(spec: s)
                .stroke(p.shadowTone.opacity(0.8), lineWidth: max(1, size.height * 0.012))
                .blur(radius: size.width * 0.004)
        }
    }

    // MARK: - Torso

    private func torso(size: CGSize, p: Palette, s: SilhouetteSpec) -> some View {
        ZStack {
            // 1. Base local color, top-lit.
            BodyShape(spec: s)
                .fill(LinearGradient(colors: [p.primary, p.deep], startPoint: .top, endPoint: .bottom))
            // 2. Edge occlusion: darken both flanks (right harder — away from light).
            BodyShape(spec: s)
                .fill(LinearGradient(stops: [.init(color: p.shadowTone.opacity(0.42), location: 0.0),
                                             .init(color: .clear, location: 0.42),
                                             .init(color: p.shadowTone.opacity(0.78), location: 1.0)],
                                     startPoint: .leading, endPoint: .trailing))
                .blendMode(.multiply)
            // 3. Chest core light from the key light.
            BodyShape(spec: s)
                .fill(RadialGradient(colors: [p.highlight.opacity(0.85), p.highlight.opacity(0.1), .clear],
                                     center: UnitPoint(x: 0.42, y: 0.66),
                                     startRadius: 0, endRadius: size.width * 0.5))
                .blendMode(.screen)
            // 4. Costume seams: a chest yoke line under the collar.
            yoke(size: size, s: s)
                .stroke(p.shadowTone.opacity(0.7), lineWidth: max(1, size.height * 0.01))
            yoke(size: size, s: s)
                .stroke(p.highlight.opacity(0.5), lineWidth: max(0.5, size.height * 0.004))
                .offset(y: -max(0.5, size.height * 0.004))
            // 5. Rim light: bright glow on the light contour, cool accent on the far edge.
            BodyShape(spec: s)
                .stroke(LinearGradient(colors: [p.glow.opacity(0.95), .clear, p.accent.opacity(0.55)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: max(1, size.height * 0.012))
        }
    }

    private func yoke(size: CGSize, s: SilhouetteSpec) -> Path {
        Path { path in
            let w = size.width, h = size.height
            let hw = s.shoulderHalfW * 0.82
            let y = (s.shoulderY + 0.06) * h
            path.move(to: CGPoint(x: (0.5 - hw) * w, y: y))
            path.addQuadCurve(to: CGPoint(x: 0.5 * w, y: y + h * 0.06),
                              control: CGPoint(x: (0.5 - hw * 0.4) * w, y: y + h * 0.02))
            path.addQuadCurve(to: CGPoint(x: (0.5 + hw) * w, y: y),
                              control: CGPoint(x: (0.5 + hw * 0.4) * w, y: y + h * 0.02))
        }
    }

    // MARK: - Pauldrons (shoulder armor)

    private func pauldrons(size: CGSize, p: Palette, s: SilhouetteSpec) -> some View {
        let w = size.width, h = size.height
        let sw = w * 0.17 * s.pauldronScale
        let sh = h * 0.11 * s.pauldronScale
        let y = s.shoulderY * h - sh * 0.28
        let dx = s.shoulderHalfW * 0.94 * w
        return ZStack {
            pauldron(p: p, lit: true).frame(width: sw, height: sh)
                .position(x: 0.5 * w - dx, y: y)
            pauldron(p: p, lit: false).frame(width: sw, height: sh)
                .position(x: 0.5 * w + dx, y: y)
        }
    }

    private func pauldron(p: Palette, lit: Bool) -> some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: lit
                                     ? [p.highlight, p.accent, p.deep]
                                     : [p.accent.opacity(0.9), p.deep, p.shadowTone],
                                     center: lightPoint, startRadius: 0, endRadius: 40))
            Ellipse()
                .stroke(p.shadowTone.opacity(0.8), lineWidth: 1)
            Ellipse()
                .fill(p.glow.opacity(lit ? 0.7 : 0.25))
                .scaleEffect(0.5)
                .offset(x: -3, y: -4)
                .blur(radius: 3)
                .blendMode(.screen)
        }
    }

    // MARK: - Chest emblem plate

    private func emblemPlate(size: CGSize, p: Palette, s: SilhouetteSpec) -> some View {
        let plate = size.height * 0.20
        let cx = size.width * 0.5
        let cy = size.height * 0.75
        return ZStack {
            // Raised metal disc.
            Circle()
                .fill(RadialGradient(colors: [p.highlight, p.accent, p.deep],
                                     center: lightPoint, startRadius: 0, endRadius: plate * 0.7))
                .frame(width: plate, height: plate)
            Circle()
                .stroke(p.shadowTone.opacity(0.85), lineWidth: max(1, size.height * 0.006))
                .frame(width: plate, height: plate)
            Circle()
                .stroke(p.glow.opacity(0.6), lineWidth: max(0.5, size.height * 0.003))
                .frame(width: plate * 0.98, height: plate * 0.98)
                .offset(x: -1, y: -1)
                .blendMode(.screen)
            // Embossed emblem: dark drop then bright face.
            Image(systemName: hero.genome.emblem)
                .resizable().scaledToFit()
                .frame(width: plate * 0.56, height: plate * 0.56)
                .foregroundStyle(p.shadowTone)
                .offset(x: size.height * 0.004, y: size.height * 0.005)
            Image(systemName: hero.genome.emblem)
                .resizable().scaledToFit()
                .frame(width: plate * 0.56, height: plate * 0.56)
                .foregroundStyle(LinearGradient(colors: [.white.opacity(0.95), p.glow],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: p.glow.opacity(0.8), radius: size.height * 0.015)
        }
        .position(x: cx, y: cy)
    }

    // MARK: - Head

    private func head(size: CGSize, p: Palette, s: SilhouetteSpec) -> some View {
        let cx = size.width * 0.5
        let cy = size.height * s.headCY
        let r = size.height * s.headR

        return ZStack {
            if s.crest {
                // A thin dorsal crest for a more helmeted read.
                Capsule()
                    .fill(LinearGradient(colors: [p.accent, p.deep], startPoint: .top, endPoint: .bottom))
                    .frame(width: r * 0.34, height: r * 1.3)
                    .position(x: cx, y: cy - r * 0.85)
            }

            if s.hooded {
                HoodShape()
                    .fill(LinearGradient(colors: [p.secondary, p.deep, p.shadowTone],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: r * 3.1, height: r * 3.4)
                    .position(x: cx, y: cy + r * 0.15)
                HoodShape()
                    .stroke(p.glow.opacity(0.5), lineWidth: max(1, size.height * 0.008))
                    .frame(width: r * 3.1, height: r * 3.4)
                    .position(x: cx, y: cy + r * 0.15)
                // Shadowed recess where the face sits.
                Ellipse()
                    .fill(RadialGradient(colors: [p.shadowTone, .black.opacity(0.92)],
                                         center: .center, startRadius: 0, endRadius: r * 1.1))
                    .frame(width: r * 1.7, height: r * 1.95)
                    .position(x: cx, y: cy + r * 0.12)
            } else {
                // Helmet: top-lit sphere.
                Circle()
                    .fill(RadialGradient(colors: [p.highlight, p.primary, p.deep, p.shadowTone],
                                         center: lightPoint, startRadius: 0, endRadius: r * 1.7))
                    .frame(width: r * 2, height: r * 2)
                    .position(x: cx, y: cy)
                // Jaw/underside occlusion.
                Ellipse()
                    .fill(RadialGradient(colors: [p.shadowTone.opacity(0.7), .clear],
                                         center: .center, startRadius: 0, endRadius: r * 0.9))
                    .frame(width: r * 1.7, height: r * 1.1)
                    .position(x: cx, y: cy + r * 0.7)
                    .blendMode(.multiply)
                // Rim light crescent on the light side.
                Circle()
                    .stroke(LinearGradient(colors: [p.glow.opacity(0.95), .clear],
                                           startPoint: .topLeading, endPoint: .init(x: 0.6, y: 0.7)),
                            lineWidth: max(1, size.height * 0.011))
                    .frame(width: r * 2, height: r * 2)
                    .position(x: cx, y: cy)
            }
            face(cx: cx, cy: s.hooded ? cy + r * 0.12 : cy + r * 0.02, r: r, p: p, s: s, size: size)
        }
    }

    private func face(cx: CGFloat, cy: CGFloat, r: CGFloat, p: Palette, s: SilhouetteSpec, size: CGSize) -> some View {
        let eyeY = cy - r * 0.02
        let eyeDim = r * 0.36
        let spacing = r * 0.54
        let offsets: [CGFloat]
        switch s.eyeCount {
        case 1: offsets = [0]
        case 3: offsets = [-spacing, 0, spacing]
        default: offsets = [-spacing * 0.62, spacing * 0.62]
        }
        return ZStack {
            // Glossy visor: dark base with a bright top reflection.
            Capsule()
                .fill(LinearGradient(colors: [.black.opacity(0.55), p.deep.opacity(0.5)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: r * 1.62, height: r * 0.66)
                .position(x: cx, y: eyeY)
            Capsule()
                .fill(LinearGradient(colors: [.white.opacity(0.4), .clear],
                                     startPoint: .top, endPoint: .center))
                .frame(width: r * 1.5, height: r * 0.3)
                .position(x: cx, y: eyeY - r * 0.14)
                .blendMode(.screen)
            Capsule()
                .stroke(p.accent.opacity(0.5), lineWidth: max(0.5, size.height * 0.003))
                .frame(width: r * 1.62, height: r * 0.66)
                .position(x: cx, y: eyeY)
            // Eyes: hot core + halo.
            ForEach(Array(offsets.enumerated()), id: \.offset) { _, dx in
                ZStack {
                    Capsule().fill(p.glow)
                        .shadow(color: p.glow, radius: r * 0.16)
                    Capsule().fill(.white.opacity(0.9)).scaleEffect(0.5)
                }
                .frame(width: eyeDim * 0.7, height: eyeDim)
                .position(x: cx + dx, y: eyeY)
            }
        }
    }
}
