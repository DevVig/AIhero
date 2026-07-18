import SwiftUI

/// The Forging Chamber — the themed "you're here, super hero; this may take a
/// moment" surface shown right after you hit Forge. It narrates the identity
/// beats that were just composed (fast, revealed as a ticking checklist while the
/// hero coalesces on the left) and then sits on the genuinely-long bespoke-art
/// render with honest elapsed time.
///
/// It never traps you: **Send to shelf** is always one click (the hero is already
/// a sealed box and its render keeps running in the background), and the
/// no-harness / failed / timeout paths all complete gracefully to the reveal with
/// the built-in illustrated art. On a finished render it auto-plays the reveal so
/// the hero bursts out already wearing its bespoke portrait.
struct ForgingChamberView: View {
    @ObservedObject var model: AppModel
    let hero: Hero
    /// Whether a bespoke-art render was started (an image harness was engaged).
    /// When false the chamber shows the built-in-art path and goes straight to
    /// the reveal after the identity beats.
    let expectsRender: Bool
    var onReveal: () -> Void
    var onSendToShelf: () -> Void
    /// Forced starting reveal count so the offscreen QA harness (`--render`), which
    /// renders statically, can capture a representative mid-forge state.
    var initialRevealed: Int

    @State private var revealed: Int
    @State private var elapsed: Int = 0
    @State private var glow = false
    @State private var handedOff = false

    init(model: AppModel, hero: Hero, expectsRender: Bool,
         onReveal: @escaping () -> Void, onSendToShelf: @escaping () -> Void,
         initialRevealed: Int = 1) {
        self.model = model
        self.hero = hero
        self.expectsRender = expectsRender
        self.onReveal = onReveal
        self.onSendToShelf = onSendToShelf
        self.initialRevealed = initialRevealed
        _revealed = State(initialValue: initialRevealed)
    }

    private var palette: Palette { Palette(seed: hero.genome.paletteSeed) }
    private var status: ArtGenStatus? { model.artGenerationStatus[hero.id] }

    /// The instant, deterministic identity beats — each is really composed, just
    /// fast, so we reveal them for delight rather than fake a loading bar.
    private let identityStages: [(label: String, icon: String)] = [
        ("Reading your signals", "antenna.radiowaves.left.and.right"),
        ("Forging an identity", "figure.stand"),
        ("Writing the origin", "book.closed"),
        ("Divining a personality", "theatermasks"),
        ("Naming the powers", "bolt.fill"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            forgePanel
            Divider()
            progressPanel
        }
        .frame(width: 640, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { startLive() }
        .onChange(of: revealed) { _, _ in maybeFinish() }
        .onChange(of: status) { _, _ in maybeFinish() }
    }

    // MARK: - Left: the hero coalescing in the forge

    private var forgePanel: some View {
        ZStack {
            LinearGradient(colors: [palette.deep.opacity(0.65), .black.opacity(0.92)],
                           startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(RadialGradient(colors: [palette.glow.opacity(glow ? 0.5 : 0.18), .clear],
                                     center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 300, height: 300)
                .offset(y: -16)
            VStack(spacing: 12) {
                HeroFigure(hero: hero, aura: true)
                    .frame(height: 210)
                VStack(spacing: 4) {
                    Text(hero.name)
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .opacity(revealed >= 2 ? 1 : 0)
                    Text(hero.title.uppercased())
                        .font(.system(size: 9, weight: .semibold)).tracking(1.5)
                        .foregroundStyle(palette.accent)
                        .opacity(revealed >= 2 ? 1 : 0)
                    Text(hero.personalityText)
                        .font(.system(size: 10).italic())
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16).padding(.top, 2)
                        .opacity(revealed >= 4 ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.4), value: revealed)
            }
            .padding(.vertical, 20)
        }
        .frame(width: 280)
        .clipped()
    }

    // MARK: - Right: narrated progress

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Forging your hero").font(.system(size: 20, weight: .bold))
                Text("You're here, super hero. This can take a moment.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(.bottom, 2)

            ForEach(Array(identityStages.enumerated()), id: \.offset) { index, stage in
                stageRow(index: index, label: stage.label, icon: stage.icon)
            }
            renderRow

            Spacer()

            HStack {
                Button(handedOff ? "Revealing…" : "Send to shelf") { onSendToShelf() }
                    .disabled(handedOff)
                Spacer()
                if handedOff {
                    Text("Meet \(hero.name)…")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private func stageRow(index: Int, label: String, icon: String) -> some View {
        let done = index < revealed
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(done ? palette.accent.opacity(0.9) : Color.white.opacity(0.08))
                    .frame(width: 26, height: 26)
                Image(systemName: done ? "checkmark" : icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(done ? .white : .secondary)
            }
            Text(label)
                .font(.system(size: 13, weight: done ? .semibold : .regular))
                .foregroundStyle(done ? .primary : .secondary)
            Spacer(minLength: 0)
        }
        .opacity(index <= revealed ? 1 : 0.4)
    }

    private var renderRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(renderColor).frame(width: 26, height: 26)
                Image(systemName: renderIcon)
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(renderTitle).font(.system(size: 13, weight: .semibold))
                if let sub = renderSubtitle {
                    Text(sub).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .opacity(revealed >= identityStages.count ? 1 : 0.4)
    }

    // MARK: - Render-stage copy (honest about each path)

    private var renderColor: Color {
        if !expectsRender { return palette.accent }
        switch status {
        case .ready:  return palette.accent
        case .failed: return .orange
        default:      return palette.glow
        }
    }

    private var renderIcon: String {
        if !expectsRender { return "checkmark" }
        switch status {
        case .ready:  return "checkmark"
        case .failed: return "paintpalette"
        default:      return "paintbrush.pointed.fill"
        }
    }

    private var renderTitle: String {
        if !expectsRender { return "Using its built-in art" }
        switch status {
        case .ready:  return "Portrait ready"
        case .failed: return "Kept its built-in art"
        default:      return "Rendering the hero…"
        }
    }

    private var renderSubtitle: String? {
        if !expectsRender { return "Illustrated on-device — no harness needed." }
        switch status {
        case .ready:  return nil
        case .failed: return "You can regenerate anytime from the shelf."
        default:      return "Runs on your machine · ~1–2 min · \(elapsedString)"
        }
    }

    private var elapsedString: String {
        String(format: "%d:%02d", elapsed / 60, elapsed % 60)
    }

    // MARK: - Lifecycle / hand-off

    /// True once there's nothing left to wait on: no render was started, or the
    /// render resolved (ready or failed → fall back to built-in art).
    private var renderResolved: Bool {
        if !expectsRender { return true }
        switch status {
        case .ready, .failed: return true
        default:              return false
        }
    }

    private func startLive() {
        guard !handedOff else { return }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { glow = true }
        Task { @MainActor in
            while revealed < identityStages.count {
                try? await Task.sleep(nanoseconds: 560_000_000)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { revealed += 1 }
            }
            maybeFinish()
            // Tick honest elapsed time while the real render runs.
            while expectsRender && status == .generating && !handedOff {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                elapsed += 1
            }
        }
    }

    /// Hand off to the reveal once the identity beats have played AND the render
    /// has resolved (or there was none). Fires exactly once.
    private func maybeFinish() {
        guard !handedOff, revealed >= identityStages.count, renderResolved else { return }
        handedOff = true
        // A short beat so the final checkmark / "ready" lands before the burst.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onReveal() }
    }
}
