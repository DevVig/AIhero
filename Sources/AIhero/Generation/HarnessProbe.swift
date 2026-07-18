import Foundation

/// One image-capable AI harness detected on the user's machine (e.g. Codex).
/// Art generation is delegated to whatever the user already runs under their own
/// login — AIhero ships no key and calls no server.
struct ImageHarness: Identifiable, Hashable {
    let id: String            // "codex"
    let displayName: String   // "Codex"
    let binaryURL: URL        // resolved absolute path to the CLI
}

/// Runtime, per-user capability detection. The dev machine is only one sample —
/// every end user has their own installed harnesses and auth state, so we probe
/// at runtime rather than baking a conclusion. Installed ≠ usable: a binary can
/// be present but auth-blocked; that surfaces at generation time and falls back
/// to procedural art, never a crash.
enum HarnessProbe {
    /// Image-capable harnesses whose CLI is installed. Order is preference order.
    ///
    /// Codex is the validated image path (built-in `image_gen`, key-free under
    /// the user's Codex login, with a bundled chroma-key cutout). Gemini can also
    /// generate images natively, but its headless file-emitting contract isn't
    /// validated here yet (and is auth-gated on some machines), so it's withheld
    /// from art generation until proven — detection stays honest.
    static func availableImageHarnesses() -> [ImageHarness] {
        var result: [ImageHarness] = []
        if let codex = resolveBinary("codex") {
            result.append(ImageHarness(id: "codex", displayName: "Codex", binaryURL: codex))
        }
        return result
    }

    /// Confirm a detected harness actually *runs* by invoking `<binary> --version`
    /// with a short budget. Catches a present-but-broken install (wrong arch,
    /// quarantined, missing runtime) so the forge can set honest expectations
    /// instead of promising a renderer that will fail on first use.
    ///
    /// Deliberately narrow: this does NOT check login/auth and never touches the
    /// network. A logged-out but runnable Codex still returns `true` here — that
    /// failure mode surfaces later as a visible, retryable `.failed` portrait,
    /// which is the honest place for it (we don't want to trigger an auth flow
    /// just to render a tooltip). Non-blocking; safe to call from a view `.task`.
    static func probeRunnable(_ harness: ImageHarness, timeout: TimeInterval = 6) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let process = Process()
            process.executableURL = harness.binaryURL
            process.arguments = ["--version"]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            // Exactly one of the termination handler, the launch-failure path, or
            // the watchdog resolves the continuation. NSLock supplies the sync the
            // compiler can't see (hence @unchecked Sendable).
            let once = OneShotBool(continuation)
            process.terminationHandler = { proc in once.resolve(proc.terminationStatus == 0) }
            do {
                try process.run()
            } catch {
                once.resolve(false)
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning { process.terminate() }
            }
        }
    }

    private final class OneShotBool: @unchecked Sendable {
        private let lock = NSLock()
        private var settled = false
        private let continuation: CheckedContinuation<Bool, Never>
        init(_ continuation: CheckedContinuation<Bool, Never>) { self.continuation = continuation }
        func resolve(_ value: Bool) {
            lock.lock(); defer { lock.unlock() }
            guard !settled else { return }
            settled = true
            continuation.resume(returning: value)
        }
    }

    /// Resolve a CLI to an absolute path, checking `PATH` plus the common install
    /// locations a GUI app (launched from Finder with a minimal `PATH`) would
    /// otherwise miss.
    static func resolveBinary(_ name: String) -> URL? {
        let home = NSHomeDirectory()
        let pathDirs = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map(String.init)
        let commonDirs = [
            "/opt/homebrew/bin", "/usr/local/bin",
            "\(home)/.local/bin", "\(home)/bin",
            "/usr/bin", "/bin",
        ]
        let fm = FileManager.default
        for dir in pathDirs + commonDirs {
            let candidate = URL(fileURLWithPath: dir).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        return nil
    }
}
