import AppKit
import SwiftUI
import Combine

struct MenuBarActions {
    var openShelf: () -> Void
    var forge: () -> Void
    var toggleCompanion: () -> Void
    var switchHero: (UUID) -> Void
    var toggleClickThrough: () -> Void
    var isClickThrough: () -> Bool
    var openSettings: () -> Void
}

/// The menu-bar presence. This is the single place operational state lives:
/// current hero, activity signal, and controls. Keeping tracking here lets the
/// desktop companion stay purely a character.
///
/// Click behavior is split: a **left-click** opens the hero menu (summon, forge,
/// switch, quick toggles); a **right-click** (or Control-click) opens the app
/// options menu (Settings, About, Quit). Both menus are built fresh per click so
/// they always reflect live state.
@MainActor
final class MenuBarController: NSObject {
    private let model: AppModel
    private let actions: MenuBarActions
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    init(model: AppModel, actions: MenuBarActions) {
        self.model = model
        self.actions = actions
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bolt.circle.fill",
                                   accessibilityDescription: "AIhero")
            button.image?.isTemplate = true
            // Route both mouse buttons through our handler so we can distinguish
            // left (hero menu) from right (options menu). Assigning `item.menu`
            // instead would pop the same menu on any click and swallow the event.
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        // Tint the menu-bar glyph with the live work state so activity is
        // glanceable even without opening the menu.
        model.$workState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.applyTint(state) }
            .store(in: &cancellables)
    }

    /// Left-click → hero menu, right/Control-click → options menu. We assign the
    /// chosen menu to the status item and re-send the click so macOS renders it
    /// with the native highlighted-status-item appearance, then detach it so the
    /// next click flows back through this handler.
    @objc private func statusItemClicked() {
        guard let item = statusItem, let button = item.button else { return }
        let event = NSApp.currentEvent
        let wantsOptions = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        item.menu = wantsOptions ? buildOptionsMenu() : buildMainMenu()
        button.performClick(nil)
        item.menu = nil
    }

    private func applyTint(_ state: WorkState) {
        guard let button = statusItem?.button else { return }
        if state == .idle {
            button.image?.isTemplate = true
            button.contentTintColor = nil
        } else {
            button.image?.isTemplate = false
            button.contentTintColor = NSColor(state.tint)
        }
    }

    // MARK: - Menus

    /// Left-click: everything to do with the hero(es) themselves.
    private func buildMainMenu() -> NSMenu {
        let menu = NSMenu()

        if let hero = model.activeHero {
            addInfo(menu, "\(hero.name) · \(hero.title)")
            addInfo(menu, "Activity: \(model.workState.label) · \(model.signalIsLive ? "live" : "simulated")")
        } else {
            addInfo(menu, "No hero on the desktop yet")
        }
        menu.addItem(.separator())

        let toggleTitle = model.isCompanionVisible ? "Rest Companion" : "Summon Companion"
        add(menu, toggleTitle, #selector(toggleCompanion), enabled: model.activeHero != nil)
        add(menu, "Open My Heroes…", #selector(openShelf))
        add(menu, "Forge a Hero…", #selector(forge))

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

        menu.addItem(.separator())

        let clickThrough = add(menu, "Companion Click-Through", #selector(toggleClickThrough))
        clickThrough.state = actions.isClickThrough() ? .on : .off

        let sim = add(menu, "Simulate Activity", #selector(toggleSimulation))
        sim.state = model.simulateActivity ? .on : .off

        menu.addItem(.separator())
        addInfo(menu, "Right-click for Settings & Quit")
        return menu
    }

    /// Right-click (or Control-click): app-level options.
    private func buildOptionsMenu() -> NSMenu {
        let menu = NSMenu()
        addInfo(menu, "AIhero \(AIheroInfo.versionString)")
        menu.addItem(.separator())
        add(menu, "Settings…", #selector(openSettings)).keyEquivalent = ","
        let login = add(menu, "Launch at Login", #selector(toggleLaunchAtLogin))
        login.state = LoginItemController.isEnabled ? .on : .off
        add(menu, "About AIhero", #selector(showAbout))
        menu.addItem(.separator())
        let quit = add(menu, "Quit AIhero", #selector(NSApplication.terminate(_:)), target: NSApp)
        quit.keyEquivalent = "q"
        return menu
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector,
                     target: AnyObject? = nil, enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target ?? self
        item.isEnabled = enabled
        menu.addItem(item)
        return item
    }

    private func addInfo(_ menu: NSMenu, _ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func toggleCompanion() { actions.toggleCompanion() }
    @objc private func openShelf() { actions.openShelf() }
    @objc private func forge() { actions.forge() }
    @objc private func openSettings() { actions.openSettings() }
    @objc private func toggleClickThrough() { actions.toggleClickThrough() }
    @objc private func toggleSimulation() { model.setSimulateActivity(!model.simulateActivity) }
    @objc private func toggleLaunchAtLogin() {
        _ = LoginItemController.setEnabled(!LoginItemController.isEnabled)
    }
    @objc private func switchHero(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID { actions.switchHero(id) }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "AIhero",
            .applicationVersion: AIheroInfo.version,
            .credits: NSAttributedString(
                string: "Your on-device superhero companion.\nNothing leaves your Mac.",
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            ),
        ])
    }
}
