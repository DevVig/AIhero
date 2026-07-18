import Foundation

/// A local signal source AIhero can (with consent) learn from. In the shipping
/// product each of these is a consented connector feeding the private identity
/// forge; here they are the flavor inputs that bias hero generation and appear
/// in the origin story. Nothing is scraped — the user chooses which contribute.
enum Source: String, Codable, CaseIterable, Identifiable, Hashable {
    case codex
    case claudeCode
    case cursor
    case ghostty
    case cmux
    case t3code

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claudeCode: return "Claude Code"
        case .cursor: return "Cursor"
        case .ghostty: return "Ghostty"
        case .cmux: return "cmux"
        case .t3code: return "T3 Code"
        }
    }

    /// SF Symbol used as a small connector chip.
    var symbol: String {
        switch self {
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .claudeCode: return "terminal"
        case .cursor: return "cursorarrow.rays"
        case .ghostty: return "apple.terminal"
        case .cmux: return "square.split.2x2"
        case .t3code: return "cube.transparent"
        }
    }

    /// A one-word trait this source tends to push a hero toward — used only for
    /// origin-story flavor, never as a behavioral claim.
    var trait: String {
        switch self {
        case .codex: return "precision"
        case .claudeCode: return "reasoning"
        case .cursor: return "velocity"
        case .ghostty: return "focus"
        case .cmux: return "orchestration"
        case .t3code: return "craft"
        }
    }
}
