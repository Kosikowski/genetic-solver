//  TournamentSelection.swift
//  genetic-solver
//
//  Tournament selection with a configurable size and random number generator.

public extension GeneticSolver {
    /// Returns a tournament selection operator: each parent is the fittest of
    /// `tournamentSize` individuals drawn at random, with replacement, from the
    /// population. On a tie, the individual drawn first wins.
    ///
    /// Larger tournaments favor fitter individuals more strongly; a size of 1
    /// picks parents uniformly at random. The default `GeneticOperators`
    /// selection is a tournament of 3 with the system generator.
    ///
    /// The operator keeps its own copy of `generator` and advances it with each
    /// draw, so with a `SeededRandomNumberGenerator` the same seed picks the
    /// same parents from the same populations.
    ///
    /// ```swift
    /// solver.selectionOperator = GeneticSolver.tournamentSelection(
    ///     tournamentSize: 5,
    ///     using: SeededRandomNumberGenerator(seed: 42)
    /// )
    /// ```
    ///
    /// - Precondition: `tournamentSize` is at least 1.
    @inlinable
    static func tournamentSelection(
        tournamentSize: Int = 3,
        using generator: any RandomNumberGenerator = SystemRandomNumberGenerator()
    )
        -> SelectionOperator<Element>
    {
        if tournamentSize < 1 {
            fatalError("tournamentSize must be at least 1, but is \(tournamentSize)")
        }
        // A generator of a concrete type, so that the standard library's random
        // functions are specialized for it (see `AnyRandomNumberGenerator`).
        var generator = AnyRandomNumberGenerator(generator)
        return { population in
            tournamentPair(from: population, size: tournamentSize, using: &generator)
        }
    }
}

/// Returns two parents, each the winner of its own tournament of `size`
/// individuals drawn from `population`. The first parent's tournament draws
/// first. Both `tournamentSelection(tournamentSize:using:)` and the default
/// `GeneticOperators` selection use it.
///
/// Inlinable, like `GeneticSolver.step()`, so that clients specialize it.
@inlinable
func tournamentPair<Element: FitnessEvaluatable>(
    from population: [EvaluatedElement<Element>],
    size: Int,
    using generator: inout some RandomNumberGenerator
)
    -> (EvaluatedElement<Element>, EvaluatedElement<Element>)
{
    let first = tournamentWinner(of: population, size: size, using: &generator)
    let second = tournamentWinner(of: population, size: size, using: &generator)
    return (first, second)
}

/// Returns the fittest of `size` individuals drawn at random, with
/// replacement, from `population`; on a tie, the one drawn first. A NaN
/// fitness ranks below every other fitness (see `isFitter(_:than:)`).
@inlinable
func tournamentWinner<Element: FitnessEvaluatable>(
    of population: [EvaluatedElement<Element>],
    size: Int,
    using generator: inout some RandomNumberGenerator
)
    -> EvaluatedElement<Element>
{
    if population.isEmpty {
        fatalError("selectionOperator needs at least one individual")
    }
    var winner = population.randomElement(using: &generator)!
    for _ in 1 ..< size {
        let candidate = population.randomElement(using: &generator)!
        if isFitter(candidate.fitness, than: winner.fitness) {
            winner = candidate
        }
    }
    return winner
}
