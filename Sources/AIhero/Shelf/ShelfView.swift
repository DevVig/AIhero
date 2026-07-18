import SwiftUI

/// Transient UI state for the shelf window (kept out of AppModel so it never
/// touches persistence).
@MainActor
final class ShelfUIState: ObservableObject {
    @Published var showingForge = false
}

/// "My Heroes" — the collectible display case and the app's primary window.
/// It's a shelf of figures, not a dashboard: forge new heroes, open sealed
/// boxes, and choose which hero stands on your desktop.
struct ShelfView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var ui: ShelfUIState
    var onOpen: (Hero) -> Void

    @State private var dossierHero: Hero?
    /// Set the moment a hero is forged; flips the forge sheet from the setup
    /// surface (`ForgeView`) to the narrated `ForgingChamberView`.
    @State private var forgingHero: Hero?

    private let columns = [GridItem(.adaptive(minimum: 190, maximum: 230), spacing: 18)]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hue: 0.62, saturation: 0.30, brightness: 0.16),
                                    Color(hue: 0.70, saturation: 0.35, brightness: 0.08)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.3)
                if model.heroes.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 22) {
                            forgeTile
                            ForEach(model.heroes) { hero in
                                HeroBoxView(
                                    hero: hero,
                                    isActive: hero.id == model.activeHeroID,
                                    artStatus: model.artGenerationStatus[hero.id],
                                    onOpen: { onOpen(hero) },
                                    onActivate: { model.setActive(hero.id) },
                                    onInspect: { dossierHero = hero },
                                    onRemove: { model.remove(hero.id) },
                                    onRetryArt: { model.retryArtGeneration(for: hero.id) }
                                )
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .sheet(item: $dossierHero) { hero in
                // Look up the live hero so level/XP and the "evolving…" state update
                // in real time while the dossier is open.
                let live = model.heroes.first(where: { $0.id == hero.id }) ?? hero
                HeroDossierView(
                    hero: live,
                    canEvolve: model.canEvolve(live),
                    xpToNext: model.xpForNextLevel(live.level),
                    artStatus: model.artGenerationStatus[live.id],
                    onEvolve: { model.evolve(live.id) })
            }
        }
        .frame(minWidth: 640, minHeight: 460)
        .sheet(isPresented: $ui.showingForge, onDismiss: { forgingHero = nil }) {
            if let hero = forgingHero {
                ForgingChamberView(
                    model: model,
                    hero: hero,
                    // A bespoke-art render was started iff the forge set a status
                    // (harness engaged). No status → built-in-art path.
                    expectsRender: model.artGenerationStatus[hero.id] != nil,
                    onReveal: {
                        ui.showingForge = false
                        // Play the full-screen Reveal burst → hand to the companion.
                        onOpen(hero)
                    },
                    onSendToShelf: {
                        // Drop to a sealed box now; its render continues in the
                        // background and opening the box later plays the Reveal.
                        ui.showingForge = false
                    })
            } else {
                ForgeView(model: model) { hero in
                    forgingHero = hero
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("My Heroes").font(.system(size: 22, weight: .bold))
                Text("\(model.heroes.count) forged · \(model.unboxedHeroes.count) opened")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                ui.showingForge = true
            } label: {
                Label("Forge a Hero", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
    }

    private var forgeTile: some View {
        Button {
            ui.showingForge = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "plus.viewfinder").font(.system(size: 34, weight: .light))
                Text("Forge a Hero").font(.system(size: 14, weight: .semibold))
                Text("Assemble a new one\nfrom your signals")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(.secondary.opacity(0.4)))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("Your shelf is empty").font(.system(size: 18, weight: .semibold))
            Text("Forge your first hero from the signals of the tools you already use.\nIt's assembled entirely on this device.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                ui.showingForge = true
            } label: {
                Label("Forge a Hero", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
