//  AnyRandomNumberGenerator.swift
//  genetic-solver
//
//  A generator of a concrete type that forwards to a generator of any type.

/// A random number generator that forwards every `next()` call to `base`, a
/// generator of any type.
///
/// The solver and `tournamentSelection(tournamentSize:using:)` take their
/// generators as `any RandomNumberGenerator`. Passing such a value to the
/// standard library's generic random functions, such as
/// `Double.random(in:using:)`, runs them unspecialized: their arithmetic goes
/// through protocol witness tables and runtime type lookups for every random
/// number. This type is concrete, so those functions are specialized for it,
/// and only the call to `base.next()` is dynamic.
///
/// `base` sees exactly the calls it would see if it were passed directly:
/// the standard library's functions call only `next()`, the protocol's one
/// requirement, so the same generator state gives the same values.
///
/// `@usableFromInline` because inlinable code, such as `GeneticSolver.step()`,
/// uses it.
@usableFromInline
struct AnyRandomNumberGenerator: RandomNumberGenerator {
    // MARK: Properties

    /// The generator that produces the numbers.
    @usableFromInline var base: any RandomNumberGenerator

    // MARK: Lifecycle

    @usableFromInline
    init(_ base: any RandomNumberGenerator) {
        self.base = base
    }

    // MARK: Functions

    @inlinable
    mutating func next() -> UInt64 {
        base.next()
    }
}
