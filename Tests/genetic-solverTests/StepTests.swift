//  StepTests.swift
//  genetic-solverTests
//
//  Tests how step() applies mutation and replacement, and the order in which
//  it calls the operators.

import XCTest
@testable import genetic_solver

// MARK: - StepTests

final class StepTests: XCTestCase {
    // MARK: Mutation rate

    func testMutationRateOfZeroNeverMutates() {
        var mutations = 0
        var solver = makeDeterministicSolver(populationSize: 6)
        solver.mutationRate = 0
        solver.mutationOperator = { mutations += 1; return $0 }

        for _ in 0 ..< 10 {
            solver.step()
        }

        XCTAssertEqual(mutations, 0)
    }

    func testMutationRateOfOneMutatesEveryNewIndividual() {
        var mutations = 0
        var solver = makeDeterministicSolver(populationSize: 6)
        solver.mutationRate = 1
        solver.mutationOperator = { mutations += 1; return $0 }

        for _ in 0 ..< 10 {
            solver.step()
        }

        XCTAssertEqual(mutations, 60, "6 individuals for each of 10 generations")
    }

    /// Mutation applies to every new individual, including parents that were
    /// copied because crossover was skipped.
    func testMutationAlsoAppliesToCopiedParents() {
        var solver = makeDeterministicSolver(
            crossoverRate: 0,
            crossoverOperator: { _, _ in XCTFail("Crossover should be skipped"); return [] }
        )
        solver.mutationRate = 1
        solver.mutationOperator = { TestIndividual(gene: $0.gene, id: $0.id + 1000) }

        solver.step()

        XCTAssertEqual(solver.currentPopulation.map(\.id), [1000, 1001, 1000, 1001])
    }

    func testMutationRateIsAppliedToEachIndividualIndependently() {
        var mutations = 0
        var solver = makeDeterministicSolver(populationSize: 10)
        solver.mutationRate = 0.3
        solver.mutationOperator = { mutations += 1; return $0 }
        solver.randomNumberGenerator = SeededRandomNumberGenerator(seed: 21)

        for _ in 0 ..< 100 {
            solver.step()
        }

        // 1,000 individuals at 30%: the standard deviation is about 14.5, so
        // this range is about 5 standard deviations wide on each side.
        XCTAssertEqual(Double(mutations), 300, accuracy: 72)
    }

    // MARK: Replacement

    func testReplacementReceivesTheCurrentPopulationAndTheMutatedNewIndividuals() {
        var received: (old: [Int], new: [Int])?
        var solver = makeDeterministicSolver(
            crossoverRate: 1,
            crossoverOperator: { [TestIndividual(gene: $0.gene, id: $0.id + 100), TestIndividual(gene: $1.gene, id: $1.id + 100)] }
        )
        solver.mutationRate = 1
        solver.mutationOperator = { TestIndividual(gene: $0.gene, id: $0.id + 1000) }
        solver.replacementOperator = { old, new in
            received = (old.map(\.id), new.map(\.id))
            return new
        }

        solver.step()

        XCTAssertEqual(received?.old, [0, 1, 2, 3])
        XCTAssertEqual(received?.new, [1100, 1101, 1100, 1101])
    }

    func testReplacementResultBecomesTheNextPopulationWhateverItsSize() {
        var solver = makeDeterministicSolver(populationSize: 4)
        solver.replacementOperator = { old, new in old + new }

        solver.step()

        XCTAssertEqual(solver.currentPopulation.map(\.id), [0, 1, 2, 3, 0, 1, 0, 1])
    }

    // MARK: Population size

    func testChangingPopulationSizeChangesTheNextGeneration() {
        var solver = makeDeterministicSolver(populationSize: 4)

        solver.populationSize = 6
        solver.step()
        XCTAssertEqual(solver.currentPopulation.count, 6)

        solver.populationSize = 3
        solver.step()
        XCTAssertEqual(solver.currentPopulation.count, 3)
    }

    // MARK: Order of operations

    func testOneGenerationCallsTheOperatorsInOrder() {
        var calls: [String] = []
        var solver = makeDeterministicSolver(
            populationSize: 4,
            crossoverRate: 1,
            crossoverOperator: { calls.append("crossover"); return [$0, $1] },
            terminationCheck: { _, _ in calls.append("termination"); return false }
        )
        let selection = solver.selectionOperator
        solver.selectionOperator = { calls.append("selection"); return selection($0) }
        solver.mutationRate = 1
        solver.mutationOperator = { calls.append("mutation"); return $0 }
        solver.replacementOperator = { calls.append("replacement"); return $1 }
        calls = []

        solver.step()

        XCTAssertEqual(calls, [
            "selection", "crossover", "selection", "crossover",
            "mutation", "mutation", "mutation", "mutation",
            "replacement", "termination",
        ])
    }
}
