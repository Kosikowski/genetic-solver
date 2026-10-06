//  SeededRandomNumberGenerator.swift
//  genetic-solver
//
//  A random number generator that repeats its sequence for the same seed.

/// A random number generator that produces the same sequence of numbers for
/// the same seed, on every platform. Use it to make runs reproducible, for
/// example while debugging or in tests: give the solver's
/// `randomNumberGenerator`, `tournamentSelection(tournamentSize:using:)` and
/// your own operators seeded generators.
///
/// It implements SplitMix64, a small and fast generator with good statistical
/// quality for simulations. It is not suitable for cryptography.
///
/// The values returned by `next()` depend only on the seed. Values that the
/// standard library derives from them, such as `Double.random(in:using:)` or
/// `randomElement(using:)`, also depend on how the standard library converts
/// them, which a future Swift version could change.
///
/// It is `Sendable`: a generator can be kept in a global or static property,
/// or passed to another task, where the copy continues the same sequence.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    // MARK: Properties

    /// Inlinable code can only use `@usableFromInline` state; see `next()`.
    @usableFromInline var state: UInt64

    // MARK: Lifecycle

    /// Creates a generator whose sequence is determined by `seed`.
    public init(seed: UInt64) {
        state = seed
    }

    // MARK: Functions

    @inlinable
    public mutating func next() -> UInt64 {
        // Inlinable, so that a client's code calling it with a known
        // generator type can inline it instead of calling it for every number.
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}
