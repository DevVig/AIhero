import XCTest
@testable import AIhero

/// The activity-signal layer is the seam between the tools the user runs and the
/// companion's `WorkState`. These cover the wire format, the verb→state mapping,
/// the CLI writer's contract, and how the model goes "live" on a real ping — all
/// against temp directories so the real `~/.aihero/` is never touched.
final class ActivitySignalTests: XCTestCase {

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("aihero-signal-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Transport

    func testPingRoundTripsThroughTransport() throws {
        let dir = tempDir()
        let ping = ActivityPing(state: "working", tool: "codex", cwd: "/tmp/proj", at: 1_700_000_000)
        try ActivityTransport.write(ping, to: dir)
        let read = try XCTUnwrap(ActivityTransport.read(from: dir))
        XCTAssertEqual(read, ping)
    }

    func testReadIsNilWhenNoFile() {
        XCTAssertNil(ActivityTransport.read(from: tempDir()))
    }

    // MARK: - Verb → WorkState mapping

    func testCanonicalVerbsMap() {
        XCTAssertEqual(WorkState(signalName: "idle"), .idle)
        XCTAssertEqual(WorkState(signalName: "thinking"), .thinking)
        XCTAssertEqual(WorkState(signalName: "working"), .working)
        XCTAssertEqual(WorkState(signalName: "shipping"), .shipping)
        XCTAssertEqual(WorkState(signalName: "waiting"), .waiting)
    }

    func testSynonymsAndCaseFold() {
        // Natural verbs a hook might emit resolve to sensible states, case-insensitively.
        XCTAssertEqual(WorkState(signalName: "PUSH"), .shipping)
        XCTAssertEqual(WorkState(signalName: "commit"), .shipping)
        XCTAssertEqual(WorkState(signalName: "Edit"), .working)
        XCTAssertEqual(WorkState(signalName: "permission"), .waiting)
        XCTAssertEqual(WorkState(signalName: "stop"), .idle)
    }

    func testUnknownVerbIsNil() {
        XCTAssertNil(WorkState(signalName: "banana"))
        XCTAssertNil(ActivityPing(state: "banana", tool: nil, cwd: nil, at: 0).workState)
    }

    // MARK: - CLI writer

    func testCLIWritesValidPing() throws {
        let dir = tempDir()
        let code = ActivitySignalCLI.run(["working", "--tool", "codex", "--cwd", "/x"], to: dir)
        XCTAssertEqual(code, 0)
        let ping = try XCTUnwrap(ActivityTransport.read(from: dir))
        XCTAssertEqual(ping.state, "working")
        XCTAssertEqual(ping.tool, "codex")
        XCTAssertEqual(ping.cwd, "/x")
        XCTAssertGreaterThan(ping.at, 0)
    }

    func testCLIRejectsMissingAndUnknownState() {
        let dir = tempDir()
        XCTAssertEqual(ActivitySignalCLI.run([], to: dir), 2)
        XCTAssertEqual(ActivitySignalCLI.run(["banana"], to: dir), 2)
        // A usage error must not leave a ping behind.
        XCTAssertNil(ActivityTransport.read(from: dir))
    }

    // MARK: - Model goes live on a real ping

    @MainActor
    func testReceivingPingGoesLiveAndDrivesState() {
        let model = AppModel(stateURL: tempDir().appendingPathComponent("state.json"))
        XCTAssertFalse(model.signalIsLive)
        XCTAssertEqual(model.workState, .idle)

        model.receiveActivityPing(ActivityPing(state: "working", tool: "codex", cwd: nil, at: 1))
        XCTAssertTrue(model.signalIsLive)
        XCTAssertEqual(model.workState, .working)

        model.receiveActivityPing(ActivityPing(state: "waiting", tool: "claude", cwd: nil, at: 2))
        XCTAssertEqual(model.workState, .waiting)
    }

    @MainActor
    func testUnknownPingIsIgnored() {
        let model = AppModel(stateURL: tempDir().appendingPathComponent("state.json"))
        model.receiveActivityPing(ActivityPing(state: "banana", tool: nil, cwd: nil, at: 1))
        // An unrecognized verb changes nothing — not even the live flag.
        XCTAssertFalse(model.signalIsLive)
        XCTAssertEqual(model.workState, .idle)
    }

    // MARK: - Listener directory-watch (real DispatchSource, headless)

    /// Thread-safe holder so the background listener callback can hand the ping
    /// back to the test.
    private final class PingBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value: ActivityPing?
        func set(_ p: ActivityPing) { lock.lock(); value = p; lock.unlock() }
        var get: ActivityPing? { lock.lock(); defer { lock.unlock() }; return value }
    }

    func testListenerDeliversAWrittenPing() {
        let dir = tempDir()
        let delivered = expectation(description: "listener delivered a ping")
        let box = PingBox()
        let listener = ActivitySignalListener(directory: dir) { ping in
            box.set(ping)
            delivered.fulfill()
        }
        listener.start()
        defer { listener.stop() }

        // Written after the source is armed → the directory-write event fires it
        // (and the initial-load read is a fresh-enough backstop either way).
        try? ActivityTransport.write(
            ActivityPing(state: "shipping", tool: "git", cwd: nil,
                         at: Date().timeIntervalSince1970), to: dir)

        wait(for: [delivered], timeout: 3)
        XCTAssertEqual(box.get?.state, "shipping")
    }
}
