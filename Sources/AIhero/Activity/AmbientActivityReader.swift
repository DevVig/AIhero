import Foundation

/// Read-only ambient activity detection — the privacy-first way AIhero learns that
/// you're actively working, without installing anything into your tools.
///
/// It answers exactly one question: *"is one of your enabled agent tools writing to
/// its own session log right now?"* — and answers it using **only file modification
/// timestamps**. It never opens or parses those files, so no prompt or code text is
/// ever read. It adds nothing to any tool's config, only looks at the `Source`s
/// you've enabled, and touches only the tools' OWN existing on-disk logs in your home
/// directory. Nothing is uploaded; there is no network path.
///
/// The signal is deliberately **coarse — busy ↔ quiet**. Distinguishing thinking /
/// waiting / plan-ready would require reading event *types* from inside those files;
/// that is intentionally left as a separate, explicitly-consented step and is not
/// done here. See the Phase F privacy contract in
/// `documentation/active/2026-07-18_unified-activity-signals.md`.
final class AmbientActivityReader {

    /// Where a given source writes its own session logs on this machine. Roots that
    /// don't exist are skipped silently; `suffixes` bounds what counts as a session
    /// file so we don't stat unrelated clutter. An empty `roots` is an honest no-op —
    /// enabling a tool we can't read this way simply contributes nothing (rather than
    /// pretending to).
    struct Probe {
        let source: Source
        let roots: [URL]
        let suffixes: [String]
    }

    private let interval: TimeInterval
    private let busyWindow: TimeInterval
    private let maxFilesScanned: Int
    private let onBusy: @Sendable () -> Void
    private let clock: @Sendable () -> Date

    private let queue = DispatchQueue(label: "ai.aihero.activity.ambient", qos: .utility)
    private let lock = NSLock()
    private var enabled: Set<Source> = []
    private let probeIndex: [Source: Probe]
    private var timer: DispatchSourceTimer?

    init(probes: [Probe] = AmbientActivityReader.defaultProbes(),
         interval: TimeInterval = 3,
         busyWindow: TimeInterval = 8,
         maxFilesScanned: Int = 6000,
         clock: @escaping @Sendable () -> Date = { Date() },
         onBusy: @escaping @Sendable () -> Void) {
        self.interval = interval
        self.busyWindow = busyWindow
        self.maxFilesScanned = maxFilesScanned
        self.clock = clock
        self.onBusy = onBusy
        var index: [Source: Probe] = [:]
        for probe in probes { index[probe.source] = probe }
        self.probeIndex = index
    }

    /// Update the consent set. Reading is gated on this — a disabled source is never
    /// looked at. Safe to call anytime (e.g. when the user toggles a tool in Settings).
    func setEnabledSources(_ sources: Set<Source>) {
        lock.lock(); enabled = sources; lock.unlock()
    }

    /// Begin polling. Safe to call once; a second call is ignored.
    func start() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        // A small initial delay keeps launch cheap; then poll on a calm cadence.
        t.schedule(deadline: .now() + 0.5, repeating: interval, leeway: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    deinit { timer?.cancel() }

    private func tick() {
        lock.lock(); let sources = enabled; lock.unlock()
        guard !sources.isEmpty else { return }

        let now = clock()
        var newest: Date?
        for source in sources {
            guard let probe = probeIndex[source] else { continue }
            if let m = Self.newestMTime(in: probe.roots, suffixes: probe.suffixes,
                                        limit: maxFilesScanned) {
                if newest == nil || m > newest! { newest = m }
            }
        }
        if Self.isBusy(newestWrite: newest, now: now, window: busyWindow) {
            onBusy()
        }
    }

    // MARK: - Pure, testable core

    /// A write within `window` seconds of `now` counts as "busy right now". A little
    /// negative slack absorbs clock skew between the writing tool and us.
    static func isBusy(newestWrite: Date?, now: Date, window: TimeInterval) -> Bool {
        guard let t = newestWrite else { return false }
        let age = now.timeIntervalSince(t)
        return age >= -2 && age <= window
    }

    /// Newest content-modification date among regular files under `roots` whose name
    /// ends with one of `suffixes` (all files if `suffixes` is empty). Reads **only
    /// metadata** — it never opens file contents. Bounded by `limit` files so a large
    /// history directory can't stall the poll; on very large histories this may miss
    /// the newest file (a rare false-negative, acceptable for a toy companion).
    static func newestMTime(in roots: [URL], suffixes: [String], limit: Int,
                            fileManager: FileManager = .default) -> Date? {
        var newest: Date?
        var scanned = 0
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
        for root in roots {
            guard fileManager.fileExists(atPath: root.path) else { continue }
            guard let walker = fileManager.enumerator(
                at: root, includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles], errorHandler: { _, _ in true }) else { continue }
            for case let url as URL in walker {
                if scanned >= limit { return newest }
                if !suffixes.isEmpty,
                   !suffixes.contains(where: { url.lastPathComponent.hasSuffix($0) }) {
                    continue
                }
                guard let values = try? url.resourceValues(forKeys: keys),
                      values.isRegularFile == true,
                      let modified = values.contentModificationDate else { continue }
                scanned += 1
                if newest == nil || modified > newest! { newest = modified }
            }
        }
        return newest
    }

    /// The tools' own session-log locations on this machine. Only Codex and Claude
    /// Code write a stable, per-session log we can read by mtime alone; the others are
    /// present as honest no-ops so enabling them never errors and never fabricates a
    /// signal we can't actually observe this way.
    static func defaultProbes(home: URL = FileManager.default.homeDirectoryForCurrentUser)
        -> [Probe] {
        func roots(_ rel: [String]) -> [URL] { rel.map { home.appendingPathComponent($0) } }
        return [
            Probe(source: .codex,
                  roots: roots([".codex/sessions", ".codex/log"]),
                  suffixes: [".jsonl", ".log"]),
            Probe(source: .claudeCode,
                  roots: roots([".claude/projects"]),
                  suffixes: [".jsonl"]),
            Probe(source: .cursor, roots: [], suffixes: []),
            Probe(source: .ghostty, roots: [], suffixes: []),
            Probe(source: .cmux, roots: [], suffixes: []),
            Probe(source: .t3code, roots: [], suffixes: []),
        ]
    }
}
