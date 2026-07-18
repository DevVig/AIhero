import SwiftUI

/// One slot on the shelf. A sealed hero shows as a collectible figure box with
/// a plastic window and a foil nameplate; an opened hero stands on a pedestal
/// and can be made the active desktop companion.
struct HeroBoxView: View {
    let hero: Hero
    let isActive: Bool
    /// Bespoke-portrait progress for this hero (nil = procedural only, nothing to show).
    var artStatus: ArtGenStatus? = nil
    var onOpen: () -> Void
    var onActivate: () -> Void
    var onInspect: () -> Void
    var onRemove: () -> Void
    var onRetryArt: () -> Void = {}

    @State private var hovering = false

    private var palette: Palette { Palette(seed: hero.genome.paletteSeed) }

    var body: some View {
        Group {
            if hero.isUnboxed { openedFigure } else { sealedBox }
        }
        .overlay(alignment: .top) { artStatusBadge }
        .onHover { hovering = $0 }
        .contextMenu {
            if hero.isUnboxed {
                Button("View Dossier", action: onInspect)
                Button("Set as Companion", action: onActivate)
            } else {
                Button("Open Box", action: onOpen)
            }
            // Always available (even after a relaunch, when transient status is
            // gone) so a procedural-only hero can get a bespoke portrait made.
            Button("Regenerate Portrait", action: onRetryArt)
            Divider()
            Button("Release Hero", role: .destructive, action: onRemove)
        }
    }

    // MARK: - Art generation badge

    /// A small pill over the top of the box while the hero's bespoke portrait is
    /// being forged, or a tap-to-retry chip if it failed. Silent once ready.
    @ViewBuilder private var artStatusBadge: some View {
        switch artStatus {
        case .generating:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Forging portrait…").font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 8)
            .transition(.opacity)
        case .failed:
            Button(action: onRetryArt) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                    Text("Portrait failed · Retry").font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Bespoke-art generation failed. Tap to try again.")
            .padding(.top, 8)
            .transition(.opacity)
        case .ready, .none:
            EmptyView()
        }
    }

    // MARK: - Sealed

    private var sealedBox: some View {
        VStack(spacing: 0) {
            ZStack {
                // Box shell
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [palette.deep, .black.opacity(0.9)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.accent.opacity(0.5), lineWidth: 1)

                // Plastic window with teaser figure
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.35))
                    .padding(14)
                HeroPortrait(hero: hero, aura: false)
                    .frame(height: 150)
                    .opacity(0.9)
                    .blur(radius: 0.4)
                    .padding(.top, 8)
                // Glossy sheen over the plastic
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [.white.opacity(0.16), .clear, .white.opacity(0.05)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(14)
                    .allowsHitTesting(false)

                // Sealed seal
                Image(systemName: "seal.fill")
                    .foregroundStyle(palette.accent)
                    .font(.system(size: 22))
                    .overlay(Image(systemName: hero.genome.emblem)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(20)

                // Open affordance on hover
                if hovering {
                    Button(action: onOpen) {
                        Label("Open", systemImage: "shippingbox.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 14)
                    .transition(.opacity)
                }
            }
            .frame(height: 220)

            // Foil nameplate
            nameplate(sealed: true)
        }
        .scaleEffect(hovering ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    // MARK: - Opened

    private var openedFigure: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(RadialGradient(colors: [palette.deep.opacity(0.55), .black.opacity(0.85)],
                                         center: .center, startRadius: 4, endRadius: 180))
                if isActive {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(palette.glow.opacity(0.9), lineWidth: 2)
                        .shadow(color: palette.glow.opacity(0.6), radius: 8)
                }

                HeroFigure(hero: hero, aura: true)
                    .frame(height: 168)
                    .padding(.top, 6)

                // Pedestal
                Ellipse()
                    .fill(LinearGradient(colors: [palette.accent.opacity(0.35), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 130, height: 26)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 14)

                if isActive {
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(palette.glow.opacity(0.9), in: Capsule())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(12)
                }

                if hovering {
                    HStack(spacing: 8) {
                        if !isActive {
                            Button(action: onActivate) {
                                Label("Set Active", systemImage: "bolt.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        Button(action: onInspect) {
                            Label("Dossier", systemImage: "doc.text.image")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 12)
                    .transition(.opacity)
                }
            }
            .frame(height: 220)
            .contentShape(Rectangle())
            .onTapGesture(perform: onInspect)

            nameplate(sealed: false)
        }
        .scaleEffect(hovering ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    private func nameplate(sealed: Bool) -> some View {
        VStack(spacing: 2) {
            Text(hero.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
            Text(hero.title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(palette.accent)
                .tracking(1.5)
            HStack(spacing: 4) {
                Text("LV \(hero.level)")
                if sealed {
                    Text("· SEALED").foregroundStyle(palette.accent)
                }
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.25))
    }
}
