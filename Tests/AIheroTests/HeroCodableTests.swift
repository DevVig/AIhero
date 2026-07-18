import XCTest
@testable import AIhero

/// Persistence fidelity for the collectible. A round-trip must be lossless, and
/// heroes saved before `artDirectionID` existed must still decode (the field is
/// optional precisely so old rosters keep loading).
final class HeroCodableTests: XCTestCase {

    private func sampleHero() -> Hero {
        // Small seeds keep the JSONSerialization round-trip below well within
        // Int64 range (large UInt64 can be mangled by NSNumber).
        let genome = HeroGenome(seed: 123, archetypeID: "sentinel", silhouette: .sentinel,
                                emblem: "shield.fill", paletteSeed: 900, motifIndex: 0)
        return Hero(id: UUID(), name: "Testarossa", title: "The Bulwark", genome: genome,
                    originStory: "origin", powers: ["Aegis", "Ward"],
                    personality: "Calm, exact — measures twice so the merge cuts once. Ships quietly.",
                    level: 3, xp: 40,
                    contributingSources: [.claudeCode], createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    isUnboxed: true, artDirectionID: "cinematic")
    }

    func testRoundTripsLosslessly() throws {
        let hero = sampleHero()
        let data = try JSONEncoder().encode(hero)
        let decoded = try JSONDecoder().decode(Hero.self, from: data)
        XCTAssertEqual(decoded, hero)
        XCTAssertEqual(decoded.artDirection, .cinematic)
    }

    func testDecodesLegacyHeroWithoutArtDirection() throws {
        let hero = sampleHero()
        let data = try JSONEncoder().encode(hero)
        var object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])
        // Simulate a hero saved before the art-direction field existed.
        object.removeValue(forKey: "artDirectionID")
        let stripped = try JSONSerialization.data(withJSONObject: object)

        let legacy = try JSONDecoder().decode(Hero.self, from: stripped)
        XCTAssertNil(legacy.artDirectionID)
        XCTAssertEqual(legacy.artDirection, .auto)   // resolves to the default
    }

    func testDecodesLegacyHeroWithoutPersonality() throws {
        let hero = sampleHero()
        let data = try JSONEncoder().encode(hero)
        var object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])
        // Simulate a hero saved before the personality field existed.
        object.removeValue(forKey: "personality")
        let stripped = try JSONSerialization.data(withJSONObject: object)

        let legacy = try JSONDecoder().decode(Hero.self, from: stripped)
        XCTAssertNil(legacy.personality)
        // The computed accessor regenerates a stable, non-empty personality from
        // the genome alone — identical to what the forge would have stored.
        XCTAssertFalse(legacy.personalityText.isEmpty)
        XCTAssertEqual(legacy.personalityText, HeroForge.personality(for: legacy.genome))
    }
}
