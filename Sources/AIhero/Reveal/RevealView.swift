import SwiftUI

/// The unboxing cinematic: a collectible box drops in, the lid bursts, the hero
/// rises and then flies to the bottom-right where the desktop companion takes
/// over. Runs on a transparent full-screen overlay, so it reads as the hero
/// literally bursting out onto the desktop.
struct RevealView: View {
    let hero: Hero
    var onFinished: () -> Void

    @State private var boxScale: CGFloat = 0.1
    @State private var boxOpacity: Double = 0
    @State private var lidOffset: CGFloat = 0
    @State private var lidOpacity: Double = 1
    @State private var flash: CGFloat = 0
    @State private var heroScale: CGFloat = 0.05
    @State private var heroOpacity: Double = 0
    @State private var heroOffset: CGSize = .zero
    @State private var sparkle: CGFloat = 0

    private var palette: Palette { Palette(seed: hero.genome.paletteSeed) }

    var body: some View {
        GeometryReader { geo in
            let target = CGSize(width: geo.size.width / 2 - 96,
                                height: geo.size.height / 2 - 96)
            ZStack {
                // Flash burst
                Circle()
                    .fill(RadialGradient(colors: [palette.glow.opacity(0.9), .clear],
                                         center: .center, startRadius: 0, endRadius: 260))
                    .frame(width: 520, height: 520)
                    .scaleEffect(flash)
                    .opacity(Double(flash))

                // Sparkle ring
                ForEach(0..<14, id: \.self) { i in
                    let angle = Double(i) / 14.0 * 2 * .pi
                    Capsule()
                        .fill(palette.accent)
                        .frame(width: 4, height: 20)
                        .offset(y: -120 * sparkle)
                        .rotationEffect(.radians(angle))
                        .opacity(Double(1 - sparkle))
                }

                // Box body
                boxBody
                    .scaleEffect(boxScale)
                    .opacity(boxOpacity)

                // Lid
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [palette.accent, palette.deep],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 168, height: 42)
                    .offset(y: -80 + lidOffset)
                    .rotationEffect(.degrees(Double(lidOffset) * 0.15))
                    .opacity(lidOpacity * boxOpacity)

                // Hero
                HeroFigure(hero: hero, aura: true)
                    .frame(height: 300)
                    .scaleEffect(heroScale)
                    .opacity(heroOpacity)
                    .offset(heroOffset)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear { runSequence(target: target) }
        }
    }

    private var boxBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [palette.deep, .black.opacity(0.9)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 176, height: 190)
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.accent.opacity(0.6), lineWidth: 1.5)
                .frame(width: 176, height: 190)
            Image(systemName: hero.genome.emblem)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(palette.accent.opacity(0.85))
        }
    }

    private func runSequence(target: CGSize) {
        // Drop the box in.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
            boxScale = 1; boxOpacity = 1
        }
        // Burst the lid + flash + hero rises.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.35)) {
                lidOffset = -160; lidOpacity = 0; flash = 1; sparkle = 1
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                heroScale = 1.1; heroOpacity = 1; boxOpacity = 0
            }
        }
        // Settle flash + hero.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) { flash = 0 }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { heroScale = 1.0 }
        }
        // Fly to the bottom-right and hand off to the companion.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeIn(duration: 0.5)) {
                heroOffset = target
                heroScale = 0.35
                heroOpacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onFinished()
        }
    }
}
