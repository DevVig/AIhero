import Foundation
import ServiceManagement

/// Controls whether AIhero opens automatically when the user logs in.
///
/// Two backends, chosen at runtime by how the app is actually running:
/// - **SMAppService** (macOS 13+) when we're inside a real `.app` bundle — the
///   Apple-blessed path, and the user can also manage it in System Settings ▸
///   General ▸ Login Items.
/// - **A LaunchAgent plist** (`~/Library/LaunchAgents/…`) when we're a bare
///   SwiftPM executable with no bundle, which `SMAppService` can't register. The
///   plist points at the current binary, so `swift run` builds start at login too.
///
/// Reads are the source of truth: the Settings toggle reflects the real system
/// state, so a failed or externally-changed setting never desyncs the UI.
enum LoginItemController {
    private static let agentLabel = "com.aihero.LoginItem"

    /// True when the running process lives inside an `.app` bundle (a shipped
    /// build) rather than a raw executable (a `swift run` / `.build` binary).
    private static var isBundled: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    /// Whether launch-at-login is currently active, read from the live system
    /// state rather than a cached preference.
    static var isEnabled: Bool {
        if isBundled {
            return SMAppService.mainApp.status == .enabled
        }
        return FileManager.default.fileExists(atPath: agentPlistURL.path)
    }

    /// Enable or disable launch-at-login. Returns `nil` on success, or a short
    /// human-readable reason on failure (surfaced beneath the Settings toggle).
    @discardableResult
    static func setEnabled(_ on: Bool) -> String? {
        if isBundled {
            do {
                if on { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
                return nil
            } catch {
                return error.localizedDescription
            }
        }
        return on ? installAgent() : removeAgent()
    }

    // MARK: - LaunchAgent fallback (unbundled / dev builds)

    private static var agentPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
    }

    private static func installAgent() -> String? {
        guard let exec = Bundle.main.executablePath else {
            return "Couldn't resolve the app's location."
        }
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": [exec],
            "RunAtLoad": true,
            // Only in a graphical login session — this is a menu-bar app.
            "LimitLoadToSessionType": "Aqua",
        ]
        do {
            try FileManager.default.createDirectory(
                at: agentPlistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: agentPlistURL)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private static func removeAgent() -> String? {
        do {
            if FileManager.default.fileExists(atPath: agentPlistURL.path) {
                try FileManager.default.removeItem(at: agentPlistURL)
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
