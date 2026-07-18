import XCTest
@testable import AIhero

/// The read-only ambient reader is the privacy-first heart of Phase F: it infers
/// "a tool is working right now" from the *modification recency* of the tools' own
/// session logs — reading only metadata, never contents, and only for enabled
/// sources. These cover the pure decision core, the metadata-only newest-mtime scan,
/// the consent gate, and the model's coarse "goes live but yields to finer states"
/// wiring. All against temp directories; the real `~/.codex` / `~/.claude` are never
/// touched.
final class AmbientActivityTests: XCTestCase {

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("aihero-ambient-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Write a file and stamp its modification date, so mtime-based logic is
    /// deterministic rather than racing the wall clock.
    @discardableResult
    private func writeFile(_ name: String, in dir: URL, modified: Date) -> URL {
        let url = dir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
        try? FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        return url
    }

    // MARK: - Pure decision core

    func testIsBusyWindow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(AmbientActivityReader.isBusy(newestWrite: now.addingTimeInterval(-3), now: now, window: 8))
        XCTAssertTrue(AmbientActivityReader.isBusy(newestWrite: now, now: now, window: 8))
        XCTAssertFalse(AmbientActivityReader.isBusy(newestWrite: now.addingTimeInterval(-20), now: now, window: 8))
        XCTAssertFalse(AmbientActivityReader.isBusy(newestWrite: nil, now: now, window: 8))
        // A little future skew is tolerated; a lot is not.
        XCTAssertTrue(AmbientActivityReader.isBusy(newestWrite: now.addingTimeInterval(1), now: now, window: 8))
        XCTAssertFalse(AmbientActivityReader.isBusy(newestWrite: now.addingTimeInterval(30), now: now, window: 8))
    }

    // MARK: - Metadata-only newest-mtime scan

    func testNewestMTimeFindsMostRecentMatchingFile() {
        let dir = tempDir()
        let base = Date(timeIntervalSince1970: 2_000_000)
        writeFile("old.jsonl", in: dir, modified: base)
        writeFile("rollout-new.jsonl", in: dir, modified: base.addingTimeInterval(100))
        let newest = AmbientActivityReader.newestMTime(in: [dir], suffixes: [".jsonl"], limit: 100)
        XCTAssertEqual(newest?.timeIntervalSince1970 ?? 0,
                       base.addingTimeInterval(100).timeIntervalSince1970, accuracy: 1)
    }

    func testNewestMTimeRespectsSuffixFilter() {
        let dir = tempDir()
        let base = Date(timeIntervalSince1970: 3_000_000)
        writeFile("session.jsonl", in: dir, modified: base)
        // A newer file with a non-matching suffix must be ignored.
        writeFile("notes.txt", in: dir, modified: base.addingTimeInterval(500))
        let newest = AmbientActivityReader.newestMTime(in: [dir], suffixes: [".jsonl"], limit: 100)
        XCTAssertEqual(newest?.timeIntervalSince1970 ?? 0, base.timeIntervalSince1970, accuracy: 1)
    }

    func testNewestMTimeNilForEmptyOrMissingRoots() {
        XCTAssertNil(AmbientActivityReader.newestMTime(in: [tempDir()], suffixes: [".jsonl"], limit: 100))
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("nope-\(UUID())")
        XCTAssertNil(AmbientActivityReader.newestMTime(in: [missing], suffixes: [], limit: 100))
    }

    func testNewestMTimeFindsNestedFiles() {
        let dir = tempDir()
        let nested = dir.appendingPathComponent("2026/07/18", isDirectory: true)
        try? FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let base = Date(timeIntervalSince1970: 4_000_000)
        writeFile("rollout-abc.jsonl", in: nested, modified: base)
        let newest = AmbientActivityReader.newestMTime(in: [dir], suffixes: [".jsonl"], limit: 100)
        XCTAssertEqual(newest?.timeIntervalSince1970 ?? 0, base.timeIntervalSince1970, accuracy: 1)
    }

    // MARK: - Reader integration (real DispatchSource timer, headless)

    /// Thread-safe latch so the background poll can signal the test.
    private final class Latch: @unchecked Sendable {
        private let lock = NSLock()
        private var fired = false
        func trip() { lock.lock(); fired = true; lock.unlock() }
        var tripped: Bool { lock.lock(); defer { lock.unlock() }; return fired }
    }

    func testReaderFiresOnRecentWriteForEnabledSource() {
        let dir = tempDir()
        writeFile("rollout-live.jsonl", in: dir, modified: Date())
        let hit = expectation(description: "ambient reader saw a busy tool")
        let latch = Latch()
        let reader = AmbientActivityReader(
            probes: [.init(source: .codex, roots: [dir], suffixes: [".jsonl"])],
            interval: 0.2, busyWindow: 30) {
                latch.trip(); hit.fulfill()
            }
        reader.setEnabledSources([.codex])
        reader.start()
        defer { reader.stop() }
        wait(for: [hit], timeout: 3)
        XCTAssertTrue(latch.tripped)
    }

    func testReaderStaysQuietForDisabledSource() {
        let dir = tempDir()
        writeFile("rollout-live.jsonl", in: dir, modified: Date())
        let quiet = expectation(description: "no busy signal for a disabled source")
        quiet.isInverted = true
        let reader = AmbientActivityReader(
            probes: [.init(source: .codex, roots: [dir], suffixes: [".jsonl"])],
            interval: 0.2, busyWindow: 30) { quiet.fulfill() }
        reader.setEnabledSources([])   // consent withheld → nothing is read
        reader.start()
        defer { reader.stop() }
        wait(for: [quiet], timeout: 1)
    }

    // MARK: - Model wiring

    @MainActor
    func testAmbientBusyGoesLiveAndLiftsIdle() {
        let model = AppModel(stateURL: tempDir().appendingPathComponent("state.json"))
        XCTAssertFalse(model.signalIsLive)
        XCTAssertEqual(model.workState, .idle)

        model.receiveAmbientBusy()
        XCTAssertTrue(model.signalIsLive)
        XCTAssertEqual(model.workState, .working)
    }

    @MainActor
    func testAmbientBusyYieldsToFinerPingState() {
        let model = AppModel(stateURL: tempDir().appendingPathComponent("state.json"))
        // A ping put us in a finer state; a coarse ambient "busy" must not stomp it.
        model.receiveActivityPing(ActivityPing(state: "waiting", tool: "claude", cwd: nil, at: 1))
        XCTAssertEqual(model.workState, .waiting)
        model.receiveAmbientBusy()
        XCTAssertEqual(model.workState, .waiting)
    }
}
