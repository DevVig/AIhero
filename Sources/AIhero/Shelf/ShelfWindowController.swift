import AppKit
import SwiftUI

/// Manages the single "My Heroes" window. This is the only conventional window
/// AIhero shows, and it stays a delightful collectible case rather than an admin
/// surface. Because the app is a menu-bar accessory, we activate explicitly when
/// bringing the shelf forward.
@MainActor
final class ShelfWindowController {
    private let model: AppModel
    let ui = ShelfUIState()
    private var window: NSWindow?

    var onOpen: (Hero) -> Void = { _ in }

    init(model: AppModel) { self.model = model }

    func show(forge: Bool = false) {
        ensureWindow()
        if forge { ui.showingForge = true }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func ensureWindow() {
        guard window == nil else { return }
        let root = ShelfView(model: model, ui: ui, onOpen: { [weak self] hero in
            self?.onOpen(hero)
        })
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "AIhero — My Heroes"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 780, height: 580))
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("AIheroShelfWindow")
        self.window = window
    }
}
