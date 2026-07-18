import SwiftUI
import Combine

/// Where a hero's bespoke portrait stands in its lifecycle. Drives the small
/// "forging portrait…" affordance and, on failure, the graceful fall back to
/// procedural art (which is always already on screen underneath).
enum ArtGenStatus: Equatable {
    case generating
    case ready
    case failed(String)
}

/// The single source of truth for the app: the roster of forged heroes, which
/// one is active on the desktop, the current work signal, and companion
/// settings. Everything persists locally to Application Support — nothing about
/// a hero or the roster ever leaves the machine.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var heroes: [Hero] = []
    @Published var activeHeroID: UUID?
    @Published var workState: WorkState = .idle
    @Published var companionScale: Double = 1.0          // 0.6 ... 1.8
    @Published var enabledSources: Set<Source> = Set(Source.allCases)
    @Published var isCompanionVisible: Bool = false
    @Published var simulateActivity: Bool = true

    /// True once a real activity signal has arrived this session. From then on the
    /// ring is driven by the tools you actually run, and the simulated wander
    /// stands down — so the UI can honestly say "live" vs "simulated".
    @Published private(set) var signalIsLive: Bool = false

    /// Per-hero bespoke-portrait generation state. Absent means "not started /
    /// procedural only". Published so the shelf and companion reflect progress.
    @Published var artGenerationStatus: [UUID: ArtGenStatus] = [:]

    /// Base companion height in points at scale 1.0. Small by design — a desktop
    /// companion, never a second window.
    static let baseCompanionHeight: CGFloat = 132

    private var workTimer: Timer?
    private let stateURL: URL
    /// The real app vs. a temp/test/render model. Only the production model watches
    /// the shared activity file and may spawn a bespoke-art harness subprocess (on
    /// forge or evolve), so tests and offscreen QA never touch either.
    private let isProduction: Bool

    // MARK: Evolution
    /// XP granted per gap of real work, and how often it can be granted — a gentle
    /// pace so a level is a session's worth of work, not a click. Only real signals
    /// (ambient or ping) earn XP; the simulated wander never does.
    private let xpGrant = 10
    private let xpGrantInterval: TimeInterval = 15
    private var lastXPGrantAt: Date?

    /// XP needed to evolve from `level` to the next. Grows with level so later
    /// evolutions feel earned. Tunable.
    func xpForNextLevel(_ level: Int) -> Int { max(1, level) * 30 }

    /// Whether a hero has banked enough real-work XP to evolve right now.
    func canEvolve(_ hero: Hero) -> Bool { hero.xp >= xpForNextLevel(hero.level) }

    /// Listens for on-device activity pings from the user's tools (only the
    /// production model owns one; temp/test models pass a `stateURL` override).
    private var activityListener: ActivitySignalListener?
    /// Read-only ambient detector: infers busy↔idle from the recency of your enabled
    /// tools' OWN session logs (mtime only — never their contents), adding nothing to
    /// any tool's config. Production model only.
    private var ambientReader: AmbientActivityReader?
    private var lastRealSignalAt: Date?
    /// After this much silence a live ring relaxes back to idle.
    private let realSignalTimeout: TimeInterval = 45

    /// Bespoke-art generation is serialized: each run is a heavy full-access
    /// harness subprocess, so forging several heroes at once must not spawn a
    /// subprocess per hero. Requests queue and run one at a time.
    private var artQueue: [(id: UUID, harness: ImageHarness)] = []
    private var artTasks: [UUID: Task<Void, Never>] = [:]
    private var activeArtGenerations = 0
    private let maxConcurrentArtGenerations = 1

    var activeHero: Hero? { heroes.first { $0.id == activeHeroID } }
    var unboxedHeroes: [Hero] { heroes.filter(\.isUnboxed) }
    var companionHeight: CGFloat { AppModel.baseCompanionHeight * companionScale }

    /// `stateURL` can be overridden (e.g. a temp file for the render harness or
    /// tests) so those paths never touch the user's real roster.
    init(stateURL override: URL? = nil) {
        stateURL = override ?? AppModel.makeStateURL()
        isProduction = (override == nil)
        load()
        startWorkSimulation()
        // Only the real app watches the shared activity file; temp/test models
        // (which pass an override) never touch it.
        if isProduction { startActivityMonitoring() }
    }

    // MARK: - Mutations

    @discardableResult
    func forge(name: String?,
               sources: [Source],
               artDirection: ArtDirection = .auto,
               harness: ImageHarness? = nil) -> Hero {
        let salt = SeedHash.combine(
            UInt64(heroes.count),
            UInt64(bitPattern: Int64(Date().timeIntervalSince1970 * 1000))
        )
        let hero = HeroForge.forge(name: name, sources: sources,
                                   salt: salt, artDirection: artDirection)
        heroes.append(hero)
        save()
        // Bespoke portrait is best-effort: if a harness is available we kick off
        // generation in the background; the hero is fully usable meanwhile with
        // its procedural look, and nothing blocks on the harness.
        if let harness {
            startArtGeneration(for: hero, using: harness)
        }
        return hero
    }

    /// Queue bespoke-art generation for a hero. The hero is fully usable meanwhile
    /// with its procedural look; on success the finished PNG lands next to the
    /// hero and `HeroFigure` swaps it in, on failure we keep the procedural art
    /// and surface a retry affordance.
    func startArtGeneration(for hero: Hero, using harness: ImageHarness) {
        enqueueArtGeneration(id: hero.id, harness: harness)
    }

    /// Re-run generation for a hero whose portrait failed (or was never made).
    /// Re-probes for a harness so a since-installed/fixed Codex is picked up.
    func retryArtGeneration(for id: UUID) {
        guard heroes.contains(where: { $0.id == id }) else { return }
        guard let harness = HarnessProbe.availableImageHarnesses().first else {
            artGenerationStatus[id] = .failed("No image harness detected.")
            return
        }
        enqueueArtGeneration(id: id, harness: harness)
    }

    private func enqueueArtGeneration(id: UUID, harness: ImageHarness) {
        // Idempotent: don't double-queue a hero that's already generating/waiting.
        guard artTasks[id] == nil, !artQueue.contains(where: { $0.id == id }) else { return }
        artGenerationStatus[id] = .generating   // reflects "queued" too, which reads as in-progress
        artQueue.append((id, harness))
        pumpArtQueue()
    }

    private func pumpArtQueue() {
        guard activeArtGenerations < maxConcurrentArtGenerations, !artQueue.isEmpty else { return }
        let (id, harness) = artQueue.removeFirst()
        guard let hero = heroes.first(where: { $0.id == id }) else {
            pumpArtQueue()   // hero was released while queued; skip it
            return
        }
        activeArtGenerations += 1
        let outputURL = HeroArtStore.artURL(for: id)
        let prompt = HeroPromptBuilder.transparentHeroPrompt(
            for: hero, direction: hero.artDirection, outputPath: outputURL.path)
        let task = Task { [weak self] in
            let result = await HeroArtGenerator.generate(
                harness: harness, prompt: prompt, outputURL: outputURL)
            guard let self else { return }
            switch result {
            case .success:
                HeroArtStore.invalidate(id)
                self.artGenerationStatus[id] = .ready
                Log.art.info("Bespoke portrait ready for \(id, privacy: .public)")
            case .failure(let message):
                self.artGenerationStatus[id] = .failed(message)
                // The message can carry a log tail; keep it private (it may echo
                // prompt fragments) while noting the failure publicly.
                Log.art.error("Portrait generation failed for \(id, privacy: .public): \(message, privacy: .private)")
            }
            self.artTasks[id] = nil
            self.activeArtGenerations -= 1
            self.pumpArtQueue()   // release the next queued hero
        }
        artTasks[id] = task
    }

    func unbox(_ id: UUID) {
        guard let index = heroes.firstIndex(where: { $0.id == id }) else { return }
        heroes[index].isUnboxed = true
        activeHeroID = id
        isCompanionVisible = true
        save()
    }

    func setActive(_ id: UUID) {
        guard let hero = heroes.first(where: { $0.id == id }), hero.isUnboxed else { return }
        activeHeroID = id
        isCompanionVisible = true
    }

    func remove(_ id: UUID) {
        heroes.removeAll { $0.id == id }
        if activeHeroID == id { activeHeroID = unboxedHeroes.first?.id }
        save()
    }

    func setScale(_ scale: Double) {
        companionScale = min(max(scale, 0.6), 1.8)
        save()
    }

    func setSimulateActivity(_ on: Bool) {
        simulateActivity = on
        save()
    }

    /// Toggle a signal AIhero is allowed to read locally. Persisted so the consent
    /// choice survives relaunches, and pushed to the ambient reader immediately so a
    /// disabled tool stops being read at once.
    func setSourceEnabled(_ source: Source, _ enabled: Bool) {
        if enabled { enabledSources.insert(source) } else { enabledSources.remove(source) }
        ambientReader?.setEnabledSources(enabledSources)
        save()
    }

    // MARK: - Activity signals (real) + simulation (fallback)

    /// Begin the on-device, read-only activity monitors. Two sources, both local:
    /// an optional ping transport (an integration point AIhero *reads*, never
    /// installs), and the ambient reader that watches the recency of your enabled
    /// tools' own logs. Neither writes to any tool's config; neither touches the
    /// network.
    private func startActivityMonitoring() {
        let listener = ActivitySignalListener { [weak self] ping in
            Task { @MainActor in self?.receiveActivityPing(ping) }
        }
        listener.start()
        activityListener = listener

        let reader = AmbientActivityReader { [weak self] in
            Task { @MainActor in self?.receiveAmbientBusy() }
        }
        reader.setEnabledSources(enabledSources)
        reader.start()
        ambientReader = reader
    }

    /// Apply a real activity ping. From the first recognized ping onward this
    /// takes over from the simulated wander for the rest of the session.
    func receiveActivityPing(_ ping: ActivityPing) {
        guard let state = ping.workState else { return }   // unknown verb: ignore
        lastRealSignalAt = Date()
        if !signalIsLive { signalIsLive = true }
        if state != .idle { grantWorkXP() }   // real work earns the active hero XP
        setWorkState(state)
    }

    /// A read-only ambient reading that one of your enabled tools is actively
    /// writing to its own log right now. Coarse by design: it goes "live" and lifts
    /// an idle ring to `.working`, and refreshes the liveness clock so a genuinely
    /// busy session doesn't decay mid-activity — but it **yields** to any finer state
    /// a ping may have set (`.thinking`/`.waiting`/`.shipping`), never overriding it.
    func receiveAmbientBusy() {
        lastRealSignalAt = Date()
        if !signalIsLive { signalIsLive = true }
        grantWorkXP()   // real work earns the active hero XP toward its next evolution
        if workState == .idle { setWorkState(.working) }
    }

    // MARK: - Evolution

    /// Award XP to a specific hero and persist. Internal so tests can seed evolution
    /// state directly; the live path (`grantWorkXP`) funnels through here.
    func awardXP(_ amount: Int, to id: UUID) {
        guard amount > 0, let index = heroes.firstIndex(where: { $0.id == id }) else { return }
        heroes[index].xp += amount
        save()
    }

    /// Grant the active hero a little XP for real work, rate-limited so it accrues
    /// at a gentle pace rather than on every poll.
    private func grantWorkXP() {
        guard let id = activeHeroID else { return }
        let now = Date()
        if let last = lastXPGrantAt, now.timeIntervalSince(last) < xpGrantInterval { return }
        lastXPGrantAt = now
        awardXP(xpGrant, to: id)
    }

    /// Evolve a hero: spend the level's banked XP, advance a level, and re-forge its
    /// portrait so the art visibly ascends at the new tier. Best-effort art — the
    /// hero keeps its current portrait while the new one renders, and falls back to
    /// it if no harness is available. A no-op if the hero hasn't earned enough XP.
    func evolve(_ id: UUID) {
        guard let index = heroes.firstIndex(where: { $0.id == id }) else { return }
        let hero = heroes[index]
        guard canEvolve(hero) else { return }
        heroes[index].xp = hero.xp - xpForNextLevel(hero.level)
        heroes[index].level = hero.level + 1
        save()
        Log.model.info("Hero \(id, privacy: .public) evolved to level \(self.heroes[index].level, privacy: .public)")
        // Re-forge the portrait at the new tier (production only; tests/QA never
        // spawn the harness subprocess). The level-aware prompt reads hero.level.
        guard isProduction, let harness = HarnessProbe.availableImageHarnesses().first else { return }
        enqueueArtGeneration(id: id, harness: harness)
    }

    private func setWorkState(_ state: WorkState) {
        guard state != workState else { return }
        withAnimation(.easeInOut(duration: 0.35)) { workState = state }
    }

    private func startWorkSimulation() {
        workTimer?.invalidate()
        let timer = Timer(timeInterval: 2.4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickWork() }
        }
        RunLoop.main.add(timer, forMode: .common)
        workTimer = timer
    }

    private func tickWork() {
        // Live mode: real signals drive the ring; here we only relax it back to
        // idle after a stretch of silence. The simulated wander stays out of the way.
        if signalIsLive {
            if workState != .idle, let last = lastRealSignalAt,
               Date().timeIntervalSince(last) > realSignalTimeout {
                setWorkState(.idle)
            }
            return
        }
        // Simulated mode (no real signals yet) — the clearly-labeled wander.
        guard simulateActivity, activeHero != nil else {
            if workState != .idle { workState = .idle }
            return
        }
        // Weighted wander so the ring feels alive but mostly calm.
        let roll = Int.random(in: 0..<10)
        let next: WorkState
        switch roll {
        case 0...4: next = .working
        case 5...7: next = .thinking
        case 8: next = .shipping
        default: next = .idle
        }
        setWorkState(next)
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var heroes: [Hero]
        var activeHeroID: UUID?
        var companionScale: Double
        var enabledSources: [Source]
        var simulateActivity: Bool
    }

    private static func makeStateURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser
        let dir = base.appendingPathComponent("AIhero", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    private func load() {
        let fm = FileManager.default
        // No file yet means a genuine first launch — start empty, silently.
        guard fm.fileExists(atPath: stateURL.path) else { return }

        let data: Data
        do {
            data = try Data(contentsOf: stateURL)
        } catch {
            // The file is there but unreadable (permissions, I/O). Preserve it —
            // never let the next save() clobber a roster we simply couldn't read.
            Log.model.error("state.json unreadable: \(error.localizedDescription, privacy: .public)")
            backupUnusableState(reason: "unreadable")
            return
        }

        do {
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
            heroes = snapshot.heroes
            activeHeroID = snapshot.activeHeroID
            companionScale = min(max(snapshot.companionScale, 0.6), 1.8)
            enabledSources = Set(snapshot.enabledSources)
            simulateActivity = snapshot.simulateActivity
            isCompanionVisible = activeHero != nil
            Log.model.info("Restored \(self.heroes.count, privacy: .public) hero(es) from state.json")
        } catch {
            // Corruption or an incompatible schema. This is the dangerous case for
            // a *collectible*: the old behavior silently reset to empty and the
            // next save() overwrote the file, losing the collection with no trace.
            // Move the bad file aside first so the user (or a future migration)
            // can still recover it, then continue empty.
            Log.model.error("state.json undecodable: \(error.localizedDescription, privacy: .public) — backing up before continuing empty")
            backupUnusableState(reason: "corrupt")
        }
    }

    /// Rename an unusable `state.json` to a timestamped sibling so a subsequent
    /// save can't overwrite it. Best-effort: if the move fails we log and move on
    /// (the alternative — refusing to run — is worse for a toy companion).
    private func backupUnusableState(reason: String) {
        let fm = FileManager.default
        let backup = stateURL.deletingLastPathComponent()
            .appendingPathComponent("state.\(reason)-\(AppModel.timestampSuffix()).json")
        do {
            try fm.moveItem(at: stateURL, to: backup)
            Log.model.notice("Preserved unusable state as \(backup.lastPathComponent, privacy: .public)")
        } catch {
            Log.model.error("Could not back up unusable state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func timestampSuffix() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func save() {
        let snapshot = Snapshot(
            heroes: heroes,
            activeHeroID: activeHeroID,
            companionScale: companionScale,
            enabledSources: Array(enabledSources),
            simulateActivity: simulateActivity
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            Log.model.error("Failed to save state: \(error.localizedDescription, privacy: .public)")
        }
    }
}
