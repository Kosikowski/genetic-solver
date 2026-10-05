//  TestSupport.swift
//  genetic-solverTests
//
//  Helpers shared by several test cases.

@testable import genetic_solver

// MARK: - ElementFactory

/// Creates test individuals with increasing ids and counts how many it made.
final class ElementFactory {
    // MARK: Properties

    private(set) var createdCount = 0

    // MARK: Functions

    func make() -> TestIndividual {
        defer { createdCount += 1 }
        return TestIndividual(gene: .zero, id: createdCount)
    }
}

// MARK: - TerminationRecorder

/// A termination check that records every call and delegates the decision.
final class TerminationRecorder {
    // MARK: Properties

    /// The generation passed to each call, in order.
    private(set) var generations: [Int] = []

    /// The ids of the population passed to each call, in order.
    private(set) var populations: [[Int]] = []

    private let decide: TerminationCheck<TestIndividual>

    // MARK: Lifecycle

    init(decide: @escaping TerminationCheck<TestIndividual> = { _, _ in false }) {
        self.decide = decide
    }

    // MARK: Functions

    func check(_ generation: Int, _ population: [EvaluatedElement<TestIndividual>]) -> Bool {
        generations.append(generation)
        populations.append(population.map(\.element.id))
        return decide(generation, population)
    }
}

// MARK: - Deterministic solver

/// A solver whose operators involve no randomness: selection always picks
/// the first two individuals, and by default crossover and mutation return
/// their input unchanged, so each generation is `[p0, p1, p0, p1, ...]`.
///
/// A `crossoverRate` of 1 applies `crossoverOperator` to every pair and a
/// rate of 0 never applies it, so both keep the solver deterministic.
func makeDeterministicSolver(
    populationSize: Int = 4,
    factory: ElementFactory = ElementFactory(),
    crossoverRate: Double = 0.7,
    crossoverOperator: @escaping CrossoverOperator<TestIndividual> = { [$0, $1] },
    terminationCheck: @escaping TerminationCheck<TestIndividual> = { _, _ in false }
)
    -> GeneticSolver<TestIndividual>
{
    GeneticSolver<TestIndividual>(
        populationSize: populationSize,
        crossoverRate: crossoverRate,
        selectionOperator: { ($0[0], $0[1]) },
        crossoverOperator: crossoverOperator,
        mutationOperator: { $0 },
        replacementOperator: { _, new in new },
        terminationCheck: terminationCheck,
        newElement: factory.make
    )
}

// MARK: - FitnessCallCounter

/// Counts `fitness()` calls across all individuals that share it.
final class FitnessCallCounter {
    var calls = 0
}

// MARK: - ScoredIndividual

/// An individual with a given fitness that counts its `fitness()` calls.
struct ScoredIndividual: GeneticElement {
    // MARK: Properties

    let id: Int
    let score: Int
    let counter: FitnessCallCounter

    // MARK: Lifecycle

    init(id: Int, score: Int, counter: FitnessCallCounter = FitnessCallCounter()) {
        self.id = id
        self.score = score
        self.counter = counter
    }

    // MARK: Functions

    func fitness() -> Int {
        counter.calls += 1
        return score
    }
}

// MARK: - ScoredDefaultOperators

/// Implements only `newElement()`, so every other operator is the
/// protocol's default implementation.
enum ScoredDefaultOperators: GeneticOperators {
    static func newElement() -> ScoredIndividual {
        ScoredIndividual(id: 0, score: 0)
    }
}
