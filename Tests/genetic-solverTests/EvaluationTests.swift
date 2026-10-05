//  EvaluationTests.swift
//  genetic-solverTests
//
//  Tests that the solver evaluates each individual's fitness once and passes
//  the result along with the individual, as an EvaluatedElement.

import XCTest
@testable import genetic_solver

// MARK: - EvaluationLog

/// Records which individuals had `fitness()` called, and how often.
private final class EvaluationLog {
    // MARK: Properties

    private(set) var callsPerID: [Int: Int] = [:]

    private var nextID = 0

    // MARK: Computed Properties

    var total: Int {
        callsPerID.values.reduce(0, +)
    }

    // MARK: Functions

    func record(_ id: Int) {
        callsPerID[id, default: 0] += 1
    }

    /// A new individual with the next id.
    func make(score: Int) -> Tracked {
        defer { nextID += 1 }
        return Tracked(id: nextID, score: score, log: self)
    }
}

// MARK: - Tracked

/// An individual whose `fitness()` calls are recorded by id.
private struct Tracked: GeneticElement {
    // MARK: Properties

    let id: Int
    let score: Int
    let log: EvaluationLog

    // MARK: Functions

    func fitness() -> Int {
        log.record(id)
        return score
    }
}

// MARK: - Point

/// A pure individual for value-semantics tests.
private struct Point: GeneticElement, Hashable {
    // MARK: Properties

    let x: Int

    // MARK: Functions

    func fitness() -> Int {
        x * x
    }
}

// MARK: - EvaluationTests

final class EvaluationTests: XCTestCase {
    // MARK: EvaluatedElement

    func testEvaluatedElementEvaluatesOnceAndKeepsTheResult() {
        let log = EvaluationLog()
        let individual = log.make(score: 7)

        let evaluated = EvaluatedElement(individual)
        let readings = (0 ..< 5).map { _ in evaluated.fitness }

        XCTAssertEqual(readings, [7, 7, 7, 7, 7])
        XCTAssertEqual(evaluated.element.id, individual.id)
        XCTAssertEqual(log.callsPerID, [individual.id: 1])
    }

    func testEvaluatedElementIsEquatableAndHashableWhenItsElementIs() {
        let three = EvaluatedElement(Point(x: 3))

        XCTAssertEqual(three, EvaluatedElement(Point(x: 3)))
        XCTAssertNotEqual(three, EvaluatedElement(Point(x: -3)), "Same fitness, different individual")
        XCTAssertEqual(Set([three, EvaluatedElement(Point(x: 3)), EvaluatedElement(Point(x: 4))]).count, 2)
    }

    // MARK: Creating populations

    func testInitAndResetEvaluateEachNewIndividualOnce() {
        let log = EvaluationLog()
        var solver = makeSolver(log: log, populationSize: 5)
        XCTAssertEqual(log.callsPerID, Dictionary(uniqueKeysWithValues: (0 ..< 5).map { ($0, 1) }))

        solver.reset()

        XCTAssertEqual(log.callsPerID, Dictionary(uniqueKeysWithValues: (0 ..< 10).map { ($0, 1) }))
        XCTAssertEqual(solver.currentPopulation.map(\.element.id), [5, 6, 7, 8, 9])
    }

    // MARK: One generation

    /// Crossover is skipped and nothing mutates, so the next generation
    /// consists of copied parents, which keep the fitness they have.
    func testCopiedParentsAreNotEvaluatedAgain() {
        let log = EvaluationLog()
        var solver = makeSolver(log: log, populationSize: 4, crossoverRate: 0, mutationRate: 0)
        let callsAfterInit = log.callsPerID

        solver.step()

        XCTAssertEqual(log.callsPerID, callsAfterInit)
        XCTAssertEqual(solver.currentPopulation.map(\.element.id), [0, 1, 0, 1])
        XCTAssertEqual(solver.currentPopulation.map(\.fitness), [10, 11, 10, 11])
    }

    func testChildrenOfCrossoverAreEvaluatedOnce() {
        let log = EvaluationLog()
        var solver = makeSolver(log: log, populationSize: 4, crossoverRate: 1, mutationRate: 0)

        solver.step()

        // Ids 0-3 are the starting population, 4-7 the children.
        XCTAssertEqual(log.callsPerID, Dictionary(uniqueKeysWithValues: (0 ..< 8).map { ($0, 1) }))
        XCTAssertEqual(solver.currentPopulation.map(\.element.id), [4, 5, 6, 7])
    }

    /// A mutated copy of a parent is a new individual, so it is evaluated,
    /// and its fitness is its own, not the parent's.
    func testMutatedCopiesAreEvaluatedWithTheirOwnFitness() {
        let log = EvaluationLog()
        var solver = makeSolver(log: log, populationSize: 4, crossoverRate: 0, mutationRate: 1)

        solver.step()

        XCTAssertEqual(log.total, 8, "4 starting individuals and 4 mutants")
        XCTAssertEqual(solver.currentPopulation.map(\.fitness), solver.currentPopulation.map(\.element.score))
        XCTAssertEqual(solver.currentPopulation.map(\.fitness), [1000, 1001, 1002, 1003])
    }

    /// A child that is mutated is only evaluated after mutation: the
    /// unmutated child is never evaluated.
    func testMutatedChildrenAreEvaluatedOnlyAfterMutation() {
        let log = EvaluationLog()
        var solver = makeSolver(log: log, populationSize: 2, crossoverRate: 1, mutationRate: 1)

        solver.step()

        // 0-1: starting population; 2-3: children; 4-5: mutated children.
        XCTAssertNil(log.callsPerID[2])
        XCTAssertNil(log.callsPerID[3])
        XCTAssertEqual(log.callsPerID[4], 1)
        XCTAssertEqual(log.callsPerID[5], 1)
        XCTAssertEqual(solver.currentPopulation.map(\.element.id), [4, 5])
    }

    // MARK: Consumers of fitness

    /// Selection, replacement, the termination check and bestElement all read
    /// the stored fitness, so over a whole run each individual is evaluated
    /// exactly once, however often they look at it.
    func testOperatorsTerminationCheckAndBestElementDoNotEvaluate() {
        let log = EvaluationLog()
        var solver = GeneticSolver<Tracked>(
            populationSize: 20,
            crossoverRate: 0.7,
            mutationRate: 0.2,
            selectionOperator: GeneticSolver.tournamentSelection(using: SeededRandomNumberGenerator(seed: 1)),
            crossoverOperator: { first, second in [log.make(score: (first.score + second.score) / 2), log.make(score: first.score)] },
            mutationOperator: { log.make(score: $0.score + 1) },
            replacementOperator: GeneticSolver.elitistReplacement(eliteCount: 2),
            terminationCheck: { _, population in population.allSatisfy { $0.fitness >= 1_000_000 } },
            newElement: { log.make(score: 0) }
        )
        solver.randomNumberGenerator = SeededRandomNumberGenerator(seed: 2)

        for _ in 0 ..< 100 {
            solver.step()
            _ = solver.bestElement
            _ = solver.bestElement.fitness
        }

        XCTAssertFalse(log.callsPerID.isEmpty)
        XCTAssertEqual(Set(log.callsPerID.values), [1], "No individual is evaluated twice")
    }

    /// The stored fitness always matches the individual it belongs to.
    func testStoredFitnessAlwaysMatchesTheIndividual() {
        var random = SeededRandomNumberGenerator(seed: 5)
        var solver = GeneticSolver<Point>(
            populationSize: 15,
            crossoverRate: 0.6,
            mutationRate: 0.3,
            selectionOperator: GeneticSolver.tournamentSelection(using: SeededRandomNumberGenerator(seed: 6)),
            // Coordinates stay between -1000 and 1000, so x * x can't overflow.
            crossoverOperator: { [Point(x: ($0.x + $1.x) / 2), Point(x: ($0.x - $1.x) % 50)] },
            mutationOperator: { Point(x: min(1000, max(-1000, $0.x + Int.random(in: -3 ... 3, using: &random)))) },
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: { Point(x: Int.random(in: -10 ... 10, using: &random)) }
        )
        solver.randomNumberGenerator = SeededRandomNumberGenerator(seed: 7)

        for generation in 0 ..< 200 {
            XCTAssertTrue(solver.currentPopulation.allSatisfy { $0.fitness == $0.element.fitness() }, "Generation \(generation)")
            solver.step()
        }
    }

    /// A replacement operator can add individuals of its own: wrapping them
    /// in `EvaluatedElement` evaluates them once.
    func testReplacementCanAddIndividualsOfItsOwn() {
        let log = EvaluationLog()
        var solver = makeSolver(log: log, populationSize: 3, crossoverRate: 0, mutationRate: 0)
        solver.replacementOperator = { _, new in Array(new.dropLast()) + [EvaluatedElement(log.make(score: 99))] }

        solver.step()

        XCTAssertEqual(solver.currentPopulation.map(\.element.id), [0, 1, 3])
        XCTAssertEqual(solver.currentPopulation.map(\.fitness), [10, 11, 99])
        XCTAssertEqual(log.callsPerID[3], 1)
        XCTAssertEqual(solver.bestElement.element.id, 3)
    }

    // MARK: Helpers

    /// A solver whose starting individuals have scores 10, 11, 12, ...,
    /// whose selection picks the first two, whose crossover makes two new
    /// children with the parents' scores, and whose mutation makes a new
    /// individual scoring 1000 more than the one it replaces, numbered in
    /// order.
    private func makeSolver(
        log: EvaluationLog,
        populationSize: Int,
        crossoverRate: Double = 0.5,
        mutationRate: Double = 0
    )
        -> GeneticSolver<Tracked>
    {
        var startingScore = 10
        var mutations = 0
        return GeneticSolver<Tracked>(
            populationSize: populationSize,
            crossoverRate: crossoverRate,
            mutationRate: mutationRate,
            selectionOperator: { ($0[0], $0[min(1, $0.count - 1)]) },
            crossoverOperator: { [log.make(score: $0.score), log.make(score: $1.score)] },
            mutationOperator: { _ in
                defer { mutations += 1 }
                return log.make(score: 1000 + mutations)
            },
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: {
                defer { startingScore += 1 }
                return log.make(score: startingScore)
            }
        )
    }
}
