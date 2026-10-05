//  ElitismTests.swift
//  genetic-solverTests
//
//  Tests the solver's eliteCount and bestElement.

import XCTest
@testable import genetic_solver

// MARK: - ComparisonCounter

/// Counts how often fitness values are compared.
private final class ComparisonCounter {
    var count = 0
}

// MARK: - CountedFitness

/// A fitness that counts its comparisons (`<` and `==`).
private struct CountedFitness: Comparable {
    // MARK: Properties

    let value: Int
    let counter: ComparisonCounter

    // MARK: Static Functions

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.counter.count += 1
        return lhs.value < rhs.value
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.counter.count += 1
        return lhs.value == rhs.value
    }
}

// MARK: - Ranked

/// An individual whose fitness counts its comparisons.
private struct Ranked: GeneticElement {
    // MARK: Properties

    let id: Int
    let rank: CountedFitness

    // MARK: Functions

    func fitness() -> CountedFitness {
        rank
    }
}

// MARK: - ElitismTests

final class ElitismTests: XCTestCase {
    // MARK: Which individuals are kept

    func testTheFittestComeFirstFollowedByTheOffspring() {
        var solver = makeSolver(scores: [5, 1, 9, 3], eliteCount: 2)

        solver.step()

        XCTAssertEqual(solver.currentPopulation.map(\.element.id), [2, 0, 100, 101], "Ids 2 and 0 score 9 and 5")
    }

    func testTiesKeepTheEarlierIndividual() {
        var solver = makeSolver(scores: [7, 7, 7, 7], eliteCount: 3)

        solver.step()

        XCTAssertEqual(solver.currentPopulation.map(\.element.id), [0, 1, 2, 100])
    }

    func testEliteCountOfZeroKeepsOnlyOffspring() {
        var solver = makeSolver(scores: [5, 1, 9, 3], eliteCount: 0)

        solver.step()

        XCTAssertEqual(solver.currentPopulation.map(\.element.id), [100, 101, 102, 103])
    }

    /// The elite skip selection, crossover and mutation, and keep the fitness
    /// they have.
    func testTheEliteAreCarriedOverUnchangedAndNotEvaluatedAgain() {
        let counter = FitnessCallCounter()
        var solver = makeSolver(scores: [5, 1, 9, 3], eliteCount: 2, counter: counter)
        solver.mutationRate = 1
        solver.mutationOperator = { ScoredIndividual(id: $0.id + 1000, score: $0.score, counter: $0.counter) }
        counter.calls = 0

        solver.step()

        XCTAssertEqual(solver.currentPopulation.map(\.element.id), [2, 0, 1100, 1101], "The elite aren't mutated")
        XCTAssertEqual(solver.currentPopulation.map(\.fitness), [9, 5, 0, 0])
        XCTAssertEqual(counter.calls, 2, "Only the two mutated offspring are evaluated")
    }

    // MARK: Offspring

    /// Only `populationSize - eliteCount` offspring are created, so no
    /// operator work is thrown away.
    func testOnlyPopulationSizeMinusEliteCountOffspringAreCreated() {
        var selections = 0
        var mutations = 0
        var solver = makeSolver(scores: Array(0 ..< 10), eliteCount: 3)
        let selection = solver.selectionOperator
        solver.selectionOperator = { selections += 1; return selection($0) }
        solver.mutationRate = 1
        solver.mutationOperator = { mutations += 1; return $0 }

        solver.step()

        XCTAssertEqual(selections, 4, "Pairs for 7 offspring")
        XCTAssertEqual(mutations, 7)
        XCTAssertEqual(solver.currentPopulation.count, 10)
    }

    /// With the largest allowed `eliteCount`, each generation still has one
    /// new individual. An `eliteCount` equal to the population size used to
    /// keep the population unchanged forever.
    func testLargestEliteCountStillLetsTheRunImprove() {
        var nextID = 0
        var solver = GeneticSolver<ScoredIndividual>(
            populationSize: 2,
            mutationRate: 1,
            eliteCount: 1,
            selectionOperator: { population in
                let fittest = population.max { $0.fitness < $1.fitness }!
                return (fittest, fittest)
            },
            crossoverOperator: { [$0, $1] },
            mutationOperator: { individual in
                defer { nextID += 1 }
                return ScoredIndividual(id: 100 + nextID, score: individual.score + 1)
            },
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: { ScoredIndividual(id: 0, score: 0) }
        )

        solver.solve(maxGenerations: 50)

        XCTAssertEqual(solver.bestElement.fitness, 50, "One improvement per generation")
        XCTAssertEqual(solver.currentPopulation.count, 2)
    }

    // MARK: Rules

    func testEliteCountMustBeAtLeastZeroAndLessThanThePopulationSize() {
        typealias Solver = GeneticSolver<ScoredIndividual>
        XCTAssertNil(Solver.invalidEliteCountMessage(0, populationSize: 1))
        XCTAssertNil(Solver.invalidEliteCountMessage(4, populationSize: 5))
        for eliteCount in [5, 6, Int.max] {
            XCTAssertEqual(
                Solver.invalidEliteCountMessage(eliteCount, populationSize: 5),
                "eliteCount must be at least 0 and less than populationSize (5), but is \(eliteCount)"
            )
        }
        for eliteCount in [-1, Int.min] {
            XCTAssertEqual(
                Solver.invalidEliteCountMessage(eliteCount, populationSize: 5),
                "eliteCount must be at least 0 and less than populationSize (5), but is \(eliteCount)"
            )
        }
    }

    func testPopulationSizeMustBeGreaterThanTheEliteCount() {
        typealias Solver = GeneticSolver<ScoredIndividual>
        XCTAssertNil(Solver.invalidPopulationSizeMessage(3, eliteCount: 2))
        XCTAssertNil(Solver.invalidPopulationSizeMessage(1, eliteCount: 0))
        XCTAssertEqual(
            Solver.invalidPopulationSizeMessage(2, eliteCount: 2),
            "populationSize must be greater than eliteCount (2), but is 2"
        )
    }

    func testInitReportsTheEliteCountAfterTheOtherParameters() {
        typealias Solver = GeneticSolver<ScoredIndividual>
        XCTAssertEqual(
            Solver.invalidParameterMessage(populationSize: 4, crossoverRate: 0.5, mutationRate: 0.5, eliteCount: 4),
            "eliteCount must be at least 0 and less than populationSize (4), but is 4"
        )
        XCTAssertEqual(
            Solver.invalidParameterMessage(populationSize: 0, crossoverRate: 0.5, mutationRate: 0.5, eliteCount: 4),
            "populationSize must be at least 1, but is 0"
        )
        XCTAssertNil(Solver.invalidParameterMessage(populationSize: 4, crossoverRate: 0.5, mutationRate: 0.5, eliteCount: 3))
    }

    func testEliteCountAndPopulationSizeCanChangeBetweenGenerations() {
        var solver = makeSolver(scores: [5, 1, 9, 3], eliteCount: 0)

        solver.eliteCount = 3
        solver.step()
        XCTAssertEqual(solver.currentPopulation.map(\.element.id), [2, 0, 3, 100])

        solver.populationSize = 6
        solver.eliteCount = 5
        solver.step()
        XCTAssertEqual(solver.currentPopulation.count, 6)
        XCTAssertEqual(Array(solver.currentPopulation.map(\.element.id).prefix(4)), [2, 0, 3, 100], "All four carried over")

        solver.eliteCount = 0
        solver.populationSize = 1
        solver.step()
        XCTAssertEqual(solver.currentPopulation.count, 1)
    }

    // MARK: Elitism in the solver

    /// Mutation always produces an individual with score 0, so without
    /// elitism the best individual is lost after one generation.
    func testElitismKeepsTheBestThatIsOtherwiseLost() {
        var withoutElitism = makeWorseningSolver(eliteCount: 0)
        var withElitism = makeWorseningSolver(eliteCount: 1)

        withoutElitism.step()
        withElitism.step()

        XCTAssertEqual(withoutElitism.bestElement.element.score, 0)
        XCTAssertEqual(withElitism.bestElement.element.score, 9)
        XCTAssertEqual(withElitism.currentPopulation.count, 4)
    }

    func testBestFitnessNeverDecreasesWithElitism() {
        var nextID = 0
        func random() -> ScoredIndividual {
            defer { nextID += 1 }
            return ScoredIndividual(id: nextID, score: Int.random(in: 0 ... 1000))
        }
        var solver = GeneticSolver<ScoredIndividual>(
            populationSize: 10,
            crossoverRate: 0.5,
            mutationRate: 1,
            eliteCount: 2,
            selectionOperator: { ($0.randomElement()!, $0.randomElement()!) },
            crossoverOperator: { _, _ in [random(), random()] },
            mutationOperator: { _ in random() },
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: random
        )

        var bestScores = [solver.bestElement.fitness]
        for _ in 0 ..< 200 {
            solver.step()
            bestScores.append(solver.bestElement.fitness)
        }

        XCTAssertEqual(bestScores, bestScores.sorted(), "The best score must never go down")
    }

    func testReplacementReceivesTheEliteFirst() {
        var received: [Int] = []
        var solver = makeSolver(scores: [5, 1, 9, 3], eliteCount: 1)
        solver.replacementOperator = { _, new in
            received = new.map(\.element.id)
            return new
        }

        solver.step()

        XCTAssertEqual(received, [2, 100, 101, 102])
    }

    func testOperatorsInitializerTakesTheEliteCount() {
        let solver = GeneticSolver(
            populationSize: 5,
            eliteCount: 2,
            operators: ScoredDefaultOperators.self,
            terminationCheck: { _, _ in false }
        )

        XCTAssertEqual(solver.eliteCount, 2)
    }

    // MARK: fittest(_:of:)

    func testFittestReturnsTheFittestInOrderAndKeepsTiesInPopulationOrder() {
        let population = evaluated(scores: [3, 8, 1, 8, 5])
        typealias Solver = GeneticSolver<ScoredIndividual>

        XCTAssertEqual(Solver.fittest(3, of: population).map(\.element.id), [1, 3, 4])
        XCTAssertEqual(Solver.fittest(1, of: population).map(\.element.id), [1])
        XCTAssertEqual(Solver.fittest(5, of: population).map(\.element.id), [1, 3, 4, 0, 2])
        XCTAssertEqual(Solver.fittest(9, of: population).map(\.element.id), [1, 3, 4, 0, 2], "Not more than there are")
        XCTAssertTrue(Solver.fittest(0, of: population).isEmpty)
        XCTAssertTrue(Solver.fittest(2, of: []).isEmpty)
    }

    /// `fittest(_:of:)` keeps only `count` individuals instead of sorting
    /// the population; it must still return exactly what a stable sort by
    /// the same rule returns, for every count, with ties and NaN.
    func testFittestMatchesASortedReference() {
        var random = SeededRandomNumberGenerator(seed: 13)
        let values: [Double] = [0, 1, 1, 2, 3, 3, 3, -1, .nan, .infinity, -.infinity]

        for _ in 0 ..< 300 {
            let size = Int.random(in: 0 ... 25, using: &random)
            let population = (0 ..< size).map { EvaluatedElement(Measured(id: $0, value: values.randomElement(using: &random)!)) }
            let reference = population.indices.sorted { first, second in
                if isFitter(population[first].fitness, than: population[second].fitness) {
                    return true
                }
                if isFitter(population[second].fitness, than: population[first].fitness) {
                    return false
                }
                return first < second
            }

            for count in 0 ... size + 2 {
                XCTAssertEqual(
                    GeneticSolver<Measured>.fittest(count, of: population).map(\.element.id),
                    Array(reference.prefix(count)),
                    "size \(size), count \(count)"
                )
            }
        }
    }

    /// Picking 2 of 1,000 shuffled individuals takes about one ranking
    /// (three comparisons) per individual: about 3,100 comparisons. Sorting
    /// the whole population, as before, took about 70,000.
    func testFittestComparesAboutOncePerIndividualForASmallCount() {
        let counter = ComparisonCounter()
        var random = SeededRandomNumberGenerator(seed: 14)
        let population = (0 ..< 1000).shuffled(using: &random).enumerated().map {
            EvaluatedElement(Ranked(id: $0.offset, rank: CountedFitness(value: $0.element, counter: counter)))
        }
        counter.count = 0

        let elite = GeneticSolver<Ranked>.fittest(2, of: population)

        XCTAssertEqual(elite.map(\.fitness.value), [999, 998])
        XCTAssertLessThan(counter.count, 4000)
    }

    /// In the worst order, weakest first, each individual is fitter than all
    /// the kept ones, so it is also placed with a binary search: about 9,000
    /// comparisons for 2 of 1,000, still one pass. (Sorting an already
    /// ordered population is cheaper, but populations are rarely ordered.)
    func testFittestStaysLinearInTheWorstOrder() {
        let counter = ComparisonCounter()
        let population = (0 ..< 1000).map { EvaluatedElement(Ranked(id: $0, rank: CountedFitness(value: $0, counter: counter))) }
        counter.count = 0

        let elite = GeneticSolver<Ranked>.fittest(2, of: population)

        XCTAssertEqual(elite.map(\.fitness.value), [999, 998])
        XCTAssertLessThan(counter.count, 10000)
    }

    func testFittestEvaluatesNothing() {
        let counter = FitnessCallCounter()
        let population = evaluated(scores: [3, 8, 1, 8, 5], counter: counter)
        counter.calls = 0

        _ = GeneticSolver<ScoredIndividual>.fittest(3, of: population)

        XCTAssertEqual(counter.calls, 0)
    }

    // MARK: bestElement

    func testBestElementIsTheFittestOfTheCurrentPopulation() {
        let solver = makeSolver(scores: [3, 8, 1, 5])

        XCTAssertEqual(solver.bestElement.element.id, 1)
    }

    func testBestElementOnATieIsTheFirst() {
        let solver = makeSolver(scores: [2, 6, 6, 1])

        XCTAssertEqual(solver.bestElement.element.id, 1)
    }

    func testBestElementOfASingleIndividual() {
        let solver = makeSolver(scores: [4])

        XCTAssertEqual(solver.bestElement.element.id, 0)
    }

    func testBestElementUsesTheStoredFitness() {
        let counter = FitnessCallCounter()
        let solver = makeSolver(scores: [3, 8, 1, 5], counter: counter)
        XCTAssertEqual(counter.calls, 4, "Each starting individual is evaluated once")

        let best = solver.bestElement

        XCTAssertEqual(best.fitness, 8)
        XCTAssertEqual(counter.calls, 4, "bestElement evaluates nothing")
    }

    // MARK: Helpers

    /// Individuals with the given scores and ids from 0, evaluated (one
    /// `fitness()` call each).
    private func evaluated(scores: [Int], counter: FitnessCallCounter = FitnessCallCounter()) -> [EvaluatedElement<ScoredIndividual>] {
        scores.enumerated().map { EvaluatedElement(ScoredIndividual(id: $0.offset, score: $0.element, counter: counter)) }
    }

    /// A solver whose starting population has the given scores, in order,
    /// with ids from 0. Selection picks the first individual twice, and
    /// crossover, applied to every pair, makes children numbered from 100
    /// with score 0.
    private func makeSolver(
        scores: [Int],
        eliteCount: Int = 0,
        counter: FitnessCallCounter = FitnessCallCounter()
    )
        -> GeneticSolver<ScoredIndividual>
    {
        var remaining = scores.enumerated().map { ScoredIndividual(id: $0.offset, score: $0.element, counter: counter) }[...]
        var nextChild = 100
        func child() -> ScoredIndividual {
            defer { nextChild += 1 }
            return ScoredIndividual(id: nextChild, score: 0, counter: counter)
        }
        return GeneticSolver<ScoredIndividual>(
            populationSize: scores.count,
            crossoverRate: 1,
            mutationRate: 0,
            eliteCount: eliteCount,
            selectionOperator: { ($0[0], $0[0]) },
            crossoverOperator: { _, _ in [child(), child()] },
            mutationOperator: { $0 },
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: { remaining.popFirst()! }
        )
    }

    /// A solver whose starting scores are [2, 9, 4, 1], whose crossover is
    /// never applied, and whose mutation, applied to every new individual,
    /// produces score 0.
    private func makeWorseningSolver(eliteCount: Int) -> GeneticSolver<ScoredIndividual> {
        var solver = makeSolver(scores: [2, 9, 4, 1], eliteCount: eliteCount)
        solver.crossoverRate = 0
        solver.mutationRate = 1
        solver.mutationOperator = { ScoredIndividual(id: 100 + $0.id, score: 0, counter: $0.counter) }
        return solver
    }
}
