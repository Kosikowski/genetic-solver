//  GeneticSolverTests.swift
//  RubicCubeTests
//
//  Created by Mateusz Kosikowski on 05/02/2025.
//

@testable import genetic_solver
import Testing

struct TestGeneticOperators: GeneticOperators {
    typealias Element = TestIndividual
    static func selectionOperator(population: [Element]) -> (Element, Element) {
        // Use the default implementation
        let candidates = (0 ..< 3).map { _ in population.randomElement()! }
        let best = candidates.max { $0.fitness() < $1.fitness() }!
        return (best, best)
    }

    static func crossoverOperator(parent1: Element, parent2: Element) -> [Element] {
        return [parent1, parent2]
    }

    static func mutationOperator(element: Element) -> Element {
        return element
    }

    static func replacementOperator(old _: [Element], new: [Element]) -> [Element] {
        return new
    }

    static func fixedGenerationTermination(maxGenerations: Int) -> TerminationCheck<Element> {
        return { generation, _ in generation >= maxGenerations }
    }

    static func newElement() -> Element {
        // Provide a default test value
        return TestIndividual(gene: .zero, id: 0)
    }
}

// Minimal mock element and fitness for testing
enum TestGene: Int, CaseIterable {
    case zero = 0, one = 1
}

struct TestIndividual: GeneticElement, FitnessEvaluatable, Equatable {
    var gene: TestGene
    var id: Int

    func fitness() -> Double {
        // Higher fitness if gene is .one
        return gene == .one ? 1.0 : 0.0
    }
}

typealias TestSelectionOperator = SelectionOperator<TestIndividual>
typealias TestCrossoverOperator = CrossoverOperator<TestIndividual>
typealias TestMutationOperator = MutationOperator<TestIndividual>
typealias TestReplacementOperator = ReplacementOperator<TestIndividual>
typealias TestTerminationCheck = TerminationCheck<TestIndividual>

@Suite("GeneticSolver.solve basic behavior")
struct GeneticSolverSolveTests {
    @Test("Population evolves and terminates as expected")
    func testSolverFindsOptimalGene() async throws {
        let randomInitializer = { TestIndividual(gene: TestGene.allCases.randomElement()!, id: Int.random(in: 0 ..< 100_000)) }

        // Use default tournament selection from TestGeneticOperators
        let selection: TestSelectionOperator = { population in
            TestGeneticOperators.selectionOperator(population: population)
        }
        // Crossover: always return one of each (simulate mix)
        let crossover: TestCrossoverOperator = { p1, p2 in [p1, p2] }
        // Mutation: switch gene with low probability
        let mutation: TestMutationOperator = { ind in
            var mutant = ind
            mutant.gene = mutant.gene == .one ? .zero : .one
            return mutant
        }
        let replacement: TestReplacementOperator = { _, newPop in newPop }
        let termination: TestTerminationCheck = { gen, pop in gen >= 20 || pop.allSatisfy { $0.gene == .one } }

        var solver = GeneticSolver<TestIndividual>(
            populationSize: 10,
            crossoverRate: 1.0,
            mutationRate: 0.2,
            selectionOperator: selection,
            crossoverOperator: crossover,
            mutationOperator: mutation,
            replacementOperator: replacement,
            terminationCheck: termination,
            newElement: randomInitializer
        )

        let finalPopulation = solver.solve(maxGenerations: 50)
        // Test that eventually all individuals are optimal
        #expect(finalPopulation.allSatisfy { $0.gene == .one }, "All individuals should converge to gene .one")
    }

    @Test("Solver respects maxGenerations and returns a population of correct size")
    func testSolverRespectsMaxGenerations() async throws {
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
        #expect(pop.count == 6, "Returned population should match populationSize")
    }
}
