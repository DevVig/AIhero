import AppKit
import SwiftUI

/// Manages the single Settings window, reached from the menu-bar icon's
/// right-click options menu. Like the shelf, it's a normal window we activate
/// explicitly because the app is a menu-bar accessory.
@MainActor
final class SettingsWindowController {
    private let model: AppModel
    private let isClickThrough: () -> Bool
    private let setClickThrough: (Bool) -> Void
    private var window: NSWindow?

    init(model: AppModel,
         isClickThrough: @escaping () -> Bool,
         setClickThrough: @escaping (Bool) -> Void) {
        self.model = model
        self.isClickThrough = isClickThrough
        self.setClickThrough = setClickThrough
    }

    func show() {
        ensureWindow()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func ensureWindow() {
        guard window == nil else { return }
        let root = SettingsView(model: model,
                                isClickThrough: isClickThrough,
                                setClickThrough: setClickThrough,
                                isLaunchAtLogin: { LoginItemController.isEnabled },
                                setLaunchAtLogin: { LoginItemController.setEnabled($0) })
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.title = "AIhero — Settings"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("AIheroSettingsWindow")
        self.window = window
    }
}
