import os

/// Lightweight structured logging over the unified logging system. One subsystem,
/// a category per area, inspectable in Console.app or `log stream --predicate
/// 'subsystem == "ai.aihero.companion"'` — no home-grown log files to manage.
///
/// Privacy discipline matches the product: the *content* of a hero (its name,
/// origin story, and the generation prompt) is never logged. Only diagnostics —
/// counts, states, error descriptions, and file basenames — are emitted, marked
/// `.public` so they're actually readable on the user's own machine.
enum Log {
    private static let subsystem = "ai.aihero.companion"
    static let model = Logger(subsystem: subsystem, category: "model")
    static let art = Logger(subsystem: subsystem, category: "art")
    static let login = Logger(subsystem: subsystem, category: "login")
}
