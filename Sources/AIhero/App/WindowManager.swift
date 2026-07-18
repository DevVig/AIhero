import AppKit

/// Top-level coordinator. Owns the model and every surface (menu bar, shelf,
/// companion, reveal) and wires the actions that cross between them, so no
/// controller needs to know about any other.
@MainActor
final class WindowManager {
    let model = AppModel()
    private lazy var companion = CompanionController(model: model)
    private lazy var shelf = ShelfWindowController(model: model)
    private lazy var reveal = RevealController(model: model)
    private lazy var settings = SettingsWindowController(
        model: model,
        isClickThrough: { [weak self] in self?.companion.isClickThrough ?? false },
        setClickThrough: { [weak self] on in self?.companion.setClickThrough(on) }
    )
    private var menuBar: MenuBarController?

    func start() {
        companion.onOpenShelf = { [weak self] in self?.showShelf() }
        companion.onForge = { [weak self] in self?.showForge() }
        shelf.onOpen = { [weak self] hero in self?.openBox(hero) }

        let actions = MenuBarActions(
            openShelf: { [weak self] in self?.showShelf() },
            forge: { [weak self] in self?.showForge() },
            toggleCompanion: { [weak self] in self?.toggleCompanion() },
            switchHero: { [weak self] id in self?.model.setActive(id) },
            toggleClickThrough: { [weak self] in self?.companion.toggleClickThrough() },
            isClickThrough: { [weak self] in self?.companion.isClickThrough ?? false },
            openSettings: { [weak self] in self?.settings.show() }
        )
        let menuBar = MenuBarController(model: model, actions: actions)
        menuBar.install()
        self.menuBar = menuBar

        companion.syncInitial()

        // First run: open the shelf so there's an obvious next step.
        if model.heroes.isEmpty {
            showShelf()
        }
    }

    private func showShelf() { shelf.show() }
    private func showForge() { shelf.show(forge: true) }

    private func toggleCompanion() {
        if model.activeHero == nil {
            showShelf()
            return
        }
        model.isCompanionVisible.toggle()
    }

    /// Opening a sealed box plays the reveal, then unboxes and lands the hero as
    /// the active desktop companion.
    private func openBox(_ hero: Hero) {
        reveal.play(for: hero) { [weak self] in
            self?.model.unbox(hero.id)
        }
    }
}
