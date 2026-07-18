import AppKit
import SwiftUI

/// Presents the unboxing cinematic on a transparent, click-through full-screen
/// overlay, then tears it down and reports completion so the hero can be
/// unboxed and handed to the desktop companion.
@MainActor
final class RevealController {
    private let model: AppModel
    private var overlay: NSWindow?

    init(model: AppModel) { self.model = model }

    func play(for hero: Hero, completion: @escaping () -> Void) {
        // If a reveal is somehow already up, finish it immediately.
        dismiss()

        let window = makeOverlay()
        let root = RevealView(hero: hero) { [weak self] in
            self?.dismiss()
            completion()
        }
        window.contentView = NSHostingView(rootView: root)
        window.orderFrontRegardless()
        overlay = window
    }

    private func makeOverlay() -> NSPanel {
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let panel = NSPanel(contentRect: frame,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.level = .screenSaver           // above the companion during the reveal
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true      // never blocks the desktop
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }

    private func dismiss() {
        overlay?.orderOut(nil)
        overlay = nil
    }
}
