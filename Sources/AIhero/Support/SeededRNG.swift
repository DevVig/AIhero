import Foundation

/// Deterministic SplitMix64 generator. The same seed always yields the same
/// stream, which is what makes a hero's "genome" reproducible and lets two
/// heroes forged from the same signals still be provably distinct (we vary the
/// seed with a salt). No dependency on the system RNG, so genomes are portable.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid a zero state producing a degenerate stream.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum SeedHash {
    /// FNV-1a 64-bit — a small, stable string hash. Foundation's `hashValue`
    /// is randomized per process, so we can't use it for reproducible seeds.
    static func of(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    static func combine(_ values: UInt64...) -> UInt64 {
        var acc: UInt64 = 0x9E3779B97F4A7C15
        for value in values {
            acc = (acc ^ value) &* 0x100000001b3
            acc ^= acc >> 29
        }
        return acc
    }
}

extension Array {
    /// Deterministic pick using a provided generator.
    func pick(using rng: inout SeededRNG) -> Element {
        precondition(!isEmpty, "cannot pick from an empty array")
        let index = Int(rng.next() % UInt64(count))
        return self[index]
    }
}
