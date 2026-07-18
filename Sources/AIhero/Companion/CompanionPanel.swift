import AppKit
import SwiftUI

/// The transparent, borderless window the hero lives in. It floats above normal
/// windows, shows no title bar or shadow, and its only visible footprint is the
/// hero itself. This is the "Clippy-like" desktop presence: draggable anywhere,
/// scalable, and never a second application window.
final class CompanionPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovableByWindowBackground = false   // we drive dragging manually to keep click-to-open
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // Visible on every Space, and stays out of Mission Control's window list.
        animationBehavior = .none
    }

    // Borderless panels refuse key/main by default; allow key so the mission
    // menu can be driven from clicks without stealing focus from the editor.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Hosting view that owns mouse handling for the companion: a short drag moves
/// the window, a click (no drag) opens the mission menu. We handle this at the
/// AppKit layer so the hero body itself is the entire draggable/clickable
/// surface, with no visible controls competing with the character.
final class CompanionHostingView<Content: View>: NSHostingView<Content> {
    var onClick: (() -> Void)?

    private var mouseDownLocation: NSPoint?
    private var didDrag = false

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownLocation else { return }
        let dx = event.locationInWindow.x - start.x
        let dy = event.locationInWindow.y - start.y
        if (dx * dx + dy * dy) > 9 {   // ~3pt threshold before it counts as a drag
            didDrag = true
            window?.performDrag(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag { onClick?() }
        mouseDownLocation = nil
        didDrag = false
    }
}
