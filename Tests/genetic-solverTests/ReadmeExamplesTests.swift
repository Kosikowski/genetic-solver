//  ReadmeExamplesTests.swift
//  genetic-solverTests
//
//  Runs the code shown in README.md so the examples stay correct.
//  Keep the operators and solver setup below in sync with the README.

import XCTest
@testable import genetic_solver

// MARK: - MyIndividual

/// The individual from the README's Quick Start.
private struct MyIndividual: GeneticElement, FitnessEvaluatable {
    // MARK: Properties

    var genes: [Int]

    // MARK: Functions

    func fitness() -> Double {
        Double(genes.reduce(0, +))
    }
}

// MARK: - ReadmeQuickStart

/// The operators and solver from the README's Quick Start, Option A.
private enum ReadmeQuickStart {
    // MARK: Static Properties

    static let geneRange = 0 ... 100
    static let geneCount = 10
    static let targetFitness = 950.0
    static let populationSize = 50
    static let maxGenerations = 200

    static let selection: SelectionOperator<MyIndividual> = { population in
        func selectOne() -> MyIndividual {
            let candidates = (0 ..< 3).map { _ in population.randomElement()! }
            return candidates.max { $0.fitness() < $1.fitness() }!
        }
        return (selectOne(), selectOne())
    }

    static let crossover: CrossoverOperator<MyIndividual> = { parent1, parent2 in
        let point = Int.random(in: 0 ..< parent1.genes.count)
        let child1 = MyIndividual(
            genes: Array(parent1.genes[..<point]) + Array(parent2.genes[point...])
        )
        let child2 = MyIndividual(
            genes: Array(parent2.genes[..<point]) + Array(parent1.genes[point...])
        )
        return [child1, child2]
    }

    static let mutation: MutationOperator<MyIndividual> = { individual in
        var mutant = individual
        let geneIndex = Int.random(in: 0 ..< mutant.genes.count)
        mutant.genes[geneIndex] = Int.random(in: 0 ... 100)
        return mutant
    }

    static let terminationCheck: TerminationCheck<MyIndividual> = { _, population in
        population.contains { $0.fitness() >= 950 }
    }

    // MARK: Static Functions

    static func newElement() -> MyIndividual {
        MyIndividual(genes: (0 ..< 10).map { _ in Int.random(in: 0 ... 100) })
    }

    static func makeSolver() -> GeneticSolver<MyIndividual> {
        GeneticSolver<MyIndividual>(
            populationSize: 50,
            crossoverRate: 0.8,
            mutationRate: 0.1,
            selectionOperator: selection,
            crossoverOperator: crossover,
            mutationOperator: mutation,
            replacementOperator: { _, new in new },
            terminationCheck: terminationCheck,
            newElement: { newElement() }
        )
    }
}

// MARK: - ReadmeExamplesTests

final class ReadmeExamplesTests: XCTestCase {
    // MARK: Quick Start

    /// The README once stopped on a condition every starting population met,
    /// so the solver returned before running a single generation.
    func testQuickStartTerminationIsNotMetByStartingPopulations() {
        let populationsMeetingTermination = (0 ..< 1000).filter { _ in
            let population = (0 ..< ReadmeQuickStart.populationSize).map { _ in ReadmeQuickStart.newElement() }
            return ReadmeQuickStart.terminationCheck(0, population)
        }.count
        XCTAssertEqual(populationsMeetingTermination, 0, "Starting populations should not already meet the termination check")
    }

    func testQuickStartRunsGenerationsAndReachesTarget() throws {
        var solver = ReadmeQuickStart.makeSolver()

        let finalPopulation = solver.solve(maxGenerations: ReadmeQuickStart.maxGenerations)
        let bestIndividual = try XCTUnwrap(finalPopulation.max { $0.fitness() < $1.fitness() })

        XCTAssertGreaterThan(solver.currentGeneration, 0, "The solver should run at least one generation")
        XCTAssertLessThanOrEqual(solver.currentGeneration, ReadmeQuickStart.maxGenerations)
        XCTAssertEqual(finalPopulation.count, ReadmeQuickStart.populationSize)
        XCTAssertGreaterThanOrEqual(bestIndividual.fitness(), ReadmeQuickStart.targetFitness)
    }

    func testQuickStartNewElementsHaveValidGenes() {
        for _ in 0 ..< 1000 {
            let element = ReadmeQuickStart.newElement()
            XCTAssertEqual(element.genes.count, ReadmeQuickStart.geneCount)
            XCTAssertTrue(element.genes.allSatisfy { ReadmeQuickStart.geneRange.contains($0) })
        }
    }

    // MARK: Quick Start operators

    func testQuickStartSelectionReturnsMembersOfThePopulation() {
        let population = (0 ..< 20).map { MyIndividual(genes: [$0]) }
        for _ in 0 ..< 1000 {
            let (first, second) = ReadmeQuickStart.selection(population)
            XCTAssertTrue(population.contains { $0.genes == first.genes })
            XCTAssertTrue(population.contains { $0.genes == second.genes })
        }
    }

    func testQuickStartSelectionWithSingleIndividualReturnsItTwice() {
        let (first, second) = ReadmeQuickStart.selection([MyIndividual(genes: [7])])
        XCTAssertEqual(first.genes, [7])
        XCTAssertEqual(second.genes, [7])
    }

    func testQuickStartCrossoverTakesEachGeneFromOneOfTheParents() {
        let parent1 = MyIndividual(genes: Array(0 ..< 10))
        let parent2 = MyIndividual(genes: Array(100 ..< 110))
        for _ in 0 ..< 1000 {
            let children = ReadmeQuickStart.crossover(parent1, parent2)
            XCTAssertEqual(children.count, 2)
            XCTAssertTrue(children.allSatisfy { $0.genes.count == parent1.genes.count })
            // The two children are complementary: at every position one holds
            // the gene from parent1 and the other the gene from parent2.
            for index in parent1.genes.indices {
                let pair = Set([children[0].genes[index], children[1].genes[index]])
                XCTAssertEqual(pair, Set([parent1.genes[index], parent2.genes[index]]))
            }
        }
    }

    func testQuickStartCrossoverWithSingleGeneSwapsTheParents() {
        // With one gene the only crossover point is 0, so each child is a copy
        // of the other parent.
        let children = ReadmeQuickStart.crossover(MyIndividual(genes: [1]), MyIndividual(genes: [2]))
        XCTAssertEqual(children.map(\.genes), [[2], [1]])
    }

    func testQuickStartMutationChangesAtMostOneGeneWithinRange() {
        let original = MyIndividual(genes: Array(repeating: 50, count: 10))
        for _ in 0 ..< 1000 {
            let mutant = ReadmeQuickStart.mutation(original)
            XCTAssertEqual(mutant.genes.count, original.genes.count)
            let changed = zip(mutant.genes, original.genes).filter { $0 != $1 }
            XCTAssertLessThanOrEqual(changed.count, 1)
            XCTAssertTrue(mutant.genes.allSatisfy { ReadmeQuickStart.geneRange.contains($0) })
        }
    }
}
