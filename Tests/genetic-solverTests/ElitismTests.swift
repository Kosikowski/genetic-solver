//  ElitismTests.swift
//  genetic-solverTests
//
//  Tests GeneticSolver.elitistReplacement(eliteCount:) and bestElement.

import XCTest
@testable import genetic_solver

// MARK: - ElitismTests

final class ElitismTests: XCTestCase {
    // MARK: Elitist replacement

    func testKeepsTheFittestOfTheCurrentPopulationFirst() {
        let old = individuals(scores: [5, 1, 9, 3])
        let new = individuals(scores: [0, 0, 0, 0], firstID: 10)

        let next = elitist(2)(old, new)

        XCTAssertEqual(next.map(\.id), [2, 0, 10, 11], "The two fittest old ones, then the first new ones")
    }

    func testZeroEliteCountReturnsTheNewIndividualsWithoutEvaluatingFitness() {
        let counter = FitnessCallCounter()
        let old = individuals(scores: [5, 1], counter: counter)
        let new = individuals(scores: [0, 0], firstID: 10, counter: counter)

        let next = elitist(0)(old, new)

        XCTAssertEqual(next.map(\.id), [10, 11])
        XCTAssertEqual(counter.calls, 0)
    }

    func testEliteCountLargerThanTheCurrentPopulationKeepsAllOfIt() {
        let old = individuals(scores: [1, 4])
        let new = individuals(scores: [0, 0, 0, 0], firstID: 10)

        let next = elitist(5)(old, new)

        XCTAssertEqual(next.map(\.id), [1, 0, 10, 11])
    }

    func testEliteCountAtLeastTheNewCountReturnsOnlyTheElite() {
        let old = individuals(scores: [1, 4, 3, 2])
        let new = individuals(scores: [0, 0], firstID: 10)

        let next = elitist(3)(old, new)

        XCTAssertEqual(next.map(\.id), [1, 2], "Only as many as there are new individuals")
    }

    func testTiesKeepTheEarlierIndividual() {
        let old = individuals(scores: [7, 7, 7])
        let new = individuals(scores: [0, 0, 0], firstID: 10)

        let next = elitist(2)(old, new)

        XCTAssertEqual(next.map(\.id), [0, 1, 10])
    }

    func testEvaluatesEachCurrentIndividualOnceAndNoNewOnes() {
        let oldCounter = FitnessCallCounter()
        let newCounter = FitnessCallCounter()
        let old = individuals(scores: [3, 1, 2, 5, 4], counter: oldCounter)
        let new = individuals(scores: [0, 0, 0, 0, 0], firstID: 10, counter: newCounter)

        _ = elitist(2)(old, new)

        XCTAssertEqual(oldCounter.calls, 5)
        XCTAssertEqual(newCounter.calls, 0)
    }

    func testEmptyPopulations() {
        let some = individuals(scores: [1, 2])

        XCTAssertEqual(elitist(2)([], some).map(\.id), [0, 1])
        XCTAssertTrue(elitist(2)(some, []).isEmpty)
        XCTAssertTrue(elitist(2)([], []).isEmpty)
    }

    func testResultAlwaysHasTheSizeOfTheNewIndividuals() {
        for oldCount in 0 ... 5 {
            for newCount in 0 ... 5 {
                for eliteCount in 0 ... 6 {
                    let old = individuals(scores: Array(repeating: 1, count: oldCount))
                    let new = individuals(scores: Array(repeating: 0, count: newCount), firstID: 100)
                    XCTAssertEqual(
                        elitist(eliteCount)(old, new).count,
                        newCount,
                        "old \(oldCount), new \(newCount), elite \(eliteCount)"
                    )
                }
            }
        }
    }

    // MARK: Elitism in the solver

    /// Mutation always produces an individual with score 0, so without
    /// elitism the best individual is lost after one generation.
    func testElitismKeepsTheBestThatTheDefaultReplacementLoses() {
        var withoutElitism = makeWorseningSolver()
        var withElitism = makeWorseningSolver()
        withElitism.replacementOperator = GeneticSolver.elitistReplacement(eliteCount: 1)

        withoutElitism.step()
        withElitism.step()

        XCTAssertEqual(withoutElitism.bestElement.score, 0)
        XCTAssertEqual(withElitism.bestElement.score, 9)
        XCTAssertEqual(withElitism.currentPopulation.count, 4)
    }

    func testBestFitnessNeverDecreasesWithElitism() {
        let counter = FitnessCallCounter()
        var nextID = 0
        func random() -> ScoredIndividual {
            defer { nextID += 1 }
            return ScoredIndividual(id: nextID, score: Int.random(in: 0 ... 1000), counter: counter)
        }
        var solver = GeneticSolver<ScoredIndividual>(
            populationSize: 10,
            crossoverRate: 0.5,
            mutationRate: 1,
            selectionOperator: { ($0.randomElement()!, $0.randomElement()!) },
            crossoverOperator: { _, _ in [random(), random()] },
            mutationOperator: { _ in random() },
            replacementOperator: GeneticSolver.elitistReplacement(eliteCount: 2),
            terminationCheck: { _, _ in false },
            newElement: random
        )

        var bestScores = [solver.bestElement.score]
        for _ in 0 ..< 200 {
            solver.step()
            bestScores.append(solver.bestElement.score)
        }

        XCTAssertEqual(bestScores, bestScores.sorted(), "The best score must never go down")
    }

    // MARK: bestElement

    func testBestElementIsTheFittestOfTheCurrentPopulation() {
        let solver = makeSolver(scores: [3, 8, 1, 5])

        XCTAssertEqual(solver.bestElement.id, 1)
    }

    func testBestElementOnATieIsTheFirst() {
        let solver = makeSolver(scores: [2, 6, 6, 1])

        XCTAssertEqual(solver.bestElement.id, 1)
    }

    func testBestElementOfASingleIndividual() {
        let solver = makeSolver(scores: [4])

        XCTAssertEqual(solver.bestElement.id, 0)
    }

    func testBestElementEvaluatesEachIndividualOnce() {
        let counter = FitnessCallCounter()
        let solver = makeSolver(scores: [3, 8, 1, 5], counter: counter)
        counter.calls = 0

        _ = solver.bestElement

        XCTAssertEqual(counter.calls, 4)
    }

    // MARK: Helpers

    private func elitist(_ eliteCount: Int) -> ReplacementOperator<ScoredIndividual> {
        GeneticSolver<ScoredIndividual>.elitistReplacement(eliteCount: eliteCount)
    }

    private func individuals(scores: [Int], firstID: Int = 0, counter: FitnessCallCounter = FitnessCallCounter()) -> [ScoredIndividual] {
        scores.enumerated().map { ScoredIndividual(id: firstID + $0.offset, score: $0.element, counter: counter) }
    }

    /// A solver whose starting population has the given scores, in order.
    private func makeSolver(scores: [Int], counter: FitnessCallCounter = FitnessCallCounter()) -> GeneticSolver<ScoredIndividual> {
        var remaining = individuals(scores: scores, counter: counter)[...]
        return GeneticSolver<ScoredIndividual>(
            populationSize: scores.count,
            selectionOperator: { ($0[0], $0[0]) },
            crossoverOperator: { [$0, $1] },
            mutationOperator: { $0 },
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: { remaining.popFirst()! }
        )
    }

    /// A solver whose starting scores are [2, 9, 4, 1] and whose mutation,
    /// applied to every child, produces score 0.
    private func makeWorseningSolver() -> GeneticSolver<ScoredIndividual> {
        var solver = makeSolver(scores: [2, 9, 4, 1])
        solver.mutationRate = 1
        solver.mutationOperator = { ScoredIndividual(id: 100 + $0.id, score: 0, counter: $0.counter) }
        return solver
    }
}
