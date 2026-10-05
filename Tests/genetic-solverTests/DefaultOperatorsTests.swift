//  DefaultOperatorsTests.swift
//  genetic-solverTests
//
//  Tests the default implementations that GeneticOperators provides.

import XCTest
@testable import genetic_solver

// MARK: - DefaultOperatorsTests

final class DefaultOperatorsTests: XCTestCase {
    // MARK: Selection

    func testSelectionEvaluatesEachCandidateOnce() {
        let counter = FitnessCallCounter()
        let population = (0 ..< 100).map { ScoredIndividual(id: $0, score: $0, counter: counter) }

        _ = ScoredDefaultOperators.selectionOperator(population: population)

        // Two tournaments of three candidates each.
        XCTAssertEqual(counter.calls, 6)
    }

    func testSelectionReturnsMembersOfThePopulation() {
        let counter = FitnessCallCounter()
        let population = (0 ..< 10).map { ScoredIndividual(id: $0, score: $0 % 3, counter: counter) }
        let ids = Set(population.map(\.id))

        for _ in 0 ..< 1000 {
            let (first, second) = ScoredDefaultOperators.selectionOperator(population: population)
            XCTAssertTrue(ids.contains(first.id))
            XCTAssertTrue(ids.contains(second.id))
        }
    }

    func testSelectionWithSingleIndividualReturnsItTwice() {
        let only = ScoredIndividual(id: 7, score: 1, counter: FitnessCallCounter())

        let (first, second) = ScoredDefaultOperators.selectionOperator(population: [only])

        XCTAssertEqual(first.id, 7)
        XCTAssertEqual(second.id, 7)
    }

    /// In a tournament of three, the weaker of two individuals only wins when
    /// all three candidates are the weaker one: (1/2)^3 = 12.5% of the time.
    func testSelectionPicksTheBestOfThreeCandidates() {
        let counter = FitnessCallCounter()
        let weak = ScoredIndividual(id: 0, score: 0, counter: counter)
        let strong = ScoredIndividual(id: 1, score: 1, counter: counter)
        let picks = 10000

        var weakPicks = 0
        for _ in 0 ..< picks / 2 {
            let (first, second) = ScoredDefaultOperators.selectionOperator(population: [weak, strong])
            weakPicks += [first, second].filter { $0.id == weak.id }.count
        }

        // The standard deviation is about 0.0033, so this range is over 7
        // standard deviations wide on each side.
        let weakShare = Double(weakPicks) / Double(picks)
        XCTAssertGreaterThan(weakShare, 0.10)
        XCTAssertLessThan(weakShare, 0.15)
    }

    /// The two parents come from separate tournaments, so they are not
    /// always the same individual.
    func testSelectionRunsTwoIndependentTournaments() {
        let counter = FitnessCallCounter()
        let population = (0 ..< 2).map { ScoredIndividual(id: $0, score: 5, counter: counter) }

        let differentPairs = (0 ..< 1000).filter { _ in
            let (first, second) = ScoredDefaultOperators.selectionOperator(population: population)
            return first.id != second.id
        }.count

        XCTAssertGreaterThan(differentPairs, 0)
    }

    // MARK: Crossover

    func testCrossoverReturnsTheParentsUnchangedInOrder() {
        let counter = FitnessCallCounter()
        let parent1 = ScoredIndividual(id: 1, score: 10, counter: counter)
        let parent2 = ScoredIndividual(id: 2, score: 20, counter: counter)

        let children = ScoredDefaultOperators.crossoverOperator(parent1: parent1, parent2: parent2)

        XCTAssertEqual(children.map(\.id), [1, 2])
        XCTAssertEqual(counter.calls, 0, "The default crossover doesn't need fitness")
    }

    func testCrossoverWithTheSameParentTwiceReturnsTwoCopies() {
        let parent = ScoredIndividual(id: 3, score: 0, counter: FitnessCallCounter())

        let children = ScoredDefaultOperators.crossoverOperator(parent1: parent, parent2: parent)

        XCTAssertEqual(children.map(\.id), [3, 3])
    }

    // MARK: Mutation

    func testMutationReturnsTheElementUnchanged() {
        let counter = FitnessCallCounter()
        let element = ScoredIndividual(id: 4, score: 40, counter: counter)

        let mutated = ScoredDefaultOperators.mutationOperator(element: element)

        XCTAssertEqual(mutated.id, 4)
        XCTAssertEqual(mutated.score, 40)
        XCTAssertEqual(counter.calls, 0, "The default mutation doesn't need fitness")
    }

    // MARK: Replacement

    func testReplacementReturnsTheNewIndividualsAndIgnoresTheOldOnes() {
        let counter = FitnessCallCounter()
        let old = (0 ..< 3).map { ScoredIndividual(id: $0, score: 100, counter: counter) }
        let new = (10 ..< 13).map { ScoredIndividual(id: $0, score: 0, counter: counter) }

        let next = ScoredDefaultOperators.replacementOperator(old: old, new: new)

        XCTAssertEqual(next.map(\.id), [10, 11, 12], "Even fitter old individuals are dropped")
        XCTAssertEqual(counter.calls, 0, "The default replacement doesn't need fitness")
    }

    func testReplacementKeepsTheSizeOfTheNewIndividuals() {
        let counter = FitnessCallCounter()
        let old = (0 ..< 3).map { ScoredIndividual(id: $0, score: 0, counter: counter) }
        let more = (10 ..< 15).map { ScoredIndividual(id: $0, score: 0, counter: counter) }

        XCTAssertEqual(ScoredDefaultOperators.replacementOperator(old: old, new: more).count, 5)
        XCTAssertTrue(ScoredDefaultOperators.replacementOperator(old: old, new: []).isEmpty)
        XCTAssertEqual(ScoredDefaultOperators.replacementOperator(old: [], new: more).count, 5)
    }

    // MARK: Fixed generation termination

    func testFixedGenerationTerminationPassesFromMaxGenerationsOn() {
        let check = ScoredDefaultOperators.fixedGenerationTermination(maxGenerations: 3)

        XCTAssertEqual((0 ... 5).map { check($0, []) }, [false, false, false, true, true, true])
    }

    func testFixedGenerationTerminationIgnoresThePopulation() {
        let counter = FitnessCallCounter()
        let check = ScoredDefaultOperators.fixedGenerationTermination(maxGenerations: 2)
        let population = (0 ..< 5).map { ScoredIndividual(id: $0, score: 1000, counter: counter) }

        XCTAssertFalse(check(1, population))
        XCTAssertTrue(check(2, []))
        XCTAssertEqual(counter.calls, 0)
    }

    func testFixedGenerationTerminationWithZeroOrNegativeMaxPassesImmediately() {
        XCTAssertTrue(ScoredDefaultOperators.fixedGenerationTermination(maxGenerations: 0)(0, []))
        XCTAssertTrue(ScoredDefaultOperators.fixedGenerationTermination(maxGenerations: -1)(0, []))
    }
}
