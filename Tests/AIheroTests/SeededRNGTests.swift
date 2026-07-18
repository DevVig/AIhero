import XCTest
@testable import AIhero

/// The deterministic RNG and string hash are the bedrock of the whole collectible
/// promise: same inputs must always reproduce the same hero. If these drift, every
/// previously forged hero silently changes identity.
final class SeededRNGTests: XCTestCase {

    func testSameSeedYieldsSameStream() {
        var a = SeededRNG(seed: 0xDEADBEEF)
        var b = SeededRNG(seed: 0xDEADBEEF)
        for _ in 0..<64 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testDifferentSeedsDiverge() {
        var a = SeededRNG(seed: 1)
        var b = SeededRNG(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }

    func testZeroSeedIsNotDegenerate() {
        // A zero seed is remapped so it can't collapse to a constant stream.
        var rng = SeededRNG(seed: 0)
        let first = rng.next()
        let second = rng.next()
        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(first, 0)
    }

    func testSeedHashEmptyStringIsFNVOffsetBasis() {
        // Known-answer test pinning the FNV-1a 64-bit offset basis. Guards against
        // an accidental constant change that would rehash every seed.
        XCTAssertEqual(SeedHash.of(""), 0xcbf29ce484222325)
    }

    func testSeedHashIsStableAndDistinct() {
        XCTAssertEqual(SeedHash.of("codex"), SeedHash.of("codex"))
        XCTAssertNotEqual(SeedHash.of("codex"), SeedHash.of("gemini"))
    }

    func testCombineIsOrderSensitive() {
        // combine() blends multiple sub-seeds; order matters so distinct blends
        // don't collide.
        XCTAssertNotEqual(SeedHash.combine(1, 2, 3), SeedHash.combine(3, 2, 1))
        XCTAssertEqual(SeedHash.combine(7, 11), SeedHash.combine(7, 11))
    }

    func testArrayPickIsDeterministic() {
        let items = ["a", "b", "c", "d", "e"]
        var a = SeededRNG(seed: 4242)
        var b = SeededRNG(seed: 4242)
        for _ in 0..<20 {
            XCTAssertEqual(items.pick(using: &a), items.pick(using: &b))
        }
    }
}
