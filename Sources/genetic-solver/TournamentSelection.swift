//  TournamentSelection.swift
//  genetic-solver
//
//  Tournament selection with a configurable size and random number generator.

public extension GeneticSolver {
    /// Returns a tournament selection operator: each parent is the fittest of
    /// `tournamentSize` individuals drawn at random, with replacement, from the
    /// population. On a tie, the individual drawn first wins, and each drawn
    /// individual has its fitness evaluated once.
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
    static func tournamentSelection(
        tournamentSize: Int = 3,
        using generator: any RandomNumberGenerator = SystemRandomNumberGenerator()
    )
        -> SelectionOperator<Element>
    {
        if tournamentSize < 1 {
            fatalError("tournamentSize must be at least 1, but is \(tournamentSize)")
        }
        var generator = generator
        return { population in
            let first = tournamentWinner(of: population, size: tournamentSize, using: &generator)
            let second = tournamentWinner(of: population, size: tournamentSize, using: &generator)
            return (first, second)
        }
    }
}

/// Returns the fittest of `size` individuals drawn at random, with
/// replacement, from `population`; on a tie, the one drawn first. Each drawn
/// individual has its fitness evaluated once.
func tournamentWinner<Element: FitnessEvaluatable>(
    of population: [Element],
    size: Int,
    using generator: inout some RandomNumberGenerator
)
    -> Element
{
    if population.isEmpty {
        fatalError("selectionOperator needs at least one individual")
    }
    var winner = population.randomElement(using: &generator)!
    var winnerFitness = winner.fitness()
    for _ in 1 ..< size {
        let candidate = population.randomElement(using: &generator)!
        let candidateFitness = candidate.fitness()
        if candidateFitness > winnerFitness {
            winner = candidate
            winnerFitness = candidateFitness
        }
    }
    return winner
}
