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

    func check(_ generation: Int, _ population: [TestIndividual]) -> Bool {
        generations.append(generation)
        populations.append(population.map(\.id))
        return decide(generation, population)
    }
}

// MARK: - Deterministic solver

/// A solver whose operators involve no randomness: selection always picks
/// the first two individuals, and crossover and mutation return their input
/// unchanged, so each generation is `[p0, p1, p0, p1, ...]`.
func makeDeterministicSolver(
    populationSize: Int = 4,
    factory: ElementFactory = ElementFactory(),
    terminationCheck: @escaping TerminationCheck<TestIndividual> = { _, _ in false }
)
    -> GeneticSolver<TestIndividual>
{
    GeneticSolver<TestIndividual>(
        populationSize: populationSize,
        selectionOperator: { ($0[0], $0[1]) },
        crossoverOperator: { [$0, $1] },
        mutationOperator: { $0 },
        replacementOperator: { _, new in new },
        terminationCheck: terminationCheck,
        newElement: factory.make
    )
}
