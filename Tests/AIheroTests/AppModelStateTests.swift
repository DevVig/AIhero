import XCTest
@testable import AIhero

/// The collection-loss guard: a corrupt `state.json` must never be silently
/// discarded (the next save would overwrite it and the roster would be gone).
/// It gets moved aside so it's recoverable, and the app still launches.
@MainActor
final class AppModelStateTests: XCTestCase {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("aihero-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testCorruptStateIsPreservedNotLost() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stateURL = dir.appendingPathComponent("state.json")
        try Data("{ this is not valid json".utf8).write(to: stateURL)

        let model = AppModel(stateURL: stateURL)
        XCTAssertTrue(model.heroes.isEmpty, "should start empty rather than crash")

        let contents = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(contents.contains { $0.hasPrefix("state.corrupt-") },
                      "corrupt roster should be backed up; found \(contents)")
    }

    func testMissingStateStartsCleanWithoutBackup() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stateURL = dir.appendingPathComponent("state.json")   // never created

        let model = AppModel(stateURL: stateURL)
        XCTAssertTrue(model.heroes.isEmpty)

        // A genuine first launch must not manufacture a spurious backup file.
        let contents = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertFalse(contents.contains { $0.hasPrefix("state.corrupt-") })
    }

    func testValidStateReloads() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stateURL = dir.appendingPathComponent("state.json")

        // Forge + persist through one model, then reload in a fresh one.
        let first = AppModel(stateURL: stateURL)
        let hero = first.forge(name: "Nova", sources: [.claudeCode])
        first.unbox(hero.id)

        let second = AppModel(stateURL: stateURL)
        XCTAssertEqual(second.heroes.map(\.id), [hero.id])
        XCTAssertEqual(second.activeHeroID, hero.id)
    }
}
