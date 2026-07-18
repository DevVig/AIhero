import AppKit
import Foundation

// `AIhero --version` prints the version and exits. When run as a packaged `.app`
// this reflects the bundle's CFBundleShortVersionString; from a bare SwiftPM
// build it's the dev fallback. Handy for release scripts and support.
if CommandLine.arguments.contains("--version") {
    print(AIheroInfo.version)
    exit(0)
}

// `AIhero signal <state> [--tool NAME] [--cwd PATH]` — the activity-ping writer.
// Invoked by a tool's hook or the shell to tell the running companion what's
// happening. Writes one on-device ping and exits; never launches the UI. Kept
// first so it stays a fast, no-side-effect CLI. Nothing is uploaded.
if CommandLine.arguments.count > 1, CommandLine.arguments[1] == "signal" {
    exit(ActivitySignalCLI.run(Array(CommandLine.arguments.dropFirst(2))))
}

// Headless end-to-end forge check: `AIhero --forge-test` forges a hero, probes
// for an image harness, runs one real bespoke-art generation under the user's
// own login, and reports where the PNG landed. Used to validate the pipeline
// without launching the UI. Nothing is uploaded and no key is used.
if CommandLine.arguments.contains("--forge-test") {
    let harnesses = HarnessProbe.availableImageHarnesses()
    guard let harness = harnesses.first else {
        FileHandle.standardError.write(Data("forge-test: no image harness detected\n".utf8))
        exit(2)
    }
    let hero = HeroForge.forge(name: "Aegis Prime",
                               sources: Array(Source.allCases),
                               salt: 7,
                               artDirection: .cinematic)
    let outURL = HeroArtStore.artURL(for: hero.id)
    let prompt = HeroPromptBuilder.transparentHeroPrompt(
        for: hero, direction: hero.artDirection, outputPath: outURL.path)
    print("forge-test: forging \"\(hero.name)\" (\(hero.title)) via \(harness.displayName)")
    print("forge-test: output → \(outURL.path)")
    fflush(stdout)

    let semaphore = DispatchSemaphore(value: 0)
    var outcome = "unknown"
    // Detached so the work runs on the cooperative pool, not the main thread we
    // block below with semaphore.wait().
    Task.detached {
        let result = await HeroArtGenerator.generate(
            harness: harness, prompt: prompt, outputURL: outURL, timeout: 480)
        switch result {
        case .success:            outcome = "SUCCESS \(outURL.path)"
        case .failure(let error): outcome = "FAILURE \(error)"
        }
        semaphore.signal()
    }
    semaphore.wait()
    print("forge-test: \(outcome)")
    exit(outcome.hasPrefix("SUCCESS") ? 0 : 1)
}

// Offscreen visual-QA mode: `AIhero --render [outdir]` renders the SwiftUI
// surfaces to PNGs and exits, without starting the menu-bar app.
if let flagIndex = CommandLine.arguments.firstIndex(of: "--render") {
    let outPath = CommandLine.arguments.count > flagIndex + 1
        ? CommandLine.arguments[flagIndex + 1]
        : NSTemporaryDirectory() + "aihero-shots"
    let outURL = URL(fileURLWithPath: outPath, isDirectory: true)
    MainActor.assumeIsolated {
        RenderHarness.renderAll(to: outURL)
    }
    exit(0)
}

// AIhero is a menu-bar-resident macOS companion. It has no Dock icon and no
// main window by default — the hero lives on the desktop as a floating figure,
// and everything else is reached from the menu bar. `.accessory` gives us that
// LSUIElement behavior without needing an Info.plist, so the app runs straight
// from a SwiftPM build during development.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
