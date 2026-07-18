import SwiftUI

/// The tiny setup surface. Pick which local signals contribute and (optionally)
/// a name, then forge. Generation is instant and on-device; the result drops
/// onto the shelf as a sealed collectible waiting to be opened.
struct ForgeView: View {
    @ObservedObject var model: AppModel
    var onForged: (Hero) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selected: Set<Source>
    @State private var previewHero: Hero
    @State private var artDirection: ArtDirection = .auto
    // Probed once at present time: which image harnesses this user actually has.
    @State private var imageHarnesses: [ImageHarness]
    @State private var selectedHarnessID: String?
    // Advisory: did the selected harness answer a `--version` ping? nil = unknown
    // / still checking, true = runs, false = present but unresponsive. Never gates
    // Forge — a hero always forges and falls back to its built-in art if needed.
    @State private var harnessResponsive: Bool? = nil

    init(model: AppModel, onForged: @escaping (Hero) -> Void) {
        self.model = model
        self.onForged = onForged
        let initial = model.enabledSources.isEmpty ? Set(Source.allCases) : model.enabledSources
        _selected = State(initialValue: initial)
        _previewHero = State(initialValue: HeroForge.forge(name: nil,
                                                           sources: Array(initial).sorted { $0.rawValue < $1.rawValue },
                                                           salt: 1))
        let harnesses = HarnessProbe.availableImageHarnesses()
        _imageHarnesses = State(initialValue: harnesses)
        _selectedHarnessID = State(initialValue: harnesses.first?.id)
    }

    /// The harness the forge will use, if any (defaults to the first detected).
    private var selectedHarness: ImageHarness? {
        imageHarnesses.first { $0.id == selectedHarnessID } ?? imageHarnesses.first
    }

    var body: some View {
        HStack(spacing: 0) {
            preview
            Divider()
            controls
        }
        .frame(width: 640, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var preview: some View {
        ZStack {
            LinearGradient(colors: [Palette(seed: previewHero.genome.paletteSeed).deep.opacity(0.55),
                                    .black.opacity(0.9)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 10) {
                HeroPortrait(hero: previewHero, aura: true)
                    .frame(height: 216)
                    .id(previewHero.id)
                    .transition(.scale.combined(with: .opacity))
                VStack(alignment: .leading, spacing: 5) {
                    Text(previewHero.name)
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    Text(previewHero.title.uppercased())
                        .font(.system(size: 9, weight: .semibold)).tracking(1.5)
                        .foregroundStyle(Palette(seed: previewHero.genome.paletteSeed).accent)
                    Text(previewHero.personalityText)
                        .font(.system(size: 10).italic())
                        .foregroundStyle(Palette(seed: previewHero.genome.paletteSeed).glow.opacity(0.95))
                        .lineSpacing(1).lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)
                    Text(previewHero.originStory)
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.82))
                        .lineSpacing(2).lineLimit(9)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 16)
        }
        .frame(width: 280)
        .clipped()
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Forge a Hero").font(.system(size: 22, weight: .bold))
                Text("Assembled on this device from the signals you choose.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("NAME").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                TextField("Optional — leave blank to let the forge name it", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("SIGNALS").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Source.allCases) { source in
                        sourceChip(source)
                    }
                }
            }

            portraitSection

            Label("Nothing is uploaded. Sources are read locally, only while enabled.",
                  systemImage: "lock.fill")
                .font(.system(size: 11)).foregroundStyle(.secondary)

            Spacer()

            HStack {
                Button("Reroll Preview") { reroll() }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Forge") { forge() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    /// Portrait rendering options. If the user has no image-capable harness, the
    /// hero simply keeps its built-in illustrated look; otherwise they pick a
    /// style, and (only when more than one harness is present) which renders it.
    @ViewBuilder private var portraitSection: some View {
        if imageHarnesses.isEmpty {
            Label("No image harness detected — using the built-in illustrated art.",
                  systemImage: "paintpalette")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("PORTRAIT").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Picker("Style", selection: $artDirection) {
                    ForEach(ArtDirection.allCases) { direction in
                        Text(direction.title).tag(direction)
                    }
                }
                .labelsHidden()
                if imageHarnesses.count > 1 {
                    Picker("Rendered by", selection: $selectedHarnessID) {
                        ForEach(imageHarnesses) { harness in
                            Text(harness.displayName).tag(Optional(harness.id))
                        }
                    }
                } else {
                    Text("Rendered on-device by \(imageHarnesses[0].displayName), under your own login.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if harnessResponsive == false {
                    Label("\(selectedHarness?.displayName ?? "The harness") didn't respond — your hero will forge now and keep its built-in art if generation can't run.",
                          systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11)).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .task(id: selectedHarnessID) { await checkHarnessResponsive() }
        }
    }

    /// Advisory only: ping the selected harness so the copy can warn if it's
    /// installed but won't run. Never blocks or disables forging.
    private func checkHarnessResponsive() async {
        guard let harness = selectedHarness else { return }
        harnessResponsive = nil
        harnessResponsive = await HarnessProbe.probeRunnable(harness)
    }

    private func sourceChip(_ source: Source) -> some View {
        let isOn = selected.contains(source)
        return Button {
            if isOn { selected.remove(source) } else { selected.insert(source) }
            reroll()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: source.symbol).frame(width: 16)
                Text(source.displayName).font(.system(size: 12, weight: .medium))
                Spacer(minLength: 0)
                if isOn { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(isOn ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(isOn ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func sortedSelection() -> [Source] {
        Array(selected).sorted { $0.rawValue < $1.rawValue }
    }

    private func reroll() {
        let salt = UInt64.random(in: 1...UInt64.max)
        let name = self.name.trimmingCharacters(in: .whitespaces)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            previewHero = HeroForge.forge(name: name.isEmpty ? nil : name,
                                          sources: sortedSelection(), salt: salt)
        }
    }

    private func forge() {
        model.enabledSources = selected
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let hero = model.forge(name: trimmed.isEmpty ? nil : trimmed,
                               sources: sortedSelection(),
                               artDirection: artDirection,
                               harness: selectedHarness)
        // No dismiss(): the parent transitions this same sheet to the Forging
        // Chamber, which narrates the identity beats and the art render before
        // handing off to the Reveal. (Cancel still dismisses outright.)
        onForged(hero)
    }
}
