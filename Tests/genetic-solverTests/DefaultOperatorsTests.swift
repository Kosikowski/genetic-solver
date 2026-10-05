//  DefaultOperatorsTests.swift
//  genetic-solverTests
//
//  Tests the default implementations that GeneticOperators provides.

import XCTest
@testable import genetic_solver

// MARK: - FitnessCounter

/// Counts how many times `fitness()` is called, across all individuals that
/// share the counter.
private final class FitnessCounter {
    var calls = 0
}

// MARK: - CountingIndividual

private struct CountingIndividual: GeneticElement, FitnessEvaluatable {
    // MARK: Properties

    let id: Int
    let value: Int
    let counter: FitnessCounter

    // MARK: Functions

    func fitness() -> Int {
        counter.calls += 1
        return value
    }
}

// MARK: - DefaultOperators

/// Implements only the required `newElement()`, so every other operator is
/// the protocol's default implementation.
private enum DefaultOperators: GeneticOperators {
    static func newElement() -> CountingIndividual {
        CountingIndividual(id: 0, value: 0, counter: FitnessCounter())
    }
}

// MARK: - DefaultOperatorsTests

final class DefaultOperatorsTests: XCTestCase {
    // MARK: Selection

    func testSelectionEvaluatesEachCandidateOnce() {
        let counter = FitnessCounter()
        let population = (0 ..< 100).map { CountingIndividual(id: $0, value: $0, counter: counter) }

        _ = DefaultOperators.selectionOperator(population: population)

        // Two tournaments of three candidates each.
        XCTAssertEqual(counter.calls, 6)
    }

    func testSelectionReturnsMembersOfThePopulation() {
        let counter = FitnessCounter()
        let population = (0 ..< 10).map { CountingIndividual(id: $0, value: $0 % 3, counter: counter) }
        let ids = Set(population.map(\.id))

        for _ in 0 ..< 1000 {
            let (first, second) = DefaultOperators.selectionOperator(population: population)
            XCTAssertTrue(ids.contains(first.id))
            XCTAssertTrue(ids.contains(second.id))
        }
    }

    func testSelectionWithSingleIndividualReturnsItTwice() {
        let only = CountingIndividual(id: 7, value: 1, counter: FitnessCounter())

        let (first, second) = DefaultOperators.selectionOperator(population: [only])

        XCTAssertEqual(first.id, 7)
        XCTAssertEqual(second.id, 7)
    }

    /// In a tournament of three, the weaker of two individuals only wins when
    /// all three candidates are the weaker one: (1/2)^3 = 12.5% of the time.
    func testSelectionPicksTheBestOfThreeCandidates() {
        let counter = FitnessCounter()
        let weak = CountingIndividual(id: 0, value: 0, counter: counter)
        let strong = CountingIndividual(id: 1, value: 1, counter: counter)
        let picks = 10000

        var weakPicks = 0
        for _ in 0 ..< picks / 2 {
            let (first, second) = DefaultOperators.selectionOperator(population: [weak, strong])
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
        let counter = FitnessCounter()
        let population = (0 ..< 2).map { CountingIndividual(id: $0, value: 5, counter: counter) }

        let differentPairs = (0 ..< 1000).filter { _ in
            let (first, second) = DefaultOperators.selectionOperator(population: population)
            return first.id != second.id
        }.count

        XCTAssertGreaterThan(differentPairs, 0)
    }
}
