//  RankingTests.swift
//  genetic-solverTests
//
//  Tests how the built-in operators rank fitness values, including NaN,
//  which ranks below every other value.

import XCTest
@testable import genetic_solver

// MARK: - RankingTests

final class RankingTests: XCTestCase {
    // MARK: isFitter(_:than:)

    func testOrderedValuesCompareWithGreaterThan() {
        XCTAssertTrue(isFitter(2.0, than: 1.0))
        XCTAssertFalse(isFitter(1.0, than: 2.0))
        XCTAssertFalse(isFitter(1.0, than: 1.0))
        XCTAssertFalse(isFitter(0.0, than: -0.0), "0 and -0 are equal")
        XCTAssertTrue(isFitter(Double.infinity, than: Double.greatestFiniteMagnitude))
        XCTAssertTrue(isFitter(3, than: 2), "Integers compare as usual")
        XCTAssertFalse(isFitter(2, than: 2))
    }

    func testNaNRanksBelowEveryOtherValue() {
        for value in [-Double.infinity, -1, 0, 1, Double.infinity] {
            XCTAssertTrue(isFitter(value, than: .nan), "\(value) ranks above NaN")
            XCTAssertFalse(isFitter(.nan, than: value), "NaN doesn't rank above \(value)")
        }
        XCTAssertFalse(isFitter(Double.nan, than: .nan), "Two NaNs tie")
        XCTAssertTrue(isFitter(Float(1), than: .nan), "Float too")
        XCTAssertFalse(isFitter(Float.nan, than: -.infinity))
    }

    // MARK: Elitism

    /// With `>` alone, NaN looked equal to both 1 and 5 while 5 ranked above
    /// 1, so the order was unspecified and the elite could miss the best.
    func testFittestIgnoresNaNInFavourOfRealValues() {
        let population = evaluated([1, .nan, 5])

        XCTAssertEqual(fittest(1, of: population), [2])
        XCTAssertEqual(fittest(3, of: population), [2, 0, 1])
    }

    func testFittestRanksNaNLastInPopulationOrder() {
        let population = evaluated([.nan, 3, .nan, -.infinity, 3, .nan])

        XCTAssertEqual(fittest(6, of: population), [1, 4, 3, 0, 2, 5])
        XCTAssertEqual(fittest(2, of: evaluated([.nan, .nan, .nan])), [0, 1], "All NaN: population order")
    }

    /// The ranking must not depend on where NaN values are: for every
    /// arrangement of the same values, the fittest are the same values in
    /// the same order.
    func testFittestGivesTheSameRankingForEveryArrangement() {
        var random = SeededRandomNumberGenerator(seed: 8)
        let values: [Double] = [4, .nan, 1, 4, .nan, -2, 7, .nan, 0]

        for _ in 0 ..< 500 {
            let arrangement = values.shuffled(using: &random)
            let population = evaluated(arrangement)
            let ranked = GeneticSolver<Measured>.fittest(values.count, of: population).map(\.fitness)

            XCTAssertEqual(ranked.prefix(6), [7, 4, 4, 1, 0, -2])
            XCTAssertTrue(ranked.suffix(3).allSatisfy(\.isNaN))
        }
    }

    // MARK: bestElement and tournaments

    func testBestElementIgnoresNaNInFavourOfRealValues() {
        XCTAssertEqual(makeSolver(values: [.nan, 1, .nan, 5, 2]).bestElement.element.id, 3)
        XCTAssertEqual(makeSolver(values: [.nan, -.infinity]).bestElement.element.id, 1)
        XCTAssertEqual(makeSolver(values: [.nan, .nan]).bestElement.element.id, 0, "All NaN: the first")
    }

    /// A NaN drawn first used to win the tournament, because no value is
    /// greater than NaN.
    func testTournamentPrefersARealValueToANaNDrawnFirst() {
        let population = evaluated([.nan, 1])
        // Draws: index 0 then 1 for each parent.
        var generator = ScriptedGenerator(values: [0, .max, 0, .max])

        let (first, second) = tournamentPair(from: population, size: 2, using: &generator)

        XCTAssertEqual([first.element.id, second.element.id], [1, 1])
    }

    func testTournamentOfNaNsGoesToTheOneDrawnFirst() {
        let population = evaluated([.nan, .nan])
        var generator = ScriptedGenerator(values: [.max, 0, 0, .max])

        let (first, second) = tournamentPair(from: population, size: 2, using: &generator)

        XCTAssertEqual([first.element.id, second.element.id], [1, 0])
    }

    // MARK: In the solver

    /// Some mutations produce NaN fitness. With elitism, the best real
    /// fitness never goes down and the elite are never NaN while a real
    /// value exists.
    func testElitismKeepsTheBestRealFitnessWhenSomeFitnessIsNaN() {
        var random = SeededRandomNumberGenerator(seed: 9)
        var nextID = 0
        func make(_ value: Double) -> Measured {
            defer { nextID += 1 }
            return Measured(id: nextID, value: value)
        }
        var solver = GeneticSolver<Measured>(
            populationSize: 12,
            crossoverRate: 0.5,
            mutationRate: 0.5,
            eliteCount: 2,
            selectionOperator: GeneticSolver.tournamentSelection(using: SeededRandomNumberGenerator(seed: 10)),
            crossoverOperator: { [make(($0.value + $1.value) / 2), make($0.value)] },
            mutationOperator: { individual in
                Double.random(in: 0 ..< 1, using: &random) < 0.3 ? make(.nan) : make(individual.value + Double.random(in: -1 ... 2, using: &random))
            },
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: { make(Double.random(in: 0 ... 10, using: &random)) }
        )
        solver.randomNumberGenerator = SeededRandomNumberGenerator(seed: 11)

        var bestValues = [solver.bestElement.fitness]
        var nanCount = 0
        for _ in 0 ..< 300 {
            solver.step()
            nanCount += solver.currentPopulation.filter(\.fitness.isNaN).count
            XCTAssertFalse(solver.currentPopulation.prefix(2).contains { $0.fitness.isNaN }, "The elite are real values")
            bestValues.append(solver.bestElement.fitness)
        }

        XCTAssertGreaterThan(nanCount, 0, "The run must contain NaN fitness to test anything")
        XCTAssertFalse(bestValues.contains(where: \.isNaN))
        XCTAssertEqual(bestValues, bestValues.sorted(), "The best real fitness never goes down")
    }

    // MARK: Helpers

    private func evaluated(_ values: [Double]) -> [EvaluatedElement<Measured>] {
        values.enumerated().map { EvaluatedElement(Measured(id: $0.offset, value: $0.element)) }
    }

    private func fittest(_ count: Int, of population: [EvaluatedElement<Measured>]) -> [Int] {
        GeneticSolver<Measured>.fittest(count, of: population).map(\.element.id)
    }

    /// A solver whose starting population has the given fitness values, in
    /// order, with ids from 0.
    private func makeSolver(values: [Double]) -> GeneticSolver<Measured> {
        var remaining = values.enumerated().map { Measured(id: $0.offset, value: $0.element) }[...]
        return GeneticSolver<Measured>(
            populationSize: values.count,
            selectionOperator: { ($0[0], $0[0]) },
            crossoverOperator: { [$0, $1] },
            mutationOperator: { $0 },
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: { remaining.popFirst()! }
        )
    }
}
