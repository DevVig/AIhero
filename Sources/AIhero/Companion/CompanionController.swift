import AppKit
import SwiftUI
import Combine

/// Owns the companion panel's lifecycle: creation, bottom-right landing,
/// scaling, drag-persisted position, and the mission menu shown on click. It
/// observes `AppModel` so showing/hiding, switching heroes, and rescaling all
/// flow from state changes.
@MainActor
final class CompanionController {
    private let model: AppModel
    private var panel: CompanionPanel?
    private var hostingView: CompanionHostingView<CompanionView>?
    private var cancellables = Set<AnyCancellable>()
    private var didRestoreFrame = false

    /// Wired by WindowManager so the mission menu can reach the other surfaces.
    var onOpenShelf: (() -> Void)?
    var onForge: (() -> Void)?

    /// When on, the hero ignores clicks so it never blocks the desktop beneath
    /// it. Exposed through the menu bar (not the hero) so it can always be
    /// switched back off.
    private(set) var isClickThrough = false

    func toggleClickThrough() {
        setClickThrough(!isClickThrough)
    }

    func setClickThrough(_ on: Bool) {
        isClickThrough = on
        panel?.ignoresMouseEvents = isClickThrough
    }

    private static let frameAutosaveName = "AIheroCompanionFrame"

    init(model: AppModel) {
        self.model = model
        observe()
    }

    func syncInitial() {
        if model.isCompanionVisible && model.activeHero != nil {
            show()
        }
    }

    // MARK: - Observation

    private func observe() {
        model.$isCompanionVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in
                if visible { self?.show() } else { self?.hide() }
            }
            .store(in: &cancellables)

        model.$companionScale
            .receive(on: RunLoop.main)
            .dropFirst()
            .sink { [weak self] _ in self?.applyScale() }
            .store(in: &cancellables)
    }

    // MARK: - Panel

    private func ensurePanel() {
        guard panel == nil else { return }
        let size = contentSize()
        let panel = CompanionPanel(contentRect: NSRect(origin: .zero, size: size))
        let host = CompanionHostingView(rootView: CompanionView(model: model))
        host.onClick = { [weak self] in self?.showMissionMenu() }
        panel.contentView = host
        self.hostingView = host
        self.panel = panel
    }

    private func contentSize() -> NSSize {
        let height = model.companionHeight * 1.2 + 24   // room for ring + burst
        let width = model.companionHeight * 0.98
        return NSSize(width: width, height: height)
    }

    func show() {
        ensurePanel()
        guard let panel else { return }
        if !didRestoreFrame {
            didRestoreFrame = true
            if !panel.setFrameUsingName(CompanionController.frameAutosaveName) {
                positionBottomRight(panel)
            }
            panel.setFrameAutosaveName(CompanionController.frameAutosaveName)
            // A frame saved on a since-disconnected display would restore
            // off-screen, hiding the hero with no way back — re-land it if so.
            clampToVisibleScreen(panel)
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func positionBottomRight(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = contentSize()
        let x = visible.maxX - size.width - 32
        let y = visible.minY + 28
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    private func applyScale() {
        guard let panel else { return }
        let old = panel.frame
        let size = contentSize()
        // Keep the hero's feet anchored (bottom-right corner) while rescaling.
        let newX = old.maxX - size.width
        let newY = old.minY
        panel.setFrame(NSRect(x: newX, y: newY, width: size.width, height: size.height),
                       display: true, animate: true)
        clampToVisibleScreen(panel)
    }

    /// Keep the panel on a connected display. If its frame overlaps no screen
    /// (disconnected external, or nudged past an edge), re-land it bottom-right
    /// on the main screen so the hero is always reachable.
    private func clampToVisibleScreen(_ panel: NSPanel) {
        let frame = panel.frame
        let isOnScreen = NSScreen.screens.contains { screen in
            let overlap = screen.visibleFrame.intersection(frame)
            return overlap.width > 20 && overlap.height > 20
        }
        if !isOnScreen { positionBottomRight(panel) }
    }

    // MARK: - Mission menu

    private func showMissionMenu() {
        guard let host = hostingView else { return }
        let menu = buildMissionMenu()
        let point = NSPoint(x: host.bounds.midX, y: host.bounds.maxY)
        menu.popUp(positioning: nil, at: point, in: host)
    }

    private func buildMissionMenu() -> NSMenu {
        let menu = NSMenu()

        if let hero = model.activeHero {
            let header = NSMenuItem(title: "\(hero.name) · \(hero.title)", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            let state = NSMenuItem(title: "State: \(model.workState.label)", action: nil, keyEquivalent: "")
            state.isEnabled = false
            menu.addItem(state)
        }
        menu.addItem(.separator())

        // Switch active hero
        if model.unboxedHeroes.count > 1 {
            let switchItem = NSMenuItem(title: "Switch Hero", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for hero in model.unboxedHeroes {
                let item = NSMenuItem(title: hero.name, action: #selector(switchHero(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = hero.id
                item.state = (hero.id == model.activeHeroID) ? .on : .off
                submenu.addItem(item)
            }
            switchItem.submenu = submenu
            menu.addItem(switchItem)
        }

        // Size
        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for (label, value) in [("Small", 0.7), ("Medium", 1.0), ("Large", 1.4)] {
            let item = NSMenuItem(title: label, action: #selector(setScaleItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = abs(model.companionScale - value) < 0.06 ? .on : .off
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(.separator())
        add(menu, "Open My Heroes…", #selector(openShelf))
        add(menu, "Forge New Hero…", #selector(forge))
        menu.addItem(.separator())
        add(menu, "Rest Companion", #selector(rest))

        return menu
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func switchHero(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID { model.setActive(id) }
    }

    @objc private func setScaleItem(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double { model.setScale(value) }
    }

    @objc private func openShelf() { onOpenShelf?() }
    @objc private func forge() { onForge?() }
    @objc private func rest() { model.isCompanionVisible = false }
}
