import Foundation

/// Runs a hero's bespoke art generation by shelling out to the user's own
/// harness (e.g. `codex exec`) with a style-locked, transparent-cutout prompt.
/// The harness generates and cuts out the figure under the user's own login —
/// AIhero ships no key and calls no server. On success the finished transparent
/// PNG lands at `outputURL`; on any failure the app keeps the procedural fallback.
enum HeroArtGenerator {

    enum Result: Equatable {
        case success
        case failure(String)
    }

    /// Thread-safe one-shot completion: the subprocess can finish normally or be
    /// killed by the watchdog concurrently, and exactly one of them resolves the
    /// continuation. `@unchecked Sendable` because the `NSLock` provides the
    /// synchronization the compiler can't see.
    private final class Completion: @unchecked Sendable {
        private let lock = NSLock()
        private var settled = false
        private let continuation: CheckedContinuation<Result, Never>
        private let logHandle: FileHandle?

        init(_ continuation: CheckedContinuation<Result, Never>, logHandle: FileHandle?) {
            self.continuation = continuation
            self.logHandle = logHandle
        }

        func settle(_ result: Result) {
            lock.lock(); defer { lock.unlock() }
            guard !settled else { return }
            settled = true
            try? logHandle?.close()
            continuation.resume(returning: result)
        }
    }

    /// Generate art for `prompt` using `harness`, writing the result to
    /// `outputURL`. Non-blocking: the subprocess runs off the main thread and the
    /// `async` call suspends until it exits (or `timeout` elapses).
    static func generate(harness: ImageHarness,
                         prompt: String,
                         outputURL: URL,
                         timeout: TimeInterval = 300) async -> Result {
        let fm = FileManager.default
        try? fm.createDirectory(at: outputURL.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
        try? fm.removeItem(at: outputURL)   // never mistake a stale file for success

        let tmpDir = fm.temporaryDirectory
            .appendingPathComponent("aihero-forge-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let logURL = tmpDir.appendingPathComponent("run.log")
        fm.createFile(atPath: logURL.path, contents: nil)

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result, Never>) in
            let process = Process()
            process.executableURL = harness.binaryURL
            // Mirrors the proven Phase 0 invocation: full access so image_gen can
            // reach the network and write files; skip the git-repo check since the
            // working dir is a throwaway temp folder.
            process.arguments = [
                "exec",
                "-s", "danger-full-access",
                "--skip-git-repo-check",
                "-C", tmpDir.path,
                prompt,
            ]
            process.currentDirectoryURL = tmpDir
            process.standardInput = FileHandle.nullDevice   // or codex hangs reading stdin

            let logHandle = try? FileHandle(forWritingTo: logURL)
            if let logHandle {
                process.standardOutput = logHandle
                process.standardError = logHandle
            }

            // Ensure the harness (and the shells it spawns) can find the usual
            // tools even when we were launched from Finder with a minimal PATH.
            var env = ProcessInfo.processInfo.environment
            let home = NSHomeDirectory()
            let extra = ["/opt/homebrew/bin", "/usr/local/bin",
                         "\(home)/.local/bin", "/usr/bin", "/bin"]
            env["PATH"] = (extra + [env["PATH"] ?? ""]).joined(separator: ":")
            process.environment = env

            let completion = Completion(continuation, logHandle: logHandle)

            process.terminationHandler = { proc in
                let produced = FileManager.default.fileExists(atPath: outputURL.path)
                if proc.terminationStatus == 0 && produced {
                    completion.settle(.success)
                } else {
                    let tail = (try? String(contentsOf: logURL, encoding: .utf8))?
                        .suffix(400) ?? ""
                    completion.settle(.failure("exit \(proc.terminationStatus), file \(produced ? "present" : "missing"): \(tail)"))
                }
            }

            do {
                try process.run()
            } catch {
                completion.settle(.failure("launch failed: \(error.localizedDescription)"))
                return
            }

            // Watchdog: terminate a run that overruns the budget; the handler then
            // reports failure and the app falls back to procedural art.
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning { process.terminate() }
            }
        }

        // The temp working/log dir has served its purpose (the failure tail was
        // already captured into `result`); remove it so runs don't accrete.
        try? fm.removeItem(at: tmpDir)
        return result
    }
}
