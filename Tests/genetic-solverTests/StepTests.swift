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

    /// Each new individual gets its own mutation decision. The total alone
    /// can't show this: one decision for a whole generation gives the same
    /// average. The spread of the per-generation counts can: with 10
    /// individuals at 30%, their variance is 2.1 (Binomial(10, 0.3)) for
    /// independent decisions, 4.2 for one decision per pair, 21 for one per
    /// generation, and 0 for a fixed number per generation.
    func testMutationRateIsAppliedToEachIndividualIndependently() {
        let statistics = mutationStatistics(seed: 21)

        // 10,000 individuals at 30%: the standard deviation is about 46, so
        // this range is 5 standard deviations wide on each side.
        XCTAssertEqual(Double(statistics.total), 3000, accuracy: 230)
        // In 20,000 simulated runs, independent decisions gave a variance
        // from 1.76 to 2.46, one decision per pair at least 3.59, and one per
        // generation at least 18.7.
        XCTAssertTrue(
            (1.5 ... 3.0).contains(statistics.variance),
            "Per-generation variance \(statistics.variance) doesn't match independent decisions"
        )
        // 1,000 decisions per position at 30%: the standard deviation is
        // about 14.5, so this range is about 5 standard deviations wide.
        for (position, count) in statistics.perPosition.enumerated() {
            XCTAssertEqual(Double(count), 300, accuracy: 75, "Position \(position)")
        }
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

    // MARK: Helpers

    /// Runs 1,000 generations of 10 individuals with a mutation rate of 0.3
    /// and counts the mutated individuals: in total, in each generation, and
    /// at each position of the population.
    func mutationStatistics(seed: UInt64) -> (total: Int, variance: Double, perPosition: [Int]) {
        let populationSize = 10
        let generations = 1000
        var solver = makeDeterministicSolver(populationSize: populationSize)
        // The parents are always new, unmutated individuals, so a marked
        // individual in the next population was mutated in that generation.
        solver.selectionOperator = { _ in (TestIndividual(gene: .zero, id: 0), TestIndividual(gene: .zero, id: 1)) }
        solver.mutationRate = 0.3
        solver.mutationOperator = { TestIndividual(gene: $0.gene, id: -1) }
        solver.randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)

        var perGeneration: [Int] = []
        var perPosition = Array(repeating: 0, count: populationSize)
        for _ in 0 ..< generations {
            solver.step()
            let mutated = solver.currentPopulation.map { $0.id == -1 }
            perGeneration.append(mutated.filter { $0 }.count)
            for (position, isMutated) in mutated.enumerated() where isMutated {
                perPosition[position] += 1
            }
        }

        let total = perGeneration.reduce(0, +)
        let mean = Double(total) / Double(generations)
        let squaredDeviations = perGeneration.map { (Double($0) - mean) * (Double($0) - mean) }
        let variance = squaredDeviations.reduce(0, +) / Double(generations - 1)
        return (total, variance, perPosition)
    }
}
