//  OperatorsInitializerTests.swift
//  genetic-solverTests
//
//  Tests GeneticSolver(populationSize:crossoverRate:mutationRate:operators:terminationCheck:).

import XCTest
@testable import genetic_solver

// MARK: - RecordingOperators

/// Records which operators were called. Crossover adds 10 to each parent's
/// id and mutation adds 100, so the ids show which operators produced an
/// individual.
private enum RecordingOperators: GeneticOperators {
    // MARK: Static Properties

    static var calls: [String] = []
    static var nextID = 0

    // MARK: Static Functions

    static func reset() {
        calls = []
        nextID = 0
    }

    static func selectionOperator(population: [TestIndividual]) -> (TestIndividual, TestIndividual) {
        calls.append("selection")
        return (population[0], population[1])
    }

    static func crossoverOperator(parent1: TestIndividual, parent2: TestIndividual) -> [TestIndividual] {
        calls.append("crossover")
        return [TestIndividual(gene: parent1.gene, id: parent1.id + 10), TestIndividual(gene: parent2.gene, id: parent2.id + 10)]
    }

    static func mutationOperator(element: TestIndividual) -> TestIndividual {
        calls.append("mutation")
        return TestIndividual(gene: element.gene, id: element.id + 100)
    }

    static func replacementOperator(old _: [TestIndividual], new: [TestIndividual]) -> [TestIndividual] {
        calls.append("replacement")
        return new
    }

    static func newElement() -> TestIndividual {
        calls.append("newElement")
        defer { nextID += 1 }
        return TestIndividual(gene: .zero, id: nextID)
    }
}

// MARK: - NewElementOnlyOperators

/// Implements only `newElement()`, so every other operator is a default.
private enum NewElementOnlyOperators: GeneticOperators {
    // MARK: Static Properties

    static var nextID = 0

    // MARK: Static Functions

    static func newElement() -> TestIndividual {
        defer { nextID += 1 }
        return TestIndividual(gene: .zero, id: nextID)
    }
}

// MARK: - OperatorsInitializerTests

final class OperatorsInitializerTests: XCTestCase {
    // MARK: Overridden Functions

    override func setUp() {
        super.setUp()
        RecordingOperators.reset()
        NewElementOnlyOperators.nextID = 0
    }

    // MARK: Functions

    func testInitCreatesThePopulationWithNewElement() {
        let solver = GeneticSolver(
            populationSize: 2,
            operators: RecordingOperators.self,
            terminationCheck: { _, _ in false }
        )

        XCTAssertEqual(RecordingOperators.calls, ["newElement", "newElement"])
        XCTAssertEqual(solver.currentPopulation.map(\.id), [0, 1])
    }

    func testStepUsesTheOperatorsOfTheType() {
        var solver = GeneticSolver(
            populationSize: 2,
            crossoverRate: 1,
            mutationRate: 1,
            operators: RecordingOperators.self,
            terminationCheck: { _, _ in false }
        )
        RecordingOperators.calls = []

        solver.step()

        XCTAssertEqual(RecordingOperators.calls, ["selection", "crossover", "mutation", "mutation", "replacement"])
        XCTAssertEqual(solver.currentPopulation.map(\.id), [110, 111])
    }

    func testResetUsesNewElementOfTheType() {
        var solver = GeneticSolver(
            populationSize: 2,
            operators: RecordingOperators.self,
            terminationCheck: { _, _ in false }
        )

        solver.reset()

        XCTAssertEqual(solver.currentPopulation.map(\.id), [2, 3])
    }

    func testInitPassesTheParametersThrough() {
        let solver = GeneticSolver(
            populationSize: 3,
            crossoverRate: 0.25,
            mutationRate: 0.5,
            operators: RecordingOperators.self,
            terminationCheck: { _, _ in false }
        )

        XCTAssertEqual(solver.populationSize, 3)
        XCTAssertEqual(solver.crossoverRate, 0.25)
        XCTAssertEqual(solver.mutationRate, 0.5)
    }

    func testInitUsesTheSameDefaultRatesAsTheMainInitializer() {
        let withOperators = GeneticSolver(
            populationSize: 2,
            operators: RecordingOperators.self,
            terminationCheck: { _, _ in false }
        )
        let withClosures = GeneticSolver<TestIndividual>(
            populationSize: 2,
            selectionOperator: { ($0[0], $0[1]) },
            crossoverOperator: { [$0, $1] },
            mutationOperator: { $0 },
            replacementOperator: { _, new in new },
            terminationCheck: { _, _ in false },
            newElement: { TestIndividual(gene: .zero, id: 0) }
        )

        XCTAssertEqual(withOperators.crossoverRate, withClosures.crossoverRate)
        XCTAssertEqual(withOperators.mutationRate, withClosures.mutationRate)
    }

    func testInitUsesTheTerminationCheck() {
        let recorder = TerminationRecorder(decide: { generation, _ in generation >= 2 })
        var solver = GeneticSolver(
            populationSize: 2,
            operators: RecordingOperators.self,
            terminationCheck: recorder.check
        )

        _ = solver.solve(maxGenerations: 10)

        XCTAssertEqual(recorder.generations, [0, 1, 2])
        XCTAssertTrue(solver.isTerminated)
    }

    func testFixedGenerationTerminationOfTheTypeStopsAtThatGeneration() {
        var solver = GeneticSolver(
            populationSize: 2,
            operators: RecordingOperators.self,
            terminationCheck: RecordingOperators.fixedGenerationTermination(maxGenerations: 3)
        )

        _ = solver.solve(maxGenerations: 100)

        XCTAssertEqual(solver.currentGeneration, 3)
        XCTAssertTrue(solver.isTerminated)
    }

    func testTypeImplementingOnlyNewElementUsesTheDefaultOperators() {
        var solver = GeneticSolver(
            populationSize: 6,
            crossoverRate: 1,
            mutationRate: 1,
            operators: NewElementOnlyOperators.self,
            terminationCheck: { _, _ in false }
        )
        let initialIDs = Set(solver.currentPopulation.map(\.id))

        _ = solver.solve(maxGenerations: 5)

        // The default crossover and mutation return their input unchanged and
        // the default replacement keeps only the new individuals, so every
        // individual is still one of the starting ones.
        XCTAssertEqual(solver.currentGeneration, 5)
        XCTAssertEqual(solver.currentPopulation.count, 6)
        XCTAssertTrue(solver.currentPopulation.allSatisfy { initialIDs.contains($0.id) })
        XCTAssertEqual(NewElementOnlyOperators.nextID, 6, "Only init should create individuals")
    }

    func testOperatorsCanBeReplacedAfterInit() {
        var solver = GeneticSolver(
            populationSize: 2,
            crossoverRate: 0,
            mutationRate: 1,
            operators: RecordingOperators.self,
            terminationCheck: { _, _ in false }
        )
        solver.mutationOperator = { TestIndividual(gene: .one, id: $0.id + 1000) }
        RecordingOperators.calls = []

        solver.step()

        XCTAssertEqual(RecordingOperators.calls, ["selection", "replacement"])
        XCTAssertEqual(solver.currentPopulation.map(\.id), [1000, 1001])
    }
}
