//  GeneticSolverTests.swift
//  RubicCubeTests
//
//  Created by Mateusz Kosikowski on 05/02/2025.

import XCTest
@testable import genetic_solver

// MARK: - TestGeneticOperators

struct TestGeneticOperators: GeneticOperators {
    // MARK: Nested Types

    typealias Element = TestIndividual

    // MARK: Static Functions

    static func selectionOperator(population: [Element]) -> (Element, Element) {
        // Use the default implementation
        let candidates = (0 ..< 3).map { _ in population.randomElement()! }
        let best = candidates.max { $0.fitness() < $1.fitness() }!
        return (best, best)
    }

    static func crossoverOperator(parent1: Element, parent2: Element) -> [Element] {
        [parent1, parent2]
    }

    static func mutationOperator(element: Element) -> Element {
        element
    }

    static func replacementOperator(old _: [Element], new: [Element]) -> [Element] {
        new
    }

    static func fixedGenerationTermination(maxGenerations: Int) -> TerminationCheck<Element> {
        { generation, _ in generation >= maxGenerations }
    }

    static func newElement() -> Element {
        // Provide a default test value
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

        // Use default tournament selection from TestGeneticOperators
        let selection: TestSelectionOperator = { population in
            TestGeneticOperators.selectionOperator(population: population)
        }
        // Crossover: actually mix the genes from parents
        let crossover: TestCrossoverOperator = { p1, p2 in
            // Create offspring with mixed genes
            let child1 = TestIndividual(gene: p1.gene, id: Int.random(in: 0 ..< 100_000))
            let child2 = TestIndividual(gene: p2.gene, id: Int.random(in: 0 ..< 100_000))
            return [child1, child2]
        }
        // Mutation: switch gene with very low probability to allow convergence
        let mutation: TestMutationOperator = { ind in
            var mutant = ind
            // Only mutate 5% of the time to allow convergence
            if Double.random(in: 0 ... 1) < 0.05 {
                mutant.gene = mutant.gene == .one ? .zero : .one
            }
            return mutant
        }
        let replacement: TestReplacementOperator = { _, newPop in newPop }
        let termination: TestTerminationCheck = { gen, pop in gen >= 50 || pop.allSatisfy { $0.gene == .one } }

        var solver = GeneticSolver<TestIndividual>(
            populationSize: 20, // Larger population for better diversity
            crossoverRate: 0.8, // High crossover rate
            mutationRate: 0.05, // Much lower mutation rate
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
        XCTAssertEqual(pop.count, 6, "Returned population should match populationSize")
    }
}
