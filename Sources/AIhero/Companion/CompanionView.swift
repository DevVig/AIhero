import SwiftUI

/// A soft energy ring at the hero's feet whose color and pulse rate encode the
/// current work state. This is the only always-on activity signal on the
/// desktop; anything more detailed lives in the menu bar.
private struct EnergyRing: View {
    let state: WorkState
    @State private var pulse = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [state.tint.opacity(0.45), .clear],
                                     center: .center, startRadius: 0, endRadius: 60))
                .scaleEffect(pulse ? 1.0 : 0.82)
            Ellipse()
                .stroke(state.tint.opacity(0.7), lineWidth: 2)
                .scaleEffect(pulse ? 1.0 : 0.7)
                .opacity(pulse ? 0.1 : 0.7)
        }
        .onAppear { animate() }
        .onChange(of: state) { _, _ in animate() }
    }

    private func animate() {
        pulse = false
        withAnimation(.easeInOut(duration: state.pulsePeriod).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

/// The sparkle burst played when a hero first lands on the desktop after being
/// unboxed — the tail end of the "bursts out of the box" moment.
private struct BurstView: View {
    @State private var progress: CGFloat = 0
    let tint: Color

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                let angle = Double(i) / 10.0 * 2 * .pi
                Capsule()
                    .fill(tint)
                    .frame(width: 3, height: 14)
                    .offset(y: -40 * progress)
                    .rotationEffect(.radians(angle))
                    .opacity(Double(1 - progress))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { progress = 1 }
        }
    }
}

/// The desktop companion: hero + energy ring + landing burst. No name, no card,
/// no chrome — per the design, the visible surface is only the superhero.
struct CompanionView: View {
    @ObservedObject var model: AppModel
    @State private var landed = false
    @State private var showBurst = false
    /// Gentle always-on "alive" motion — a float + breathing scale layered over
    /// the ring. Its period tracks WorkState, so the corner is calmer when idle
    /// and livelier while working/shipping. (The full sprite-atlas animation is
    /// the tracked fast-follow; this is the cheap, no-generated-frames MVP.)
    @State private var breathing = false

    var body: some View {
        Group {
            if let hero = model.activeHero {
                ZStack {
                    EnergyRing(state: model.workState)
                        .frame(height: 40)
                        .offset(y: heroHeight * 0.44)

                    HeroFigure(hero: hero, aura: true)
                        .frame(height: heroHeight)
                        // Breathe from the feet so the figure rises off the ring
                        // rather than scaling about its center.
                        .scaleEffect(breathing ? 1.015 : 0.99, anchor: .bottom)
                        .offset(y: breathing ? -3 : 2)

                    if showBurst {
                        BurstView(tint: Palette(seed: hero.genome.paletteSeed).glow)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(landed ? 1.0 : 0.25)
                .opacity(landed ? 1.0 : 0.0)
                .onAppear { playEntrance() }
                .onChange(of: model.workState) { _, _ in startBreathing() }
                .id(hero.id)   // replay the entrance when the active hero changes
            }
        }
    }

    private var heroHeight: CGFloat { model.companionHeight }

    private func playEntrance() {
        landed = false
        showBurst = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
            landed = true
        }
        showBurst = true
        // Retire the burst after it finishes so it doesn't linger.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            showBurst = false
        }
        startBreathing()
    }

    /// (Re)start the breathing loop at the current WorkState's cadence. A slightly
    /// slower period than the ring keeps the two from marching in lockstep.
    private func startBreathing() {
        breathing = false
        withAnimation(.easeInOut(duration: model.workState.pulsePeriod * 1.3)
            .repeatForever(autoreverses: true)) {
            breathing = true
        }
    }
}
