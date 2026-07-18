import Foundation

/// The on-device identity forge. Given an optional name, the set of consented
/// sources, and a salt (so repeat forges differ), it deterministically produces
/// a fully-formed hero — genome, codename, title, origin story, and powers —
/// with no network call and no image model. All synthesis is local template
/// composition seeded by the genome.
enum HeroForge {
    static func forge(name rawName: String?,
                      sources: [Source],
                      salt: UInt64,
                      artDirection: ArtDirection = .auto) -> Hero {
        let trimmed = rawName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let providedName = (trimmed?.isEmpty == false) ? trimmed : nil

        // Seed blends the chosen name, the selected sources, and a salt so that
        // "same signals" still yields distinct collectibles across forges.
        let sourceSeed = SeedHash.of(sources.map(\.rawValue).sorted().joined(separator: "+"))
        let nameSeed = SeedHash.of(providedName ?? "unnamed")
        let seed = SeedHash.combine(nameSeed, sourceSeed, salt)

        var rng = SeededRNG(seed: seed)

        let archetype = biasedArchetype(for: sources, using: &rng)
        let motifIndex = Int(rng.next() % UInt64(archetype.motifs.count))
        let paletteSeed = rng.next()

        let genome = HeroGenome(
            seed: seed,
            archetypeID: archetype.id,
            silhouette: archetype.silhouette,
            emblem: archetype.emblem,
            paletteSeed: paletteSeed,
            motifIndex: motifIndex
        )

        let codename = providedName ?? generateCodename(using: &rng)
        let powers = choosePowers(from: archetype, sources: sources, using: &rng)
        let story = composeOrigin(
            codename: codename,
            archetype: archetype,
            motifIndex: motifIndex,
            sources: sources,
            paletteSeed: paletteSeed,
            powers: powers,
            using: &rng
        )

        return Hero(
            id: UUID(),
            name: codename,
            title: archetype.title,
            genome: genome,
            originStory: story,
            powers: powers,
            personality: personality(for: genome),
            level: 1,
            xp: 0,
            contributingSources: sources,
            createdAt: Date(),
            isUnboxed: false,
            artDirectionID: artDirection.rawValue
        )
    }

    // MARK: - Composition

    private static func biasedArchetype(for sources: [Source],
                                        using rng: inout SeededRNG) -> Archetype {
        // A light bias: certain sources nudge toward a matching archetype, but
        // the seed still decides, so results stay varied.
        var pool = Archetype.all
        if sources.contains(.cmux) { pool += [Archetype.by(id: "orchestrator")] }
        if sources.contains(.claudeCode) { pool += [Archetype.by(id: "debugger")] }
        if sources.contains(.t3code) { pool += [Archetype.by(id: "refactorer")] }
        if sources.contains(.ghostty) { pool += [Archetype.by(id: "phantom")] }
        return pool.pick(using: &rng)
    }

    private static func generateCodename(using rng: inout SeededRNG) -> String {
        let prefix = NamePool.prefixes.pick(using: &rng)
        let suffix = NamePool.suffixes.pick(using: &rng)
        return "\(prefix) \(suffix)"
    }

    private static func choosePowers(from archetype: Archetype,
                                     sources: [Source],
                                     using rng: inout SeededRNG) -> [String] {
        var remaining = archetype.powers
        var chosen: [String] = []
        let count = min(3, remaining.count)
        for _ in 0..<count {
            let index = Int(rng.next() % UInt64(remaining.count))
            chosen.append(remaining.remove(at: index))
        }
        // One signature power flavored by a contributing source, if any.
        if let source = sources.sorted(by: { $0.rawValue < $1.rawValue }).first {
            chosen.append("\(source.trait.capitalized) Surge")
        }
        return chosen
    }

    /// Builds a three-beat origin: where the hero came from, what forged them,
    /// and the enemy they now answer. Composed entirely from local templates,
    /// seeded so a given genome always tells the same story.
    private static func composeOrigin(codename: String,
                                      archetype: Archetype,
                                      motifIndex: Int,
                                      sources: [Source],
                                      paletteSeed: UInt64,
                                      powers: [String],
                                      using rng: inout SeededRNG) -> String {
        let motif = archetype.motifs[motifIndex]
        let hue = PaletteDescriptor.name(forSeed: paletteSeed)

        // Beat 1 — the origin moment.
        let openers = [
            "\(codename), \(archetype.title.lowercased()), was \(motif).",
            "They call this one \(codename): \(motif).",
            "\(codename) — \(motif)."
        ]
        let beat1 = openers.pick(using: &rng)

        // Beat 2 — the signals that forged them.
        let named = sources.map(\.displayName)
        let sourceClause: String
        switch named.count {
        case 0:  sourceClause = "Forged from your own quiet hours at the keyboard"
        case 1:  sourceClause = "Forged from the signals of \(named[0])"
        case 2:  sourceClause = "Forged where \(named[0]) and \(named[1]) overlap"
        default: sourceClause = "Forged at the crossing of \(humanList(named))"
        }
        var seenTrait = Set<String>()
        let traits = sources.map(\.trait).filter { seenTrait.insert($0).inserted }
        let traitClause = traits.isEmpty ? "tempered in solitude"
                                         : "tempered toward \(humanList(traits))"
        let beat2 = "\(sourceClause), \(codename) was \(traitClause) and now wears \(hue) like a warning."

        // Beat 3 — the nemesis and the signature power that answers it.
        let signature = powers.last ?? archetype.powers.first ?? "resolve"
        let verb = ["answers", "meets", "hunts", "unmakes"].pick(using: &rng)
        let beat3 = "Now \(codename) \(verb) \(archetype.nemesis) with \(signature). \(archetype.creed)"

        return [beat1, beat2, beat3].joined(separator: "\n\n")
    }

    // MARK: - Personality

    /// Salt keeping the personality stream independent from the main forge RNG.
    private static let personalitySalt: UInt64 = 0xA5E1_D0E5_50E5_0A11

    /// A hero's personality — a short, characterful read on temperament and
    /// bearing. Derived on an INDEPENDENT stream keyed on the genome (seed +
    /// archetype), so it: (a) is stable for a given hero, (b) can be regenerated
    /// for heroes forged before this field existed, and (c) does NOT perturb the
    /// main forge stream, so existing origins/powers stay byte-for-byte the same.
    static func personality(for genome: HeroGenome) -> String {
        let archetype = Archetype.by(id: genome.archetypeID)
        var rng = SeededRNG(seed: SeedHash.combine(genome.seed,
                                                   SeedHash.of(archetype.id),
                                                   personalitySalt))
        // Two distinct temperament adjectives.
        var pool = PersonalityPool.temperaments
        let first = pool.remove(at: Int(rng.next() % UInt64(pool.count)))
        let second = pool.remove(at: Int(rng.next() % UInt64(pool.count)))
        let quirk = PersonalityPool.quirks.pick(using: &rng)
        let bearing = PersonalityPool.bearings.pick(using: &rng)
        let lead = first.prefix(1).uppercased() + first.dropFirst()
        return "\(lead), \(second) — \(quirk). \(bearing)"
    }

    /// "a, b, and c" — an Oxford-comma list for prose.
    private static func humanList(_ items: [String]) -> String {
        switch items.count {
        case 0:  return ""
        case 1:  return items[0]
        case 2:  return "\(items[0]) and \(items[1])"
        default: return "\(items.dropLast().joined(separator: ", ")), and \(items.last!)"
        }
    }
}
