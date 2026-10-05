//  SolverLifecycleTests.swift
//  genetic-solverTests
//
//  Tests how init, step(), solve(maxGenerations:) and reset() share the
//  solver's population and generation count.

import XCTest
@testable import genetic_solver

// MARK: - SolverLifecycleTests

final class SolverLifecycleTests: XCTestCase {
    // MARK: init

    func testInitCreatesOnePopulation() {
        let factory = ElementFactory()
        let solver = makeDeterministicSolver(populationSize: 5, factory: factory)

        XCTAssertEqual(factory.createdCount, 5)
        XCTAssertEqual(solver.currentPopulation.map(\.id), [0, 1, 2, 3, 4])
        XCTAssertEqual(solver.currentGeneration, 0)
    }

    // MARK: solve

    func testSolveUsesThePopulationCreatedByInit() {
        let factory = ElementFactory()
        var solver = makeDeterministicSolver(factory: factory)

        let result = solver.solve(maxGenerations: 1)

        XCTAssertEqual(factory.createdCount, 4, "solve should not create a new population")
        XCTAssertEqual(result.map(\.id), [0, 1, 0, 1])
        XCTAssertEqual(solver.currentGeneration, 1)
    }

    func testSolveWithZeroMaxGenerationsReturnsTheCurrentPopulationUnchanged() {
        let factory = ElementFactory()
        var solver = makeDeterministicSolver(factory: factory)

        let result = solver.solve(maxGenerations: 0)

        XCTAssertEqual(result.map(\.id), [0, 1, 2, 3])
        XCTAssertEqual(solver.currentGeneration, 0)
        XCTAssertEqual(factory.createdCount, 4)
    }

    func testSolveWithNegativeMaxGenerationsRunsNothing() {
        let factory = ElementFactory()
        var solver = makeDeterministicSolver(factory: factory)

        let result = solver.solve(maxGenerations: -5)

        XCTAssertEqual(result.map(\.id), [0, 1, 2, 3])
        XCTAssertEqual(solver.currentGeneration, 0)
    }

    func testSolveContinuesAfterStep() {
        let factory = ElementFactory()
        var solver = makeDeterministicSolver(factory: factory)

        solver.step()
        solver.step()
        solver.step()
        let result = solver.solve(maxGenerations: 5)

        XCTAssertEqual(solver.currentGeneration, 5, "maxGenerations caps the total generation count")
        XCTAssertEqual(result.map(\.id), [0, 1, 0, 1])
        XCTAssertEqual(factory.createdCount, 4)
    }

    func testSolveDoesNothingWhenMaxGenerationsAlreadyReached() {
        let factory = ElementFactory()
        var solver = makeDeterministicSolver(factory: factory)
        solver.step()
        solver.step()
        solver.step()
        let populationBefore = solver.currentPopulation

        let result = solver.solve(maxGenerations: 2)

        XCTAssertEqual(solver.currentGeneration, 3)
        XCTAssertEqual(result, populationBefore)
    }

    func testSecondSolveContinuesFromTheFirst() {
        let factory = ElementFactory()
        var solver = makeDeterministicSolver(factory: factory)

        _ = solver.solve(maxGenerations: 2)
        _ = solver.solve(maxGenerations: 2)
        XCTAssertEqual(solver.currentGeneration, 2, "a second call with the same cap runs nothing")

        _ = solver.solve(maxGenerations: 6)
        XCTAssertEqual(solver.currentGeneration, 6)
        XCTAssertEqual(factory.createdCount, 4)
    }

    func testSolveReturnsTheCurrentPopulation() {
        var solver = makeDeterministicSolver(factory: ElementFactory())

        let result = solver.solve(maxGenerations: 3)

        XCTAssertEqual(result, solver.currentPopulation)
    }

    func testSolveStopsAtTerminationAndKeepsThatState() {
        let factory = ElementFactory()
        var solver = makeDeterministicSolver(factory: factory, terminationCheck: { generation, _ in generation >= 2 })

        _ = solver.solve(maxGenerations: 10)
        XCTAssertEqual(solver.currentGeneration, 2)

        _ = solver.solve(maxGenerations: 10)
        XCTAssertEqual(solver.currentGeneration, 2, "a terminated solver stays terminated")
        XCTAssertEqual(factory.createdCount, 4)
    }

    // MARK: reset

    func testResetCreatesANewPopulationAndRestartsTheGenerationCount() {
        let factory = ElementFactory()
        var solver = makeDeterministicSolver(factory: factory)
        _ = solver.solve(maxGenerations: 3)

        solver.reset()

        XCTAssertEqual(solver.currentGeneration, 0)
        XCTAssertEqual(solver.currentPopulation.map(\.id), [4, 5, 6, 7])
        XCTAssertEqual(factory.createdCount, 8)
    }

    func testResetUsesTheCurrentPopulationSize() {
        let factory = ElementFactory()
        var solver = makeDeterministicSolver(populationSize: 4, factory: factory)

        solver.populationSize = 6
        solver.reset()

        XCTAssertEqual(solver.currentPopulation.count, 6)
    }

    func testResetUsesTheCurrentNewElementClosure() {
        var solver = makeDeterministicSolver(factory: ElementFactory())

        solver.newElement = { TestIndividual(gene: .one, id: -1) }
        solver.reset()

        XCTAssertTrue(solver.currentPopulation.allSatisfy { $0.gene == .one && $0.id == -1 })
    }

    func testSolveAfterResetRunsFromGenerationZero() {
        let factory = ElementFactory()
        var solver = makeDeterministicSolver(factory: factory, terminationCheck: { generation, _ in generation >= 2 })
        _ = solver.solve(maxGenerations: 10)

        solver.reset()
        let result = solver.solve(maxGenerations: 10)

        XCTAssertEqual(solver.currentGeneration, 2)
        XCTAssertEqual(result.map(\.id), [4, 5, 4, 5])
    }

    // MARK: Copies

    func testCopiesHaveTheirOwnPopulationAndGenerationCount() {
        var original = makeDeterministicSolver()
        var copy = original

        original.step()
        original.step()
        copy.reset()

        XCTAssertEqual(original.currentGeneration, 2)
        XCTAssertEqual(original.currentPopulation.map(\.id), [0, 1, 0, 1])
        XCTAssertEqual(copy.currentGeneration, 0)
        XCTAssertEqual(copy.currentPopulation.map(\.id), [4, 5, 6, 7])
    }

    /// Operators are closures, so state they capture is shared by copies.
    func testCopiesShareStateCapturedByOperators() {
        var checks = 0
        var original = makeDeterministicSolver(terminationCheck: { _, _ in checks += 1; return false })
        var copy = original

        original.step()
        copy.step()

        XCTAssertEqual(checks, 3, "Once in init, then once for each copy's generation")
    }
}
