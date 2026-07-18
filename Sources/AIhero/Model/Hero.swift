import Foundation

/// The immutable core of a hero. Everything here is derived deterministically
/// from `seed`, so a genome fully reproduces a hero's identity and appearance.
/// Evolution changes the surrounding `Hero` (level, powers, story chapters) but
/// never the genome — that's what keeps a collectible stable and recognizable.
struct HeroGenome: Codable, Hashable {
    let seed: UInt64
    let archetypeID: String
    let silhouette: Silhouette
    let emblem: String
    let paletteSeed: UInt64
    let motifIndex: Int
}

/// A forged hero: a collectible instance. Sealed heroes sit in a box on the
/// shelf; once unboxed the hero can become the active desktop companion.
struct Hero: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var title: String
    let genome: HeroGenome
    var originStory: String
    var powers: [String]
    /// A short, characterful read on the hero's temperament and bearing. Optional
    /// so heroes forged before personality existed still decode (`decodeIfPresent`);
    /// `nil` regenerates deterministically from the genome via `personalityText`.
    var personality: String?
    var level: Int
    var xp: Int
    var contributingSources: [Source]
    var createdAt: Date
    var isUnboxed: Bool
    /// The forge-time art direction chosen for this hero's bespoke portrait.
    /// Optional so heroes saved before art generation existed still decode
    /// (synthesized Decodable uses `decodeIfPresent` for optionals). `nil`
    /// resolves to `.auto` at read time.
    var artDirectionID: String?

    var archetype: Archetype { Archetype.by(id: genome.archetypeID) }

    /// The hero's personality, regenerated deterministically from the genome for
    /// heroes forged before the field existed. Stored and regenerated values are
    /// identical for a given genome (same composer), so this is stable either way.
    var personalityText: String { personality ?? HeroForge.personality(for: genome) }

    /// The chosen art direction, defaulting to `.auto` for older heroes.
    var artDirection: ArtDirection {
        artDirectionID.flatMap(ArtDirection.init(rawValue:)) ?? .auto
    }
}
