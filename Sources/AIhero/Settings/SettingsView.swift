import SwiftUI

/// AIhero's one settings surface. Deliberately small and on-brand — a menu-bar
/// companion's config, not an admin console. Everything here binds to state the
/// app already owns; nothing leaves the machine.
struct SettingsView: View {
    @ObservedObject var model: AppModel
    /// Click-through lives on the companion controller, not the model, so it's
    /// threaded in as a get/set pair.
    var isClickThrough: () -> Bool
    var setClickThrough: (Bool) -> Void
    /// Launch-at-login is a system setting; read/write it through closures so QA
    /// renders can stub it and never touch the real login-item state.
    var isLaunchAtLogin: () -> Bool
    var setLaunchAtLogin: (Bool) -> String?

    var body: some View {
        ScrollView {
            SettingsContent(model: model,
                            isClickThrough: isClickThrough,
                            setClickThrough: setClickThrough,
                            isLaunchAtLogin: isLaunchAtLogin,
                            setLaunchAtLogin: setLaunchAtLogin)
        }
        .frame(width: 460, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// The settings sections, split out of `SettingsView`'s `ScrollView` so offscreen
/// QA (`ImageRenderer`, which doesn't traverse scroll views) can render them
/// directly.
struct SettingsContent: View {
    @ObservedObject var model: AppModel
    var isClickThrough: () -> Bool
    var setClickThrough: (Bool) -> Void
    var isLaunchAtLogin: () -> Bool
    var setLaunchAtLogin: (Bool) -> String?

    /// Display cache for the login-item state. The setter performs the side
    /// effect then refreshes this from the real system state, so a failed toggle
    /// snaps back and `startupNote` explains why.
    @State private var launchAtLogin = false
    @State private var startupNote = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            companionSection
            heroSection
            startupSection
            activitySection
            signalsSection
            aboutSection
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { launchAtLogin = isLaunchAtLogin() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings").font(.system(size: 22, weight: .bold))
            Text("Tune your companion. All on this device.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    // MARK: - Companion

    private var companionSection: some View {
        section("COMPANION") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Size").font(.system(size: 13))
                    Spacer()
                    Text("\(Int((model.companionScale * 100).rounded()))%")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(get: { model.companionScale },
                                   set: { model.setScale($0) }),
                    in: 0.6...1.8
                )
            }

            Toggle(isOn: Binding(get: isClickThrough, set: setClickThrough)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Click-through").font(.system(size: 13))
                    Text("The hero ignores clicks so it never blocks what's beneath it.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Hero (evolution)

    @ViewBuilder
    private var heroSection: some View {
        if let hero = model.activeHero {
            let evolving = model.artGenerationStatus[hero.id] == .generating
            let ready = model.canEvolve(hero)
            section("HERO") {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(hero.name) · Level \(hero.level)")
                            .font(.system(size: 13, weight: .semibold))
                        Text(evolving
                             ? "Evolving… re-forging the portrait on your Mac (~1–2 min)."
                             : ready
                               ? "Ready to evolve to Level \(hero.level + 1)."
                               : "\(hero.xp) / \(model.xpForNextLevel(hero.level)) XP toward "
                                 + "Level \(hero.level + 1) — earned as you work.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Update") { model.evolve(hero.id) }
                        .disabled(!ready || evolving)
                }
            }
        }
    }

    // MARK: - Startup

    private var startupSection: some View {
        section("STARTUP") {
            Toggle(isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    startupNote = setLaunchAtLogin(newValue) ?? ""
                    launchAtLogin = isLaunchAtLogin()
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at login").font(.system(size: 13))
                    Text("Open AIhero automatically when you sign in to your Mac.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            if !startupNote.isEmpty {
                Text(startupNote)
                    .font(.system(size: 11)).foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Activity

    private var activitySection: some View {
        section("ACTIVITY") {
            // Honest status: is the ring driven by real, read-only signals yet?
            HStack(spacing: 6) {
                Circle()
                    .fill(model.signalIsLive ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)
                Text(model.signalIsLive
                     ? "Live — reading your enabled tools' activity (read-only)."
                     : "Simulated — no tool activity detected yet.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Toggle(isOn: Binding(get: { model.simulateActivity },
                                 set: { model.setSimulateActivity($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Simulate when idle").font(.system(size: 13))
                    Text("When no real tool activity is detected, let the companion's "
                         + "state gently wander so it still feels alive.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Signals

    private var signalsSection: some View {
        section("SIGNALS") {
            Text("The tools AIhero may learn from — to flavor a hero when forging, and "
                 + "(for tools with a local session log, like Codex and Claude Code) to "
                 + "sense when you're working. It reads only activity recency — never "
                 + "message or code content — and never changes your tools' settings. "
                 + "Turn one off and it isn't read. Nothing is uploaded.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ForEach(Source.allCases) { source in
                    Toggle(isOn: Binding(
                        get: { model.enabledSources.contains(source) },
                        set: { model.setSourceEnabled(source, $0) }
                    )) {
                        Label {
                            Text(source.displayName).font(.system(size: 13))
                        } icon: {
                            Image(systemName: source.symbol)
                        }
                    }
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        section("ABOUT") {
            HStack(spacing: 10) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AIhero \(AIheroInfo.versionString)")
                        .font(.system(size: 13, weight: .semibold))
                    Text("On-device superhero companion. Nothing leaves your Mac.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Section chrome

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .semibold)).tracking(1.2)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

/// Lightweight app-identity constants. When running as a packaged `.app` the
/// version is read from the bundle's `CFBundleShortVersionString` (the single
/// source of truth); a bare `swift run` build has no Info dictionary, so it falls
/// back to a dev default.
enum AIheroInfo {
    static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1-dev"
    }
    static var versionString: String { "v\(version)" }
}
