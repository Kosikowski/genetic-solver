//  GeneticSolverTests.swift
//  RubicCubeTests
//
//  Created by Mateusz Kosikowski on 05/02/2025.

import XCTest
@testable import genetic_solver

// MARK: - TestGeneticOperators

/// Implements only `newElement()`, so the tests below use the default
/// implementations of every other `GeneticOperators` operator.
struct TestGeneticOperators: GeneticOperators {
    // MARK: Nested Types

    typealias Element = TestIndividual

    // MARK: Static Functions

    static func newElement() -> Element {
        TestIndividual(gene: .zero, id: 0)
    }
}

// MARK: - TestGene

/// Minimal mock element and fitness for testing
enum TestGene: Int, CaseIterable {
    case zero = 0
    case one = 1
}

// MARK: - TestIndividual

struct TestIndividual: GeneticElement, FitnessEvaluatable, Equatable {
    // MARK: Properties

    var gene: TestGene
    var id: Int

    // MARK: Functions

    func fitness() -> Double {
        // Higher fitness if gene is .one
        gene == .one ? 1.0 : 0.0
    }
}

typealias TestSelectionOperator = SelectionOperator<TestIndividual>
typealias TestCrossoverOperator = CrossoverOperator<TestIndividual>
typealias TestMutationOperator = MutationOperator<TestIndividual>
typealias TestReplacementOperator = ReplacementOperator<TestIndividual>
typealias TestTerminationCheck = TerminationCheck<TestIndividual>

// MARK: - GeneticSolverTests

final class GeneticSolverTests: XCTestCase {
    func testSolverFindsOptimalGene() {
        let randomInitializer = { TestIndividual(gene: TestGene.allCases.randomElement()!, id: Int.random(in: 0 ..< 100_000)) }

        // The default tournament selection, which TestGeneticOperators doesn't override
        let selection: TestSelectionOperator = { population in
            TestGeneticOperators.selectionOperator(population: population)
        }
        // Crossover: each child copies one parent's single gene, with a new id
        let crossover: TestCrossoverOperator = { p1, p2 in
            let child1 = TestIndividual(gene: p1.gene, id: Int.random(in: 0 ..< 100_000))
            let child2 = TestIndividual(gene: p2.gene, id: Int.random(in: 0 ..< 100_000))
            return [child1, child2]
        }
        // Mutation: flip the gene 5% of the time it is applied. With the 5%
        // mutation rate below, a gene flips with probability 0.25% per
        // individual per generation, rarely enough for the population to converge.
        let mutation: TestMutationOperator = { ind in
            var mutant = ind
            if Double.random(in: 0 ... 1) < 0.05 {
                mutant.gene = mutant.gene == .one ? .zero : .one
            }
            return mutant
        }
        let replacement: TestReplacementOperator = { _, newPop in newPop }
        let termination: TestTerminationCheck = { gen, pop in gen >= 50 || pop.allSatisfy { $0.gene == .one } }

        var solver = GeneticSolver<TestIndividual>(
            populationSize: 20,
            crossoverRate: 0.8,
            mutationRate: 0.05,
            selectionOperator: selection,
            crossoverOperator: crossover,
            mutationOperator: mutation,
            replacementOperator: replacement,
            terminationCheck: termination,
            newElement: randomInitializer
        )

        let finalPopulation = solver.solve(maxGenerations: 100)
        // Test that eventually all individuals are optimal
        XCTAssertTrue(finalPopulation.allSatisfy { $0.gene == .one }, "All individuals should converge to gene .one")
    }

    func testSolverRespectsMaxGenerations() {
        let randomInitializer = { TestIndividual(gene: .zero, id: Int.random(in: 0 ..< 100_000)) }
        var solver = GeneticSolver<TestIndividual>(
            populationSize: 6,
            selectionOperator: { TestGeneticOperators.selectionOperator(population: $0) },
            crossoverOperator: { p1, p2 in [p1, p2] },
            mutationOperator: { $0 },
            replacementOperator: { _, n in n },
            terminationCheck: { gen, _ in gen >= 1000 },
            newElement: randomInitializer
        )
        let pop = solver.solve(maxGenerations: 5)
        XCTAssertEqual(solver.currentGeneration, 5, "solve should stop at maxGenerations")
        XCTAssertFalse(solver.isTerminated, "The termination check (generation 1000) was never met")
        XCTAssertEqual(pop.count, 6, "Returned population should match populationSize")
    }

    func testSolverStopsOnceWhenMaxGenerationsEqualsTheTerminationGeneration() {
        var terminationCalls = 0
        var solver = GeneticSolver<TestIndividual>(
            populationSize: 6,
            selectionOperator: { TestGeneticOperators.selectionOperator(population: $0) },
            crossoverOperator: { p1, p2 in [p1, p2] },
            mutationOperator: { $0 },
            replacementOperator: { _, n in n },
            terminationCheck: { gen, _ in
                terminationCalls += 1
                return gen >= 5
            },
            newElement: { TestIndividual(gene: .zero, id: 0) }
        )
        _ = solver.solve(maxGenerations: 5)
        XCTAssertEqual(solver.currentGeneration, 5)
        XCTAssertTrue(solver.isTerminated, "The check runs for generation 5 before solve stops")
        XCTAssertEqual(terminationCalls, 6, "Once for each of generations 0 through 5")
    }
}
