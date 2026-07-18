import Foundation

/// The `aihero signal …` subcommand — the ping *writer*. This is what a tool's
/// hook (Codex/Claude/Cursor) or a shell `preexec`/`precmd` invokes to tell the
/// companion what's happening:
///
///     AIhero signal working --tool codex --cwd "$PWD"
///     AIhero signal shipping --tool claude
///     AIhero signal idle
///
/// It writes one ping to the on-device transport and exits. It never blocks, never
/// touches the network, and carries only the activity *verb* (plus advisory tool /
/// cwd) — never any prompt or code content.
enum ActivitySignalCLI {
    /// Runs the subcommand with the args *after* `signal`. Returns a process exit
    /// code: 0 success, 2 usage error, 1 write failure. `directory` is overridable
    /// so tests exercise the success path without writing to the real `~/.aihero/`.
    static func run(_ args: [String],
                    to directory: URL = ActivityTransport.defaultDirectory) -> Int32 {
        guard let verb = args.first, !verb.hasPrefix("-") else {
            printUsage()
            return 2
        }
        // Validate against the accepted vocabulary so misconfigured hooks fail
        // loudly at setup time rather than silently emitting ignored pings.
        guard WorkState(signalName: verb) != nil else {
            FileHandle.standardError.write(Data("aihero signal: unknown state '\(verb)'\n".utf8))
            printUsage()
            return 2
        }

        var tool: String?
        var cwd: String?
        var i = 1
        while i < args.count {
            switch args[i] {
            case "--tool":
                tool = value(after: i, in: args); i += 2
            case "--cwd":
                cwd = value(after: i, in: args); i += 2
            default:
                i += 1   // ignore unknown flags so future hook templates stay forward-compatible
            }
        }

        let ping = ActivityPing(
            state: verb,
            tool: tool,
            cwd: cwd ?? FileManager.default.currentDirectoryPath,
            at: Date().timeIntervalSince1970)

        do {
            try ActivityTransport.write(ping, to: directory)
            return 0
        } catch {
            FileHandle.standardError.write(Data("aihero signal: \(error.localizedDescription)\n".utf8))
            return 1
        }
    }

    private static func value(after index: Int, in args: [String]) -> String? {
        let next = index + 1
        guard next < args.count, !args[next].hasPrefix("--") else { return nil }
        return args[next]
    }

    private static func printUsage() {
        let usage = """
        usage: AIhero signal <idle|thinking|working|shipping|waiting> [--tool NAME] [--cwd PATH]
          Emits one on-device activity ping to the AIhero companion. Nothing is uploaded.
        """
        FileHandle.standardError.write(Data((usage + "\n").utf8))
    }
}
