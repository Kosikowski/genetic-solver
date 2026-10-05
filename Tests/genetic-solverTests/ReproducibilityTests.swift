//  ReproducibilityTests.swift
//  genetic-solverTests
//
//  Tests SeededRandomNumberGenerator, the solver's randomNumberGenerator and
//  GeneticSolver.tournamentSelection(tournamentSize:using:).

import XCTest
@testable import genetic_solver

// MARK: - ConstantGenerator

/// Always returns the same value, so random decisions become predictable:
/// 0 makes `Double.random(in: 0 ..< 1)` return 0, and `UInt64.max` makes it
/// return the largest value below 1.
private struct ConstantGenerator: RandomNumberGenerator {
    // MARK: Properties

    let value: UInt64

    // MARK: Functions

    mutating func next() -> UInt64 {
        value
    }
}

// MARK: - ScriptedGenerator

/// Returns the given values in order, then repeats the last one. For a
/// two-element array, `randomElement(using:)` picks index 0 for 0 and index 1
/// for `UInt64.max`.
private struct ScriptedGenerator: RandomNumberGenerator {
    // MARK: Properties

    var values: [UInt64]

    // MARK: Functions

    mutating func next() -> UInt64 {
        values.count > 1 ? values.removeFirst() : values[0]
    }
}

// MARK: - ReproducibilityTests

final class ReproducibilityTests: XCTestCase {
    // MARK: SeededRandomNumberGenerator

    /// Reference values from an independent SplitMix64 implementation. Those
    /// for seed 0 are the published SplitMix64 test vector.
    func testMatchesReferenceSplitMix64Values() {
        let expected: [(seed: UInt64, values: [UInt64])] = [
            (0, [0xE220_A839_7B1D_CDAF, 0x6E78_9E6A_A1B9_65F4, 0x06C4_5D18_8009_454F]),
            (1, [0x910A_2DEC_8902_5CC1, 0xBEEB_8DA1_658E_EC67, 0xF893_A2EE_FB32_555E]),
            (42, [0xBDD7_3226_2FEB_6E95, 0x28EF_E333_B266_F103, 0x4752_6757_130F_9F52]),
            (UInt64.max, [0xE4D9_7177_1B65_2C20, 0xE99F_F867_DBF6_82C9, 0x382F_F84C_B272_81E9]),
        ]
        for (seed, values) in expected {
            var generator = SeededRandomNumberGenerator(seed: seed)
            XCTAssertEqual((0 ..< 3).map { _ in generator.next() }, values, "seed \(seed)")
        }
    }

    func testSameSeedGivesTheSameSequence() {
        var first = SeededRandomNumberGenerator(seed: 2024)
        var second = SeededRandomNumberGenerator(seed: 2024)

        XCTAssertEqual((0 ..< 1000).map { _ in first.next() }, (0 ..< 1000).map { _ in second.next() })
    }

    func testDifferentSeedsGiveDifferentSequences() {
        var first = SeededRandomNumberGenerator(seed: 1)
        var second = SeededRandomNumberGenerator(seed: 2)

        XCTAssertNotEqual((0 ..< 10).map { _ in first.next() }, (0 ..< 10).map { _ in second.next() })
    }

    func testCopyContinuesWithTheSameSequence() {
        var original = SeededRandomNumberGenerator(seed: 5)
        _ = original.next()
        var copy = original

        XCTAssertEqual((0 ..< 10).map { _ in original.next() }, (0 ..< 10).map { _ in copy.next() })
    }

    // MARK: The solver's randomNumberGenerator

    func testSolverDecisionsUseItsRandomNumberGenerator() {
        // With a generator that always returns 0, even a 1% rate always
        // applies crossover and mutation.
        var always = makeMarkingSolver(crossoverRate: 0.01, mutationRate: 0.01)
        always.randomNumberGenerator = ConstantGenerator(value: 0)
        always.step()
        XCTAssertEqual(always.currentPopulation.map(\.id), [1100, 1101, 1100, 1101], "Crossed (+100) and mutated (+1000)")

        // With one that always returns UInt64.max, even a 99% rate never does.
        var never = makeMarkingSolver(crossoverRate: 0.99, mutationRate: 0.99)
        never.randomNumberGenerator = ConstantGenerator(value: .max)
        never.step()
        XCTAssertEqual(never.currentPopulation.map(\.id), [0, 1, 0, 1], "Copied parents, not mutated")
    }

    func testCopiedSolverMakesTheSameDecisions() {
        var original = makeMarkingSolver(crossoverRate: 0.5, mutationRate: 0.5)
        original.randomNumberGenerator = SeededRandomNumberGenerator(seed: 11)
        original.step()
        var copy = original

        for _ in 0 ..< 5 {
            original.step()
            copy.step()
            XCTAssertEqual(original.currentPopulation.map(\.id), copy.currentPopulation.map(\.id))
        }
    }

    func testSeededRunsAreReproducible() {
        XCTAssertEqual(seededRun(seed: 7), seededRun(seed: 7))
        XCTAssertNotEqual(seededRun(seed: 7), seededRun(seed: 8))
    }

    // MARK: tournamentSelection

    func testTournamentSelectionWithTheSameSeedPicksTheSameParents() {
        let population = (0 ..< 20).map { ScoredIndividual(id: $0, score: $0 % 7) }
        let first = GeneticSolver<ScoredIndividual>.tournamentSelection(using: SeededRandomNumberGenerator(seed: 3))
        let second = GeneticSolver<ScoredIndividual>.tournamentSelection(using: SeededRandomNumberGenerator(seed: 3))

        for _ in 0 ..< 100 {
            let (a1, b1) = first(population)
            let (a2, b2) = second(population)
            XCTAssertEqual([a1.id, b1.id], [a2.id, b2.id])
        }
    }

    func testTournamentSizeOneDrawsUniformly() {
        XCTAssertEqual(weakShare(tournamentSize: 1), 0.5, accuracy: 0.03)
    }

    func testDefaultTournamentSizeIsThree() {
        // The weaker of two individuals wins only when all three draws are it.
        XCTAssertEqual(weakShare(tournamentSize: nil), 1.0 / 8, accuracy: 0.025)
    }

    func testLargerTournamentsFavorFitterIndividualsMore() {
        XCTAssertEqual(weakShare(tournamentSize: 5), 1.0 / 32, accuracy: 0.012)
    }

    func testTournamentTieGoesToTheIndividualDrawnFirst() {
        let first = ScoredIndividual(id: 0, score: 5)
        let second = ScoredIndividual(id: 1, score: 5)

        // Draws: index 0 then 1 for the first parent, 1 then 0 for the second.
        let select = GeneticSolver<ScoredIndividual>.tournamentSelection(
            tournamentSize: 2,
            using: ScriptedGenerator(values: [0, .max, .max, 0])
        )
        let (parent1, parent2) = select([first, second])

        XCTAssertEqual(parent1.id, 0)
        XCTAssertEqual(parent2.id, 1)
    }

    func testTournamentFitterIndividualWinsWhicheverIsDrawnFirst() {
        let weak = ScoredIndividual(id: 0, score: 1)
        let strong = ScoredIndividual(id: 1, score: 2)

        let select = GeneticSolver<ScoredIndividual>.tournamentSelection(
            tournamentSize: 2,
            using: ScriptedGenerator(values: [0, .max, .max, 0])
        )
        let (parent1, parent2) = select([weak, strong])

        XCTAssertEqual([parent1.id, parent2.id], [1, 1])
    }

    func testTournamentEvaluatesEachDrawnIndividualOnce() {
        let counter = FitnessCallCounter()
        let population = (0 ..< 10).map { ScoredIndividual(id: $0, score: $0, counter: counter) }

        _ = GeneticSolver<ScoredIndividual>.tournamentSelection(tournamentSize: 4)(population)

        XCTAssertEqual(counter.calls, 8, "Two tournaments of four")
    }

    func testTournamentSelectionReturnsMembersOfThePopulation() {
        let population = (0 ..< 5).map { ScoredIndividual(id: $0, score: 1) }
        let select = GeneticSolver<ScoredIndividual>.tournamentSelection(tournamentSize: 2)

        for _ in 0 ..< 200 {
            let (first, second) = select(population)
            XCTAssertTrue((0 ..< 5).contains(first.id))
            XCTAssertTrue((0 ..< 5).contains(second.id))
        }
        let (only1, only2) = select([ScoredIndividual(id: 9, score: 0)])
        XCTAssertEqual([only1.id, only2.id], [9, 9])
    }

    // MARK: Helpers

    /// A solver whose crossover adds 100 to each parent's id and whose
    /// mutation adds 1000, so the ids show which operators were applied.
    /// Selection always picks the first two individuals.
    private func makeMarkingSolver(crossoverRate: Double, mutationRate: Double) -> GeneticSolver<TestIndividual> {
        var solver = makeDeterministicSolver(
            crossoverRate: crossoverRate,
            crossoverOperator: { [TestIndividual(gene: $0.gene, id: $0.id + 100), TestIndividual(gene: $1.gene, id: $1.id + 100)] }
        )
        solver.mutationRate = mutationRate
        solver.mutationOperator = { TestIndividual(gene: $0.gene, id: $0.id + 1000) }
        return solver
    }

    /// Runs 30 generations where every random choice comes from generators
    /// seeded with `seed`, and returns each generation's scores.
    private func seededRun(seed: UInt64) -> [[Int]] {
        var random = SeededRandomNumberGenerator(seed: seed)
        func randomIndividual() -> ScoredIndividual {
            ScoredIndividual(id: 0, score: Int.random(in: 0 ... 1000, using: &random))
        }
        var solver = GeneticSolver<ScoredIndividual>(
            populationSize: 10,
            crossoverRate: 0.7,
            mutationRate: 0.3,
            selectionOperator: GeneticSolver.tournamentSelection(using: SeededRandomNumberGenerator(seed: seed &+ 1)),
            crossoverOperator: { first, second in
                [ScoredIndividual(id: 0, score: (first.score + second.score) / 2), randomIndividual()]
            },
            mutationOperator: { _ in randomIndividual() },
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: randomIndividual
        )
        solver.randomNumberGenerator = SeededRandomNumberGenerator(seed: seed &+ 2)

        var scores = [solver.currentPopulation.map(\.score)]
        for _ in 0 ..< 30 {
            solver.step()
            scores.append(solver.currentPopulation.map(\.score))
        }
        return scores
    }

    /// The share of 10,000 picks won by the weaker of two individuals.
    /// `nil` uses the default `GeneticOperators` selection.
    private func weakShare(tournamentSize: Int?) -> Double {
        let weak = ScoredIndividual(id: 0, score: 0)
        let strong = ScoredIndividual(id: 1, score: 1)
        let select: SelectionOperator<ScoredIndividual> = if let tournamentSize {
            GeneticSolver.tournamentSelection(tournamentSize: tournamentSize, using: SeededRandomNumberGenerator(seed: 99))
        } else {
            { DefaultSelection.selectionOperator(population: $0) }
        }
        var weakPicks = 0
        for _ in 0 ..< 5000 {
            let (first, second) = select([weak, strong])
            weakPicks += [first, second].filter { $0.id == weak.id }.count
        }
        return Double(weakPicks) / 10000
    }
}

// MARK: - DefaultSelection

/// Uses every default `GeneticOperators` operator.
private enum DefaultSelection: GeneticOperators {
    static func newElement() -> ScoredIndividual {
        ScoredIndividual(id: 0, score: 0)
    }
}
