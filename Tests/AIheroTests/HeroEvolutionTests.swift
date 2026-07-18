import XCTest
@testable import AIhero

/// Evolution is the payoff of the read-only activity layer: real work earns the
/// active hero XP, and clicking "Update" spends it to advance a level and re-forge
/// the portrait at a higher tier. These cover the XP curve, the evolve transaction,
/// the rate-limited earn path, and the level-aware prompt — all on temp models, so
/// no real roster is touched and (isProduction == false) no harness is ever spawned.
final class HeroEvolutionTests: XCTestCase {

    @MainActor
    private func tempModel() -> AppModel {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("aihero-evo-\(UUID().uuidString).json")
        return AppModel(stateURL: url)
    }

    // MARK: - XP curve + readiness

    @MainActor
    func testXPCurveGrowsWithLevel() {
        let model = tempModel()
        XCTAssertEqual(model.xpForNextLevel(1), 30)
        XCTAssertEqual(model.xpForNextLevel(2), 60)
        XCTAssertEqual(model.xpForNextLevel(3), 90)
    }

    @MainActor
    func testCanEvolveOnlyAtThreshold() {
        let model = tempModel()
        var hero = HeroForge.forge(name: "Aegis", sources: [], salt: 1, artDirection: .auto)
        hero.xp = 29
        XCTAssertFalse(model.canEvolve(hero))
        hero.xp = 30
        XCTAssertTrue(model.canEvolve(hero))
    }

    // MARK: - Evolve transaction

    @MainActor
    func testEvolveAdvancesLevelAndSpendsXPWithCarry() {
        let model = tempModel()
        let hero = model.forge(name: "Aegis", sources: [])
        model.unbox(hero.id)
        model.awardXP(35, to: hero.id)            // 5 over the level-1 threshold of 30

        model.evolve(hero.id)

        let evolved = model.heroes.first { $0.id == hero.id }!
        XCTAssertEqual(evolved.level, 2)
        XCTAssertEqual(evolved.xp, 5)             // remainder carries forward
    }

    @MainActor
    func testEvolveIsNoOpWhenNotReady() {
        let model = tempModel()
        let hero = model.forge(name: "Aegis", sources: [])
        model.awardXP(10, to: hero.id)            // below threshold
        model.evolve(hero.id)
        let after = model.heroes.first { $0.id == hero.id }!
        XCTAssertEqual(after.level, 1)
        XCTAssertEqual(after.xp, 10)              // untouched
    }

    // MARK: - Earning XP from real work

    @MainActor
    func testRealWorkGrantsRateLimitedXP() {
        let model = tempModel()
        let hero = model.forge(name: "Aegis", sources: [])
        model.unbox(hero.id)                       // makes it the active hero

        model.receiveAmbientBusy()
        XCTAssertEqual(model.heroes.first { $0.id == hero.id }!.xp, 10)

        // A second reading moments later is rate-limited — no double-count.
        model.receiveAmbientBusy()
        XCTAssertEqual(model.heroes.first { $0.id == hero.id }!.xp, 10)
    }

    @MainActor
    func testIdlePingEarnsNoXP() {
        let model = tempModel()
        let hero = model.forge(name: "Aegis", sources: [])
        model.unbox(hero.id)
        model.receiveActivityPing(ActivityPing(state: "idle", tool: nil, cwd: nil, at: 1))
        XCTAssertEqual(model.heroes.first { $0.id == hero.id }!.xp, 0)
    }

    // MARK: - Level-aware prompt

    func testPromptOmitsEvolutionTierAtLevelOne() {
        let hero = HeroForge.forge(name: "Aegis", sources: [], salt: 2, artDirection: .cinematic)
        let prompt = HeroPromptBuilder.transparentHeroPrompt(
            for: hero, direction: hero.artDirection, outputPath: "/tmp/x.png")
        XCTAssertFalse(prompt.contains("Evolution tier"))
    }

    func testPromptCarriesEvolutionTierAndIdentityGuardWhenLeveled() {
        var hero = HeroForge.forge(name: "Aegis", sources: [], salt: 2, artDirection: .cinematic)
        hero.level = 3
        let prompt = HeroPromptBuilder.transparentHeroPrompt(
            for: hero, direction: hero.artDirection, outputPath: "/tmp/x.png")
        XCTAssertTrue(prompt.contains("Evolution tier 3"))
        // The genome must stay fixed so an evolved hero is the same collectible.
        XCTAssertTrue(prompt.contains("unchanged"))
    }
}
