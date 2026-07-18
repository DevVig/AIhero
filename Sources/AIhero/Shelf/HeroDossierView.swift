import SwiftUI

/// The hero's dossier: the home for everything the forge already writes but the
/// shelf never showed — the origin story, powers, the signals that forged them,
/// and their creed. Opened from an unboxed hero on the shelf.
struct HeroDossierView: View {
    let hero: Hero
    /// Evolution wiring, injected by the presenter from the live model. Defaults keep
    /// the dossier a pure, self-contained view for offscreen QA (which has no model).
    var canEvolve: Bool = false
    var xpToNext: Int? = nil
    var artStatus: ArtGenStatus? = nil
    var onEvolve: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    private var palette: Palette { Palette(seed: hero.genome.paletteSeed) }
    private var archetype: Archetype { hero.archetype }

    /// The portrait is mid-evolution when a re-forge is generating for this hero.
    private var isEvolving: Bool { artStatus == .generating }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading
            Divider().overlay(palette.accent.opacity(0.3))
            if onEvolve != nil { section("EVOLUTION") { evolutionRow } }
            section("ORIGIN") {
                Text(hero.originStory)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            section("PERSONALITY") {
                Text(hero.personalityText)
                    .font(.system(size: 13).italic())
                    .foregroundStyle(.white.opacity(0.82))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            section("POWERS") { powerGrid }
            section("FORGED FROM") { sourceRow }
            creed
            Spacer(minLength: 4)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(background)
    }

    // MARK: - Heading (portrait + identity)

    private var heading: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(RadialGradient(colors: [palette.deep.opacity(0.7), .black.opacity(0.9)],
                                         center: .center, startRadius: 4, endRadius: 150))
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.glow.opacity(0.5), lineWidth: 1)
                HeroFigure(hero: hero, aura: true)
                    .frame(height: 190)
                Ellipse()
                    .fill(LinearGradient(colors: [palette.accent.opacity(0.4), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 120, height: 22)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 12)
            }
            .frame(width: 190, height: 210)

            VStack(alignment: .leading, spacing: 6) {
                Text(hero.name)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.7)
                Text(hero.title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(palette.accent)
                Text(archetype.tagline)
                    .font(.system(size: 13).italic())
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                HStack(spacing: 10) {
                    statPill("LEVEL", "\(hero.level)")
                    statPill("XP", "\(hero.xp)")
                    if hero.contributingSources.isEmpty {
                        statPill("FORGE", "Solo")
                    } else {
                        statPill("SIGNALS", "\(hero.contributingSources.count)")
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func statPill(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 8, weight: .semibold)).tracking(1)
                .foregroundStyle(.white.opacity(0.45))
            Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
    }

    // MARK: - Evolution

    private var evolutionRow: some View {
        let target = xpToNext ?? 0
        let progress = target > 0 ? min(1, Double(hero.xp) / Double(target)) : 0
        return VStack(alignment: .leading, spacing: 10) {
            // Manual progress bar (GeometryReader renders in the offscreen QA harness
            // where a native ProgressView bar would not).
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [palette.accent, palette.glow],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * (canEvolve ? 1 : progress)))
                }
            }
            .frame(height: 8)

            HStack(spacing: 12) {
                if isEvolving {
                    Text("Evolving… re-forging the portrait on your Mac (~1–2 min).")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
                    Spacer(minLength: 0)
                } else if canEvolve {
                    Text("Ready to evolve to Level \(hero.level + 1).")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                    Spacer(minLength: 0)
                    Button { onEvolve?() } label: {
                        Label("Update", systemImage: "arrow.up.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)
                } else {
                    Text("Keep working to evolve — \(hero.xp) / \(target) XP toward Level \(hero.level + 1).")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Sections

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(palette.accent.opacity(0.9))
            content()
        }
    }

    private var powerGrid: some View {
        // Manual two-column rows so the layout renders in the offscreen QA
        // harness (LazyVGrid does not).
        let rows = stride(from: 0, to: hero.powers.count, by: 2).map {
            Array(hero.powers[$0..<min($0 + 2, hero.powers.count)])
        }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { powerChip($0) }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func powerChip(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(palette.accent)
            Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 11).padding(.vertical, 6)
        .background(palette.accent.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(palette.accent.opacity(0.4), lineWidth: 1))
    }

    private var sourceRow: some View {
        HStack(spacing: 8) {
            if hero.contributingSources.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "keyboard").font(.system(size: 10))
                    Text("Your own quiet hours").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Color.white.opacity(0.06), in: Capsule())
            } else {
                ForEach(hero.contributingSources) { source in
                    HStack(spacing: 6) {
                        Image(systemName: source.symbol).font(.system(size: 10))
                        Text(source.displayName).font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var creed: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.opening").font(.system(size: 12)).foregroundStyle(palette.accent.opacity(0.7))
            Text(archetype.creed)
                .font(.system(size: 14, weight: .semibold).italic())
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.top, 2)
    }

    private var background: some View {
        LinearGradient(colors: [Color(hue: palette.baseHue, saturation: 0.35, brightness: 0.14),
                                Color.black.opacity(0.96)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
        .overlay(
            RadialGradient(colors: [palette.glow.opacity(0.10), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 420)
        )
        .ignoresSafeArea()
    }
}
