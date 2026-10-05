//  GeneticElementTests.swift
//  genetic-solverTests
//
//  Tests that conforming to GeneticElement alone is enough to use a type
//  with the solver, and that listing both protocols still works.

import XCTest
@testable import genetic_solver

// MARK: - Minimal

/// Conforms only to `GeneticElement`, not to `FitnessEvaluatable` directly.
private struct Minimal: GeneticElement {
    // MARK: Properties

    let value: Int

    // MARK: Functions

    func fitness() -> Int {
        value
    }
}

// MARK: - MinimalOperators

private enum MinimalOperators: GeneticOperators {
    static func newElement() -> Minimal {
        Minimal(value: Int.random(in: 0 ... 9))
    }
}

/// Only accepts types that are `FitnessEvaluatable`.
private func fitness<Individual: FitnessEvaluatable>(of individual: Individual) -> Individual.Fitness {
    individual.fitness()
}

/// Only accepts types that are `GeneticElement`.
private func isGeneticElement(_: (some GeneticElement).Type) -> Bool {
    true
}

// MARK: - GeneticElementTests

final class GeneticElementTests: XCTestCase {
    func testGeneticElementIncludesFitnessEvaluatable() {
        XCTAssertEqual(fitness(of: Minimal(value: 7)), 7)
    }

    func testTypeListingBothProtocolsIsStillAGeneticElement() {
        XCTAssertTrue(isGeneticElement(TestIndividual.self))
        XCTAssertEqual(fitness(of: TestIndividual(gene: .one, id: 0)), 1)
    }

    func testTypeConformingOnlyToGeneticElementWorksWithTheSolver() {
        var nextValue = 0
        var solver = GeneticSolver<Minimal>(
            populationSize: 4,
            selectionOperator: { ($0[0], $0[1]) },
            crossoverOperator: { [$0, $1] },
            mutationOperator: { Minimal(value: $0.value + 10) },
            replacementOperator: GeneticSolver.elitistReplacement(eliteCount: 1),
            terminationCheck: { generation, _ in generation >= 3 },
            newElement: {
                defer { nextValue += 1 }
                return Minimal(value: nextValue)
            }
        )

        _ = solver.solve(maxGenerations: 10)

        XCTAssertEqual(solver.currentGeneration, 3)
        XCTAssertTrue(solver.isTerminated)
        XCTAssertEqual(solver.currentPopulation.count, 4)
        XCTAssertGreaterThanOrEqual(solver.bestElement.value, 3, "Elitism keeps the best starting value")
    }

    func testOperatorsTypeWhoseElementConformsOnlyToGeneticElement() {
        var solver = GeneticSolver(
            populationSize: 4,
            operators: MinimalOperators.self,
            terminationCheck: MinimalOperators.fixedGenerationTermination(maxGenerations: 2)
        )

        _ = solver.solve()

        XCTAssertEqual(solver.currentGeneration, 2)
        XCTAssertTrue(solver.currentPopulation.allSatisfy { (0 ... 9).contains($0.value) })
    }
}
