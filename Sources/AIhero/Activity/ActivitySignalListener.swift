import Foundation

/// Watches the on-device transport for new activity pings and delivers them.
///
/// It opens `~/.aihero/` and uses a `DispatchSource` on the *directory* (so it
/// catches the atomic rename-into-place that `ActivityTransport.write` performs),
/// re-reads `activity.json` on each change, de-dupes by the ping's timestamp, and
/// hands fresh pings to `onPing`. On start it reads once so a ping written moments
/// before launch is picked up — but only if it's recent (a day-old file must not
/// make the hero look busy at login).
///
/// Everything is local file I/O in the user's home; no network, no content.
final class ActivitySignalListener {
    /// On launch, ignore any ping older than this — stale state shouldn't animate
    /// the companion until the tools actually do something.
    static let freshnessWindow: TimeInterval = 90

    private let directory: URL
    private let onPing: @Sendable (ActivityPing) -> Void
    private let queue = DispatchQueue(label: "ai.aihero.activity.listener")

    private var source: DispatchSourceFileSystemObject?
    private var dirFD: Int32 = -1
    private var lastAt: Double = 0

    init(directory: URL = ActivityTransport.defaultDirectory,
         onPing: @escaping @Sendable (ActivityPing) -> Void) {
        self.directory = directory
        self.onPing = onPing
    }

    /// Begin watching. Safe to call once; a second call is ignored.
    func start() {
        guard source == nil else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else {
            Log.model.error("activity listener: cannot open \(self.directory.path, privacy: .public)")
            return
        }
        dirFD = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write], queue: queue)
        src.setEventHandler { [weak self] in self?.reload(initialLoad: false) }
        src.setCancelHandler { [weak self] in
            if let fd = self?.dirFD, fd >= 0 { close(fd) }
            self?.dirFD = -1
        }
        source = src
        src.resume()

        // Pick up a recent ping already on disk (e.g. a hook fired during launch).
        queue.async { [weak self] in self?.reload(initialLoad: true) }
        Log.model.info("activity listener watching \(self.directory.path, privacy: .public)")
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit { source?.cancel() }

    private func reload(initialLoad: Bool) {
        guard let ping = ActivityTransport.read(from: directory) else { return }
        // Monotonic guard: only advance on a strictly newer ping.
        guard ping.at > lastAt else { return }
        lastAt = ping.at
        if initialLoad,
           Date().timeIntervalSince1970 - ping.at > ActivitySignalListener.freshnessWindow {
            return   // too old to be meaningful at launch
        }
        onPing(ping)
    }
}
