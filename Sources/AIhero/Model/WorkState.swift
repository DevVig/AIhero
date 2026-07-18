import SwiftUI

/// The activity signal shown as the companion's energy ring and in the menu bar.
/// In the shipping product this is driven by consented harness lifecycle hooks
/// (Codex/Claude Code/Cursor hooks, cmux events, T3 Code's local projections).
/// Until those connectors land it runs in a clearly-labeled simulated mode.
enum WorkState: String, Codable, CaseIterable {
    case idle
    case thinking
    case working
    case shipping
    /// Blocked on you — a permission prompt or a question is waiting for input.
    /// Only ever set from a real signal (hooks map Notification/PermissionRequest
    /// here); the simulated wander never uses it.
    case waiting

    var label: String {
        switch self {
        case .idle: return "Resting"
        case .thinking: return "Thinking"
        case .working: return "Working"
        case .shipping: return "Shipping"
        case .waiting: return "Waiting on you"
        }
    }

    var tint: Color {
        switch self {
        case .idle: return Color(hue: 0.58, saturation: 0.10, brightness: 0.75)
        case .thinking: return Color(hue: 0.62, saturation: 0.70, brightness: 1.0)
        case .working: return Color(hue: 0.14, saturation: 0.85, brightness: 1.0)
        case .shipping: return Color(hue: 0.36, saturation: 0.80, brightness: 1.0)
        case .waiting: return Color(hue: 0.09, saturation: 0.90, brightness: 1.0)
        }
    }

    /// Ring pulse period in seconds; idle barely breathes, shipping is urgent,
    /// waiting is a slow, expectant beat.
    var pulsePeriod: Double {
        switch self {
        case .idle: return 4.0
        case .thinking: return 1.6
        case .working: return 1.0
        case .shipping: return 0.6
        case .waiting: return 2.2
        }
    }

    /// Map an incoming activity-signal verb to a work state. Accepts the canonical
    /// vocabulary plus a few natural synonyms so tool hooks can emit intuitive
    /// names (`push`, `commit`, `permission`, …). Unknown verbs return nil and are
    /// ignored by the listener rather than guessed at.
    init?(signalName raw: String) {
        switch raw.lowercased() {
        case "idle", "stop", "done", "end":            self = .idle
        case "thinking", "prompt", "submit", "think":  self = .thinking
        case "working", "work", "tool", "edit", "run": self = .working
        case "shipping", "ship", "push", "commit":     self = .shipping
        case "waiting", "wait", "notification",
             "permission", "ask", "approval":          self = .waiting
        default: return nil
        }
    }
}
