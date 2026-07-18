import XCTest
@testable import AIhero

/// The prompt handed to the user's harness must be well-formed and, critically,
/// pick a chroma key that doesn't collide with the hero's own colors — a green
/// subject on a green key can't be cut out cleanly.
final class HeroPromptBuilderTests: XCTestCase {

    /// A hero with a hand-picked palette seed so we can steer the key-color logic.
    /// `paletteSeed % 3600` maps to a hue: 900 → 0.25 → "verdant green".
    private func hero(paletteSeed: UInt64) -> Hero {
        let genome = HeroGenome(seed: 123, archetypeID: "sentinel", silhouette: .sentinel,
                                emblem: "shield.fill", paletteSeed: paletteSeed, motifIndex: 0)
        return Hero(id: UUID(), name: "Testarossa", title: "The Bulwark", genome: genome,
                    originStory: "origin", powers: ["Aegis"], personality: nil, level: 1, xp: 0,
                    contributingSources: [], createdAt: Date(), isUnboxed: false,
                    artDirectionID: nil)
    }

    func testPromptCarriesOutputPathAndTrailer() {
        let path = "/tmp/aihero/out.png"
        let prompt = HeroPromptBuilder.transparentHeroPrompt(
            for: hero(paletteSeed: 0), direction: .auto, outputPath: path)
        XCTAssertTrue(prompt.contains(path))
        // The harness signals success by printing this exact trailer.
        XCTAssertTrue(prompt.contains("SAVED \(path)"))
    }

    func testPromptIncludesOriginalityGuardAndIdentity() {
        let prompt = HeroPromptBuilder.transparentHeroPrompt(
            for: hero(paletteSeed: 0), direction: .auto, outputPath: "/tmp/out.png")
        XCTAssertTrue(prompt.contains("do NOT copy any known/trademarked hero"))
        XCTAssertTrue(prompt.contains("Testarossa"))
        XCTAssertTrue(prompt.contains("The Bulwark"))
    }

    func testGreenHeroUsesMagentaKey() {
        // Body color "verdant green" must flip the key to magenta and never emit
        // the green key value anywhere.
        let prompt = HeroPromptBuilder.transparentHeroPrompt(
            for: hero(paletteSeed: 900), direction: .auto, outputPath: "/tmp/out.png")
        XCTAssertTrue(prompt.contains("#ff00ff"))
        XCTAssertFalse(prompt.contains("#00ff00"))
    }

    func testNonGreenHeroUsesGreenKey() {
        // Crimson body + teal energy → the default green key.
        let prompt = HeroPromptBuilder.transparentHeroPrompt(
            for: hero(paletteSeed: 0), direction: .auto, outputPath: "/tmp/out.png")
        XCTAssertTrue(prompt.contains("#00ff00"))
        XCTAssertFalse(prompt.contains("#ff00ff"))
    }
}
