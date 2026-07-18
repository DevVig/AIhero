import Foundation

/// Turns a forged hero's genome into a style-locked, transparent-cutout image
/// prompt for the user's harness. The prompt is fully derived from the hero's
/// own (fictional) identity — archetype, silhouette, palette, emblem, chosen art
/// direction — so every hero is bespoke and one-of-one, yet reproducible.
///
/// It follows Codex's imagegen transparent-image workflow verbatim (generate on
/// a flat chroma-key background, remove it with the bundled helper, save alpha),
/// which is the path proven in the Phase 0 spike.
enum HeroPromptBuilder {

    /// The full instruction handed to `codex exec`. `outputPath` is the absolute
    /// destination for the finished transparent PNG.
    static func transparentHeroPrompt(for hero: Hero,
                                      direction rawDirection: ArtDirection,
                                      outputPath: String) -> String {
        let genome = hero.genome
        let direction = rawDirection.resolved(seed: genome.seed)
        let bodyColor = PaletteDescriptor.name(forSeed: genome.paletteSeed)
        let energyColor = PaletteDescriptor.name(forHue:
            Double(genome.paletteSeed % 3600) / 3600.0 + 0.5)
        let costume = costumeHint(for: genome.silhouette)
        let emblem = emblemDescription(for: genome.archetypeID)
        // A green key conflicts with green subjects; the imagegen skill uses
        // magenta in that case. Our palette word tells us when to switch.
        let keyColor = (bodyColor.contains("green") || energyColor.contains("green"))
            ? "#ff00ff" : "#00ff00"

        return """
        Generate ONE bespoke original superhero, full body, and produce a clean transparent PNG cutout. \
        Use the built-in image_gen tool (no API key, no Python HTTP calls). This is an ORIGINAL character — \
        do NOT copy any known/trademarked hero.

        Character: "\(hero.name)", also known as \(hero.title). \(hero.title)'s creed: "\(hero.archetype.creed)"
        Build & costume: \(costume)
        Palette: \(bodyColor) as the dominant costume color, with glowing \(energyColor) energy accents \
        tracing the armor seams and eyes/visor.
        Chest emblem: \(emblem), glowing in \(energyColor).
        Pose: confident heroic standing pose, facing forward, full body from head to boots, symmetrical, centered.
        Bearing: \(hero.personalityText) Let this personality read only in the face and posture (expression, stance) — never as any text on the image.
        \(evolutionClause(for: hero.level))
        \(direction.styleClause)

        CRITICAL — follow the imagegen skill transparent-image workflow exactly:
        1. Generate the hero on a PERFECTLY FLAT solid \(keyColor) chroma-key background — no shadow, no floor, \
        no gradient, no reflection, no text, no watermark. Crisp edges, generous padding around the full body. \
        Portrait orientation, tall (roughly 3:4). Do not use \(keyColor) anywhere on the character.
        2. Copy the generated source out of $CODEX_HOME/generated_images, then run \
        $CODEX_HOME/skills/.system/imagegen/scripts/remove_chroma_key.py with --auto-key border --soft-matte \
        --despill to produce alpha.
        3. Validate the result has an alpha channel, transparent corners, and plausible subject coverage.
        4. Save the final transparent PNG to \(outputPath).
        When finished print exactly: SAVED \(outputPath)
        """
    }

    /// An evolution-tier clause driven by the hero's level. Evolution ascends the
    /// *rendition* — richer armor detail, a stronger aura, a more commanding stance —
    /// while the genome (identity, palette, emblem, silhouette) stays fixed, so an
    /// evolved hero is unmistakably the same collectible, just grown into its power.
    private static func evolutionClause(for level: Int) -> String {
        switch level {
        case ...1:
            return ""   // base look — a newly forged hero
        case 2...3:
            return "Evolution tier \(level): render a more seasoned, battle-tested version of this "
                 + "same hero — subtly more ornate armor detailing and a brighter, steadier energy "
                 + "aura than a rookie. Keep the identity, palette, emblem, and silhouette unchanged."
        case 4...6:
            return "Evolution tier \(level): render an ascended, elite form of this same hero — "
                 + "noticeably more elaborate armor with layered glowing filigree, a commanding "
                 + "stance, and a strong radiant aura. Keep the identity, palette, emblem, and "
                 + "silhouette unchanged."
        default:
            return "Evolution tier \(level): render a legendary, fully-ascended form of this same "
                 + "hero — the most ornate and powerful rendition, intense radiant energy and "
                 + "heroic grandeur. Keep the core identity, palette, emblem, and silhouette "
                 + "unchanged so it stays recognizably the same character."
        }
    }

    // MARK: - Genome → visual language

    /// Costume/body language per silhouette family — keeps a hero's build
    /// consistent with how its procedural fallback reads.
    private static func costumeHint(for silhouette: Silhouette) -> String {
        switch silhouette {
        case .sentinel:
            return "broad-shouldered heavy guardian armor with large pauldrons and a short cape; "
                 + "helmet with a crested fin and a glowing visor"
        case .vanguard:
            return "lean athletic build in sleek aerodynamic armor, forward-leaning and dynamic, "
                 + "a large flowing cape, streamlined helmet"
        case .oracle:
            return "a hooded, robed figure with a tapered silhouette, face half-shadowed under the hood, "
                 + "arcane trim on the sleeves"
        case .artificer:
            return "a compact, geometric suit of utilitarian power armor, three-lensed visor, "
                 + "tool-laden gauntlets, no cape"
        case .phantom:
            return "a slender, wisp-like figure in a close bodysuit with a tattered cape, "
                 + "the lower body dissolving into faint smoke, masked"
        }
    }

    /// A described chest glyph per archetype (the SF Symbol name is not visual,
    /// so we translate its concept into something an image model can draw).
    private static func emblemDescription(for archetypeID: String) -> String {
        switch archetypeID {
        case "orchestrator": return "a constellation of three linked nodes joined into one converging line"
        case "refactorer":   return "two arrows chasing each other in a clean circular-refactor loop"
        case "debugger":     return "a stylized beetle centered in a targeting reticle"
        case "architect":    return "a precise 3x3 blueprint grid with one corner cell filled"
        case "shipper":      return "an upward-launching paper plane leaving a motion trail"
        case "sentinel":     return "a split heraldic shield glyph"
        case "cartographer": return "a folded map crossed with a compass needle"
        case "phantom":      return "a wand throwing a small spray of stars"
        default:             return "an abstract glowing sigil"
        }
    }
}
