import XCTest
@testable import AIhero

/// The forge is the product's core guarantee: identical inputs reproduce an
/// identical hero identity, and any change to the salt yields a distinct one.
/// (`id` and `createdAt` are intentionally fresh each call — they're instance
/// metadata, not identity.)
final class HeroForgeTests: XCTestCase {

    func testSameInputsReproduceIdentity() {
        let a = HeroForge.forge(name: "Nova", sources: [.claudeCode, .ghostty], salt: 42)
        let b = HeroForge.forge(name: "Nova", sources: [.claudeCode, .ghostty], salt: 42)
        XCTAssertEqual(a.genome, b.genome)
        XCTAssertEqual(a.name, b.name)
        XCTAssertEqual(a.title, b.title)
        XCTAssertEqual(a.originStory, b.originStory)
        XCTAssertEqual(a.powers, b.powers)
        XCTAssertEqual(a.personality, b.personality)
        // Instance metadata must differ so each collectible is its own object.
        XCTAssertNotEqual(a.id, b.id)
    }

    func testForgePopulatesStablePersonality() {
        let hero = HeroForge.forge(name: "Nova", sources: [.claudeCode, .ghostty], salt: 9)
        // Populated at forge time, and the stored value equals what the genome
        // regenerates — so `personalityText` is stable whether stored or legacy.
        XCTAssertFalse((hero.personality ?? "").isEmpty)
        XCTAssertEqual(hero.personality, hero.personalityText)
        XCTAssertEqual(hero.personalityText, HeroForge.personality(for: hero.genome))
    }

    func testSourceOrderDoesNotChangeGenome() {
        // The genome seed folds sources through a sorted join, so selection order
        // can't change which hero you get.
        let a = HeroForge.forge(name: "Nova", sources: [.claudeCode, .ghostty], salt: 42)
        let b = HeroForge.forge(name: "Nova", sources: [.ghostty, .claudeCode], salt: 42)
        XCTAssertEqual(a.genome.seed, b.genome.seed)
    }

    func testDifferentSaltProducesDifferentHero() {
        let a = HeroForge.forge(name: "Nova", sources: [.claudeCode], salt: 1)
        let b = HeroForge.forge(name: "Nova", sources: [.claudeCode], salt: 2)
        XCTAssertNotEqual(a.genome.seed, b.genome.seed)
    }

    func testUnnamedForgeStillGetsACodename() {
        let hero = HeroForge.forge(name: nil, sources: [.claudeCode], salt: 3)
        XCTAssertFalse(hero.name.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    func testBlankNameIsTreatedAsUnnamed() {
        // A whitespace-only name must not become the codename.
        let hero = HeroForge.forge(name: "   ", sources: [.claudeCode], salt: 5)
        XCTAssertFalse(hero.name.trimmingCharacters(in: .whitespaces).isEmpty)
        XCTAssertNotEqual(hero.name, "   ")
    }

    func testForgePopulatesPowersAndStory() {
        let hero = HeroForge.forge(name: "Nova", sources: [.claudeCode, .ghostty], salt: 9)
        XCTAssertFalse(hero.powers.isEmpty)
        XCTAssertFalse(hero.originStory.isEmpty)
        XCTAssertEqual(hero.level, 1)
        XCTAssertFalse(hero.isUnboxed)
    }

    func testArtDirectionRoundTripsThroughForge() {
        let hero = HeroForge.forge(name: "Nova", sources: [.claudeCode], salt: 1,
                                   artDirection: .cinematic)
        XCTAssertEqual(hero.artDirection, .cinematic)
    }
}
