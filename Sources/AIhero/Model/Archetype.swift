import Foundation

/// The silhouette family drives the procedural portrait's body shape so heroes
/// read as visually distinct at a glance, even scaled down to a desktop figure.
enum Silhouette: String, Codable, CaseIterable {
    case sentinel   // broad-shouldered, grounded
    case vanguard   // lean, forward-leaning, caped
    case oracle     // hooded, tapered
    case artificer  // compact, geometric
    case phantom    // slender, wisp-like
}

/// An "identity lens": the archetype a hero is forged into. This is the
/// role/title layer ("The Orchestrator"), distinct from the hero's codename.
struct Archetype: Identifiable, Codable {
    let id: String
    let title: String
    let tagline: String
    let emblem: String          // SF Symbol for the chest emblem
    let silhouette: Silhouette
    let motifs: [String]        // origin-story seeds
    let powers: [String]        // power pool to draw from
    let nemesis: String         // the force this hero exists to oppose
    let creed: String           // a one-line oath, shown on the dossier

    static let all: [Archetype] = [
        Archetype(
            id: "orchestrator",
            title: "The Orchestrator",
            tagline: "Turns scattered agents into one moving line.",
            emblem: "point.3.connected.trianglepath.dotted",
            silhouette: .sentinel,
            motifs: [
                "born the night a dozen terminals finally moved as one",
                "assembled from the hum of parallel sessions that refused to drift"
            ],
            powers: ["Parallel Command", "Context Weave", "Zero-Drift Sync", "Fleet Recall"],
            nemesis: "the entropy of a dozen sessions drifting out of sync",
            creed: "Many hands, one intent."
        ),
        Archetype(
            id: "refactorer",
            title: "The Refactorer",
            tagline: "Leaves every system cleaner than they found it.",
            emblem: "arrow.triangle.2.circlepath",
            silhouette: .artificer,
            motifs: [
                "forged in a rewrite that never broke a single test",
                "tempered by ten thousand small, fearless renamings"
            ],
            powers: ["Fearless Rename", "Dead-Code Purge", "Invariant Lock", "Seamless Migration"],
            nemesis: "the slow rot of code no one dares to touch",
            creed: "Leave it cleaner than you found it."
        ),
        Archetype(
            id: "debugger",
            title: "The Debugger",
            tagline: "Follows the fault line straight to its source.",
            emblem: "ant.circle",
            silhouette: .oracle,
            motifs: [
                "awoke chasing a heisenbug through a silent stack",
                "sharpened on failures that only happened in production"
            ],
            powers: ["Root-Cause Sight", "Stack Unwind", "Repro Snare", "Silent-Fail Radar"],
            nemesis: "the bug that only breathes in production",
            creed: "Every fault has a first cause."
        ),
        Archetype(
            id: "architect",
            title: "The Architect",
            tagline: "Draws the boundaries the future will thank you for.",
            emblem: "square.grid.3x3.topleft.filled",
            silhouette: .sentinel,
            motifs: [
                "raised amid diagrams that outlived their whiteboards",
                "cut from the first clean seam between two tangled domains"
            ],
            powers: ["Boundary Draw", "Load-Bearing Insight", "Seam Vision", "Decoupling Strike"],
            nemesis: "the tangle that turns one change into a hundred",
            creed: "Draw the line the future will thank you for."
        ),
        Archetype(
            id: "shipper",
            title: "The Shipper",
            tagline: "Closes the loop while others are still opening tabs.",
            emblem: "paperplane.circle",
            silhouette: .vanguard,
            motifs: [
                "made real by a Friday deploy that held all weekend",
                "quickened by the green of a pipeline that finally passed"
            ],
            powers: ["Green Pipeline", "Last-Mile Dash", "Rollback Ward", "Merge Momentum"],
            nemesis: "the branch that never quite ships",
            creed: "Done is a feature."
        ),
        Archetype(
            id: "sentinel",
            title: "The Sentinel",
            tagline: "Guards the boundary between your work and the world.",
            emblem: "shield.lefthalf.filled",
            silhouette: .sentinel,
            motifs: [
                "sworn in the moment a secret almost left the machine",
                "hardened against every prompt that asked for too much"
            ],
            powers: ["Redaction Veil", "Consent Gate", "Local-Only Ward", "Leak Sense"],
            nemesis: "the secret one keystroke from leaving the machine",
            creed: "Nothing leaves without consent."
        ),
        Archetype(
            id: "cartographer",
            title: "The Cartographer",
            tagline: "Maps the codebase no one else dares to enter.",
            emblem: "map",
            silhouette: .oracle,
            motifs: [
                "charted from a monorepo that had swallowed its own history",
                "drawn by tracing one call the whole way down"
            ],
            powers: ["Dependency Map", "Call-Path Trace", "Blast-Radius Read", "Legacy Compass"],
            nemesis: "the monorepo that swallowed its own history",
            creed: "No corner of the map stays blank."
        ),
        Archetype(
            id: "phantom",
            title: "The Phantom",
            tagline: "Moves through the terminal without leaving a trace.",
            emblem: "wand.and.stars",
            silhouette: .phantom,
            motifs: [
                "condensed from keystrokes too fast to see",
                "slipped loose from a session that ran entirely in the background"
            ],
            powers: ["Silent Exec", "Ghost Branch", "Trace-Free Run", "Flow Cloak"],
            nemesis: "the noise that breaks a perfect flow state",
            creed: "Move unseen; leave only the work."
        )
    ]

    static func by(id: String) -> Archetype {
        all.first { $0.id == id } ?? all[0]
    }
}

/// Codename pools. A hero's proper name (e.g. "Vector Nyx") is assembled from
/// these deterministically so it stays stable across relaunches.
enum NamePool {
    static let prefixes = [
        "Vector", "Nyx", "Aegis", "Cipher", "Quanta", "Halcyon", "Rune", "Ember",
        "Solace", "Vertex", "Onyx", "Lumen", "Aria", "Kestrel", "Vesper", "Astra",
        "Corvid", "Delta", "Pyre", "Sable"
    ]
    static let suffixes = [
        "Prime", "Vega", "Nova", "Reign", "Vale", "Storm", "Wren", "Sol",
        "Quill", "Ridge", "Cross", "Fenn", "Locke", "Thorn", "Ash", "Rook"
    ]
}

/// Pools for a hero's personality line: two temperament adjectives, a tell/quirk,
/// and a bearing. Composed deterministically (see `HeroForge.personality`) so a
/// given genome always reads the same way.
enum PersonalityPool {
    /// Lowercase adjectives; two distinct ones lead each personality line.
    static let temperaments = [
        "wry", "unshakeable", "restless", "methodical", "fiercely loyal",
        "quietly intense", "warm but exacting", "stubborn", "playful", "deadpan",
        "patient", "unflappable", "curious to a fault", "relentless", "earnest",
        "mischievous", "guarded", "dryly funny", "calm under fire", "impatient with waste"
    ]
    /// Verb-phrase tells, lowercase, no trailing punctuation.
    static let quirks = [
        "reads the stack trace bottom-up, always",
        "never trusts a green check without reading why",
        "counts problems like heartbeats",
        "collects edge cases like souvenirs",
        "keeps a mental map of every loose thread",
        "narrates the plan out loud, then beats it",
        "double-checks the exits before the entrances",
        "hums when the tests finally pass",
        "treats every TODO as a personal dare",
        "leaves the codebase tidier than the mood they found it in",
        "argues with the compiler like an old friend",
        "measures twice so the merge cuts once"
    ]
    /// Full sentences (with trailing period) on how the hero carries themselves.
    static let bearings = [
        "Carries themselves like the outcome is already decided.",
        "Speaks softly, ships loudly.",
        "Would rather be right at 3am than comfortable at noon.",
        "Answers pressure with a steadier hand.",
        "Moves first, explains later — but always explains.",
        "Believes the quiet path is usually the correct one.",
        "Keeps one eye on the horizon and one on the diff.",
        "Meets every deadline like a dare worth taking.",
        "Never louder than the work, never quieter than the truth.",
        "Treats a hard bug as an invitation, not an insult."
    ]
}
