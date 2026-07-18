import Foundation

/// One activity signal from a tool the user runs — the wire format of the
/// unified ping. Emitted by `aihero signal …` (from a tool's hook or the shell)
/// and read by the app to drive the companion's `WorkState`.
///
/// It carries an activity verb, an optional originating tool + working directory
/// (for future per-project attribution), and the writer's timestamp so the reader
/// can ignore stale pings and de-duplicate. It deliberately carries **no message
/// or code content** — only the *type* of activity — which is the whole privacy
/// story for the signal layer.
struct ActivityPing: Codable, Equatable, Sendable {
    /// Activity verb — see `WorkState(signalName:)` for the accepted vocabulary.
    var state: String
    /// Which tool emitted it ("codex" / "claude" / "cursor" / "shell" / …). Advisory.
    var tool: String?
    /// The tool's working directory when it fired. Advisory; used later for
    /// per-project attribution. Never inspected for content.
    var cwd: String?
    /// Writer's wall-clock time (seconds since 1970). Lets the reader drop stale
    /// pings on launch and de-dupe repeats.
    var at: Double

    /// The work state this ping resolves to, or nil if the verb is unrecognized.
    var workState: WorkState? { WorkState(signalName: state) }
}

/// The on-device transport for activity pings. MVP uses a single atomically-written
/// JSON file under `~/.aihero/`; the app watches its directory for changes. (A
/// low-latency Unix-domain-socket fast path is a tracked fast-follow; the file is
/// reliable, trivially testable, and fast enough — FSEvents latency is tens of ms.)
///
/// Everything here is local to the user's home; nothing is uploaded and no network
/// is ever touched. Directory is overridable so tests never touch the real file.
enum ActivityTransport {
    /// `~/.aihero/` — a stable, tool-agnostic location a hook can reach without
    /// knowing where the app is installed.
    static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aihero", isDirectory: true)
    }

    static func stateFile(in directory: URL) -> URL {
        directory.appendingPathComponent("activity.json")
    }

    /// Atomically write the latest ping, creating `~/.aihero/` if needed. Atomic so
    /// a reader never sees a half-written file (the directory watcher fires on the
    /// rename-into-place).
    static func write(_ ping: ActivityPing, to directory: URL = defaultDirectory) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(ping)
        try data.write(to: stateFile(in: directory), options: .atomic)
    }

    /// Read the latest ping, or nil if none exists / it can't be decoded.
    static func read(from directory: URL = defaultDirectory) -> ActivityPing? {
        guard let data = try? Data(contentsOf: stateFile(in: directory)) else { return nil }
        return try? JSONDecoder().decode(ActivityPing.self, from: data)
    }
}
