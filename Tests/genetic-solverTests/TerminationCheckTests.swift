//  TerminationCheckTests.swift
//  genetic-solverTests
//
//  Tests that the solver calls terminationCheck exactly once for each
//  population, keeps the result in isTerminated, and calls it again on
//  request with checkTermination().

import XCTest
@testable import genetic_solver

// MARK: - TerminationCheckTests

final class TerminationCheckTests: XCTestCase {
    // MARK: Calls per population

    func testCheckIsCalledOnceForTheInitialPopulation() {
        let recorder = TerminationRecorder()
        let solver = makeDeterministicSolver(terminationCheck: recorder.check)

        XCTAssertEqual(recorder.generations, [0])
        XCTAssertEqual(recorder.populations, [[0, 1, 2, 3]])
        XCTAssertFalse(solver.isTerminated)
    }

    func testSolveCallsTheCheckOncePerGeneration() {
        let recorder = TerminationRecorder()
        var solver = makeDeterministicSolver(terminationCheck: recorder.check)

        _ = solver.solve(maxGenerations: 5)

        XCTAssertEqual(recorder.generations, [0, 1, 2, 3, 4, 5])
    }

    func testStepCallsTheCheckOncePerGeneration() {
        let recorder = TerminationRecorder()
        var solver = makeDeterministicSolver(terminationCheck: recorder.check)

        for expectedGeneration in 1 ... 3 {
            solver.step()
            XCTAssertEqual(recorder.generations, Array(0 ... expectedGeneration))
        }
    }

    func testCheckReceivesThePopulationAfterReplacement() {
        let recorder = TerminationRecorder()
        var solver = makeDeterministicSolver(terminationCheck: recorder.check)

        solver.step()

        XCTAssertEqual(recorder.populations.last, solver.currentPopulation.map(\.id))
        XCTAssertEqual(recorder.populations.last, [0, 1, 0, 1])
    }

    // MARK: isTerminated and step()

    func testStepReturnsIsTerminated() {
        var solver = makeDeterministicSolver(terminationCheck: { generation, _ in generation >= 2 })

        XCTAssertFalse(solver.step())
        XCTAssertFalse(solver.isTerminated)
        XCTAssertTrue(solver.step())
        XCTAssertTrue(solver.isTerminated)
    }

    func testStepAfterTerminationRunsNothingAndDoesNotCallTheCheck() {
        let recorder = TerminationRecorder(decide: { generation, _ in generation >= 2 })
        var solver = makeDeterministicSolver(terminationCheck: recorder.check)
        _ = solver.solve(maxGenerations: 10)
        let populationBefore = solver.currentPopulation

        XCTAssertTrue(solver.step())
        XCTAssertTrue(solver.step())

        XCTAssertEqual(solver.currentGeneration, 2)
        XCTAssertEqual(solver.currentPopulation, populationBefore)
        XCTAssertEqual(recorder.generations, [0, 1, 2])
    }

    func testTerminationAtGenerationZeroRunsNoGenerations() {
        var selectionCalls = 0
        let recorder = TerminationRecorder(decide: { _, _ in true })
        var solver = GeneticSolver<TestIndividual>(
            populationSize: 4,
            selectionOperator: { selectionCalls += 1; return ($0[0], $0[1]) },
            crossoverOperator: { [$0, $1] },
            mutationOperator: { $0 },
            replacementOperator: { _, new in new },
            terminationCheck: recorder.check,
            newElement: ElementFactory().make
        )

        XCTAssertTrue(solver.isTerminated)
        XCTAssertTrue(solver.step())
        _ = solver.solve(maxGenerations: 10)

        XCTAssertEqual(solver.currentGeneration, 0)
        XCTAssertEqual(selectionCalls, 0)
        XCTAssertEqual(recorder.generations, [0])
    }

    func testStoppingAtMaxGenerationsDoesNotMarkTheSolverTerminated() {
        let recorder = TerminationRecorder()
        var solver = makeDeterministicSolver(terminationCheck: recorder.check)

        _ = solver.solve(maxGenerations: 3)
        XCTAssertFalse(solver.isTerminated)

        _ = solver.solve(maxGenerations: 5)
        XCTAssertEqual(solver.currentGeneration, 5)
        XCTAssertEqual(recorder.generations, [0, 1, 2, 3, 4, 5])
    }

    // MARK: reset()

    func testResetCallsTheCheckOnceAndClearsTermination() {
        let recorder = TerminationRecorder(decide: { generation, _ in generation >= 2 })
        var solver = makeDeterministicSolver(terminationCheck: recorder.check)
        _ = solver.solve(maxGenerations: 10)
        XCTAssertTrue(solver.isTerminated)

        solver.reset()

        XCTAssertFalse(solver.isTerminated)
        XCTAssertEqual(recorder.generations, [0, 1, 2, 0])
        XCTAssertEqual(recorder.populations.last, [4, 5, 6, 7])

        _ = solver.solve(maxGenerations: 10)
        XCTAssertEqual(solver.currentGeneration, 2)
    }

    func testResetKeepsTheSolverTerminatedWhenTheNewPopulationMeetsTheCheck() {
        var solver = makeDeterministicSolver(terminationCheck: { _, population in population.contains { $0.id >= 4 } })
        XCTAssertFalse(solver.isTerminated)

        solver.reset()

        XCTAssertTrue(solver.isTerminated)
        XCTAssertTrue(solver.step())
        XCTAssertEqual(solver.currentGeneration, 0)
    }

    // MARK: Replacing the check

    func testReplacingTheCheckCallsItOnceForTheCurrentPopulation() {
        var solver = makeDeterministicSolver()
        solver.step()
        solver.step()
        let recorder = TerminationRecorder()

        solver.terminationCheck = recorder.check

        XCTAssertEqual(recorder.generations, [2])
        XCTAssertEqual(recorder.populations, [solver.currentPopulation.map(\.id)])
    }

    func testReplacingTheCheckLetsATerminatedSolverContinue() {
        var solver = makeDeterministicSolver(terminationCheck: { generation, _ in generation >= 2 })
        _ = solver.solve(maxGenerations: 10)
        XCTAssertTrue(solver.isTerminated)

        solver.terminationCheck = { generation, _ in generation >= 4 }

        XCTAssertFalse(solver.isTerminated)
        _ = solver.solve(maxGenerations: 10)
        XCTAssertEqual(solver.currentGeneration, 4)
    }

    func testReplacingTheCheckWithOneThatPassesStopsTheSolver() {
        var solver = makeDeterministicSolver()
        solver.step()

        solver.terminationCheck = { _, _ in true }

        XCTAssertTrue(solver.isTerminated)
        XCTAssertTrue(solver.step())
        XCTAssertEqual(solver.currentGeneration, 1)
    }

    // MARK: checkTermination()

    func testCheckTerminationCallsTheCheckOnceForTheCurrentPopulation() {
        let recorder = TerminationRecorder()
        var solver = makeDeterministicSolver(terminationCheck: recorder.check)
        solver.step()
        solver.step()
        let populationBefore = solver.currentPopulation.map(\.id)

        XCTAssertFalse(solver.checkTermination())

        XCTAssertEqual(recorder.generations, [0, 1, 2, 2])
        XCTAssertEqual(recorder.populations.last, populationBefore)
        XCTAssertEqual(solver.currentPopulation.map(\.id), populationBefore, "Runs no generation")
        XCTAssertEqual(solver.currentGeneration, 2)
        XCTAssertFalse(solver.isTerminated)
    }

    /// The check runs after each generation, not before the next one, so a
    /// change to outside state is seen after the next generation.
    func testCheckThatReadsOutsideStateSeesAChangeAfterTheNextGeneration() {
        var cancelled = false
        var solver = makeDeterministicSolver(terminationCheck: { _, _ in cancelled })
        solver.step()

        cancelled = true

        XCTAssertFalse(solver.isTerminated, "Not checked since the flag changed")
        XCTAssertTrue(solver.step(), "Runs one more generation, then sees the flag")
        XCTAssertEqual(solver.currentGeneration, 2)
    }

    func testCheckTerminationAppliesAChangeInOutsideStateRightAway() {
        var cancelled = false
        var solver = makeDeterministicSolver(terminationCheck: { _, _ in cancelled })
        solver.step()

        cancelled = true
        XCTAssertTrue(solver.checkTermination())

        XCTAssertTrue(solver.isTerminated)
        XCTAssertTrue(solver.step())
        _ = solver.solve(maxGenerations: 10)
        XCTAssertEqual(solver.currentGeneration, 1, "No generation runs after the flag is applied")
    }

    /// A check whose limit is captured from outside stops the run; raising
    /// the limit and calling `checkTermination()` lets the run continue.
    func testCheckTerminationLetsTheRunContinueAfterTheOutsideLimitIsRaised() {
        var limit = 3
        var solver = makeDeterministicSolver(terminationCheck: { generation, _ in generation >= limit })
        _ = solver.solve(maxGenerations: 10)
        XCTAssertEqual(solver.currentGeneration, 3)

        limit = 6
        _ = solver.solve(maxGenerations: 10)
        XCTAssertEqual(solver.currentGeneration, 3, "Still terminated: the check hasn't run since")

        XCTAssertFalse(solver.checkTermination())
        _ = solver.solve(maxGenerations: 10)
        XCTAssertEqual(solver.currentGeneration, 6)
        XCTAssertTrue(solver.isTerminated)
    }

    func testCheckTerminationKeepsATerminatedSolverTerminatedWhenTheCheckStillPasses() {
        let recorder = TerminationRecorder(decide: { generation, _ in generation >= 1 })
        var solver = makeDeterministicSolver(terminationCheck: recorder.check)
        solver.step()

        XCTAssertTrue(solver.checkTermination())

        XCTAssertTrue(solver.isTerminated)
        XCTAssertEqual(recorder.generations, [0, 1, 1])
    }

    // MARK: Checks with their own state

    /// A check that counts generations without improvement only works if it
    /// sees each generation exactly once.
    func testCheckWithOwnStateSeesEachGenerationOnce() {
        var bestSoFar = -Double.infinity
        var generationsWithoutImprovement = 0
        let patience = 3
        // The deterministic solver never changes fitness, so the best fitness
        // stops improving right after the initial population.
        var solver = makeDeterministicSolver(terminationCheck: { _, population in
            let currentBest = population.map { $0.fitness() }.max() ?? 0
            if currentBest > bestSoFar {
                bestSoFar = currentBest
                generationsWithoutImprovement = 0
            } else {
                generationsWithoutImprovement += 1
            }
            return generationsWithoutImprovement >= patience
        })

        _ = solver.solve(maxGenerations: 100)

        XCTAssertEqual(solver.currentGeneration, patience)
    }
}
